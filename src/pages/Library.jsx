import React, { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { Heart, History, Library as LibraryIcon, Play } from 'lucide-react';
import { db } from '../services/db';
import { TrackCard } from '../components/TrackCard';
import { usePlayerStore } from '../store/usePlayerStore';

export const Library = () => {
  const [activeSubTab, setActiveSubTab] = useState('favorites');
  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const history = useLiveQuery(() => db.history.orderBy('id').reverse().limit(30).toArray()) || [];
  const { playTrack } = usePlayerStore();

  return (
    <div className="w-full min-h-screen pb-36 px-4 lg:px-12 pt-6 flex flex-col gap-6">
      {/* Header & Sub-Tabs */}
      <div className="flex flex-col gap-4">
        <h1 className="text-3xl font-extrabold text-white">Your Music Library</h1>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setActiveSubTab('favorites')}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold transition-all ${
              activeSubTab === 'favorites'
                ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/30'
                : 'glass-card text-white/70 hover:text-white'
            }`}
          >
            <Heart size={14} fill={activeSubTab === 'favorites' ? 'white' : 'none'} />
            <span>Liked Songs ({favorites.length})</span>
          </button>

          <button
            onClick={() => setActiveSubTab('history')}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold transition-all ${
              activeSubTab === 'history'
                ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/30'
                : 'glass-card text-white/70 hover:text-white'
            }`}
          >
            <History size={14} />
            <span>Recently Played ({history.length})</span>
          </button>
        </div>
      </div>

      {/* Content */}
      {activeSubTab === 'favorites' ? (
        favorites.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
            {favorites.map((track) => (
              <TrackCard key={track.id} track={track} queue={favorites} />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <Heart size={48} className="mb-4 text-pink-500/50" />
            <h3 className="text-lg font-bold text-white mb-1">No liked songs yet</h3>
            <p className="text-sm">Tap the heart icon on any song to save it to your library</p>
          </div>
        )
      ) : (
        history.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
            {history.map((item, idx) => (
              <TrackCard 
                key={`${item.trackId}-${idx}`} 
                track={{
                  id: item.trackId,
                  title: item.title,
                  artistName: item.artistName,
                  artworkUrl: item.artworkUrl,
                }} 
                queue={history.map(h => ({
                  id: h.trackId,
                  title: h.title,
                  artistName: h.artistName,
                  artworkUrl: h.artworkUrl,
                }))} 
              />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <History size={48} className="mb-4 text-purple-400/50" />
            <h3 className="text-lg font-bold text-white mb-1">No listening history</h3>
            <p className="text-sm">Songs you play will appear here</p>
          </div>
        )
      )}
    </div>
  );
};
