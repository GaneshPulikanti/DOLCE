import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Play, Shuffle, Music, Heart, Loader2, Disc, User, ListMusic, Plus, Check } from 'lucide-react';
import { fetchCollectionTracks, searchSongs } from '../services/catalog';
import { usePlayerStore } from '../store/usePlayerStore';
import { db, toggleFavorite, isFavorite, saveFullPlaylistToLibrary, isPlaylistSaved } from '../services/db';
import { useLiveQuery } from 'dexie-react-hooks';

export const CollectionModal = ({ collection, isOpen, onClose }) => {
  const { playTrack, currentTrack, isPlaying } = usePlayerStore();
  const [tracks, setTracks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isSaved, setIsSaved] = useState(false);
  const favorites = useLiveQuery(() => db.favorites.toArray()) || [];
  const favIds = new Set(favorites.map(f => f.id));

  useEffect(() => {
    if (!isOpen || !collection) return;

    let isMounted = true;
    setLoading(true);
    setTracks([]);

    isPlaylistSaved(collection.id).then(saved => {
      if (isMounted) setIsSaved(saved);
    });

    const loadData = async () => {
      let resultTracks = [];
      if (collection.type === 'artist') {
        const query = `${collection.name || collection.title} top songs`;
        resultTracks = await searchSongs(query);
      } else {
        resultTracks = await fetchCollectionTracks(collection.id);
        if (resultTracks.length === 0 && (collection.title || collection.name)) {
          // Backup fetch by title if browseId returned empty
          const fallbackQuery = `${collection.artistName || collection.author || ''} ${collection.title || collection.name} album songs`;
          resultTracks = await searchSongs(fallbackQuery);
        }
      }

      if (isMounted) {
        setTracks(resultTracks);
        setLoading(false);
      }
    };

    loadData();
    return () => { isMounted = false; };
  }, [isOpen, collection]);

  if (!isOpen || !collection) return null;

  const title = collection.title || collection.name || 'Collection';
  const subtitle = collection.artistName || collection.author || collection.subtitle || (collection.type === 'artist' ? 'Artist' : 'Various Artists');
  const artworkUrl = collection.artworkUrl || '/favicon.png';

  const handlePlayAll = () => {
    if (tracks.length > 0) {
      playTrack(tracks[0], tracks);
    }
  };

  const handleShufflePlay = () => {
    if (tracks.length > 0) {
      const shuffled = [...tracks].sort(() => Math.random() - 0.5);
      playTrack(shuffled[0], shuffled);
    }
  };

  const handleToggleSavePlaylist = async () => {
    const savedNow = await saveFullPlaylistToLibrary(collection, tracks);
    setIsSaved(savedNow);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 pt-12 pb-[165px] font-['Plus_Jakarta_Sans'] select-none">
          {/* Backdrop Blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/80 backdrop-blur-xl"
          />

          {/* Modal Container (Sits 100% cleanly above mini player bar on both Web & Mobile) */}
          <motion.div
            initial={{ opacity: 0, scale: 0.94, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.94, y: 20 }}
            transition={{ type: 'spring', damping: 25, stiffness: 220 }}
            className="relative w-full max-w-2xl h-full max-h-[calc(100vh-220px)] bg-[#0c0c0e]/95 border border-white/15 rounded-3xl shadow-2xl overflow-hidden flex flex-col z-10"
          >

            {/* Mobile Pull Handle Indicator */}
            <div className="w-full pt-2 flex justify-center sm:hidden bg-[#0c0c0e] flex-shrink-0">
              <div className="w-10 h-1 rounded-full bg-white/30" />
            </div>

            {/* Top Navigation & Close Bar (Sticky at Top) */}
            <div className="p-3 sm:p-4 px-4 sm:px-6 flex items-center justify-between border-b border-white/10 bg-[#0c0c0e] sticky top-0 z-20 flex-shrink-0">
              <div className="flex items-center gap-2 text-[10px] sm:text-xs uppercase font-extrabold tracking-widest text-white/70">
                {collection.type === 'artist' ? (
                  <User size={15} className="text-emerald-400" />
                ) : collection.type === 'album' ? (
                  <Disc size={15} className="text-purple-400" />
                ) : (
                  <ListMusic size={15} className="text-blue-400" />
                )}
                <span>{collection.type?.toUpperCase() || 'COLLECTION'}</span>
              </div>
              <button
                onClick={onClose}
                className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white border border-white/15 transition-all shadow-md active:scale-95 flex items-center justify-center"
                title="Close"
              >
                <X size={18} className="text-white" />
              </button>
            </div>

            {/* Collection Header Banner */}
            <div className="p-3.5 sm:p-6 flex flex-row items-center sm:items-end gap-3.5 sm:gap-6 bg-gradient-to-b from-white/10 to-transparent border-b border-white/10 flex-shrink-0">
              <div className="relative w-20 h-20 sm:w-40 sm:h-40 rounded-2xl overflow-hidden border border-white/20 shadow-2xl flex-shrink-0 bg-black/40">
                <img
                  src={artworkUrl}
                  alt={title}
                  referrerPolicy="no-referrer"
                  className="w-full h-full object-cover"
                />
              </div>

              <div className="flex flex-col items-start text-left min-w-0 flex-1 gap-1 sm:gap-2">
                <span className="text-[10px] sm:text-xs uppercase font-bold tracking-widest text-white/50">
                  {collection.type === 'artist' ? 'Verified Artist' : 'Official Release'}
                </span>
                <h2 className="text-base sm:text-2xl font-black text-white leading-tight truncate w-full">
                  {title}
                </h2>
                <p className="text-xs sm:text-sm font-semibold text-white/70 truncate w-full">
                  {subtitle}
                </p>
                <span className="text-[10px] sm:text-xs font-medium text-white/40">
                  {loading ? 'Fetching tracks...' : `${tracks.length} Songs`}
                </span>

                {/* Play, Shuffle & Add to Playlists Buttons */}
                {!loading && (
                  <div className="flex items-center flex-wrap gap-2 mt-1 sm:mt-2">
                    {tracks.length > 0 && (
                      <>
                        <button
                          onClick={handlePlayAll}
                          className="px-3.5 py-1.5 sm:px-5 sm:py-2.5 rounded-full bg-white text-black font-extrabold text-[11px] sm:text-xs flex items-center gap-1.5 hover:scale-105 active:scale-95 transition-all shadow-xl"
                        >
                          <Play size={14} fill="black" />
                          <span>PLAY ALL</span>
                        </button>
                        <button
                          onClick={handleShufflePlay}
                          className="p-1.5 sm:p-2.5 rounded-full bg-white/10 border border-white/15 text-white hover:bg-white/20 active:scale-95 transition-all"
                          title="Shuffle Play"
                        >
                          <Shuffle size={15} />
                        </button>
                      </>
                    )}
                    <button
                      onClick={handleToggleSavePlaylist}
                      className={`px-3 py-1.5 sm:px-4 sm:py-2.5 rounded-full border text-[11px] sm:text-xs font-bold flex items-center gap-1.5 transition-all active:scale-95 ${
                        isSaved
                          ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300 hover:bg-emerald-500/30'
                          : 'bg-white/10 border-white/15 text-white hover:bg-white/20'
                      }`}
                      title={isSaved ? "Saved in Playlists" : "Add to Playlists"}
                    >
                      {isSaved ? (
                        <>
                          <Check size={14} className="text-emerald-400" />
                          <span>Saved</span>
                        </>
                      ) : (
                        <>
                          <Plus size={14} />
                          <span>Save</span>
                        </>
                      )}
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Tracklist Container (Fits completely above mini player) */}
            <div className="flex-1 overflow-y-auto p-3 sm:p-6 pb-6 sm:pb-8 flex flex-col gap-2 min-h-0">



              {loading ? (
                <div className="flex flex-col items-center justify-center py-16 text-white/50 gap-3">
                  <Loader2 size={32} className="animate-spin text-white/70" />
                  <p className="text-xs font-bold">Loading collection tracks...</p>
                </div>
              ) : tracks.length > 0 ? (
                tracks.map((track, idx) => {
                  const isCurrent = currentTrack?.id === track.id;
                  const isFav = favIds.has(track.id);

                  return (
                    <div
                      key={track.id || idx}
                      onClick={() => playTrack(track, tracks)}
                      className={`group flex items-center justify-between p-3 rounded-2xl transition-all cursor-pointer border ${
                        isCurrent
                          ? 'bg-white/15 border-white/30 text-white'
                          : 'bg-white/[0.02] border-white/5 hover:bg-white/[0.08] hover:border-white/15'
                      }`}
                    >
                      <div className="flex items-center gap-3.5 min-w-0">
                        <span className="text-xs font-bold text-white/40 w-5 text-center flex-shrink-0">
                          {idx + 1}
                        </span>
                        <div className="relative w-11 h-11 rounded-xl overflow-hidden bg-black/40 border border-white/10 flex-shrink-0">
                          <img
                            src={track.artworkUrl || (track.id ? `https://i.ytimg.com/vi/${track.id}/hqdefault.jpg` : '')}
                            alt={track.title}
                            referrerPolicy="no-referrer"
                            className="w-full h-full object-cover"
                            onError={(e) => {
                              if (track.id) {
                                e.target.src = `https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`;
                              }
                            }}
                          />
                          {isCurrent && isPlaying && (
                            <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                              <Music size={16} className="text-white animate-bounce" />
                            </div>
                          )}
                        </div>
                        <div className="flex flex-col min-w-0">
                          <h4 className={`text-sm font-bold truncate ${isCurrent ? 'text-pink-300' : 'text-white'}`}>
                            {track.title}
                          </h4>
                          <p className="text-xs text-white/50 truncate mt-0.5">
                            {track.artistName}
                          </p>
                        </div>
                      </div>

                      <div className="flex items-center gap-3 flex-shrink-0">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            toggleFavorite(track);
                          }}
                          className="p-2 text-white/40 hover:text-pink-400 transition-colors"
                        >
                          <Heart size={16} fill={isFav ? '#f43f5e' : 'none'} className={isFav ? 'text-pink-500' : ''} />
                        </button>
                        <span className="text-xs font-semibold text-white/40">
                          {track.duration || '3:45'}
                        </span>
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="py-16 text-center text-white/50">
                  <Music size={36} className="mx-auto mb-2 text-white/30" />
                  <p className="text-sm font-bold text-white">No tracks found</p>
                  <p className="text-xs mt-0.5">Could not load tracklist for this collection</p>
                </div>
              )}
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
