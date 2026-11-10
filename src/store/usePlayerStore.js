import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { audioEngine } from '../services/player';
import { recordHistory } from '../services/db';
import { syncMediaSession, updateMediaPosition } from '../services/mediaSession';
import { jamService } from '../services/jamService';

let isApplyingRemoteJamSync = false;
let isExpandingQueue = false;

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
            const { currentTrack, isPlaying, currentTime, queue } = data;
            const targetTime = currentTime || 0;

            if (queue && Array.isArray(queue) && queue.length > 0) {
              set({ queue });
            }

            if (currentTrack && currentTrack.id) {
              const activeId = audioEngine.currentVideoId || get().currentTrack?.id;
              if (activeId === currentTrack.id) {
                // Song already loaded in audio engine/buffer: align state smoothly without reloading
                audioEngine.currentVideoId = currentTrack.id;
                if (isPlaying) {
                  audioEngine.resume(true);
                  if (Math.abs(get().currentTime - targetTime) > 5.0) {
                    audioEngine.seek(targetTime);
                  }
                } else {
                  audioEngine.pause();
                  if (Math.abs(get().currentTime - targetTime) > 5.0) {
                    audioEngine.seek(targetTime);
                  }
                }
                set({ currentTrack, isPlaying, currentTime: targetTime, isLoading: false });
              } else {
                get().playTrack(currentTrack, queue || [currentTrack], targetTime);
                if (!isPlaying) {
                  setTimeout(() => {
                    audioEngine.pause();
                    set({ isPlaying: false, currentTime: targetTime });
                  }, 350);
                }
              }
            }
          } finally {
            isApplyingRemoteJamSync = false;
          }
          return;
        }

        if (command === 'APPLY_HEARTBEAT') {
          const { trackId, isPlaying: hostPlaying, currentTime: hostTime } = data;
          const { currentTrack, isPlaying: localPlaying } = get();
          if (!trackId || !currentTrack) return;

          // ⚡ Smooth Drift Sync: ONLY sync position when BOTH devices are actively playing the same song
          if (hostPlaying && localPlaying && trackId === currentTrack.id) {
            const localTime = audioEngine.getCurrentTime() || get().currentTime || 0;
            // 2.5s tolerance: tight enough so listeners are beat-matched, avoiding micro-seeks
            if (hostTime !== undefined && Math.abs(localTime - hostTime) > 2.5) {
              audioEngine.seek(hostTime);
              set({ currentTime: hostTime });
            }
          }
          return;
        }

        if (command === 'REMOTE_PLAY') {
          isApplyingRemoteJamSync = true;
          try {
            const currentTrack = get().currentTrack;
            const targetTrack = data.track || currentTrack;
            const targetTrackId = data.trackId || targetTrack?.id;
            const localTime = audioEngine.getCurrentTime() || get().currentTime || 0;
            const targetTime = data.currentTime !== undefined ? data.currentTime : localTime;

            const activeId = audioEngine.currentVideoId || currentTrack?.id;

            // If audio engine has not loaded this track yet, load and play it
            if (targetTrackId && targetTrackId !== activeId) {
              if (targetTrack) {
                get().playTrack(targetTrack, get().queue, targetTime);
              } else {
                audioEngine.playTrack(targetTrackId, targetTime);
              }
            } else {
              // ⚡ Instant in-memory resume (0ms latency, keep pre-buffered audio)
              audioEngine.currentVideoId = targetTrackId || activeId;
              audioEngine.resume(true);

              // Only seek if drift > 2.5s
              if (targetTime !== undefined && Math.abs(localTime - targetTime) > 2.5) {
                audioEngine.seek(targetTime);
              }
            }
            set({ isPlaying: true, ...(targetTrack ? { currentTrack: targetTrack } : {}) });
          } finally {
            isApplyingRemoteJamSync = false;
          }
          return;
        }

        if (command === 'REMOTE_PAUSE') {
          isApplyingRemoteJamSync = true;
          try {
            // ⚡ Zero-Latency Instant Pause on all devices
            audioEngine.pause();
            set({ isPlaying: false });
            if (data.currentTime !== undefined) {
              set({ currentTime: data.currentTime });
            }
          } finally {
            isApplyingRemoteJamSync = false;
          }
          return;
        }

        if (command === 'REMOTE_SEEK') {
          isApplyingRemoteJamSync = true;
          try {
            audioEngine.seek(data.currentTime);
            set({ currentTime: data.currentTime });
          } finally {
            isApplyingRemoteJamSync = false;
          }
          return;
        }

        if (command === 'REMOTE_TRACK_CHANGE') {
          isApplyingRemoteJamSync = true;
          try {
            if (data.track) {
              get().playTrack(data.track, data.queue || get().queue, data.startSeconds || 0);
            }
          } finally {
            isApplyingRemoteJamSync = false;
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
            isApplyingRemoteJamSync = false;
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
          // When in a Jam session, only the host automatically triggers skipNext when a track finishes
          // This prevents multiple connected devices from racing and skipping songs ahead
          if (!jamService.roomCode || jamService.role === 'host') {
            get().skipNext();
          }
        }
      };

      audioEngine.onProgress = (currentTime, duration) => {
        const validDuration = duration || get().duration || 210;
        set({
          currentTime,
          duration: validDuration,
        });

        updateMediaPosition(currentTime, validDuration);

        // Gapless Pre-Buffering & Queue Expansion: Cue next track and expand recommendations
        if (validDuration > 0 && currentTime / validDuration > 0.65) {
          const { queue, currentIndex, currentTrack } = get();
          if (queue && queue[currentIndex + 1]) {
            audioEngine.cueNextTrack(queue[currentIndex + 1].id);
          }
          if (queue.length - currentIndex <= 4 && currentTrack) {
            get().expandInfiniteQueue(currentTrack);
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

          // ♾️ Infinite Auto-Queue: Expand radio recommendations in background if queue is near end
          if (queue.length - currentIndex <= 5) {
            get().expandInfiniteQueue(track);
          }
        },

        expandInfiniteQueue: async (seedTrack) => {
          if (!seedTrack || !seedTrack.id || isExpandingQueue) return;
          isExpandingQueue = true;
          try {
            const { fetchTrackRadio, searchSongs, isValidAudioSong } = await import('../services/catalog');
            
            // 1. YouTube Music AI Track Radio recommendations (RDAMVM graph)
            let recommendedTracks = await fetchTrackRadio(seedTrack.id);

            // 2. Cohesive fallback: artist top hits (NEVER random search keywords)
            if (!recommendedTracks || recommendedTracks.length === 0) {
              const query = `${seedTrack.artistName || ''} top hits`;
              recommendedTracks = await searchSongs(query);
            }

            const currentQueue = get().queue;
            const existingIds = new Set(currentQueue.map(q => q.id));

            const newTracks = (recommendedTracks || []).filter(
              r => r && r.id && !existingIds.has(r.id) && isValidAudioSong(r) && r.artworkUrl && r.artworkUrl.length > 15
            );
            
            if (newTracks.length > 0) {
              const sliceToAppend = newTracks.slice(0, 25);
              const updatedQueue = [...currentQueue, ...sliceToAppend];
              set({ queue: updatedQueue });
              
              const currIdx = get().currentIndex;
              if (updatedQueue[currIdx + 1]) {
                audioEngine.cueNextTrack(updatedQueue[currIdx + 1].id);
              }
            }
          } catch (e) {
            console.error('Failed to expand infinite queue:', e);
          } finally {
            isExpandingQueue = false;
          }
        },

        togglePlayPause: () => {
          const { isPlaying, currentTrack } = get();
          if (!currentTrack) return;
          const currentTime = audioEngine.getCurrentTime() || get().currentTime || 0;

          if (isPlaying) {
            audioEngine.pause();
            set({ isPlaying: false, currentTime });
            if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
              jamService.broadcastPause(currentTime, currentTrack);
            }
          } else {
            if (audioEngine.currentVideoId !== currentTrack.id) {
              audioEngine.playTrack(currentTrack.id, currentTime || 0);
            } else {
              audioEngine.resume(true);
            }
            set({ isPlaying: true, currentTime });
            if (!isApplyingRemoteJamSync && jamService.roomCode && (jamService.role === 'host' || jamService.allowGuestControl)) {
              jamService.broadcastPlay(currentTime, currentTrack);
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
            // Reached end of queue: seamlessly expand via AI track radio recommendations!
            if (currentTrack) {
              await get().expandInfiniteQueue(currentTrack);
              const updatedQueue = get().queue;
              if (nextIndex < updatedQueue.length) {
                playTrack(updatedQueue[nextIndex]);
                return;
              }
            }
            // Continuous Loop: If no new recommendations available, loop back to the start of the queue so music never stops
            if (queue.length > 0) {
              playTrack(queue[0]);
            } else {
              set({ isPlaying: false, currentTime: 0 });
            }
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
