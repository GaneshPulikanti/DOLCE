import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { audioEngine } from '../services/player';
import { recordHistory } from '../services/db';
import { syncMediaSession, updateMediaPosition } from '../services/mediaSession';
import { jamService } from '../services/jamService';

let isApplyingRemoteJamSync = false;

export const usePlayerStore = create(
  persist(
    (set, get) => {
      // Wire Jam Sync Command Callback
      jamService.onSyncCommandCallback = (command, data) => {
        if (command === 'GET_CURRENT_STATE') {
          return {
            currentTrack: get().currentTrack,
            isPlaying: get().isPlaying,
            currentTime: get().currentTime,
            queue: get().queue,
          };
        }

        if (command === 'APPLY_SYNC_STATE') {
          isApplyingRemoteJamSync = true;
          try {
            const { currentTrack, isPlaying, currentTime, queue, hostTimestamp } = data;
            const transitLatency = Math.max(0, (Date.now() - (hostTimestamp || Date.now())) / 1000);
            const targetTime = (currentTime || 0) + (isPlaying ? transitLatency : 0);

            if (queue && Array.isArray(queue) && queue.length > 0) {
              set({ queue });
            }

            if (currentTrack && currentTrack.id) {
              get().playTrack(currentTrack, queue || [currentTrack], targetTime);
              if (!isPlaying) {
                setTimeout(() => {
                  audioEngine.pause();
                  set({ isPlaying: false, currentTime: targetTime });
                }, 350);
              }
            }
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 600);
          }
          return;
        }

        if (command === 'APPLY_HEARTBEAT') {
          const { trackId, isPlaying, currentTime, hostTimestamp } = data;
          const { currentTrack, isPlaying: localPlaying, currentTime: localTime } = get();
          if (!trackId || !currentTrack) return;

          const transitLatency = Math.max(0, (Date.now() - (hostTimestamp || Date.now())) / 1000);
          const targetTime = (currentTime || 0) + (isPlaying ? transitLatency : 0);

          if (isPlaying && !localPlaying) {
            audioEngine.resume(true);
            set({ isPlaying: true });
          } else if (!isPlaying && localPlaying) {
            audioEngine.pause();
            set({ isPlaying: false });
          }

          if (Math.abs(localTime - targetTime) > 1.8) {
            audioEngine.seek(targetTime);
            set({ currentTime: targetTime });
          }
          return;
        }

        if (command === 'REMOTE_PLAY') {
          isApplyingRemoteJamSync = true;
          try {
            const transitLatency = Math.max(0, (Date.now() - (data.hostTimestamp || Date.now())) / 1000);
            const targetTime = (data.currentTime || 0) + transitLatency;
            audioEngine.seek(targetTime);
            audioEngine.resume(true);
            set({ isPlaying: true, currentTime: targetTime });
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 400);
          }
          return;
        }

        if (command === 'REMOTE_PAUSE') {
          isApplyingRemoteJamSync = true;
          try {
            audioEngine.pause();
            if (data.currentTime !== undefined) {
              audioEngine.seek(data.currentTime);
              set({ isPlaying: false, currentTime: data.currentTime });
            } else {
              set({ isPlaying: false });
            }
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 400);
          }
          return;
        }

        if (command === 'REMOTE_SEEK') {
          isApplyingRemoteJamSync = true;
          try {
            audioEngine.seek(data.currentTime);
            set({ currentTime: data.currentTime });
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 400);
          }
          return;
        }

        if (command === 'REMOTE_TRACK_CHANGE') {
          isApplyingRemoteJamSync = true;
          try {
            get().playTrack(data.track, data.queue, data.startSeconds || 0);
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 500);
          }
          return;
        }

        if (command === 'REMOTE_QUEUE_UPDATE') {
          isApplyingRemoteJamSync = true;
          try {
            if (data.queue && Array.isArray(data.queue)) {
              set({ queue: data.queue });
            }
          } finally {
            setTimeout(() => { isApplyingRemoteJamSync = false; }, 400);
          }
          return;
        }
      };

      // Wire audio engine listeners
      audioEngine.onStateChange = (stateStr) => {
        const isPlaying = stateStr === 'playing';
        set({
          isPlaying,
          isLoading: stateStr === 'buffering',
        });

        syncMediaSession({
          track: get().currentTrack,
          isPlaying,
          onPlay: () => get().togglePlayPause(),
          onPause: () => get().togglePlayPause(),
          onSkipNext: () => get().skipNext(),
          onSkipPrev: () => get().skipPrev(),
          onSeek: (s) => get().seek(s),
        });

        if (stateStr === 'ended') {
          get().skipNext();
        }
      };

      audioEngine.onProgress = (currentTime, duration) => {
        const validDuration = duration || get().duration || 210;
        set({
          currentTime,
          duration: validDuration,
        });

        updateMediaPosition(currentTime, validDuration);

        // Gapless Pre-Buffering: Cue next track in buffer when current track reaches 65% progress
        if (validDuration > 0 && currentTime / validDuration > 0.65) {
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

        addToQueue: (track) => {
          if (!track || !track.id) return;
          const currentQueue = get().queue;
          const currentTrack = get().currentTrack;

          if (!currentTrack) {
            get().playTrack(track, [track]);
            return;
          }

          if (currentQueue.some(t => t.id === track.id)) {
            return;
          }

          const updatedQueue = [...currentQueue, track];
          set({ queue: updatedQueue });

          if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
            jamService.broadcastQueueUpdate(updatedQueue);
          }
        },

        removeFromQueue: (index) => {
          const { queue, currentIndex } = get();
          if (index < 0 || index >= queue.length) return;

          const updatedQueue = queue.filter((_, idx) => idx !== index);
          let newCurrentIndex = currentIndex;

          if (index < currentIndex) {
            newCurrentIndex = currentIndex - 1;
          } else if (index === currentIndex) {
            if (updatedQueue.length > 0) {
              const nextIndex = index < updatedQueue.length ? index : 0;
              get().playTrack(updatedQueue[nextIndex], updatedQueue);
              return;
            } else {
              set({ queue: [], currentTrack: null, currentIndex: -1, isPlaying: false });
              return;
            }
          }

          set({ queue: updatedQueue, currentIndex: newCurrentIndex });

          if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
            jamService.broadcastQueueUpdate(updatedQueue);
          }
        },

        moveQueueItem: (fromIndex, toIndex) => {
          const { queue, currentIndex } = get();
          if (fromIndex < 0 || fromIndex >= queue.length || toIndex < 0 || toIndex >= queue.length) return;
          if (fromIndex === toIndex) return;

          const updatedQueue = [...queue];
          const [movedTrack] = updatedQueue.splice(fromIndex, 1);
          updatedQueue.splice(toIndex, 0, movedTrack);

          let newCurrentIndex = currentIndex;
          if (currentIndex === fromIndex) {
            newCurrentIndex = toIndex;
          } else if (fromIndex < currentIndex && toIndex >= currentIndex) {
            newCurrentIndex = currentIndex - 1;
          } else if (fromIndex > currentIndex && toIndex <= currentIndex) {
            newCurrentIndex = currentIndex + 1;
          }

          set({ queue: updatedQueue, currentIndex: newCurrentIndex });

          if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
            jamService.broadcastQueueUpdate(updatedQueue);
          }
        },


        playTrack: async (track, newQueue = null, startSeconds = 0) => {
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
            currentTime: startSeconds,
          });

          audioEngine.playTrack(track.id, startSeconds);
          recordHistory(track);

          // Broadcast to Jam if active
          if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
            jamService.broadcastTrackChange(track, queue, startSeconds);
          }

          syncMediaSession({
            track,
            isPlaying: true,
            onPlay: () => get().togglePlayPause(),
            onPause: () => get().togglePlayPause(),
            onSkipNext: () => get().skipNext(),
            onSkipPrev: () => get().skipPrev(),
            onSeek: (s) => get().seek(s),
          });

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
            
            const similarQuery = `${seedTrack.artistName || ''} ${seedTrack.title} audio`;
            const artistQuery = `${seedTrack.artistName || ''} top songs`;
            
            const [similarRes, artistRes] = await Promise.allSettled([
              searchSongs(similarQuery),
              searchSongs(artistQuery)
            ]);

            const similarTracks = similarRes.status === 'fulfilled' ? similarRes.value : [];
            const artistTracks = artistRes.status === 'fulfilled' ? artistRes.value : [];

            const currentQueue = get().queue;
            const existingIds = new Set(currentQueue.map(q => q.id));

            const combined = [...similarTracks, ...artistTracks];
            const newTracks = combined.filter(r => r && r.id && !existingIds.has(r.id) && isValidAudioSong(r) && r.artworkUrl && r.artworkUrl.length > 15);
            
            if (newTracks.length > 0) {
              const updatedQueue = [...currentQueue, ...newTracks];
              set({ queue: updatedQueue });
              
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
          const { isPlaying, currentTrack, currentTime } = get();
          if (!currentTrack) return;

          if (isPlaying) {
            audioEngine.pause();
            set({ isPlaying: false });
            if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
              jamService.broadcastPause(currentTime);
            }
          } else {
            if (audioEngine.currentVideoId !== currentTrack.id) {
              audioEngine.playTrack(currentTrack.id, currentTime || 0);
            } else {
              audioEngine.resume(true);
            }
            set({ isPlaying: true });
            if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
              jamService.broadcastPlay(currentTime);
            }
          }
        },

        seek: (seconds) => {
          audioEngine.seek(seconds);
          set({ currentTime: seconds });
          if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
            jamService.broadcastSeek(seconds);
          }
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
    },
    {
      name: 'dolce-player-state-persistence',
      partialize: (state) => ({
        currentTrack: state.currentTrack,
        queue: state.queue,
        currentIndex: state.currentIndex,
        currentTime: state.currentTime,
        duration: state.duration,
        volume: state.volume,
        isMuted: state.isMuted,
        isShuffle: state.isShuffle,
        repeatMode: state.repeatMode,
        lyricFont: state.lyricFont,
      }),
      onRehydrateStorage: () => (state) => {
        if (state && state.currentTrack) {
          state.isPlaying = false;
          syncMediaSession({
            track: state.currentTrack,
            isPlaying: false,
            onPlay: () => state.togglePlayPause(),
            onPause: () => state.togglePlayPause(),
            onSkipNext: () => state.skipNext(),
            onSkipPrev: () => state.skipPrev(),
            onSeek: (s) => state.seek(s),
          });
        }
      },
    }
  )
);

if (typeof window !== 'undefined') {
  window.usePlayerStore = usePlayerStore;
}
