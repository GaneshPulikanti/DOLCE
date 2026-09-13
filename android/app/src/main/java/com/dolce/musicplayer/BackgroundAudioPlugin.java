package com.dolce.musicplayer;

import android.content.Intent;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "BackgroundAudio")
public class BackgroundAudioPlugin extends Plugin {

    @PluginMethod
    public void updateNotification(PluginCall call) {
        String title = call.getString("title", "DOLCE Music");
        String artist = call.getString("artist", "Ambient Audio Streaming");
        String artworkUrl = call.getString("artworkUrl", "");
        Boolean isPlaying = call.getBoolean("isPlaying", true);

        Intent intent = new Intent(getContext(), BackgroundAudioService.class);
        intent.setAction("UPDATE_NOTIFICATION");
        intent.putExtra("title", title);
        intent.putExtra("artist", artist);
        intent.putExtra("artworkUrl", artworkUrl);
        intent.putExtra("isPlaying", isPlaying != null ? isPlaying : true);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            getContext().startForegroundService(intent);
        } else {
            getContext().startService(intent);
        }

        call.resolve();
    }
}
