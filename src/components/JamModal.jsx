import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  X, Radio, Users, Copy, Check, Share2, LogOut, Shield, 
  Headphones, Sparkles, AlertCircle, Loader2, ArrowRight
} from 'lucide-react';
import { useJamStore } from '../store/useJamStore';
import { usePlayerStore } from '../store/usePlayerStore';

export const JamModal = () => {
  const {
    isJamModalOpen,
    closeJamModal,
    isInJam,
    roomCode,
    isHost,
    isConnecting,
    participants,
    allowGuestControl,
    userName,
    errorMsg,
    setUserName,
    setAllowGuestControl,
    createJam,
    joinJam,
    leaveJam
  } = useJamStore();

  const { currentTrack, isPlaying } = usePlayerStore();

  const [activeTab, setActiveTab] = useState('start'); // 'start' | 'join'
  const [joinCodeInput, setJoinCodeInput] = useState('');
  const [copied, setCopied] = useState(false);
  const [shared, setShared] = useState(false);

  if (!isJamModalOpen) return null;

  const handleCreate = async () => {
    try {
      await createJam(() => usePlayerStore.getState());
    } catch (_) {}
  };

  const handleJoin = async (e) => {
    e.preventDefault();
    if (!joinCodeInput.trim()) return;
    try {
      await joinJam(joinCodeInput.trim());
      setJoinCodeInput('');
    } catch (_) {}
  };

  const handleCopyCode = () => {
    if (!roomCode) return;
    navigator.clipboard.writeText(roomCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShareInvite = async () => {
    if (!roomCode) return;
    const shareText = `Join my DOLCE Jam to listen together in sync! Use Jam Code: ${roomCode}`;
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Join DOLCE Jam',
          text: shareText,
        });
        setShared(true);
        setTimeout(() => setShared(false), 2000);
        return;
      } catch (_) {}
    }
    // Fallback: Copy to clipboard
    navigator.clipboard.writeText(shareText);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[80] flex items-center justify-center p-4 font-['Plus_Jakarta_Sans'] select-none">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={closeJamModal}
          className="fixed inset-0 bg-black/75 backdrop-blur-md"
        />

        {/* Modal Window */}
        <motion.div
          initial={{ opacity: 0, scale: 0.94, y: 15 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.94, y: 15 }}
          transition={{ type: 'spring', damping: 25, stiffness: 280 }}
          className="relative w-full max-w-md bg-[#121216]/95 border border-white/20 rounded-3xl p-6 shadow-2xl overflow-hidden flex flex-col gap-5 text-white z-10"
        >
          {/* Top Glow Accent */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-20 bg-gradient-to-b from-pink-500/20 via-purple-500/10 to-transparent blur-2xl pointer-events-none" />

          {/* Header */}
          <div className="flex items-center justify-between border-b border-white/10 pb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-pink-500 to-purple-600 flex items-center justify-center shadow-lg shadow-pink-500/30">
                <Radio size={20} className="text-white animate-pulse" />
              </div>
              <div className="flex flex-col">
                <div className="flex items-center gap-2">
                  <h3 className="text-base font-black tracking-tight text-white">DOLCE Jam</h3>
                  {isInJam && (
                    <span className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-500/40 text-[10px] font-bold text-emerald-300">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
                      Live
                    </span>
                  )}
                </div>
                <p className="text-xs text-white/50">Listen together on separate earbuds</p>
              </div>
            </div>

            <button
              onClick={closeJamModal}
              className="p-2 rounded-full hover:bg-white/10 text-white/60 hover:text-white transition-colors"
            >
              <X size={18} />
            </button>
          </div>

          {/* Error Message if Any */}
          {errorMsg && (
            <div className="p-3 rounded-2xl bg-red-500/20 border border-red-500/40 text-red-200 text-xs font-semibold flex items-center gap-2">
              <AlertCircle size={16} className="text-red-400 flex-shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* ─── CASE A: NOT IN A JAM ─── */}
          {!isInJam ? (
            <div className="flex flex-col gap-4">
              {/* Tab Selector */}
              <div className="flex p-1 rounded-2xl bg-white/[0.06] border border-white/10">
                <button
                  onClick={() => setActiveTab('start')}
                  className={`flex-1 py-2.5 rounded-xl text-xs font-extrabold transition-all flex items-center justify-center gap-2 ${
                    activeTab === 'start'
                      ? 'bg-white text-black shadow-lg'
                      : 'text-white/60 hover:text-white'
                  }`}
                >
                  <Sparkles size={14} />
                  <span>Start a Jam</span>
                </button>
                <button
                  onClick={() => setActiveTab('join')}
                  className={`flex-1 py-2.5 rounded-xl text-xs font-extrabold transition-all flex items-center justify-center gap-2 ${
                    activeTab === 'join'
                      ? 'bg-white text-black shadow-lg'
                      : 'text-white/60 hover:text-white'
                  }`}
                >
                  <Users size={14} />
                  <span>Join a Jam</span>
                </button>
              </div>

              {/* Rider / User Name Input */}
              <div className="flex flex-col gap-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-white/50">
                  Your Nickname
                </label>
                <input
                  type="text"
                  value={userName}
                  onChange={(e) => setUserName(e.target.value)}
                  placeholder="e.g. Rider Ganesh"
                  maxLength={25}
                  className="w-full h-11 px-4 rounded-xl bg-white/5 border border-white/15 text-sm text-white placeholder-white/40 focus:outline-none focus:border-white/50 font-semibold"
                />
              </div>

              {activeTab === 'start' ? (
                /* Tab 1: Start Jam */
                <div className="flex flex-col gap-4 pt-1">
                  <div className="p-4 rounded-2xl bg-white/[0.04] border border-white/10 flex flex-col gap-2">
                    <div className="flex items-center gap-2 text-xs font-bold text-pink-300">
                      <Headphones size={16} />
                      <span>Perfect for Rides & Workouts</span>
                    </div>
                    <p className="text-xs text-white/60 leading-relaxed">
                      Start a session and invite your friend. You both keep your own Bluetooth earbuds in, and whatever you play, skip, or queue plays in perfect sync across both devices.
                    </p>
                  </div>

                  <button
                    onClick={handleCreate}
                    disabled={isConnecting}
                    className="w-full h-12 rounded-2xl bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 text-white font-extrabold text-sm flex items-center justify-center gap-2 shadow-xl shadow-pink-500/25 active:scale-98 transition-all disabled:opacity-50"
                  >
                    {isConnecting ? (
                      <>
                        <Loader2 size={18} className="animate-spin" />
                        <span>Starting Jam...</span>
                      </>
                    ) : (
                      <>
                        <Radio size={18} />
                        <span>Start Jam Session</span>
                      </>
                    )}
                  </button>
                </div>
              ) : (
                /* Tab 2: Join Jam */
                <form onSubmit={handleJoin} className="flex flex-col gap-4 pt-1">
                  <div className="flex flex-col gap-1.5">
                    <label className="text-[11px] font-bold uppercase tracking-wider text-white/50">
                      Enter 4-Digit Jam Code
                    </label>
                    <input
                      type="text"
                      value={joinCodeInput}
                      onChange={(e) => setJoinCodeInput(e.target.value.toUpperCase())}
                      placeholder="e.g. 7K4A"
                      maxLength={6}
                      className="w-full h-14 px-4 rounded-2xl bg-white/5 border border-white/20 text-center text-2xl font-black tracking-widest text-white uppercase placeholder-white/30 focus:outline-none focus:border-pink-500"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={isConnecting || !joinCodeInput.trim()}
                    className="w-full h-12 rounded-2xl bg-white text-black hover:bg-white/90 font-extrabold text-sm flex items-center justify-center gap-2 shadow-xl active:scale-98 transition-all disabled:opacity-50"
                  >
                    {isConnecting ? (
                      <>
                        <Loader2 size={18} className="animate-spin" />
                        <span>Connecting...</span>
                      </>
                    ) : (
                      <>
                        <span>Join Jam</span>
                        <ArrowRight size={18} />
                      </>
                    )}
                  </button>
                </form>
              )}
            </div>
          ) : (
            /* ─── CASE B: ACTIVE JAM SESSION ─── */
            <div className="flex flex-col gap-4">
              {/* Jam Room Code Display Card */}
              <div className="p-4 rounded-2xl bg-gradient-to-br from-white/[0.08] to-white/[0.02] border border-white/20 flex flex-col items-center gap-3 text-center">
                <span className="text-[11px] font-extrabold uppercase tracking-widest text-white/50">
                  Invite Code (Share with Friend)
                </span>
                <span className="text-4xl font-black tracking-[0.25em] text-transparent bg-clip-text bg-gradient-to-r from-pink-300 via-white to-purple-300 font-mono">
                  {roomCode}
                </span>

                <div className="flex items-center gap-2 w-full pt-1">
                  <button
                    onClick={handleCopyCode}
                    className="flex-1 py-2.5 px-3 rounded-xl bg-white/10 hover:bg-white/20 border border-white/15 text-xs font-bold text-white flex items-center justify-center gap-1.5 transition-all active:scale-95"
                  >
                    {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
                    <span>{copied ? 'Code Copied!' : 'Copy Code'}</span>
                  </button>

                  <button
                    onClick={handleShareInvite}
                    className="flex-1 py-2.5 px-3 rounded-xl bg-pink-500/20 hover:bg-pink-500/30 border border-pink-500/40 text-xs font-bold text-pink-300 flex items-center justify-center gap-1.5 transition-all active:scale-95"
                  >
                    {shared ? <Check size={14} /> : <Share2 size={14} />}
                    <span>{shared ? 'Shared!' : 'Share Invite'}</span>
                  </button>
                </div>
              </div>

              {/* Now Playing in Jam */}
              {currentTrack && (
                <div className="p-3 rounded-2xl bg-white/[0.04] border border-white/10 flex items-center gap-3">
                  <img
                    src={currentTrack.artworkUrl}
                    alt={currentTrack.title}
                    className="w-10 h-10 rounded-xl object-cover border border-white/10 flex-shrink-0"
                  />
                  <div className="flex flex-col min-w-0 flex-1">
                    <span className="text-[10px] font-bold text-white/50 uppercase tracking-wider flex items-center gap-1">
                      <Radio size={10} className="text-emerald-400" />
                      <span>{isPlaying ? 'Playing on both devices' : 'Paused in sync'}</span>
                    </span>
                    <h5 className="text-xs font-bold text-white truncate">{currentTrack.title}</h5>
                    <p className="text-[11px] text-white/50 truncate">{currentTrack.artistName}</p>
                  </div>
                </div>
              )}

              {/* Connected Listeners */}
              <div className="flex flex-col gap-2">
                <span className="text-[11px] font-extrabold uppercase tracking-wider text-white/50 flex items-center justify-between">
                  <span>Connected Listeners ({participants.length})</span>
                  <span className="text-emerald-400 font-bold lowercase">● synchronized</span>
                </span>
                <div className="max-h-36 overflow-y-auto flex flex-col gap-1.5 pr-1 no-scrollbar">
                  {participants.map((p, idx) => (
                    <div
                      key={p.deviceId || idx}
                      className="p-2.5 rounded-xl bg-white/[0.04] border border-white/10 flex items-center justify-between"
                    >
                      <div className="flex items-center gap-2.5">
                        <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-xs font-bold text-white">
                          <Headphones size={14} className="text-pink-400" />
                        </div>
                        <span className="text-xs font-bold text-white">{p.name}</span>
                      </div>
                      {p.isHost && (
                        <span className="px-2 py-0.5 rounded-full bg-pink-500/20 text-pink-300 text-[10px] font-extrabold">
                          Host
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Host Settings */}
              {isHost && (
                <div className="flex items-center justify-between p-3 rounded-2xl bg-white/[0.04] border border-white/10">
                  <div className="flex items-center gap-2.5">
                    <Shield size={16} className="text-purple-400" />
                    <div className="flex flex-col">
                      <span className="text-xs font-bold text-white">Guest Playback Controls</span>
                      <span className="text-[10px] text-white/50">Allow guests to skip, pause, & queue</span>
                    </div>
                  </div>
                  <input
                    type="checkbox"
                    checked={allowGuestControl}
                    onChange={(e) => setAllowGuestControl(e.target.checked)}
                    className="w-4 h-4 accent-pink-500 rounded cursor-pointer"
                  />
                </div>
              )}

              {/* Leave / End Jam Button */}
              <button
                onClick={leaveJam}
                className="w-full py-3 rounded-2xl bg-red-500/10 hover:bg-red-500/20 border border-red-500/30 text-red-300 font-bold text-xs flex items-center justify-center gap-2 transition-all active:scale-98 mt-1"
              >
                <LogOut size={16} />
                <span>{isHost ? 'End Jam for Everyone' : 'Leave Jam Session'}</span>
              </button>
            </div>
          )}

          {/* Riding Tip */}
          <div className="pt-2 border-t border-white/10 text-center">
            <p className="text-[10px] text-white/40 leading-relaxed">
              🏍️ <strong>Ride Ready:</strong> Keep separate earbuds connected to your respective phones. All play, pause, seek, and queue actions stay beat-for-beat aligned!
            </p>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};

