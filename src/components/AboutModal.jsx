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

            {/* Top Featured Developer Profile & Photo */}
            <div className="flex flex-col items-center text-center gap-3 pt-2">
              <div className="relative w-24 h-24 sm:w-28 sm:h-28 rounded-full overflow-hidden border-2 border-white/30 shadow-2xl p-1 bg-gradient-to-tr from-purple-500 via-pink-500 to-amber-400">
                <img 
                  src="/developer.jpg" 
                  alt="Ganesh Pulikanti" 
                  className="w-full h-full object-cover rounded-full shadow-inner" 
                />
              </div>

              <div className="flex flex-col items-center gap-0.5">
                <span className="text-[10px] font-black uppercase tracking-[0.2em] text-pink-400">
                  Lead Developer & Creator
                </span>
                <h3 className="text-2xl font-black text-white tracking-tight font-['Plus_Jakarta_Sans']">
                  Ganesh Pulikanti
                </h3>
                <a
                  href="https://github.com/GaneshPulikanti"
                  target="_blank"
                  rel="noreferrer"
                  className="mt-1 px-3.5 py-1 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 text-xs font-bold text-white transition-all transform active:scale-95 flex items-center gap-1.5 shadow-md"
                >
                  <span>GitHub: @GaneshPulikanti</span>
                </a>
              </div>
            </div>

            {/* App Description Box */}
            <div className="glass-panel p-3.5 rounded-2xl bg-white/[0.04] border border-white/10 text-xs text-white/80 leading-relaxed text-center flex flex-col gap-1.5 mt-1">
              <div className="flex items-center justify-center gap-2">
                <img src="/favicon.png" alt="DOLCE Logo" className="w-5 h-5 rounded-md" />
                <span className="font-black text-white tracking-wider text-sm">DOLCE AUDIO</span>
                <span className="text-[10px] text-pink-400 font-mono font-bold">v1.0</span>
              </div>
              <p className="text-white/70">
                High-fidelity ambient music streaming application with real-time synchronized lyrics, offline downloads, and dynamic artwork theme matching.
              </p>
            </div>

            {/* Footer */}
            <div className="pt-2 border-t border-white/10 text-center text-[11px] text-white/50 font-medium">
              <p>Designed & Developed by <strong className="text-white font-bold">Ganesh Pulikanti</strong></p>
              <p>© 2026 DOLCE Audio</p>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
