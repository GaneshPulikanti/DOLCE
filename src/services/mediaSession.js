/**
 * MediaSession Service for Android Lock Screen Controls & Background Audio Keepalive.
 * Enables Android OS Media Notification Controls (Title, Artist, Artwork, Play, Pause, Next, Prev, Seek).
 */

export function syncMediaSession({ track, isPlaying, onPlay, onPause, onSkipNext, onSkipPrev, onSeek }) {
  if (typeof window === 'undefined' || !('mediaSession' in navigator)) return;

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
  }

  navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused';

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
