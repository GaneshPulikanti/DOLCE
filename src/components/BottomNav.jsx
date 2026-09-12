import React from 'react';
import { Home, Search, Library, Sparkles } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const BottomNav = () => {
  const { activeTab, setActiveTab } = useSearchStore();

  const navItems = [
    { id: 'home', label: 'Home', icon: Home },
    { id: 'search', label: 'Search', icon: Search },
    { id: 'library', label: 'Library', icon: Library },
    { id: 'profile', label: 'Taste Profile', icon: Sparkles },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 px-4 py-2 glass-panel rounded-none border-t border-white/10 bg-black/80 backdrop-blur-2xl md:hidden">
      <div className="flex items-center justify-around max-w-md mx-auto">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center gap-1 p-2 rounded-xl transition-all ${
                isActive ? 'text-purple-400 font-bold scale-105' : 'text-white/50 hover:text-white/80'
              }`}
            >
              <Icon size={20} className={isActive ? 'text-purple-400' : ''} />
              <span className="text-[10px]">{item.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};
