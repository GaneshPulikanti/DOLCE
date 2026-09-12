import React, { useEffect, useState } from 'react';
import { Sparkles, TrendingUp, Music, Play } from 'lucide-react';
import { getHomeFeed } from '../services/catalog';
import { TrackCard } from '../components/TrackCard';
import { usePlayerStore } from '../store/usePlayerStore';

export const Home = () => {
  const [sections, setSections] = useState([]);
  const [loading, setLoading] = useState(true);
  const { playTrack } = usePlayerStore();

  useEffect(() => {
    let isMounted = true;
    getHomeFeed().then((data) => {
      if (isMounted) {
        setSections(data);
        setLoading(false);
      }
    });
    return () => { isMounted = false; };
  }, []);

  const heroTrack = sections[0]?.tracks?.[0];

  return (
    <div className="w-full min-h-screen pb-36 px-4 lg:px-12 pt-6 flex flex-col gap-10">
      {/* ─── Hero Recommendation Banner ─── */}
      {heroTrack && (
        <div className="relative w-full rounded-3xl overflow-hidden glass-panel p-6 lg:p-10 flex flex-col md:flex-row items-center justify-between gap-6 border border-white/15 bg-gradient-to-r from-purple-900/40 via-pink-900/30 to-black/60 shadow-2xl">
          <div className="flex-1 flex flex-col items-start gap-3">
            <span className="flex items-center gap-2 px-3 py-1 rounded-full bg-purple-500/20 border border-purple-500/30 text-xs font-bold text-purple-300">
              <Sparkles size={14} /> Featured Recommendation
            </span>
            <h1 className="text-3xl lg:text-5xl font-black text-white leading-tight">
              {heroTrack.title}
            </h1>
            <p className="text-base lg:text-lg text-white/70 font-medium">
              {heroTrack.artistName}
            </p>
            <button
              onClick={() => playTrack(heroTrack, sections[0]?.tracks)}
              className="mt-4 px-6 py-3.5 rounded-full bg-gradient-to-r from-purple-600 to-pink-500 text-white font-bold flex items-center gap-3 shadow-lg shadow-purple-600/30 hover:scale-105 transition-all"
            >
              <Play size={20} fill="white" />
              <span>Listen Now</span>
            </button>
          </div>

          <div className="relative w-48 h-48 lg:w-64 lg:h-64 rounded-2xl overflow-hidden shadow-2xl border border-white/20 bg-black">
            <img
              src={heroTrack.artworkUrl}
              alt={heroTrack.title}
              className="w-full h-full object-cover"
              onError={(e) => { e.target.src = `https://img.youtube.com/vi/${heroTrack.id}/hqdefault.jpg`; }}
            />
          </div>
        </div>
      )}

      {/* ─── Curated Sections ─── */}
      {loading ? (
        <div className="flex flex-col gap-8">
          {[1, 2, 3].map((i) => (
            <div key={i} className="flex flex-col gap-4">
              <div className="h-7 w-48 bg-white/10 rounded-lg animate-pulse" />
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
                {[1, 2, 3, 4, 5].map((j) => (
                  <div key={j} className="h-56 rounded-2xl bg-white/5 animate-pulse" />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        sections.map((section, idx) => (
          <section key={idx} className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl lg:text-2xl font-bold text-white flex items-center gap-2">
                <TrendingUp size={22} className="text-purple-400" />
                <span>{section.title}</span>
              </h2>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
              {section.tracks.map((track) => (
                <TrackCard key={track.id} track={track} queue={section.tracks} />
              ))}
            </div>
          </section>
        ))
      )}
    </div>
  );
};
