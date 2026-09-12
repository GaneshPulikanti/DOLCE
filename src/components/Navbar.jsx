import React from 'react';
import { Menu, Search, User } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const Navbar = ({ onOpenDrawer }) => {
  const { activeTab, setActiveTab, searchQuery, setSearchQuery } = useSearchStore();

  const getTitle = () => {
    switch (activeTab) {
      case 'search':
        return 'Search';
      case 'library':
        return 'Library';
      case 'profile':
        return 'Taste Profile';
      case 'home':
      default:
        return 'Discover';
    }
  };

  const handleSearchChange = (e) => {
    setSearchQuery(e.target.value);
    if (activeTab !== 'search') {
      setActiveTab('search');
    }
  };

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

        <h1 className="text-xl lg:text-2xl font-black text-white tracking-tight">
          {getTitle()}
        </h1>
      </div>

      {/* Center: Search Input (When on Search or expanded) */}
      <div className="hidden sm:flex flex-1 max-w-md mx-4 lg:mx-8">
        <div className="relative w-full flex items-center">
          <Search size={16} className="absolute left-3.5 text-white/40 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={handleSearchChange}
            placeholder="Search songs, artists, albums..."
            className="w-full h-9 pl-9 pr-4 rounded-full bg-white/5 border border-white/10 text-xs text-white placeholder-white/40 focus:outline-none focus:border-white/30 focus:bg-white/10 transition-all font-medium"
          />
        </div>
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
