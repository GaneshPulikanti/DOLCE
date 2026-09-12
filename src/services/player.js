/**
 * Web & Mobile Audio Engine wrapping YouTube IFrame API and HTML5 Audio.
 */

class AudioEngine {
  constructor() {
    this.ytPlayer = null;
    this.isYtReady = false;
    this.audioElement = new Audio();
    this.useIframe = true;
    this.onStateChange = null;
    this.onProgress = null;
    this.progressTimer = null;
    this.initYtIframe();
  }

  initYtIframe() {
    if (typeof window === 'undefined') return;

    // Create container element for hidden iframe
    let container = document.getElementById('yt-player-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'yt-player-container';
      container.style.position = 'fixed';
      container.style.left = '-9999px';
      container.style.top = '-9999px';
      container.style.width = '1px';
      container.style.height = '1px';
      container.style.opacity = '0.001';
      container.style.pointerEvents = 'none';
      document.body.appendChild(container);
    }

    const playerDiv = document.createElement('div');
    playerDiv.id = 'yt-player-iframe';
    container.appendChild(playerDiv);

    // Load YouTube IFrame API script asynchronously
    if (!window.YT) {
      const tag = document.createElement('script');
      tag.src = 'https://www.youtube.com/iframe_api';
      const firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag?.parentNode?.insertBefore(tag, firstScriptTag);
    }

    window.onYouTubeIframeAPIReady = () => {
      this.ytPlayer = new window.YT.Player('yt-player-iframe', {
        height: '1',
        width: '1',
        videoId: '',
        playerVars: {
          playsinline: 1,
          controls: 0,
          disablekb: 1,
          fs: 0,
          rel: 0,
          modestbranding: 1,
          autoplay: 1,
        },
        events: {
          onReady: () => {
            this.isYtReady = true;
            console.log('🛸 [AudioEngine] YouTube IFrame API Ready.');
          },
          onStateChange: (event) => this.handleYtStateChange(event),
          onError: (err) => console.error('🔴 [AudioEngine] YouTube IFrame Error:', err),
        },
      });
    };

    // Global tap unlock to prevent Autoplay restriction on mobile/Safari
    const unlockAudio = () => {
      if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
        this.ytPlayer.playVideo();
      }
      document.removeEventListener('click', unlockAudio);
      document.removeEventListener('touchstart', unlockAudio);
    };
    document.addEventListener('click', unlockAudio, { once: true });
    document.addEventListener('touchstart', unlockAudio, { once: true });
  }

  handleYtStateChange(event) {
    if (!window.YT) return;
    const states = {
      [window.YT.PlayerState.UNSTARTED]: 'idle',
      [window.YT.PlayerState.ENDED]: 'ended',
      [window.YT.PlayerState.PLAYING]: 'playing',
      [window.YT.PlayerState.PAUSED]: 'paused',
      [window.YT.PlayerState.BUFFERING]: 'buffering',
      [window.YT.PlayerState.CUED]: 'idle',
    };

    const stateStr = states[event.data] || 'idle';
    console.log(`🛸 [AudioEngine] State changed: ${stateStr}`);

    if (stateStr === 'playing') {
      this.startProgressUpdates();
    } else {
      this.stopProgressUpdates();
    }

    if (this.onStateChange) {
      this.onStateChange(stateStr);
    }
  }

  startProgressUpdates() {
    this.stopProgressUpdates();
    this.progressTimer = setInterval(() => {
      if (this.ytPlayer && typeof this.ytPlayer.getCurrentTime === 'function') {
        const currentTime = this.ytPlayer.getCurrentTime() || 0;
        const duration = this.ytPlayer.getDuration() || 0;
        if (this.onProgress) {
          this.onProgress(currentTime, duration);
        }
      }
    }, 400);
  }

  stopProgressUpdates() {
    if (this.progressTimer) {
      clearInterval(this.progressTimer);
      this.progressTimer = null;
    }
  }

  playTrack(videoId, startSeconds = 0) {
    if (!videoId) return;

    console.log(`▶️ [AudioEngine] playTrack: ${videoId} at ${startSeconds}s`);

    if (this.isYtReady && this.ytPlayer && typeof this.ytPlayer.loadVideoById === 'function') {
      this.ytPlayer.loadVideoById({
        videoId: videoId,
        startSeconds: startSeconds,
      });
      if (typeof this.ytPlayer.playVideo === 'function') {
        this.ytPlayer.playVideo();
      }
    } else {
      setTimeout(() => this.playTrack(videoId, startSeconds), 300);
    }
  }

  pause() {
    if (this.ytPlayer && typeof this.ytPlayer.pauseVideo === 'function') {
      this.ytPlayer.pauseVideo();
    }
  }

  resume() {
    if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
      this.ytPlayer.playVideo();
    }
  }

  seek(seconds) {
    if (this.ytPlayer && typeof this.ytPlayer.seekTo === 'function') {
      this.ytPlayer.seekTo(seconds, true);
    }
  }

  setVolume(volumePct) {
    if (this.ytPlayer && typeof this.ytPlayer.setVolume === 'function') {
      this.ytPlayer.setVolume(Math.min(100, Math.max(0, volumePct)));
    }
  }
}

export const audioEngine = new AudioEngine();
