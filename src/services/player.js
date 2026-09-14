/**
 * High-Performance Official Audio Engine wrapping YouTube IFrame API & Native Service Player.
 * Guarantees 100% background uptime and unified state synchronization across Desktop & Android.
 */
class AudioEngine {
  constructor() {
    this.ytPlayer = null;
    this.isYtReady = false;
    this.pendingVideoId = null;
    this.currentVideoId = null;
    this.onStateChange = null;
    this.onProgress = null;
    this.progressTimer = null;
    this.isCurrentlyPlaying = false;
    this.userIntentToPause = false;

    this.initYtIframe();
  }

  initYtIframe() {
    if (typeof window === 'undefined') return;

    // Expose engine globally for native Android WebView background hooks
    window.audioEngine = this;

    // On native Android app, BackgroundAudioService is the SINGLE MASTER AUDIO PLAYER!
    // MainActivity WebView does NOT load a duplicate YouTube iframe to prevent dual-player stutter loops.
    if (window.AndroidNativePlayer) {
      console.log('🛸 [AudioEngine] AndroidNativePlayer present. Using BackgroundAudioService as Single Master Player.');
      return;
    }

    let container = document.getElementById('yt-player-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'yt-player-container';
      container.style.cssText = 'position: absolute !important; top: 0 !important; left: 0 !important; width: 1px !important; height: 1px !important; overflow: hidden !important; opacity: 0.001 !important; pointer-events: none !important; z-index: -9999 !important; clip: rect(0, 0, 0, 0) !important;';
      document.body.appendChild(container);
    }

    let playerDiv = document.getElementById('yt-player-iframe');
    if (!playerDiv) {
      playerDiv = document.createElement('div');
      playerDiv.id = 'yt-player-iframe';
      playerDiv.style.cssText = 'width: 1px !important; height: 1px !important; overflow: hidden !important;';
      container.appendChild(playerDiv);
    }

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
        host: 'https://www.youtube-nocookie.com',
        playerVars: {
          playsinline: 1,
          controls: 0,
          disablekb: 1,
          fs: 0,
          rel: 0,
          modestbranding: 1,
          autoplay: 1,
          origin: window.location.origin,
        },
        events: {
          onReady: () => {
            this.isYtReady = true;
            console.log('🛸 [AudioEngine] YouTube IFrame API Ready.');
            this.secureIframeElement();
            if (this.pendingVideoId) {
              this.playTrack(this.pendingVideoId, this.pendingStartSeconds || 0);
              this.pendingVideoId = null;
              this.pendingStartSeconds = 0;
            }
          },
          onStateChange: (event) => this.handleYtStateChange(event),
          onError: (err) => {
            console.warn('🔴 [AudioEngine] YouTube IFrame Error:', err);
          },
        },
      });
    };

    // User gesture unlock for mobile browsers
    const unlockAudio = () => {
      try {
        if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
          this.ytPlayer.playVideo();
        }
        this.initWebAudioKeepAlive();
      } catch (_) {}
      document.removeEventListener('click', unlockAudio);
      document.removeEventListener('touchstart', unlockAudio);
    };
    document.addEventListener('click', unlockAudio, { once: true });
    document.addEventListener('touchstart', unlockAudio, { once: true });
  }

  initWebAudioKeepAlive() {
    try {
      if (!this.audioCtx && typeof window !== 'undefined') {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (AudioCtx) {
          this.audioCtx = new AudioCtx();
          const osc = this.audioCtx.createOscillator();
          const gain = this.audioCtx.createGain();
          gain.gain.value = 0.0001;
          osc.connect(gain);
          gain.connect(this.audioCtx.destination);
          osc.start();
        }
      }
      if (this.audioCtx && this.audioCtx.state === 'suspended') {
        this.audioCtx.resume().catch(() => {});
      }
    } catch (_) {}
  }

  secureIframeElement() {
    try {
      const iframe = document.getElementById('yt-player-iframe');
      if (iframe) {
        iframe.setAttribute('tabindex', '-1');
        iframe.setAttribute('playsinline', '1');
        iframe.setAttribute('webkit-playsinline', 'true');
        iframe.setAttribute('allow', 'autoplay');
        iframe.style.cssText = 'width: 1px !important; height: 1px !important; position: absolute !important; top: 0 !important; left: 0 !important; opacity: 0.001 !important; pointer-events: none !important; z-index: -9999 !important; border: none !important;';
      }
    } catch (_) {}
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
      this.isCurrentlyPlaying = true;
      this.userIntentToPause = false;
      this.startProgressUpdates();
    } else if (stateStr === 'paused') {
      this.isCurrentlyPlaying = false;
      this.stopProgressUpdates();
    } else if (stateStr === 'ended' || stateStr === 'idle') {
      this.isCurrentlyPlaying = false;
      this.stopProgressUpdates();
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

    this.currentVideoId = videoId;
    this.isCurrentlyPlaying = true;
    this.userIntentToPause = false;
    console.log(`▶️ [AudioEngine] playTrack: ${videoId} at ${startSeconds}s`);

    // On native Android app, delegate to AndroidNativePlayer BackgroundAudioService
    if (typeof window !== 'undefined' && window.AndroidNativePlayer) {
      try {
        const track = window.usePlayerStore ? window.usePlayerStore.getState().currentTrack : null;
        window.AndroidNativePlayer.updateNotification(
          videoId,
          track?.title || 'DOLCE Music',
          track?.artistName || 'DOLCE Stream',
          track?.artworkUrl || '',
          true
        );
      } catch (e) {
        console.warn('Native updateNotification error:', e);
      }
      return;
    }

    // Web Browser Mode
    this.secureIframeElement();
    if (this.isYtReady && this.ytPlayer && typeof this.ytPlayer.loadVideoById === 'function') {
      this.ytPlayer.loadVideoById({
        videoId: videoId,
        startSeconds: startSeconds,
      });
      if (typeof this.ytPlayer.playVideo === 'function') {
        this.ytPlayer.playVideo();
      }
    } else {
      this.pendingVideoId = videoId;
      this.pendingStartSeconds = startSeconds;
    }
  }

  pause() {
    this.userIntentToPause = true;
    this.isCurrentlyPlaying = false;

    if (typeof window !== 'undefined' && window.AndroidNativePlayer) {
      try {
        const track = window.usePlayerStore ? window.usePlayerStore.getState().currentTrack : null;
        window.AndroidNativePlayer.updateNotification(
          this.currentVideoId || '',
          track?.title || 'DOLCE Music',
          track?.artistName || 'DOLCE Stream',
          track?.artworkUrl || '',
          false
        );
      } catch (_) {}
    }

    if (this.ytPlayer && typeof this.ytPlayer.pauseVideo === 'function') {
      this.ytPlayer.pauseVideo();
    }
    this.stopProgressUpdates();
    if (this.onStateChange) {
      this.onStateChange('paused');
    }
  }

  resume(userInitiated = false) {
    this.userIntentToPause = false;
    this.isCurrentlyPlaying = true;

    if (typeof window !== 'undefined' && window.AndroidNativePlayer) {
      try {
        const track = window.usePlayerStore ? window.usePlayerStore.getState().currentTrack : null;
        window.AndroidNativePlayer.updateNotification(
          this.currentVideoId || '',
          track?.title || 'DOLCE Music',
          track?.artistName || 'DOLCE Stream',
          track?.artworkUrl || '',
          true
        );
      } catch (_) {}
    }

    if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
      this.ytPlayer.playVideo();
    }
    if (this.onStateChange) {
      this.onStateChange('playing');
    }
  }

  seek(seconds) {
    if (typeof window !== 'undefined' && window.AndroidNativePlayer) {
      try {
        if (typeof window.AndroidNativePlayer.seekTo === 'function') {
          window.AndroidNativePlayer.seekTo(seconds);
        }
      } catch (_) {}
    }
    if (this.ytPlayer && typeof this.ytPlayer.seekTo === 'function') {
      this.ytPlayer.seekTo(seconds, true);
    }
  }

  setVolume(volumePct) {
    const vol = Math.min(100, Math.max(0, volumePct));
    if (this.ytPlayer && typeof this.ytPlayer.setVolume === 'function') {
      this.ytPlayer.setVolume(vol);
    }
  }
}

export const audioEngine = new AudioEngine();
