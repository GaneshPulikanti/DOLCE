import React from 'react';
import { Home, Search, Library } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const BottomNav = () => {
  const { activeTab, setActiveTab } = useSearchStore();

  const tabs = [
    { id: 'home', label: 'Discover', icon: Home },
    { id: 'search', label: 'Search', icon: Search },
    { id: 'library', label: 'Library', icon: Library },
  ];

  const currentIndex = Math.max(0, tabs.findIndex((t) => t.id === activeTab));

  return (
    <nav className="fixed bottom-3 left-4 right-4 z-40 max-w-md mx-auto pointer-events-auto font-['Inter']">
      <div className="relative w-full h-14 rounded-full glass-panel bg-[#121215]/90 border border-white/15 backdrop-blur-2xl shadow-2xl p-1.5 flex items-center justify-between overflow-hidden">
        
        {/* Sliding Active Pill Highlight (Stays 100% strictly within the bar container) */}
        <div
          className="absolute top-1.5 bottom-1.5 rounded-full bg-white/15 border border-white/20 backdrop-blur-md shadow-[0_0_15px_rgba(255,255,255,0.15)] transition-all duration-300 ease-out z-0 pointer-events-none"
          style={{
            width: 'calc(33.333% - 4px)',
            left: `calc(${currentIndex * 33.333}% + 2px)`,
          }}
        />

        {/* Navigation Tabs */}
        {tabs.map((tab, idx) => {
          const Icon = tab.icon;
          const isSelected = idx === currentIndex;

          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="relative z-10 flex-1 h-full flex items-center justify-center gap-2 rounded-full transition-all duration-300 focus:outline-none"
            >
              <Icon
                size={20}
                className={`transition-all duration-300 ${
                  isSelected
                    ? 'text-white scale-110 drop-shadow-[0_0_10px_rgba(255,255,255,0.8)]'
                    : 'text-white/50 hover:text-white/80'
                }`}
              />
              <span
                className={`text-xs font-bold transition-all duration-300 ${
                  isSelected ? 'text-white opacity-100 font-extrabold' : 'text-white/50 opacity-60'
                }`}
              >
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

