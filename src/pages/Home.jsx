import React, { useEffect, useState } from 'react';
import { Heart, ChevronRight, Play } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { getHomeFeed } from '../services/catalog';
import { TrackCard } from '../components/TrackCard';
import { db } from '../services/db';
import { useSearchStore } from '../store/useSearchStore';
import { usePlayerStore } from '../store/usePlayerStore';

export const Home = () => {
  const [feedData, setFeedData] = useState(() => {
    if (typeof localStorage !== 'undefined') {
      try {
        const cachedV3 = localStorage.getItem('DOLCE_HOME_FEED_V3');
        if (cachedV3) return JSON.parse(cachedV3);
        const cachedV2 = localStorage.getItem('DOLCE_HOME_FEED_CACHE_V2');
        if (cachedV2) {
          const parsed = JSON.parse(cachedV2);
          return Array.isArray(parsed) ? { quickPicks: [], sections: parsed } : parsed;
        }
      } catch (_) { }
    }
    return { quickPicks: [], sections: [] };
  });

  const sections = feedData.sections || [];
  const quickPicks = feedData.quickPicks || [];
  const [loading, setLoading] = useState(() => sections.length === 0);
  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const historyCount = useLiveQuery(() => db.history.count()) || 0;
  const { setActiveTab } = useSearchStore();
  const { playTrack } = usePlayerStore();

  useEffect(() => {
    let isMounted = true;
    getHomeFeed().then((data) => {
      if (isMounted && data) {
        if (data.sections && data.sections.length > 0) {
          setFeedData(data);
          setLoading(false);
        } else if (Array.isArray(data) && data.length > 0) {
          setFeedData({ quickPicks: [], sections: data });
          setLoading(false);
        }
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

      {/* ── Spotify-Style Quick Picks / "Jump Back In" (6-Item Grid) ── */}
      {quickPicks.length > 0 && (
        <section className="flex flex-col gap-2.5">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-2.5 sm:gap-3">
            {quickPicks.slice(0, 6).map((track) => (
              <div
                key={track.id}
                onClick={() => playTrack(track, quickPicks)}
                className="group relative h-14 sm:h-16 rounded-xl glass-panel bg-white/[0.04] hover:bg-white/[0.09] border border-white/10 flex items-center overflow-hidden cursor-pointer transition-all duration-200 hover:scale-[1.01] shadow-md select-none"
              >
                <img
                  src={track.artworkUrl}
                  alt={track.title}
                  referrerPolicy="no-referrer"
                  className="w-14 sm:w-16 h-14 sm:h-16 object-cover flex-shrink-0 bg-white/5"
                  onError={(e) => {
                    if (track.id) {
                      e.target.src = `https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`;
                    }
                  }}
                />
                <div className="flex-1 min-w-0 px-3 flex flex-col justify-center">
                  <span className="text-xs sm:text-sm font-bold text-white truncate group-hover:text-pink-300 transition-colors">
                    {track.title}
                  </span>
                  <span className="text-[11px] text-white/50 truncate mt-0.5">
                    {track.artistName}
                  </span>
                </div>
                <div className="mr-3 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                  <div className="w-8 h-8 rounded-full bg-white text-black flex items-center justify-center shadow-lg transform active:scale-90">
                    <Play size={15} fill="black" className="ml-0.5" />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── Synced Liked Songs Card (If favorites exist) ── */}
      {favorites.length > 0 && (
        <div
          onClick={() => setActiveTab('library')}
          className="w-full rounded-2xl p-4 sm:p-5 glass-panel border border-white/12 bg-white/[0.03] backdrop-blur-2xl flex items-center justify-between cursor-pointer hover:bg-white/[0.07] transition-all shadow-lg"
        >
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-gradient-to-tr from-pink-600 to-red-500 flex items-center justify-center shadow-lg shadow-pink-600/30 flex-shrink-0">
              <Heart size={22} fill="white" className="text-white" />
            </div>
            <div className="flex flex-col min-w-0">
              <h4 className="text-base font-bold text-white">Liked Songs</h4>
              <p className="text-xs text-white/50 mt-0.5 truncate">
                {favorites.length} songs synchronized · Offline play
              </p>
            </div>
          </div>
          <ChevronRight size={22} className="text-white/40 flex-shrink-0" />
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
