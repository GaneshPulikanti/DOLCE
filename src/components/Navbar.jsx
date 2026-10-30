import React from 'react';
import { Menu, Info, Radio } from 'lucide-react';
import { useJamStore } from '../store/useJamStore';

export const Navbar = ({ onOpenDrawer, onOpenAbout }) => {
  const { isInJam, participants, openJamModal } = useJamStore();

  return (
    <header className="sticky top-0 z-30 w-full px-4 lg:px-8 py-3.5 flex items-center justify-between bg-[#080808]/80 backdrop-blur-xl border-b border-white/10 font-['Plus_Jakarta_Sans']">
      {/* Left: Hamburger Drawer Menu Button & Title */}
      <div className="flex items-center gap-3.5">
        <button
          onClick={onOpenDrawer}
          className="p-2 rounded-2xl bg-white/5 border border-white/10 text-white/90 hover:text-white hover:bg-white/10 transition-all active:scale-95"
          title="Open Menu"
        >
          <Menu size={22} />
        </button>

        <div 
          onClick={onOpenAbout}
          className="flex items-center gap-2.5 cursor-pointer hover:opacity-90 transition-opacity"
        >
          <img 
            src="/favicon.png" 
            alt="DOLCE Logo" 
            className="w-8 h-8 rounded-xl object-cover border border-white/14 shadow-md flex-shrink-0" 
          />
          <div className="flex flex-col leading-none">
            <span className="text-xl lg:text-2xl font-black tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-white via-white/90 to-white/70">
              DOLCE
            </span>
            <span className="text-[9px] font-extrabold text-pink-400/90 tracking-wider uppercase mt-0.5">
              by Ganesh Pulikanti
            </span>
          </div>
        </div>
      </div>

      {/* Right: Jam Co-Listening & Info / About App Button */}
      <div className="flex items-center gap-2">
        <button
          onClick={openJamModal}
          className={`p-2 rounded-2xl border transition-all active:scale-95 flex items-center gap-1.5 px-3 text-xs font-bold ${
            isInJam
              ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300 shadow-md shadow-emerald-500/10'
              : 'bg-white/5 border-white/10 text-white/80 hover:text-white hover:bg-white/10'
          }`}
          title={isInJam ? `In Jam (${participants.length} listeners)` : "DOLCE Jam"}
        >
          <Radio size={16} className={isInJam ? 'text-emerald-400 animate-pulse' : 'text-pink-400'} />
          <span>{isInJam ? `Jam (${participants.length})` : 'Jam'}</span>
        </button>

        <button
          onClick={onOpenAbout}
          className="p-2 rounded-2xl bg-white/5 border border-white/10 text-white/80 hover:text-white hover:bg-white/10 transition-all active:scale-95 flex items-center gap-1.5 px-3 text-xs font-bold"
          title="About DOLCE"
        >
          <Info size={18} className="text-purple-400" />
          <span className="hidden sm:inline">About</span>
        </button>
      </div>
    </header>
  );
};
