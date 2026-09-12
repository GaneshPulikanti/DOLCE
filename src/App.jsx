import React from 'react';
import { Navbar } from './components/Navbar';
import { BottomNav } from './components/BottomNav';
import { PlayerBar } from './components/PlayerBar';
import { Home } from './pages/Home';
import { Search } from './pages/Search';
import { Library } from './pages/Library';
import { TasteProfile } from './pages/TasteProfile';
import { useSearchStore } from './store/useSearchStore';

export const App = () => {
  const { activeTab } = useSearchStore();

  return (
    <div className="relative w-full h-full min-h-screen bg-[#050508] text-white flex flex-col overflow-hidden selection:bg-purple-500 selection:text-white">
      {/* Background Glowing Ambient Orbs */}
      <div className="bg-glow-container">
        <div className="bg-glow-orb-1" />
        <div className="bg-glow-orb-2" />
      </div>

      {/* Top Navbar Header */}
      <Navbar />

      {/* Main Content Area */}
      <main className="relative z-10 flex-1 w-full max-w-7xl mx-auto overflow-y-auto">
        {activeTab === 'home' && <Home />}
        {activeTab === 'search' && <Search />}
        {activeTab === 'library' && <Library />}
        {activeTab === 'profile' && <TasteProfile />}
      </main>

      {/* Persistent Bottom Mini Player & Expanded Player Modal */}
      <PlayerBar />

      {/* Bottom Mobile Tab Navigation */}
      <BottomNav />
    </div>
  );
};

export default App;
