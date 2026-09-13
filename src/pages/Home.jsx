import React, { useEffect, useState } from 'react';
import { Heart, ChevronRight } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { getHomeFeed } from '../services/catalog';
import { TrackCard } from '../components/TrackCard';
import { db } from '../services/db';
import { useSearchStore } from '../store/useSearchStore';

export const Home = () => {
  const [sections, setSections] = useState(() => {
    if (typeof localStorage !== 'undefined') {
      try {
        const cached = localStorage.getItem('DOLCE_HOME_FEED_CACHE_V2');
        if (cached) return JSON.parse(cached);
      } catch (_) {}
    }
    return [];
  });
  const [loading, setLoading] = useState(() => sections.length === 0);
  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const historyCount = useLiveQuery(() => db.history.count()) || 0;
  const { setActiveTab } = useSearchStore();

  useEffect(() => {
    let isMounted = true;
    getHomeFeed().then((data) => {
      if (isMounted && data && data.length > 0) {
        setSections(data);
        setLoading(false);
      }
    });
    return () => { isMounted = false; };
  }, [historyCount]);

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  };

  return (
    <div className="w-full min-h-screen pb-40 px-4 lg:px-12 pt-4 flex flex-col gap-6 font-['Plus_Jakarta_Sans']">
      
      {/* ── Greeting Header ── */}
      <div className="flex flex-col items-start gap-0.5">
        <span className="text-xs font-medium text-white/50 tracking-wider">
          {getGreeting()},
        </span>
        <h2 className="text-2xl lg:text-3xl font-black text-white tracking-tight">
          Welcome to DOLCE
        </h2>
      </div>

      {/* ── Synced Liked Songs Card (If favorites exist) ── */}
      {favorites.length > 0 && (
        <div 
          onClick={() => setActiveTab('library')}
          className="w-full rounded-3xl p-5 glass-panel border border-white/14 bg-white/[0.04] backdrop-blur-2xl flex items-center justify-between cursor-pointer hover:bg-white/[0.08] transition-all shadow-xl"
        >
          <div className="flex items-center gap-4">
            <div className="w-13 h-13 rounded-2xl bg-gradient-to-tr from-pink-600 to-red-500 flex items-center justify-center shadow-lg shadow-pink-600/30">
              <Heart size={24} fill="white" className="text-white" />
            </div>
            <div className="flex flex-col">
              <h4 className="text-base font-bold text-white">Liked Songs</h4>
              <p className="text-xs text-white/50 mt-0.5">
                {favorites.length} songs synchronized · Offline play
              </p>
            </div>
          </div>
          <ChevronRight size={22} className="text-white/40" />
        </div>
      )}

      {/* ── Curated Recommendation Sections (Horizontal Carousels) ── */}
      {loading ? (
        <div className="flex flex-col gap-8">
          {[1, 2, 3].map((i) => (
            <div key={i} className="flex flex-col gap-4">
              <div className="h-6 w-40 bg-white/10 rounded-lg animate-pulse" />
              <div className="flex gap-4 overflow-hidden">
                {[1, 2, 3, 4].map((j) => (
                  <div key={j} className="w-40 h-52 flex-shrink-0 rounded-2xl bg-white/5 animate-pulse" />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        sections.map((section, idx) => (
          <section key={idx} className="flex flex-col gap-3">
            <h3 className="text-lg lg:text-xl font-bold text-white flex items-center gap-2">
              <span>{section.title}</span>
            </h3>

            {/* Horizontal Scroll Carousel */}
            <div className="flex items-center gap-4 overflow-x-auto pb-4 pt-1 no-scrollbar scroll-smooth">
              {section.tracks.map((track) => (
                <div key={track.id} className="w-40 lg:w-44 flex-shrink-0">
                  <TrackCard track={track} queue={section.tracks} />
                </div>
              ))}
            </div>
          </section>
        ))
      )}

    </div>
  );
};
