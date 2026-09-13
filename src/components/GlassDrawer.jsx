import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Home, Search, Library, Heart, Download, History, Music } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const GlassDrawer = ({ isOpen, onClose, onOpenAbout }) => {
  const { setActiveTab } = useSearchStore();

  const menuItems = [
    { label: 'Discover', icon: Home, tab: 'home' },
    { label: 'Search', icon: Search, tab: 'search' },
    { label: 'Library', icon: Library, tab: 'library' },
    { label: 'Liked Songs', icon: Heart, tab: 'library' },
    { label: 'Offline Downloads', icon: Download, tab: 'library' },
    { label: 'Recently Played', icon: History, tab: 'library' },
  ];

  const handleNavigation = (item) => {
    setActiveTab(item.tab);
    onClose();
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex font-['Plus_Jakarta_Sans'] select-none">
          {/* Smooth Fade Backdrop Overlay */}
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
            onClick={onClose}
            className="fixed inset-0 bg-black/60 backdrop-blur-md"
          />

          {/* Buttery Smooth Liquid Spring Slide Drawer Panel */}
          <motion.div
            initial={{ x: '-100%' }}
            animate={{ x: 0 }}
            exit={{ x: '-100%' }}
            transition={{ type: 'spring', damping: 28, stiffness: 220, mass: 0.8 }}
            className="relative w-72 max-w-[80vw] h-full bg-[#111111]/95 backdrop-blur-2xl border-r border-white/10 shadow-2xl flex flex-col z-10"
          >
            {/* Header */}
            <div className="p-6 flex items-center justify-between border-b border-white/10">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl overflow-hidden border border-white/20 shadow-md">
                  <img src="/favicon.png" alt="DOLCE Logo" className="w-full h-full object-cover" />
                </div>
                <span className="text-lg font-black tracking-widest text-white">DOLCE</span>
              </div>
              <button 
                onClick={onClose}
                className="p-1.5 text-white/60 hover:text-white transition-colors rounded-full hover:bg-white/10"
                title="Close Menu"
              >
                <X size={20} />
              </button>
            </div>

            {/* Navigation Items */}
            <div className="flex-1 overflow-y-auto py-4 px-3 flex flex-col gap-1">
              {menuItems.map((item, idx) => {
                const Icon = item.icon;
                return (
                  <button
                    key={idx}
                    onClick={() => handleNavigation(item)}
                    className="flex items-center gap-3.5 px-4 py-3 rounded-2xl text-sm font-semibold text-white/80 hover:text-white hover:bg-white/10 transition-all text-left transform active:scale-98"
                  >
                    <Icon size={18} className="text-white/70" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>

            {/* Drawer Footer: About DOLCE & Developer Credits */}
            <div className="p-3 border-t border-white/10 flex flex-col gap-2">
              <button
                onClick={() => {
                  onClose();
                  if (onOpenAbout) onOpenAbout();
                }}
                className="w-full flex items-center justify-between px-4 py-3 rounded-2xl bg-white/[0.05] border border-white/10 text-white hover:bg-white/10 transition-all font-bold text-xs transform active:scale-98 shadow-md"
              >
                <div className="flex items-center gap-3">
                  <div className="w-7 h-7 rounded-xl bg-purple-500/20 flex items-center justify-center text-purple-300">
                    <img src="/favicon.png" alt="DOLCE" className="w-4 h-4 rounded" />
                  </div>
                  <span>About DOLCE</span>
                </div>
                <span className="text-[10px] text-white/40 font-mono">v1.0</span>
              </button>

              <div className="px-2 pt-1 pb-2 flex flex-col items-center text-center">
                <span className="text-[10px] text-white/40 font-medium uppercase tracking-wider">
                  Developed by <strong className="text-white font-bold">Ganesh Pulikanti</strong>
                </span>
              </div>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
