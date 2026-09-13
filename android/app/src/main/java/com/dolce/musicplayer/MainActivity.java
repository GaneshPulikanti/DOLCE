package com.dolce.musicplayer;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
        startBackgroundAudioService();

        keepAliveRunnable = new Runnable() {
            @Override
            public void run() {
                if (bridge != null && bridge.getWebView() != null) {
                    WebView webView = bridge.getWebView();
                    webView.onResume();
                    webView.resumeTimers();
                }
                keepAliveHandler.postDelayed(this, 1000);
            }
        };
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
        super.onPause();
        // Keep WebView audio stream and JS timers active when app is minimized or screen is locked
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine) { window.audioEngine.resume(); }", null);
        }
        keepAliveHandler.post(keepAliveRunnable);
    }

    @Override
    public void onStop() {
        super.onStop();
        if (bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine) { window.audioEngine.resume(); }", null);
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        keepAliveHandler.removeCallbacks(keepAliveRunnable);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (!hasFocus && bridge != null && bridge.getWebView() != null) {
            WebView webView = bridge.getWebView();
            webView.onResume();
            webView.resumeTimers();
            webView.evaluateJavascript("if (window.audioEngine) { window.audioEngine.resume(); }", null);
        }
    }
}
