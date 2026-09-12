import { getStreamUrl } from './catalog';

/**
 * High-Performance Dual Audio Engine (HTML5 Audio + YouTube IFrame).
 * Guarantees seamless playback on mobile devices, mobile hotspots, Chrome, Safari & Capacitor Android.
 */
class AudioEngine {
  constructor() {
    this.ytPlayer = null;
    this.isYtReady = false;
    this.audioElement = new Audio();
    this.mode = 'yt'; // 'yt' | 'html5'
    this.currentVideoId = null;
    this.onStateChange = null;
    this.onProgress = null;
    this.progressTimer = null;
    this.fallbackTimer = null;

    this.initAudioElement();
    this.initYtIframe();
  }

  initAudioElement() {
    if (typeof window === 'undefined') return;

    this.audioElement.preload = 'auto';

    this.audioElement.addEventListener('play', () => {
      if (this.mode === 'html5') {
        console.log('🛸 [AudioEngine-HTML5] Playing');
        this.onStateChange?.('playing');
        this.startProgressUpdates();
      }
    });

    this.audioElement.addEventListener('pause', () => {
      if (this.mode === 'html5') {
        console.log('🛸 [AudioEngine-HTML5] Paused');
        this.onStateChange?.('paused');
        this.stopProgressUpdates();
      }
    });

    this.audioElement.addEventListener('ended', () => {
      if (this.mode === 'html5') {
        console.log('🛸 [AudioEngine-HTML5] Ended');
        this.onStateChange?.('ended');
        this.stopProgressUpdates();
      }
    });

    this.audioElement.addEventListener('timeupdate', () => {
      if (this.mode === 'html5' && this.onProgress) {
        this.onProgress(this.audioElement.currentTime || 0, this.audioElement.duration || 0);
      }
    });

    this.audioElement.addEventListener('error', (e) => {
      console.warn('⚠️ [AudioEngine-HTML5] HTML5 Audio error:', e);
    });

    // Mobile tap gesture unlocker
    const unlockAudio = () => {
      try {
        this.audioElement.play().then(() => this.audioElement.pause()).catch(() => {});
        if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
          this.ytPlayer.playVideo();
        }
      } catch (_) {}
      document.removeEventListener('click', unlockAudio);
      document.removeEventListener('touchstart', unlockAudio);
    };
    document.addEventListener('click', unlockAudio, { once: true });
    document.addEventListener('touchstart', unlockAudio, { once: true });
  }

  initYtIframe() {
    if (typeof window === 'undefined') return;

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
          onError: (err) => {
            console.warn('🔴 [AudioEngine] YouTube IFrame Error, switching to HTML5 stream fallback...', err);
            this.switchToHtml5Fallback();
          },
        },
      });
    };
  }

  handleYtStateChange(event) {
    if (!window.YT || this.mode !== 'yt') return;

    const states = {
      [window.YT.PlayerState.UNSTARTED]: 'idle',
      [window.YT.PlayerState.ENDED]: 'ended',
      [window.YT.PlayerState.PLAYING]: 'playing',
      [window.YT.PlayerState.PAUSED]: 'paused',
      [window.YT.PlayerState.BUFFERING]: 'buffering',
      [window.YT.PlayerState.CUED]: 'idle',
    };

    const stateStr = states[event.data] || 'idle';
    console.log(`🛸 [AudioEngine-YT] State changed: ${stateStr}`);

    if (stateStr === 'playing') {
      if (this.fallbackTimer) {
        clearTimeout(this.fallbackTimer);
        this.fallbackTimer = null;
      }
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
      if (this.mode === 'yt' && this.ytPlayer && typeof this.ytPlayer.getCurrentTime === 'function') {
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

  async switchToHtml5Fallback() {
    if (!this.currentVideoId) return;
    console.log(`⚡ [AudioEngine] Resolving HTML5 audio stream fallback for ${this.currentVideoId}...`);
    this.mode = 'html5';

    try {
      if (this.ytPlayer && typeof this.ytPlayer.pauseVideo === 'function') {
        this.ytPlayer.pauseVideo();
      }
    } catch (_) {}

    const streamUrl = await getStreamUrl(this.currentVideoId);
    if (streamUrl) {
      console.log(`✅ [AudioEngine] Playing direct stream on HTML5 Audio: ${streamUrl}`);
      this.audioElement.src = streamUrl;
      this.audioElement.play().catch(e => console.error('HTML5 play error:', e));
    } else {
      console.error('❌ Could not resolve audio stream for fallback.');
    }
  }

  playTrack(videoId, startSeconds = 0) {
    if (!videoId) return;

    this.currentVideoId = videoId;
    console.log(`▶️ [AudioEngine] playTrack: ${videoId} at ${startSeconds}s`);

    if (this.fallbackTimer) {
      clearTimeout(this.fallbackTimer);
    }

    // Stop previous HTML5 audio if active
    if (!this.audioElement.paused) {
      this.audioElement.pause();
    }

    const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

    if (isMobile) {
      // Direct stream on mobile for 100% instant reliability
      this.switchToHtml5Fallback();
      return;
    }

    // On Desktop, try YouTube IFrame first with fallback timer
    this.mode = 'yt';
    if (this.isYtReady && this.ytPlayer && typeof this.ytPlayer.loadVideoById === 'function') {
      this.ytPlayer.loadVideoById({
        videoId: videoId,
        startSeconds: startSeconds,
      });
      if (typeof this.ytPlayer.playVideo === 'function') {
        this.ytPlayer.playVideo();
      }

      // Fallback timer: If YT iframe doesn't start playing within 1.5s, switch to HTML5
      this.fallbackTimer = setTimeout(() => {
        if (this.mode === 'yt') {
          const ytState = this.ytPlayer?.getPlayerState?.();
          if (ytState !== window.YT?.PlayerState?.PLAYING) {
            console.warn('⚠️ [AudioEngine] YT Iframe stall detected, engaging HTML5 fallback...');
            this.switchToHtml5Fallback();
          }
        }
      }, 1500);
    } else {
      // If YT iframe is not ready, try direct stream immediately
      this.switchToHtml5Fallback();
    }
  }

  pause() {
    if (this.mode === 'html5') {
      this.audioElement.pause();
    } else if (this.ytPlayer && typeof this.ytPlayer.pauseVideo === 'function') {
      this.ytPlayer.pauseVideo();
    }
  }

  resume() {
    if (this.mode === 'html5') {
      this.audioElement.play().catch(() => {});
    } else if (this.ytPlayer && typeof this.ytPlayer.playVideo === 'function') {
      this.ytPlayer.playVideo();
    }
  }

  seek(seconds) {
    if (this.mode === 'html5') {
      this.audioElement.currentTime = seconds;
    } else if (this.ytPlayer && typeof this.ytPlayer.seekTo === 'function') {
      this.ytPlayer.seekTo(seconds, true);
    }
  }

  setVolume(volumePct) {
    const vol = Math.min(100, Math.max(0, volumePct));
    this.audioElement.volume = vol / 100;
    if (this.ytPlayer && typeof this.ytPlayer.setVolume === 'function') {
      this.ytPlayer.setVolume(vol);
    }
  }
}

export const audioEngine = new AudioEngine();

