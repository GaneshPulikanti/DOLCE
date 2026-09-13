import React, { useEffect, useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Navbar } from './components/Navbar';
import { BottomNav } from './components/BottomNav';
import { PlayerBar } from './components/PlayerBar';
import { GlassDrawer } from './components/GlassDrawer';
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
  const [prevTab, setPrevTab] = useState(activeTab);

  const mainTabs = ['home', 'search', 'library'];
  const currentIndex = mainTabs.indexOf(activeTab);

  const touchStartRef = useRef(0);
  const touchStartYRef = useRef(0);

  useEffect(() => {
    setPrevTab(activeTab);
  }, [activeTab]);

  useEffect(() => {
    if (currentTrack?.artworkUrl) {
      extractArtworkColor(currentTrack.artworkUrl).then(setThemePalette);
    }
  }, [currentTrack?.artworkUrl, currentTrack?.id]);

  const handleTouchStart = (e) => {
    touchStartRef.current = e.touches[0].clientX;
    touchStartYRef.current = e.touches[0].clientY;
  };

  const handleTouchEnd = (e) => {
    if (!touchStartRef.current) return;
    const deltaX = e.changedTouches[0].clientX - touchStartRef.current;
    const deltaY = e.changedTouches[0].clientY - touchStartYRef.current;

    // Trigger tab swipe ONLY if horizontal swipe is dominant over vertical scroll
    if (Math.abs(deltaX) > 75 && Math.abs(deltaX) > Math.abs(deltaY) * 1.6) {
      if (deltaX < 0 && currentIndex !== -1 && currentIndex < mainTabs.length - 1) {
        setActiveTab(mainTabs[currentIndex + 1]);
      } else if (deltaX > 0 && currentIndex > 0) {
        setActiveTab(mainTabs[currentIndex - 1]);
      }
    }
    touchStartRef.current = 0;
    touchStartYRef.current = 0;
  };

  const orb1Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.dominant} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

  const orb2Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.glow} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

  // Calculate slide direction
  const prevIdx = mainTabs.indexOf(prevTab);
  const direction = currentIndex >= prevIdx ? 1 : -1;

  return (
    <div className="relative w-full h-full min-h-screen bg-[#050505] text-white flex flex-col overflow-hidden selection:bg-white/20 selection:text-white font-['Inter']">
      {/* Background Ambient Orbs */}
      <div className="bg-glow-container pointer-events-none">
        <div className="bg-glow-orb-1 transition-all duration-1000 opacity-20" style={orb1Style} />
        <div className="bg-glow-orb-2 transition-all duration-1000 opacity-20" style={orb2Style} />
      </div>

      {/* Slide-over Side Glass Drawer */}
      <GlassDrawer isOpen={isDrawerOpen} onClose={() => setIsDrawerOpen(false)} />

      {/* Top App Bar Header */}
      <Navbar onOpenDrawer={() => setIsDrawerOpen(true)} />

      {/* Main Page Area with Touch Swipe & Buttery Smooth Horizontal Transitions */}
      <main 
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
        className="relative z-10 flex-1 w-full max-w-7xl mx-auto overflow-y-auto overflow-x-hidden"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, x: direction * 40 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -direction * 40 }}
            transition={{ duration: 0.28, ease: [0.16, 1, 0.3, 1] }}
            className="w-full min-h-full"
          >
            {activeTab === 'home' && <Home />}
            {activeTab === 'search' && <Search />}
            {activeTab === 'library' && <Library />}
            {activeTab === 'profile' && <TasteProfile />}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Persistent Mini Player & Expanded Player Modal */}
      <PlayerBar themePalette={themePalette} />

      {/* Curved Liquid Bottom Tab Navigation */}
      <BottomNav />
    </div>
  );
};

export default App;
