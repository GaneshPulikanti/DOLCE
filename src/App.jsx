import React, { useEffect, useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
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
  const { activeTab } = useSearchStore();
  const { currentTrack } = usePlayerStore();
  const [themePalette, setThemePalette] = useState(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [isAboutOpen, setIsAboutOpen] = useState(false);

  useEffect(() => {
    if (currentTrack?.artworkUrl) {
      extractArtworkColor(currentTrack.artworkUrl).then(setThemePalette);
    }
  }, [currentTrack?.artworkUrl, currentTrack?.id]);

  // Strictly block horizontal touch swipe gestures outside horizontal scroll elements
  useEffect(() => {
    let startX = 0;
    let startY = 0;

    const handleTouchStart = (e) => {
      if (e.touches && e.touches.length > 0) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
      }
    };

    const handleTouchMove = (e) => {
      if (!e.touches || e.touches.length === 0) return;
      const deltaX = Math.abs(e.touches[0].clientX - startX);
      const deltaY = Math.abs(e.touches[0].clientY - startY);

      if (deltaX > deltaY && deltaX > 15) {
        let target = e.target;
        let isInsideHorizontalScroll = false;

        while (target && target !== document.body) {
          if (
            target.scrollWidth > target.clientWidth &&
            (window.getComputedStyle(target).overflowX === 'auto' ||
              window.getComputedStyle(target).overflowX === 'scroll')
          ) {
            isInsideHorizontalScroll = true;
            break;
          }
          target = target.parentElement;
        }

        if (!isInsideHorizontalScroll && e.cancelable) {
          e.preventDefault();
        }
      }
    };

    window.addEventListener('touchstart', handleTouchStart, { passive: true });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });

    return () => {
      window.removeEventListener('touchstart', handleTouchStart);
      window.removeEventListener('touchmove', handleTouchMove);
    };
  }, []);

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
