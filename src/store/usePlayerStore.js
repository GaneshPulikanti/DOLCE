import { create } from 'zustand';
import { audioEngine } from '../services/player';
import { recordHistory } from '../services/db';

export const usePlayerStore = create((set, get) => {
  // Wire audio engine listeners
  audioEngine.onStateChange = (stateStr) => {
    const isPlaying = stateStr === 'playing';
    set({
      isPlaying,
      isLoading: stateStr === 'buffering',
    });

    if (stateStr === 'ended') {
      get().skipNext();
    }
  };

  audioEngine.onProgress = (currentTime, duration) => {
    set({
      currentTime,
      duration: duration || get().duration || 210,
    });

    // Gapless Pre-Buffering: Cue next track in buffer when current track reaches 65% progress
    if (duration > 0 && currentTime / duration > 0.65) {
      const { queue, currentIndex } = get();
      if (queue && queue[currentIndex + 1]) {
        audioEngine.cueNextTrack(queue[currentIndex + 1].id);
      }
    }
  };

  return {
    currentTrack: null,
    queue: [],
    currentIndex: -1,
    isPlaying: false,
    isLoading: false,
    currentTime: 0,
    duration: 0,
    volume: 80,
    isMuted: false,
    isShuffle: false,
    repeatMode: 'off', // 'off' | 'one' | 'all'
    isExpanded: false,
    lyricFont: 'jakarta', // 'jakarta' | 'sora' | 'syne' | 'space' | 'outfit'
    setLyricFont: (lyricFont) => set({ lyricFont }),

    playTrack: async (track, newQueue = null) => {
      if (!track || !track.id) return;

      let queue = get().queue;
      let currentIndex = get().currentIndex;

      if (newQueue && newQueue.length > 0) {
        queue = newQueue;
        currentIndex = queue.findIndex(t => t.id === track.id);
        if (currentIndex === -1) {
          queue = [track, ...newQueue];
          currentIndex = 0;
        }
      } else if (!queue.some(t => t.id === track.id)) {
        queue = [...queue, track];
        currentIndex = queue.length - 1;
      } else {
        currentIndex = queue.findIndex(t => t.id === track.id);
      }

      set({
        currentTrack: track,
        queue,
        currentIndex,
        isPlaying: true,
        isLoading: true,
        currentTime: 0,
      });

      audioEngine.playTrack(track.id);
      recordHistory(track);

      // Cue next track in buffer if available for 0ms gapless skip
      if (queue[currentIndex + 1]) {
        audioEngine.cueNextTrack(queue[currentIndex + 1].id);
      }

      // ♾️ Infinite Auto-Queue: Expand radio & album recommendations in background if queue is near end
      if (queue.length - currentIndex <= 3) {
        get().expandInfiniteQueue(track);
      }
    },

    expandInfiniteQueue: async (seedTrack) => {
      if (!seedTrack || !seedTrack.title) return;
      try {
        const { searchSongs, isValidAudioSong } = await import('../services/catalog');
        
        // Pass 1: Try movie/album full soundtrack pass for seedTrack
        const albumQuery = `${seedTrack.artistName || ''} ${seedTrack.title} movie full songs`;
        const radioQuery = `${seedTrack.artistName || ''} ${seedTrack.title} songs radio`;
        
        const [albumRes, radioRes] = await Promise.allSettled([
          searchSongs(albumQuery),
          searchSongs(radioQuery)
        ]);

        const albumTracks = albumRes.status === 'fulfilled' ? albumRes.value : [];
        const radioTracks = radioRes.status === 'fulfilled' ? radioRes.value : [];

        const currentQueue = get().queue;
        const existingIds = new Set(currentQueue.map(q => q.id));

        const combined = [...albumTracks, ...radioTracks];
        const newTracks = combined.filter(r => r && r.id && !existingIds.has(r.id) && isValidAudioSong(r));
        
        if (newTracks.length > 0) {
          const updatedQueue = [...currentQueue, ...newTracks];
          set({ queue: updatedQueue });
          
          // Cue the next track in YouTube player for instant playback
          const currIdx = get().currentIndex;
          if (updatedQueue[currIdx + 1]) {
            audioEngine.cueNextTrack(updatedQueue[currIdx + 1].id);
          }
        }
      } catch (e) {
        console.error('Failed to expand infinite queue:', e);
      }
    },

    togglePlayPause: () => {
      const { isPlaying, currentTrack } = get();
      if (!currentTrack) return;

      if (isPlaying) {
        audioEngine.pause();
        set({ isPlaying: false });
      } else {
        audioEngine.resume();
        set({ isPlaying: true });
      }
    },

    seek: (seconds) => {
      audioEngine.seek(seconds);
      set({ currentTime: seconds });
    },

    setVolume: (volume) => {
      audioEngine.setVolume(volume);
      set({ volume, isMuted: volume === 0 });
    },

    toggleMute: () => {
      const { isMuted, volume } = get();
      if (isMuted) {
        audioEngine.setVolume(80);
        set({ isMuted: false, volume: 80 });
      } else {
        audioEngine.setVolume(0);
        set({ isMuted: true });
      }
    },

    skipNext: async () => {
      const { queue, currentIndex, isShuffle, repeatMode, playTrack, currentTrack } = get();
      if (queue.length === 0) return;

      if (repeatMode === 'one') {
        audioEngine.seek(0);
        audioEngine.resume();
        return;
      }

      let nextIndex = currentIndex + 1;
      if (isShuffle) {
        nextIndex = Math.floor(Math.random() * queue.length);
      }

      if (nextIndex < queue.length) {
        playTrack(queue[nextIndex]);
      } else if (repeatMode === 'all') {
        playTrack(queue[0]);
      } else {
        // ♾️ Infinite Queue Trigger: Fetch similar radio tracks when reaching end of queue
        if (currentTrack) {
          await get().expandInfiniteQueue(currentTrack);
          const updatedQueue = get().queue;
          if (nextIndex < updatedQueue.length) {
            playTrack(updatedQueue[nextIndex]);
            return;
          }
        }
        set({ isPlaying: false, currentTime: 0 });
      }
    },

    skipPrev: () => {
      const { queue, currentIndex, currentTime, playTrack } = get();
      if (queue.length === 0) return;

      if (currentTime > 5) {
        audioEngine.seek(0);
        return;
      }

      let prevIndex = currentIndex - 1;
      if (prevIndex < 0) {
        prevIndex = queue.length - 1;
      }

      if (prevIndex >= 0 && prevIndex < queue.length) {
        playTrack(queue[prevIndex]);
      }
    },

    toggleShuffle: () => {
      set((state) => ({ isShuffle: !state.isShuffle }));
    },

    cycleRepeatMode: () => {
      const modes = ['off', 'all', 'one'];
      const current = get().repeatMode;
      const nextMode = modes[(modes.indexOf(current) + 1) % modes.length];
      set({ repeatMode: nextMode });
    },

    cyclePlaybackMode: () => {
      const { isShuffle, repeatMode } = get();
      if (!isShuffle && repeatMode === 'off') {
        set({ isShuffle: true, repeatMode: 'all' });
      } else if (isShuffle) {
        set({ isShuffle: false, repeatMode: 'all' });
      } else if (repeatMode === 'all') {
        set({ isShuffle: false, repeatMode: 'one' });
      } else {
        set({ isShuffle: false, repeatMode: 'off' });
      }
    },

    setExpanded: (isExpanded) => set({ isExpanded }),
  };
});
