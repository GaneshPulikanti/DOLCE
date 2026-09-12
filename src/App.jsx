import React, { useEffect, useState } from 'react';
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
  const { activeTab } = useSearchStore();
  const { currentTrack } = usePlayerStore();
  const [themePalette, setThemePalette] = useState(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);

  useEffect(() => {
    if (currentTrack?.artworkUrl) {
      extractArtworkColor(currentTrack.artworkUrl).then(setThemePalette);
    }
  }, [currentTrack?.artworkUrl, currentTrack?.id]);

  const orb1Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.dominant} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

  const orb2Style = themePalette ? {
    background: `radial-gradient(circle, ${themePalette.glow} 0%, rgba(0, 0, 0, 0) 75%)`
  } : {};

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

      {/* Main Page Area */}
      <main className="relative z-10 flex-1 w-full max-w-7xl mx-auto overflow-y-auto">
        {activeTab === 'home' && <Home />}
        {activeTab === 'search' && <Search />}
        {activeTab === 'library' && <Library />}
        {activeTab === 'profile' && <TasteProfile />}
      </main>

      {/* Persistent Mini Player & Expanded Player Modal */}
      <PlayerBar themePalette={themePalette} />

      {/* Curved Liquid Bottom Tab Navigation */}
      <BottomNav />
    </div>
  );
};

export default App;
