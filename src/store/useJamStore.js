import { create } from 'zustand';
import { jamService } from '../services/jamService';

const savedSession = jamService.getSavedSession();

export const useJamStore = create((set, get) => {
  // Sync state from jamService
  jamService.onStateChangeCallback = (state) => {
    set(state);
  };

  return {
    isJamModalOpen: false,
    isInJam: !!savedSession?.code,
    roomCode: savedSession?.code || null,
    role: savedSession?.role || null,
    isHost: savedSession?.isHost || false,
    isConnected: false,
    isConnecting: !!savedSession?.code,
    participants: savedSession ? [{
      deviceId: jamService.deviceId,
      name: savedSession.isHost ? `${jamService.userName} (Host)` : jamService.userName,
      role: savedSession.role,
      isHost: savedSession.isHost,
      joinedAt: savedSession.savedAt || Date.now()
    }] : [],
    allowGuestControl: true,
    userName: jamService.userName,
    errorMsg: null,

    openJamModal: () => set({ isJamModalOpen: true, errorMsg: null }),
    closeJamModal: () => set({ isJamModalOpen: false, errorMsg: null }),

    setUserName: (name) => {
      jamService.setUserName(name);
      set({ userName: jamService.userName });
    },

    setAllowGuestControl: (allowed) => {
      jamService.setAllowGuestControl(allowed);
      set({ allowGuestControl: allowed });
    },

    createJam: async (getCurrentState) => {
      set({ isConnecting: true, errorMsg: null });
      try {
        const res = await jamService.createSession(getCurrentState);
        set({
          isInJam: true,
          roomCode: res.code,
          role: 'host',
          isHost: true,
          isConnected: true,
          isConnecting: false,
          errorMsg: null
        });
        return res;
      } catch (err) {
        set({
          isConnecting: false,
          errorMsg: err.message || 'Failed to create Jam Session'
        });
        throw err;
      }
    },

    joinJam: async (code) => {
      if (!code || !code.trim()) {
        set({ errorMsg: 'Please enter a valid 4-digit Jam code' });
        return;
      }
      set({ isConnecting: true, errorMsg: null });
      try {
        const res = await jamService.joinSession(code);
        set({
          isInJam: true,
          roomCode: res.code,
          role: 'guest',
          isHost: false,
          isConnected: true,
          isConnecting: false,
          errorMsg: null
        });
        return res;
      } catch (err) {
        set({
          isConnecting: false,
          errorMsg: err.message || 'Failed to connect to Jam room'
        });
        throw err;
      }
    },

    leaveJam: () => {
      jamService.leaveSession();
      set({
        isInJam: false,
        roomCode: null,
        role: null,
        isHost: false,
        isConnected: false,
        isConnecting: false,
        participants: [],
        errorMsg: null
      });
    }
  };
});

export const initJamAutoRestore = () => {
  if (typeof window !== 'undefined') {
    jamService.autoRestoreSession(() => {
      return window.usePlayerStore ? window.usePlayerStore.getState() : {};
    });
  }
};
