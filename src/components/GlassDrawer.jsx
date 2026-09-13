import React from 'react';
import { X, Home, Search, Library, Heart, Download, History, Music } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const GlassDrawer = ({ isOpen, onClose }) => {
  const { setActiveTab } = useSearchStore();

  if (!isOpen) return null;

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
    <div className="fixed inset-0 z-50 flex">
      {/* Backdrop overlay */}
      <div 
        onClick={onClose}
        className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300"
      />

      {/* Drawer content */}
      <div className="relative w-72 max-w-[80vw] h-full bg-[#111111]/95 backdrop-blur-2xl border-r border-white/10 shadow-2xl flex flex-col z-10 font-['Inter']">
        {/* Header */}
        <div className="p-6 flex items-center justify-between border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-white/10 border border-white/20 flex items-center justify-center">
              <Music size={18} className="text-white" />
            </div>
            <span className="text-lg font-black tracking-widest text-white">DOLCE</span>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 text-white/60 hover:text-white transition-colors"
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
                className="flex items-center gap-3.5 px-4 py-3 rounded-2xl text-sm font-semibold text-white/80 hover:text-white hover:bg-white/10 transition-all text-left"
              >
                <Icon size={18} className="text-white/70" />
                <span>{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};
