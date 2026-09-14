package com.dolce.musicplayer;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.core.app.NotificationCompat;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class BackgroundAudioService extends Service {
    public static final String CHANNEL_ID = "DOLCE_AUDIO_BACKGROUND_CHANNEL_V3";
    public static final int NOTIFICATION_ID = 1001;

    public static final String ACTION_PREVIOUS = "com.dolce.musicplayer.ACTION_PREVIOUS";
    public static final String ACTION_TOGGLE_PLAY_PAUSE = "com.dolce.musicplayer.ACTION_TOGGLE_PLAY_PAUSE";
    public static final String ACTION_NEXT = "com.dolce.musicplayer.ACTION_NEXT";

    private PowerManager.WakeLock wakeLock;
    private WifiManager.WifiLock wifiLock;
    private AudioManager audioManager;
    private AudioFocusRequest audioFocusRequest;
    private MediaSessionCompat mediaSession;
    private WebView serviceWebView;
    private Handler mainHandler = new Handler(Looper.getMainLooper());

    private String currentVideoId = "";
    private String currentTitle = "DOLCE Music";
    private String currentArtist = "Ambient Music Streaming";
    private String currentArtworkUrl = "";
    private boolean currentIsPlaying = false;
    private Bitmap currentArtworkBitmap = null;
    private boolean isPlayerReady = false;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        initMediaSession();
        acquireLocksAndFocus();
        initServiceWebView();
    }

    private void initMediaSession() {
        try {
            mediaSession = new MediaSessionCompat(this, "DOLCE_MEDIA_SESSION");
            mediaSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS | MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);
            
            mediaSession.setCallback(new MediaSessionCompat.Callback() {
                @Override
                public void onPlay() {
                    togglePlayPauseInService();
                    MainActivity.sendMediaControlToWeb("togglePlayPause");
                }

                @Override
                public void onPause() {
                    togglePlayPauseInService();
                    MainActivity.sendMediaControlToWeb("togglePlayPause");
                }

                @Override
                public void onSkipToNext() {
                    MainActivity.sendMediaControlToWeb("next");
                }

                @Override
                public void onSkipToPrevious() {
                    MainActivity.sendMediaControlToWeb("prev");
                }
            });

            PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_PAUSE |
                            PlaybackStateCompat.ACTION_SKIP_TO_NEXT | PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
                    .setState(PlaybackStateCompat.STATE_PAUSED, 0, 0.0f);
            mediaSession.setPlaybackState(stateBuilder.build());
            mediaSession.setActive(true);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void acquireLocksAndFocus() {
        try {
            PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DOLCE::CPUWakeLock");
                if (!wakeLock.isHeld()) {
                    wakeLock.acquire();
                }
            }

            WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null) {
                wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "DOLCE::WifiLock");
                if (!wifiLock.isHeld()) {
                    wifiLock.acquire();
                }
            }

            audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            if (audioManager != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AudioAttributes playbackAttributes = new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build();
                    audioFocusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                            .setAudioAttributes(playbackAttributes)
                            .setAcceptsDelayedFocusGain(true)
                            .setOnAudioFocusChangeListener(focusChange -> {})
                            .build();
                    audioManager.requestAudioFocus(audioFocusRequest);
                } else {
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void initServiceWebView() {
        mainHandler.post(() -> {
            try {
                serviceWebView = new WebView(getApplicationContext());
                WebSettings settings = serviceWebView.getSettings();
                settings.setJavaScriptEnabled(true);
                settings.setMediaPlaybackRequiresUserGesture(false);
                settings.setDomStorageEnabled(true);
                serviceWebView.setWebViewClient(new WebViewClient());

                serviceWebView.addJavascriptInterface(new Object() {
                    @JavascriptInterface
                    public void onPlayerReady() {
                        isPlayerReady = true;
                        if (currentVideoId != null && !currentVideoId.isEmpty()) {
                            playVideoIdInService(currentVideoId);
                        }
                    }

                    @JavascriptInterface
                    public void onStateChange(int state) {
                        if (state == 1) { // PLAYING
                            currentIsPlaying = true;
                            updateAndPostNotification();
                        } else if (state == 2) { // PAUSED
                            currentIsPlaying = false;
                            updateAndPostNotification();
                        } else if (state == 0) { // ENDED
                            currentIsPlaying = false;
                            updateAndPostNotification();
                            MainActivity.sendMediaControlToWeb("next");
                        }
                    }
                }, "NativeAudioService");

                String html = "<!DOCTYPE html><html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"></head>" +
                        "<body style=\"margin:0;padding:0;background:#000;\">" +
                        "<div id=\"player\"></div>" +
                        "<script src=\"https://www.youtube.com/iframe_api\"></script>" +
                        "<script>" +
                        "var player;" +
                        "function onYouTubeIframeAPIReady(){" +
                        "  player = new YT.Player('player',{" +
                        "    height:'100%',width:'100%',videoId:'',host:'https://www.youtube-nocookie.com'," +
                        "    playerVars:{autoplay:1,playsinline:1,controls:0,disablekb:1,fs:0,rel:0,modestbranding:1}," +
                        "    events:{" +
                        "      onReady:function(){ if(window.NativeAudioService) window.NativeAudioService.onPlayerReady(); }," +
                        "      onStateChange:function(e){ if(window.NativeAudioService) window.NativeAudioService.onStateChange(e.data); }" +
                        "    }" +
                        "  });" +
                        "}" +
                        "function loadAndPlay(id){ if(player && player.loadVideoById){ player.loadVideoById(id); player.playVideo(); } }" +
                        "function playVideo(){ if(player && player.playVideo) player.playVideo(); }" +
                        "function pauseVideo(){ if(player && player.pauseVideo) player.pauseVideo(); }" +
                        "</script></body></html>";

                serviceWebView.loadDataWithBaseURL("https://music.youtube.com", html, "text/html", "UTF-8", null);
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    private void playVideoIdInService(String videoId) {
        mainHandler.post(() -> {
            if (serviceWebView != null && videoId != null && !videoId.isEmpty()) {
                serviceWebView.evaluateJavascript("loadAndPlay('" + videoId + "');", null);
            }
        });
    }

    private void togglePlayPauseInService() {
        mainHandler.post(() -> {
            if (serviceWebView != null) {
                if (currentIsPlaying) {
                    serviceWebView.evaluateJavascript("pauseVideo();", null);
                } else {
                    serviceWebView.evaluateJavascript("playVideo();", null);
                }
            }
        });
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getAction();
            if (ACTION_PREVIOUS.equals(action)) {
                MainActivity.sendMediaControlToWeb("prev");
                return START_STICKY;
            } else if (ACTION_TOGGLE_PLAY_PAUSE.equals(action)) {
                togglePlayPauseInService();
                MainActivity.sendMediaControlToWeb("togglePlayPause");
                return START_STICKY;
            } else if (ACTION_NEXT.equals(action)) {
                MainActivity.sendMediaControlToWeb("next");
                return START_STICKY;
            }

            if (intent.hasExtra("title")) {
                currentTitle = intent.getStringExtra("title");
            }
            if (intent.hasExtra("artist")) {
                currentArtist = intent.getStringExtra("artist");
            }
            if (intent.hasExtra("isPlaying")) {
                currentIsPlaying = intent.getBooleanExtra("isPlaying", false);
            }
            String newVideoId = intent.hasExtra("videoId") ? intent.getStringExtra("videoId") : "";
            String newArtworkUrl = intent.hasExtra("artworkUrl") ? intent.getStringExtra("artworkUrl") : "";

            if (newVideoId != null && !newVideoId.isEmpty() && !newVideoId.equals(currentVideoId)) {
                currentVideoId = newVideoId;
                if (isPlayerReady) {
                    playVideoIdInService(newVideoId);
                }
            } else if (intent.hasExtra("isPlaying")) {
                if (currentIsPlaying) {
                    mainHandler.post(() -> { if (serviceWebView != null) serviceWebView.evaluateJavascript("playVideo();", null); });
                } else {
                    mainHandler.post(() -> { if (serviceWebView != null) serviceWebView.evaluateJavascript("pauseVideo();", null); });
                }
            }

            // Update MediaSession Playback State
            if (mediaSession != null) {
                int state = currentIsPlaying ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED;
                PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
                        .setActions(PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_PAUSE |
                                PlaybackStateCompat.ACTION_SKIP_TO_NEXT | PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
                        .setState(state, 0, currentIsPlaying ? 1.0f : 0.0f);
                mediaSession.setPlaybackState(stateBuilder.build());

                MediaMetadataCompat.Builder metaBuilder = new MediaMetadataCompat.Builder()
                        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist);
                if (currentArtworkBitmap != null) {
                    metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentArtworkBitmap);
                }
                mediaSession.setMetadata(metaBuilder.build());
            }

            // Build & update notification
            updateAndPostNotification();

            // Fetch Cover Art Bitmap asynchronously if artworkUrl is provided and changed
            if (newArtworkUrl != null && !newArtworkUrl.isEmpty() && !newArtworkUrl.equals(currentArtworkUrl)) {
                currentArtworkUrl = newArtworkUrl;
                new Thread(() -> {
                    try {
                        URL url = new URL(newArtworkUrl);
                        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                        connection.setDoInput(true);
                        connection.setConnectTimeout(5000);
                        connection.setReadTimeout(5000);
                        connection.connect();
                        InputStream input = connection.getInputStream();
                        Bitmap bitmap = BitmapFactory.decodeStream(input);
                        if (bitmap != null) {
                            currentArtworkBitmap = bitmap;
                            
                            if (mediaSession != null) {
                                MediaMetadataCompat.Builder metaBuilder = new MediaMetadataCompat.Builder()
                                        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                                        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                                        .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap);
                                mediaSession.setMetadata(metaBuilder.build());
                            }

                            updateAndPostNotification();
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }).start();
            }
        }

        return START_STICKY;
    }

    private void updateAndPostNotification() {
        try {
            Intent notificationIntent = new Intent(this, MainActivity.class);
            notificationIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent contentPendingIntent = PendingIntent.getActivity(
                    this, 0, notificationIntent,
                    PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
            );

            // Action Pending Intents
            Intent prevIntent = new Intent(this, BackgroundAudioService.class).setAction(ACTION_PREVIOUS);
            PendingIntent prevPendingIntent = PendingIntent.getService(this, 1, prevIntent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

            Intent playPauseIntent = new Intent(this, BackgroundAudioService.class).setAction(ACTION_TOGGLE_PLAY_PAUSE);
            PendingIntent playPausePendingIntent = PendingIntent.getService(this, 2, playPauseIntent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

            Intent nextIntent = new Intent(this, BackgroundAudioService.class).setAction(ACTION_NEXT);
            PendingIntent nextPendingIntent = PendingIntent.getService(this, 3, nextIntent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

            int playPauseIcon = currentIsPlaying ? R.drawable.ic_pause : R.drawable.ic_play_arrow;
            String playPauseTitle = currentIsPlaying ? "Pause" : "Play";

            NotificationCompat.Action actionPrev = new NotificationCompat.Action.Builder(
                    R.drawable.ic_skip_previous, "Previous", prevPendingIntent).build();
            NotificationCompat.Action actionPlayPause = new NotificationCompat.Action.Builder(
                    playPauseIcon, playPauseTitle, playPausePendingIntent).build();
            NotificationCompat.Action actionNext = new NotificationCompat.Action.Builder(
                    R.drawable.ic_skip_next, "Next", nextPendingIntent).build();

            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle(currentTitle)
                    .setContentText(currentArtist)
                    .setSubText("DOLCE")
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentIntent(contentPendingIntent)
                    .setOngoing(currentIsPlaying)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_SERVICE)
                    .setOnlyAlertOnce(true)
                    .addAction(actionPrev)
                    .addAction(actionPlayPause)
                    .addAction(actionNext);

            if (currentArtworkBitmap != null) {
                builder.setLargeIcon(currentArtworkBitmap);
            }

            if (mediaSession != null) {
                builder.setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setMediaSession(mediaSession.getSessionToken())
                        .setShowActionsInCompactView(0, 1, 2));
            }

            Notification notification = builder.build();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        try {
            if (serviceWebView != null) {
                serviceWebView.destroy();
                serviceWebView = null;
            }
            if (mediaSession != null) {
                mediaSession.setActive(false);
                mediaSession.release();
            }
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
            }
            if (wifiLock != null && wifiLock.isHeld()) {
                wifiLock.release();
            }
            if (audioManager != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                    audioManager.abandonAudioFocusRequest(audioFocusRequest);
                } else {
                    audioManager.abandonAudioFocus(null);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    CHANNEL_ID,
                    "DOLCE Music Player Controller",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            serviceChannel.setDescription("Controls background audio playback, displays track info and media control notification card");
            serviceChannel.setSound(null, null);
            serviceChannel.setVibrationPattern(null);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(serviceChannel);
            }
        }
    }
}
