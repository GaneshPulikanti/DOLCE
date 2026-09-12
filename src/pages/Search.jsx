import React, { useEffect, useState } from 'react';
import { Search as SearchIcon, Music } from 'lucide-react';
import { searchSongs } from '../services/catalog';
import { TrackCard } from '../components/TrackCard';
import { useSearchStore } from '../store/useSearchStore';

export const Search = () => {
  const { searchQuery, setSearchQuery, filterCategory, setFilterCategory } = useSearchStore();
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!searchQuery || !searchQuery.trim()) {
      setResults([]);
      return;
    }

    const timer = setTimeout(async () => {
      setLoading(true);
      const data = await searchSongs(searchQuery);
      setResults(data);
      setLoading(false);
    }, 350);

    return () => clearTimeout(timer);
  }, [searchQuery]);

  const categories = [
    { id: 'all', label: 'All Songs' },
    { id: 'songs', label: 'Tracks' },
    { id: 'artists', label: 'Artists' },
    { id: 'videos', label: 'Music Videos' },
  ];

  return (
    <div className="w-full min-h-screen pb-40 px-4 lg:px-12 pt-6 flex flex-col gap-6 font-['Inter']">
      {/* Search Header */}
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl lg:text-3xl font-black text-white tracking-tight">Search Catalog</h1>

        {/* Search Input for Mobile View */}
        <div className="relative w-full flex items-center sm:hidden">
          <SearchIcon size={18} className="absolute left-3.5 text-white/40 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search songs, artists, albums..."
            className="w-full h-11 pl-10 pr-4 rounded-full bg-white/5 border border-white/10 text-sm text-white placeholder-white/40 focus:outline-none focus:border-white/30 focus:bg-white/10 transition-all font-medium"
          />
        </div>

        {/* Category Filters */}
        <div className="flex items-center gap-2 overflow-x-auto pb-2 no-scrollbar">
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setFilterCategory(cat.id)}
              className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
                filterCategory === cat.id
                  ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                  : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>

      {/* Results Content */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6 mt-4">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) => (
            <div key={i} className="h-52 rounded-2xl bg-white/5 animate-pulse" />
          ))}
        </div>
      ) : results.length > 0 ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6 mt-2">
          {results.map((track) => (
            <TrackCard key={track.id} track={track} queue={results} />
          ))}
        </div>
      ) : (
        searchQuery && (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <Music size={48} className="mb-4 text-white/30" />
            <h3 className="text-lg font-bold text-white mb-1">No songs found</h3>
            <p className="text-xs">Try searching for a different title, artist, or album</p>
          </div>
        )
      )}
    </div>
  );
};
