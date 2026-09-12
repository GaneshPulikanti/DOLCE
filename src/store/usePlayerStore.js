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

    playTrack: (track, newQueue = null) => {
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
      const { queue, currentIndex, isShuffle, repeatMode, playTrack } = get();
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
        // Auto Queue: Automatically generate related tracks so music never stops
        const currentTrack = get().currentTrack;
        if (currentTrack?.artistName) {
          try {
            const { searchSongs } = await import('../services/catalog');
            const related = await searchSongs(`${currentTrack.artistName} songs`);
            const newTracks = related.filter(r => !queue.some(q => q.id === r.id));
            if (newTracks.length > 0) {
              const updatedQueue = [...queue, ...newTracks];
              set({ queue: updatedQueue });
              playTrack(updatedQueue[nextIndex]);
              return;
            }
          } catch (_) {}
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

    setExpanded: (isExpanded) => set({ isExpanded }),
  };
});
