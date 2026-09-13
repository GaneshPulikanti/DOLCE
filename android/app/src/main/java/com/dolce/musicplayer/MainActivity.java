package com.dolce.musicplayer;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.Settings;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    private Handler keepAliveHandler = new Handler(Looper.getMainLooper());
    private Runnable keepAliveRunnable;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
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

        keepAliveRunnable = new Runnable() {
            @Override
            public void run() {
                if (bridge != null && bridge.getWebView() != null) {
                    WebView webView = bridge.getWebView();
                    webView.onResume();
                    webView.resumeTimers();
                    webView.evaluateJavascript("if (window.audioEngine && window.audioEngine.isCurrentlyPlaying) { window.audioEngine.resume(); }", null);
                }
                keepAliveHandler.postDelayed(this, 1000);
            }
        };
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
            
            // Strictly disable all WebView overscroll and horizontal drag gestures
            webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
            webView.setHorizontalScrollBarEnabled(false);
        }
    }

    @Override
    public void onPause() {
        // Prevent default Capacitor/Chromium webView.onPause() which kills iframe media decoders!
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine && window.audioEngine.isCurrentlyPlaying) { window.audioEngine.resume(); }", null);
        }
        keepAliveHandler.post(keepAliveRunnable);
    }

    @Override
    public void onStop() {
        // Prevent default Capacitor/Chromium webView.onStop() which halts DOM timers!
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine && window.audioEngine.isCurrentlyPlaying) { window.audioEngine.resume(); }", null);
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
        }
        keepAliveHandler.removeCallbacks(keepAliveRunnable);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (!hasFocus && bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine && window.audioEngine.isCurrentlyPlaying) { window.audioEngine.resume(); }", null);
        }
    }
}
