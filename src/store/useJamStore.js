import { create } from 'zustand';
import { jamService } from '../services/jamService';

export const useJamStore = create((set, get) => {
  // Sync initial state from jamService
  jamService.onStateChangeCallback = (state) => {
    set(state);
  };

  return {
    isJamModalOpen: false,
    isInJam: false,
    roomCode: null,
    role: null,
    isHost: false,
    isConnected: false,
    isConnecting: false,
    participants: [],
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

