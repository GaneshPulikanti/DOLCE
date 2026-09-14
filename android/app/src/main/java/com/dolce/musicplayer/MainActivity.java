package com.dolce.musicplayer;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    private static MainActivity instance;

    public static MainActivity getInstance() {
        return instance;
    }

    public static void sendMediaControlToWeb(final String actionStr) {
        if (instance != null && instance.bridge != null && instance.bridge.getWebView() != null) {
            instance.runOnUiThread(() -> {
                try {
                    WebView webView = instance.bridge.getWebView();
                    if (webView != null) {
                        String js = "";
                        if ("togglePlayPause".equals(actionStr)) {
                            js = "if (window.usePlayerStore) { window.usePlayerStore.getState().togglePlayPause(); }";
                        } else if ("next".equals(actionStr)) {
                            js = "if (window.usePlayerStore) { window.usePlayerStore.getState().skipNext(); }";
                        } else if ("prev".equals(actionStr)) {
                            js = "if (window.usePlayerStore) { window.usePlayerStore.getState().skipPrev(); }";
                        }
                        if (!js.isEmpty()) {
                            webView.evaluateJavascript(js, null);
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
    }

    public static void sendProgressToWeb(final double currentTime, final double duration) {
        if (instance != null && instance.bridge != null && instance.bridge.getWebView() != null) {
            instance.runOnUiThread(() -> {
                try {
                    WebView webView = instance.bridge.getWebView();
                    if (webView != null) {
                        String js = "if (window.usePlayerStore) { window.usePlayerStore.setState({ currentTime: " + currentTime + ", duration: " + (duration > 0 ? duration : 210) + " }); }";
                        webView.evaluateJavascript(js, null);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
    }

    public static void sendSeekToWeb(final double seconds) {
        if (instance != null && instance.bridge != null && instance.bridge.getWebView() != null) {
            instance.runOnUiThread(() -> {
                try {
                    WebView webView = instance.bridge.getWebView();
                    if (webView != null) {
                        String js = "if (window.usePlayerStore) { window.usePlayerStore.getState().seek(" + seconds + "); }";
                        webView.evaluateJavascript(js, null);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        instance = this;
        registerPlugin(BackgroundAudioPlugin.class);
        super.onCreate(savedInstanceState);
        
        // 1. Request Notification Permission on launch (required for Android 13+ & Oppo ColorOS)
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 101);
            }
        }

        // 2. Automatically prompt user for Unrestricted Background Activity / Battery Optimization Exemption on launch
        requestBatteryOptimizationExemption();

        startBackgroundAudioService();
    }

    private void requestBatteryOptimizationExemption() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                if (pm != null && !pm.isIgnoringBatteryOptimizations(getPackageName())) {
                    Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void startBackgroundAudioService() {
        try {
            Intent serviceIntent = new Intent(this, BackgroundAudioService.class);
            serviceIntent.putExtra("title", "DOLCE Music");
            serviceIntent.putExtra("artist", "Ambient Audio Streaming");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onStart() {
        super.onStart();
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            WebSettings settings = webView.getSettings();
            settings.setMediaPlaybackRequiresUserGesture(false);
            settings.setJavaScriptEnabled(true);
            settings.setDomStorageEnabled(true);
            
            // Add native bridge for dynamic notification and playback state sync
            webView.addJavascriptInterface(new WebAppInterface(this), "AndroidNativePlayer");

            // Strictly disable all WebView overscroll and horizontal drag gestures
            webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
            webView.setHorizontalScrollBarEnabled(false);
        }
    }

    @Override
    public void onPause() {
        super.onPause();
    }

    @Override
    public void onStop() {
        super.onStop();
    }

    @Override
    public void onResume() {
        super.onResume();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }
}
