import React from 'react';
import { Menu, User } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const Navbar = ({ onOpenDrawer }) => {
  const { setActiveTab } = useSearchStore();

  return (
    <header className="sticky top-0 z-30 w-full px-4 lg:px-8 py-3.5 flex items-center justify-between bg-[#080808]/80 backdrop-blur-xl border-b border-white/10 font-['Inter']">
      {/* Left: Hamburger Drawer Menu Button & Title */}
      <div className="flex items-center gap-3.5">
        <button
          onClick={onOpenDrawer}
          className="p-2 rounded-2xl bg-white/5 border border-white/10 text-white/90 hover:text-white hover:bg-white/10 transition-all active:scale-95"
          title="Open Menu"
        >
          <Menu size={22} />
        </button>

        <h1 className="text-xl lg:text-2xl font-black tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-white via-white/90 to-white/70">
          DOLCE
        </h1>
      </div>

      {/* Right: User Profile Avatar */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setActiveTab('profile')}
          className="w-9 h-9 rounded-full bg-white/10 border border-white/20 flex items-center justify-center text-white hover:border-white/40 transition-all shadow-md overflow-hidden"
          title="Profile Settings"
        >
          <User size={18} className="text-white/80" />
        </button>
      </div>
    </header>
  );
};

