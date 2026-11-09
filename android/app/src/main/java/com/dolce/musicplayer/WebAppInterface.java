package com.dolce.musicplayer;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.webkit.JavascriptInterface;

public class WebAppInterface {
    private Context mContext;

    public WebAppInterface(Context c) {
        mContext = c;
    }

    @JavascriptInterface
    public void updateNotification(String videoId, String title, String artist, String artworkUrl, boolean isPlaying) {
        try {
            Intent intent = new Intent(mContext, BackgroundAudioService.class);
            intent.setAction("UPDATE_NOTIFICATION");
            intent.putExtra("videoId", videoId != null ? videoId : "");
            intent.putExtra("title", title != null ? title : "DOLCE Music");
            intent.putExtra("artist", artist != null ? artist : "Ambient Audio Streaming");
            intent.putExtra("artworkUrl", artworkUrl != null ? artworkUrl : "");
            intent.putExtra("isPlaying", isPlaying);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                mContext.startForegroundService(intent);
            } else {
                mContext.startService(intent);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @JavascriptInterface
    public double getCurrentPosition() {
        try {
            BackgroundAudioService service = BackgroundAudioService.getInstance();
            if (service != null) {
                return service.getCurrentPositionSeconds();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return 0;
    }

    @JavascriptInterface
    public boolean getIsPlaying() {
        try {
            BackgroundAudioService service = BackgroundAudioService.getInstance();
            if (service != null) {
                return service.getIsPlaying();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    @JavascriptInterface
    public void resume() {
        try {
            BackgroundAudioService service = BackgroundAudioService.getInstance();
            if (service != null) {
                service.playDirectly();
            } else {
                updateNotification("", "", "", "", true);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @JavascriptInterface
    public void pause() {
        try {
            BackgroundAudioService service = BackgroundAudioService.getInstance();
            if (service != null) {
                service.pauseDirectly();
            } else {
                updateNotification("", "", "", "", false);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @JavascriptInterface
    public void seekTo(double seconds) {
        try {
            Intent intent = new Intent(mContext, BackgroundAudioService.class);
            intent.setAction("UPDATE_NOTIFICATION");
            intent.putExtra("seekToSeconds", seconds);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                mContext.startForegroundService(intent);
            } else {
                mContext.startService(intent);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
