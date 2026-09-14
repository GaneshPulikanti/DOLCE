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
    <nav className="fixed bottom-4 left-4 right-4 z-40 max-w-md mx-auto pointer-events-auto font-['Plus_Jakarta_Sans']">
      {/* iOS Camera Mode Switcher Glossy Glass Container */}
      <div className="relative w-full h-14 rounded-full bg-[#0c0c0e]/85 border border-white/20 backdrop-blur-3xl shadow-[0_12px_40px_rgba(0,0,0,0.7)] p-1 flex items-center justify-between overflow-hidden">
        
        {/* iOS Camera Mode Glossy Active Pill Indicator (Strictly container-bound) */}
        <div
          className="absolute top-1 bottom-1 rounded-full bg-gradient-to-b from-white/30 via-white/15 to-white/5 border border-white/40 backdrop-blur-3xl shadow-[0_4px_16px_rgba(0,0,0,0.5),_inset_0_1px_1px_rgba(255,255,255,0.6)] transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] z-0 pointer-events-none"
          style={{
            width: 'calc(33.333% - 2px)',
            left: `calc(${currentIndex * 33.333}% + 1px)`,
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
              className="relative z-10 flex-1 h-full flex items-center justify-center gap-2 rounded-full transition-all duration-300 focus:outline-none active:scale-95"
            >
              <Icon
                size={19}
                className={`transition-all duration-300 ${
                  isSelected
                    ? 'text-white scale-110 drop-shadow-[0_2px_10px_rgba(255,255,255,0.95)]'
                    : 'text-white/45 hover:text-white/80'
                }`}
              />
              <span
                className={`text-xs tracking-wide transition-all duration-300 ${
                  isSelected 
                    ? 'text-white font-extrabold drop-shadow-[0_1px_4px_rgba(255,255,255,0.6)]' 
                    : 'text-white/45 font-medium hover:text-white/80'
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
