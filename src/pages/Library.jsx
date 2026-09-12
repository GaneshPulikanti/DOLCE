import React, { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { Heart, History, Download } from 'lucide-react';
import { db } from '../services/db';
import { TrackCard } from '../components/TrackCard';

export const Library = () => {
  const [activeSubTab, setActiveSubTab] = useState('favorites');
  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const downloads = useLiveQuery(() => db.downloads.toArray()) || [];
  const history = useLiveQuery(() => db.history.orderBy('id').reverse().limit(30).toArray()) || [];

  return (
    <div className="w-full min-h-screen pb-40 px-4 lg:px-12 pt-6 flex flex-col gap-6 font-['Inter']">
      {/* Header & Sub-Tabs */}
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl lg:text-3xl font-black text-white tracking-tight">Your Library</h1>

        <div className="flex items-center gap-2 overflow-x-auto pb-2 no-scrollbar">
          <button
            onClick={() => setActiveSubTab('favorites')}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
              activeSubTab === 'favorites'
                ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
            }`}
          >
            <Heart size={14} fill={activeSubTab === 'favorites' ? 'black' : 'none'} />
            <span>Liked Songs ({favorites.length})</span>
          </button>

          <button
            onClick={() => setActiveSubTab('downloads')}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
              activeSubTab === 'downloads'
                ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
            }`}
          >
            <Download size={14} />
            <span>Offline Downloads ({downloads.length})</span>
          </button>

          <button
            onClick={() => setActiveSubTab('history')}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
              activeSubTab === 'history'
                ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
            }`}
          >
            <History size={14} />
            <span>Recently Played ({history.length})</span>
          </button>
        </div>
      </div>

      {/* Content */}
      {activeSubTab === 'favorites' && (
        favorites.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
            {favorites.map((track) => (
              <TrackCard key={track.id} track={track} queue={favorites} />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <Heart size={48} className="mb-4 text-white/20" />
            <h3 className="text-lg font-bold text-white mb-1">No liked songs yet</h3>
            <p className="text-xs">Tap the heart icon on any song to save it to your library</p>
          </div>
        )
      )}

      {activeSubTab === 'downloads' && (
        downloads.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
            {downloads.map((track) => (
              <TrackCard key={track.id} track={track} queue={downloads} />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <Download size={48} className="mb-4 text-white/20" />
            <h3 className="text-lg font-bold text-white mb-1">No downloaded songs</h3>
            <p className="text-xs">Tap the download icon in the player window to save songs offline</p>
          </div>
        )
      )}

      {activeSubTab === 'history' && (
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
            <History size={48} className="mb-4 text-white/20" />
            <h3 className="text-lg font-bold text-white mb-1">No listening history</h3>
            <p className="text-xs">Songs you play will appear here</p>
          </div>
        )
      )}
    </div>
  );
};
