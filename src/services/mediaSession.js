import { Capacitor, registerPlugin } from '@capacitor/core';
const BackgroundAudio = registerPlugin('BackgroundAudio');

// Silent WAV Data URI (1-second silent audio loop) to hold Android OS Audio Focus lock in WebViews
const SILENT_AUDIO_URI = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

let silentAudioEl = null;

function getSilentAudioElement() {
  if (typeof window === 'undefined') return null;
  if (!silentAudioEl) {
    try {
      silentAudioEl = new Audio(SILENT_AUDIO_URI);
      silentAudioEl.loop = true;
      silentAudioEl.volume = 0.001; // Silent / minimal volume to hold audio focus
    } catch (_) {}
  }
  return silentAudioEl;
}

export function syncMediaSession({ track, isPlaying, onPlay, onPause, onSkipNext, onSkipPrev, onSeek }) {
  if (typeof window === 'undefined' || !('mediaSession' in navigator)) return;

  const silentAudio = getSilentAudioElement();

  if (track) {
    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: track.title || 'DOLCE Music',
        artist: track.artistName || 'DOLCE Stream',
        album: 'DOLCE Music Player',
        artwork: [
          { src: track.artworkUrl || '/favicon.png', sizes: '96x96', type: 'image/png' },
          { src: track.artworkUrl || '/favicon.png', sizes: '128x128', type: 'image/png' },
          { src: track.artworkUrl || '/favicon.png', sizes: '192x192', type: 'image/png' },
          { src: track.artworkUrl || '/favicon.png', sizes: '256x256', type: 'image/png' },
          { src: track.artworkUrl || '/favicon.png', sizes: '512x512', type: 'image/png' },
        ],
      });
    } catch (e) {
      console.warn('MediaMetadata creation warning:', e);
    }

    if (typeof window !== 'undefined' && window.AndroidNativePlayer) {
      try {
        window.AndroidNativePlayer.updateNotification(
          track.title || 'DOLCE Music',
          track.artistName || 'DOLCE Stream',
          track.artworkUrl || '',
          !!isPlaying
        );
      } catch (_) {}
    }

    if (Capacitor.isNativePlatform()) {
      try {
        BackgroundAudio.updateNotification({
          title: track.title || 'DOLCE Music',
          artist: track.artistName || 'DOLCE Stream',
          artworkUrl: track.artworkUrl || '',
          isPlaying: !!isPlaying,
        }).catch(() => {});
      } catch (_) {}
    }
  }

  navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused';

  // Sustain Android OS Audio Focus and keep WebView CPU awake during background playback
  if (silentAudio) {
    if (isPlaying) {
      silentAudio.play().catch(() => {});
    } else {
      silentAudio.pause();
    }
  }

  const setHandler = (action, handler) => {
    try {
      navigator.mediaSession.setActionHandler(action, handler);
    } catch (_) {}
  };

  setHandler('play', () => onPlay && onPlay());
  setHandler('pause', () => onPause && onPause());
  setHandler('previoustrack', () => onSkipPrev && onSkipPrev());
  setHandler('nexttrack', () => onSkipNext && onSkipNext());
  setHandler('seekto', (details) => {
    if (details.seekTime !== undefined && onSeek) {
      onSeek(details.seekTime);
    }
  });
}

export function updateMediaPosition(currentTime, duration) {
  if (typeof window === 'undefined' || !('mediaSession' in navigator)) return;
  if (typeof navigator.mediaSession.setPositionState === 'function') {
    try {
      if (duration > 0 && currentTime >= 0 && currentTime <= duration) {
        navigator.mediaSession.setPositionState({
          duration: duration,
          playbackRate: 1,
          position: currentTime,
        });
      }
    } catch (_) {}
  }
}

