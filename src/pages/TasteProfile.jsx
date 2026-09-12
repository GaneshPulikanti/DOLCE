import React from 'react';
import { Sparkles, Compass, Flame, Radio } from 'lucide-react';
import { useSearchStore } from '../store/useSearchStore';

export const TasteProfile = () => {
  const { setSearchQuery, setActiveTab } = useSearchStore();

  const genres = [
    { name: 'Pop & Dance', color: 'from-pink-500 to-purple-600', query: 'pop dance hits 2026' },
    { name: 'Lo-Fi & Chill', color: 'from-purple-600 to-indigo-700', query: 'lofi chill study beats' },
    { name: 'Hip-Hop & Rap', color: 'from-amber-500 to-red-600', query: 'hip hop rap trending' },
    { name: 'Bollywood Hits', color: 'from-emerald-500 to-teal-700', query: 'latest bollywood songs' },
    { name: 'Indie & Acoustic', color: 'from-cyan-500 to-blue-600', query: 'indie acoustic songs' },
    { name: 'Electronic & EDM', color: 'from-fuchsia-600 to-pink-600', query: 'edm festival hits' },
  ];

  const handleGenreClick = (query) => {
    setSearchQuery(query);
    setActiveTab('search');
  };

  return (
    <div className="w-full min-h-screen pb-36 px-4 lg:px-12 pt-6 flex flex-col gap-8">
      {/* Banner */}
      <div className="glass-panel p-8 rounded-3xl bg-gradient-to-r from-purple-900/40 via-indigo-900/30 to-black border border-white/15 flex flex-col md:flex-row items-center justify-between gap-6 shadow-2xl">
        <div className="flex flex-col gap-3">
          <span className="flex items-center gap-2 px-3 py-1 rounded-full bg-pink-500/20 border border-pink-500/30 text-xs font-bold text-pink-300 w-fit">
            <Sparkles size={14} /> Personalized Sound Profile
          </span>
          <h1 className="text-3xl lg:text-4xl font-black text-white">Your Music Vibe</h1>
          <p className="text-sm lg:text-base text-white/70 max-w-lg">
            Explore curated radio mix categories tailored to your listening habits and mood.
          </p>
        </div>
      </div>

      {/* Genre Grid */}
      <div className="flex flex-col gap-4">
        <h2 className="text-xl font-bold text-white flex items-center gap-2">
          <Compass size={20} className="text-purple-400" />
          <span>Explore Mood Mixes</span>
        </h2>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 lg:gap-6">
          {genres.map((g, idx) => (
            <div
              key={idx}
              onClick={() => handleGenreClick(g.query)}
              className={`glass-card p-6 rounded-2xl cursor-pointer bg-gradient-to-br ${g.color} opacity-85 hover:opacity-100 hover:scale-105 transition-all shadow-xl flex flex-col justify-between h-36`}
            >
              <span className="text-xs font-bold uppercase tracking-widest text-white/70">Radio Mix</span>
              <h3 className="text-xl font-extrabold text-white">{g.name}</h3>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
