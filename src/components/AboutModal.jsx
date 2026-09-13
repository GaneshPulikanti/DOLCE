import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Sparkles, Music, Mic2, Zap, Palette, HardDrive, ShieldCheck, Heart } from 'lucide-react';

export const AboutModal = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 font-['Plus_Jakarta_Sans']">
          {/* Backdrop Blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/80 backdrop-blur-xl"
          />

          {/* Modal Panel */}
          <motion.div
            initial={{ opacity: 0, scale: 0.92, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.92, y: 20 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="relative w-full max-w-md bg-[#0d0d0f]/98 border border-white/20 rounded-3xl p-5 sm:p-6 shadow-2xl z-10 flex flex-col gap-4 max-h-[90vh] overflow-y-auto touch-pan-y overscroll-contain"
          >
            {/* Close Button */}
            <button
              onClick={onClose}
              className="absolute top-4 right-4 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white/80 hover:text-white transition-all z-20"
              title="Close"
            >
              <X size={18} />
            </button>

            {/* 1. Primary Header: App Logo & Title */}
            <div className="flex flex-col items-center text-center gap-3 pt-2">
              <div className="relative w-20 h-20 sm:w-22 sm:h-22 rounded-3xl overflow-hidden border border-white/25 shadow-2xl bg-gradient-to-tr from-purple-900/60 to-pink-600/60 p-1 flex items-center justify-center">
                <img src="/favicon.png" alt="DOLCE Logo" className="w-full h-full object-cover rounded-2xl" />
              </div>
              <div className="flex flex-col items-center">
                <h2 className="text-3xl sm:text-4xl font-black text-white tracking-widest">DOLCE</h2>
                <span className="text-xs font-bold uppercase tracking-[0.2em] text-pink-400 mt-1">
                  Ambient Music Streaming v1.0
                </span>
              </div>
            </div>

            {/* 2. App Overview Description */}
            <div className="glass-panel p-4 rounded-2xl bg-white/[0.04] border border-white/10 text-xs sm:text-sm text-white/80 leading-relaxed text-center">
              <p>
                <strong className="text-white">DOLCE</strong> is a high-fidelity music streaming application designed for seamless audio playback, real-time synchronized lyrics, and personalized music discovery. Engineered with an ultra-responsive glassmorphic interface, DOLCE delivers an immersive, ad-free music listening experience across Web and Mobile.
              </p>
            </div>

            {/* 3. Developer Showcase Card (Ganesh Pulikanti) */}
            <div className="glass-panel p-5 rounded-2xl bg-gradient-to-br from-purple-900/40 via-pink-950/30 to-black/80 border border-purple-500/30 flex flex-col items-center text-center gap-3.5 shadow-xl">
              {/* Prominent Big Developer Photo */}
              <div className="relative w-24 h-24 sm:w-28 sm:h-28 rounded-full overflow-hidden border-2 border-white/30 shadow-2xl p-1 bg-gradient-to-tr from-purple-500 via-pink-500 to-amber-400 flex-shrink-0">
                <img 
                  src="/developer.jpg" 
                  alt="Ganesh Pulikanti" 
                  className="w-full h-full object-cover rounded-full shadow-inner" 
                />
              </div>

              {/* Developer Title & Name Underneath */}
              <div className="flex flex-col items-center gap-1">
                <span className="text-[10px] font-black uppercase tracking-[0.2em] text-pink-400">
                  Lead Developer & Creator
                </span>
                <h3 className="text-xl sm:text-2xl font-black text-white tracking-tight font-['Plus_Jakarta_Sans']">
                  Ganesh Pulikanti
                </h3>
              </div>
            </div>

            {/* 4. Footer */}
            <div className="pt-2 border-t border-white/10 text-center text-[11px] text-white/50 font-medium">
              <p>Designed & Developed by <strong className="text-white font-bold">Ganesh Pulikanti</strong></p>
              <p>© 2026 DOLCE Audio · All rights reserved</p>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
