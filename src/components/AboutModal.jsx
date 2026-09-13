import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Sparkles, Music, Mic2, Zap, Palette, HardDrive, ShieldCheck, Heart } from 'lucide-react';

export const AboutModal = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 font-['Plus_Jakarta_Sans'] select-none">
          {/* Backdrop Blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/75 backdrop-blur-xl"
          />

          {/* Modal Panel */}
          <motion.div
            initial={{ opacity: 0, scale: 0.92, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.92, y: 20 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="relative w-full max-w-lg bg-[#0d0d0f]/95 border border-white/20 rounded-3xl p-6 sm:p-8 shadow-2xl z-10 flex flex-col gap-6 max-h-[85vh] overflow-y-auto no-scrollbar"
          >
            {/* Close Button */}
            <button
              onClick={onClose}
              className="absolute top-5 right-5 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white/80 hover:text-white transition-all"
              title="Close"
            >
              <X size={18} />
            </button>

            {/* Header / Logo */}
            <div className="flex flex-col items-center text-center gap-3 pt-2">
              <div className="relative w-20 h-20 rounded-3xl overflow-hidden border border-white/25 shadow-2xl bg-gradient-to-tr from-purple-900/60 to-pink-600/60 p-1 flex items-center justify-center">
                <img src="/favicon.png" alt="DOLCE Logo" className="w-full h-full object-cover rounded-2xl" />
              </div>
              <div className="flex flex-col items-center">
                <h2 className="text-3xl font-black text-white tracking-widest">DOLCE</h2>
                <span className="text-xs font-bold uppercase tracking-[0.2em] text-pink-400 mt-1">
                  Ambient Music Streaming v1.0
                </span>
              </div>
            </div>

            {/* App Description */}
            <div className="glass-panel p-4 rounded-2xl bg-white/[0.03] border border-white/10 text-xs sm:text-sm text-white/80 leading-relaxed text-center">
              <p>
                <strong className="text-white">DOLCE</strong> is a high-fidelity music streaming application designed for seamless audio playback, real-time synchronized lyrics, and personalized music discovery. Engineered with an ultra-responsive glassmorphic interface, DOLCE delivers an immersive, ad-free music listening experience across Web and Mobile.
              </p>
            </div>

            {/* Features List */}
            <div className="flex flex-col gap-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-white/50 px-1">
                Key Features & Capabilities
              </h4>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.04] border border-white/10">
                  <div className="p-2 rounded-lg bg-purple-500/20 text-purple-300">
                    <Music size={16} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-white">HD Audio Catalog</span>
                    <span className="text-[10px] text-white/50">Millions of songs & remixes</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.04] border border-white/10">
                  <div className="p-2 rounded-lg bg-pink-500/20 text-pink-300">
                    <Mic2 size={16} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-white">Synced Lyrics</span>
                    <span className="text-[10px] text-white/50">LRCLIB real-time karaoke</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.04] border border-white/10">
                  <div className="p-2 rounded-lg bg-cyan-500/20 text-cyan-300">
                    <Palette size={16} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-white">Dynamic Palette</span>
                    <span className="text-[10px] text-white/50">Adaptive artwork glow</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.04] border border-white/10">
                  <div className="p-2 rounded-lg bg-emerald-500/20 text-emerald-300">
                    <HardDrive size={16} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-white">Offline Downloads</span>
                    <span className="text-[10px] text-white/50">IndexedDB local storage</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.04] border border-white/10 sm:col-span-2">
                  <div className="p-2 rounded-lg bg-amber-500/20 text-amber-300">
                    <Zap size={16} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-white">60+ FPS Native Engine</span>
                    <span className="text-[10px] text-white/50">GPU-accelerated native animations for Android & Web</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Developer Showcase Card */}
            <div className="glass-panel p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-purple-900/40 via-pink-900/25 to-black/60 border border-purple-500/30 flex items-center justify-between shadow-xl">
              <div className="flex items-center gap-3.5">
                <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-purple-600 to-pink-500 flex items-center justify-center text-white font-black text-base shadow-lg shadow-purple-600/30 border border-white/20">
                  GP
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-extrabold uppercase tracking-[0.18em] text-pink-400">
                    Lead Developer & Architect
                  </span>
                  <h3 className="text-base sm:text-lg font-black text-white tracking-tight flex items-center gap-1.5 font-['Plus_Jakarta_Sans']">
                    <span>Ganesh Pulikanti</span>
                    <Sparkles size={14} className="text-amber-400 fill-amber-400 animate-pulse" />
                  </h3>
                </div>
              </div>

              <a
                href="https://github.com/GaneshPulikanti"
                target="_blank"
                rel="noreferrer"
                className="px-3.5 py-1.5 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 text-xs font-bold text-white transition-all transform active:scale-95 flex items-center gap-1.5"
              >
                <span>@GaneshPulikanti</span>
              </a>
            </div>

            {/* Footer / Copyright */}
            <div className="pt-2 border-t border-white/10 flex flex-col items-center text-center gap-1.5 text-[11px] text-white/50 font-medium">
              <div className="flex items-center gap-1.5">
                <span>Designed & Developed by</span>
                <span className="text-white font-black tracking-wide">Ganesh Pulikanti</span>
                <Heart size={12} className="text-pink-500 fill-pink-500 ml-0.5" />
              </div>
              <p>© 2026 DOLCE Audio · Created by Ganesh Pulikanti</p>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
