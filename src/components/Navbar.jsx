import React from 'react';
import { Menu, Info } from 'lucide-react';

export const Navbar = ({ onOpenDrawer, onOpenAbout }) => {
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

      {/* Right: Info / About App Button */}
      <button
        onClick={onOpenAbout}
        className="p-2 rounded-2xl bg-white/5 border border-white/10 text-white/80 hover:text-white hover:bg-white/10 transition-all active:scale-95 flex items-center gap-1.5 px-3 text-xs font-bold"
        title="About DOLCE"
      >
        <Info size={18} className="text-purple-400" />
        <span className="hidden sm:inline">About</span>
      </button>
    </header>
  );
};
