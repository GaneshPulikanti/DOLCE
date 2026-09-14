import React, { useEffect, useState } from 'react';
import { Navbar } from './components/Navbar';
import { BottomNav } from './components/BottomNav';
import { PlayerBar } from './components/PlayerBar';
import { GlassDrawer } from './components/GlassDrawer';
import { AboutModal } from './components/AboutModal';
import { Home } from './pages/Home';
import { Search } from './pages/Search';
import { Library } from './pages/Library';
import { TasteProfile } from './pages/TasteProfile';
import { useSearchStore } from './store/useSearchStore';
import { usePlayerStore } from './store/usePlayerStore';
import { extractArtworkColor } from './services/colorExtractor';

export const App = () => {
  const { activeTab, setActiveTab } = useSearchStore();
  const { currentTrack } = usePlayerStore();
  const [themePalette, setThemePalette] = useState(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [isAboutOpen, setIsAboutOpen] = useState(false);

  useEffect(() => {
    if (currentTrack?.artworkUrl) {
      extractArtworkColor(currentTrack.artworkUrl).then(setThemePalette);
    }
  }, [currentTrack?.artworkUrl, currentTrack?.id]);

  // Touch Swipe Gesture Navigation between Discover <-> Search <-> Library
  useEffect(() => {
    let startX = 0;
    let startY = 0;

    const handleTouchStart = (e) => {
      if (e.touches && e.touches.length > 0) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
      }
    };

    const handleTouchEnd = (e) => {
      if (!e.changedTouches || e.changedTouches.length === 0) return;

      const endX = e.changedTouches[0].clientX;
      const endY = e.changedTouches[0].clientY;

      const deltaX = endX - startX;
      const deltaY = endY - startY;

      // Swipe trigger: horizontal distance > 50px and horizontal movement is dominant over vertical
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
        const tabs = ['home', 'search', 'library'];
        const currentIdx = tabs.indexOf(activeTab);

        if (currentIdx !== -1) {
          if (deltaX < 0 && currentIdx < tabs.length - 1) {
            // Swipe Left -> Move to Next Tab
            setActiveTab(tabs[currentIdx + 1]);
          } else if (deltaX > 0 && currentIdx > 0) {
            // Swipe Right -> Move to Previous Tab
            setActiveTab(tabs[currentIdx - 1]);
          }
        }
      }
    };

    const mainEl = document.querySelector('main');
    if (mainEl) {
      mainEl.addEventListener('touchstart', handleTouchStart, { passive: true });
      mainEl.addEventListener('touchend', handleTouchEnd, { passive: true });
    }

    return () => {
      if (mainEl) {
        mainEl.removeEventListener('touchstart', handleTouchStart);
        mainEl.removeEventListener('touchend', handleTouchEnd);
      }
    };
  }, [activeTab, setActiveTab]);

  const orb1Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.dominant} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

  const orb2Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.glow} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

  return (
    <div className="relative w-full h-full min-h-screen bg-[#050505] text-white flex flex-col overflow-hidden selection:bg-white/20 selection:text-white font-['Plus_Jakarta_Sans']">
      {/* Background Ambient Orbs */}
      <div className="bg-glow-container pointer-events-none">
        <div className="bg-glow-orb-1 transition-all duration-1000 opacity-20" style={orb1Style} />
        <div className="bg-glow-orb-2 transition-all duration-1000 opacity-20" style={orb2Style} />
      </div>

      {/* Slide-over Side Glass Drawer */}
      <GlassDrawer 
        isOpen={isDrawerOpen} 
        onClose={() => setIsDrawerOpen(false)} 
        onOpenAbout={() => setIsAboutOpen(true)}
      />

      {/* About DOLCE Information Modal */}
      <AboutModal 
        isOpen={isAboutOpen} 
        onClose={() => setIsAboutOpen(false)} 
      />

      {/* Top App Bar Header */}
      <Navbar 
        onOpenDrawer={() => setIsDrawerOpen(true)} 
        onOpenAbout={() => setIsAboutOpen(true)}
      />

      {/* Main Page Area */}
      <main 
        className="relative z-10 flex-1 w-full max-w-7xl mx-auto overflow-y-auto overflow-x-hidden no-scrollbar"
      >
        <div className="w-full min-h-full">
          {activeTab === 'home' && <Home />}
          {activeTab === 'search' && <Search />}
          {activeTab === 'library' && <Library />}
          {activeTab === 'profile' && <TasteProfile />}
        </div>
      </main>

      {/* Persistent Mini Player & Expanded Player Modal */}
      <PlayerBar themePalette={themePalette} />

      {/* Curved Liquid Bottom Tab Navigation */}
      <BottomNav />
    </div>
  );
};

export default App;
