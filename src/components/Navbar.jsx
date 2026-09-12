import React from 'react';
import { Search, Music, Sparkles } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const Navbar = () => {
  const { activeTab, setActiveTab, searchQuery, setSearchQuery } = useSearchStore();

  const handleSearchChange = (e) => {
    setSearchQuery(e.target.value);
    if (activeTab !== 'search') {
      setActiveTab('search');
    }
  };

  return (
    <header className="sticky top-0 z-40 w-full px-4 lg:px-8 py-3.5 flex items-center justify-between glass-panel border-b border-white/10 rounded-none bg-black/60 backdrop-blur-xl">
      {/* Brand Logo */}
      <div 
        onClick={() => setActiveTab('home')}
        className="flex items-center gap-3 cursor-pointer group"
      >
        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-purple-600 via-pink-500 to-cyan-400 p-[1px] shadow-lg shadow-purple-500/20 group-hover:scale-105 transition-transform">
          <div className="w-full h-full bg-black/90 rounded-[11px] flex items-center justify-center">
            <Music size={20} className="text-purple-400" />
          </div>
        </div>
        <span className="text-xl font-extrabold tracking-wider text-gradient font-sans">
          DOLCE
        </span>
      </div>

      {/* Search Input Bar */}
      <div className="flex-1 max-w-md mx-4 lg:mx-12">
        <div className="relative flex items-center">
          <Search size={18} className="absolute left-3.5 text-white/40 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={handleSearchChange}
            placeholder="Search for songs, artists, or albums..."
            className="w-full h-10 pl-10 pr-4 rounded-full bg-white/5 border border-white/10 text-sm text-white placeholder-white/40 focus:outline-none focus:border-purple-500/60 focus:bg-white/10 transition-all"
          />
        </div>
      </div>

      {/* Action Chips / Profile */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => setActiveTab('profile')}
          className="flex items-center gap-2 px-3 py-1.5 rounded-full glass-card text-xs font-semibold text-white/80 hover:text-white hover:border-purple-500/40 transition-all"
        >
          <Sparkles size={14} className="text-pink-400" />
          <span>Taste Profile</span>
        </button>
      </div>
    </header>
  );
};
