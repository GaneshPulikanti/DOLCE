import React, { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { Heart, History, Download, ListMusic, Play } from 'lucide-react';
import { db } from '../services/db';
import { TrackCard } from '../components/TrackCard';
import { usePlayerStore } from '../store/usePlayerStore';

export const Library = () => {
  const [activeSubTab, setActiveSubTab] = useState('favorites');
  const [selectedPlaylistId, setSelectedPlaylistId] = useState(null);

  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const downloads = useLiveQuery(() => db.downloads.toArray()) || [];
  const history = useLiveQuery(() => db.history.orderBy('id').reverse().limit(30).toArray()) || [];
  const playlists = useLiveQuery(() => db.playlists.toArray()) || [];

  const { playTrack } = usePlayerStore();

  const selectedPlaylist = playlists.find(p => p.id === selectedPlaylistId);

  return (
    <div className="w-full min-h-screen pb-40 px-4 lg:px-12 pt-6 flex flex-col gap-6 font-['Inter']">
      {/* Header & Sub-Tabs */}
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl lg:text-3xl font-black text-white tracking-tight">Your Library</h1>

        <div className="flex items-center gap-2 overflow-x-auto pb-2 no-scrollbar">
          <button
            onClick={() => { setActiveSubTab('favorites'); setSelectedPlaylistId(null); }}
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
            onClick={() => { setActiveSubTab('playlists'); setSelectedPlaylistId(null); }}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
              activeSubTab === 'playlists'
                ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
            }`}
          >
            <ListMusic size={14} />
            <span>Playlists ({playlists.length})</span>
          </button>

          <button
            onClick={() => { setActiveSubTab('downloads'); setSelectedPlaylistId(null); }}
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
            onClick={() => { setActiveSubTab('history'); setSelectedPlaylistId(null); }}
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

      {activeSubTab === 'playlists' && (
        selectedPlaylist ? (
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <div className="flex flex-col">
                <h2 className="text-xl font-bold text-white">{selectedPlaylist.name}</h2>
                <span className="text-xs text-white/50">{selectedPlaylist.tracks?.length || 0} songs</span>
              </div>
              <button
                onClick={() => setSelectedPlaylistId(null)}
                className="px-3 py-1 rounded-full bg-white/10 hover:bg-white/20 text-xs font-bold text-white transition-all"
              >
                Back to Playlists
              </button>
            </div>

            {selectedPlaylist.tracks && selectedPlaylist.tracks.length > 0 ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
                {selectedPlaylist.tracks.map((track) => (
                  <TrackCard key={track.id} track={track} queue={selectedPlaylist.tracks} />
                ))}
              </div>
            ) : (
              <div className="py-12 text-center text-white/40 text-xs font-bold">
                No songs in this playlist yet. Add songs from the expanded player!
              </div>
            )}
          </div>
        ) : playlists.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
            {playlists.map((pl) => (
              <div
                key={pl.id}
                onClick={() => setSelectedPlaylistId(pl.id)}
                className="group relative rounded-2xl glass-panel p-4 bg-white/[0.03] border border-white/10 hover:bg-white/[0.08] hover:border-white/25 transition-all duration-300 cursor-pointer flex flex-col gap-3 shadow-lg"
              >
                <div className="relative aspect-square w-full rounded-xl overflow-hidden bg-black/40 flex items-center justify-center">
                  {pl.tracks && pl.tracks[0]?.artworkUrl ? (
                    <img src={pl.tracks[0].artworkUrl} alt={pl.name} className="w-full h-full object-cover group-hover:scale-105 transition-transform" />
                  ) : (
                    <ListMusic size={32} className="text-white/40" />
                  )}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <div 
                      onClick={(e) => {
                        e.stopPropagation();
                        if (pl.tracks && pl.tracks.length > 0) playTrack(pl.tracks[0], pl.tracks);
                      }}
                      className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-xl scale-90 group-hover:scale-100 transition-transform"
                    >
                      <Play size={20} fill="black" className="ml-0.5" />
                    </div>
                  </div>
                </div>
                <div className="flex flex-col min-w-0">
                  <h4 className="text-sm font-bold text-white truncate group-hover:text-pink-300 transition-colors">{pl.name}</h4>
                  <p className="text-xs text-white/50 truncate mt-0.5">{pl.tracks?.length || 0} songs</p>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <ListMusic size={48} className="mb-4 text-white/20" />
            <h3 className="text-lg font-bold text-white mb-1">No custom playlists</h3>
            <p className="text-xs">Tap the Add to Playlist icon in the player header to create your first playlist</p>
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

