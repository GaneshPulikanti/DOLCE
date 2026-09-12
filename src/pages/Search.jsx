import React, { useEffect, useState } from 'react';
import { Search as SearchIcon, Music, Filter } from 'lucide-react';
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
    <div className="w-full min-h-screen pb-36 px-4 lg:px-12 pt-6 flex flex-col gap-6">
      {/* Search Header */}
      <div className="flex flex-col gap-4">
        <h1 className="text-3xl font-extrabold text-white">Search Music Catalog</h1>

        {/* Category Filters */}
        <div className="flex items-center gap-2 overflow-x-auto pb-2">
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setFilterCategory(cat.id)}
              className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
                filterCategory === cat.id
                  ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/30'
                  : 'glass-card text-white/70 hover:text-white'
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
            <div key={i} className="h-56 rounded-2xl bg-white/5 animate-pulse" />
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
            <Music size={48} className="mb-4 text-purple-400/60" />
            <h3 className="text-lg font-bold text-white mb-1">No songs found</h3>
            <p className="text-sm">Try searching for a different song title, artist, or band</p>
          </div>
        )
      )}
    </div>
  );
};
