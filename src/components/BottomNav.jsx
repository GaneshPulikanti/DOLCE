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
  
  // Percent horizontal offset: 16.666%, 50%, 83.333%
  const locPercent = (currentIndex * 2 + 1) / 6 * 100;
  // Rotation angle calculation for rolling bubble
  const rotationAngle = (currentIndex - 0) * 360;

  return (
    <nav className="fixed bottom-2 left-4 right-4 z-30 h-16 max-w-md mx-auto pointer-events-auto">
      {/* ── Background Curved Capsule Container with SVG U-Scoop Dip ── */}
      <div className="absolute inset-0 rounded-[28px] overflow-hidden shadow-2xl bg-[#141416] border border-white/10">
        <svg className="w-full h-full" preserveAspectRatio="none" viewBox="0 0 300 64">
          <defs>
            <filter id="dipShadow" x="-10%" y="-10%" width="120%" height="120%">
              <feDropShadow dx="0" dy="4" stdDeviation="6" floodColor="#000000" floodOpacity="0.6" />
            </filter>
          </defs>

          {/* Dynamic U-Scoop Cutout Path */}
          <path
            d={`
              M 0 0 
              H ${locPercent * 3 - 35} 
              C ${locPercent * 3 - 20} 0, ${locPercent * 3 - 15} 24, ${locPercent * 3} 24 
              C ${locPercent * 3 + 15} 24, ${locPercent * 3 + 20} 0, ${locPercent * 3 + 35} 0 
              H 300 
              V 64 
              H 0 
              Z
            `}
            fill="#141416"
            className="transition-all duration-400 ease-out"
          />
        </svg>
      </div>

      {/* ── Sliding Rolling Active Circle Bubble ── */}
      <div
        className="absolute -top-3.5 w-13 h-13 rounded-full glass-panel border border-white/30 bg-white/14 backdrop-blur-xl shadow-[0_0_20px_rgba(255,255,255,0.2)] flex items-center justify-center transition-all duration-400 ease-out z-20 pointer-events-none"
        style={{
          left: `calc(${locPercent}% - 26px)`,
        }}
      >
        <div
          className="transition-transform duration-500 ease-out flex items-center justify-center"
          style={{ transform: `rotate(${rotationAngle}deg)` }}
        >
          {React.createElement(tabs[currentIndex]?.icon || Home, {
            size: 24,
            className: 'text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.8)]',
          })}
        </div>
      </div>

      {/* ── Bottom Icons Row ── */}
      <div className="relative z-10 w-full h-full flex items-center justify-around">
        {tabs.map((tab, idx) => {
          const Icon = tab.icon;
          const isSelected = idx === currentIndex;

          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="w-20 h-full flex items-center justify-center transition-all focus:outline-none"
            >
              <div className={`transition-opacity duration-250 ${isSelected ? 'opacity-0 scale-75' : 'opacity-60 hover:opacity-100'}`}>
                <Icon size={22} className="text-white" />
              </div>
            </button>
          );
        })}
      </div>
    </nav>
  );
};
