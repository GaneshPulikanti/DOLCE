import React, { useState, useEffect } from 'react';
import { Play, Pause, Heart, Music, ListPlus, Check } from 'lucide-react';
import { usePlayerStore } from '../store/usePlayerStore';
import { toggleFavorite, isFavorite } from '../services/db';

export const TrackCard = ({ track, queue = [] }) => {
  const { currentTrack, isPlaying, playTrack, togglePlayPause, addToQueue } = usePlayerStore();
  const [liked, setLiked] = useState(false);
  const [addedQueue, setAddedQueue] = useState(false);
  const [imgSrc, setImgSrc] = useState(track.artworkUrl);
  const [fallbackStage, setFallbackStage] = useState(0);

  const isCurrent = currentTrack?.id === track.id;

  useEffect(() => {
    setImgSrc(track.artworkUrl);
    setFallbackStage(0);
  }, [track.artworkUrl, track.id]);

  useEffect(() => {
    isFavorite(track.id).then(setLiked);
  }, [track.id]);

  const handleImgError = () => {
    if (fallbackStage === 0) {
      setFallbackStage(1);
      if (track.artworkUrl) {
        setImgSrc(`https://wsrv.nl/?url=${encodeURIComponent(track.artworkUrl)}&w=400&h=400&fit=cover`);
      } else if (track.id) {
        setImgSrc(`https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`);
      } else {
        setFallbackStage(4);
      }
    } else if (fallbackStage === 1) {
      setFallbackStage(2);
      if (track.id) {
        setImgSrc(`https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`);
      } else {
        setFallbackStage(4);
      }
    } else if (fallbackStage === 2) {
      setFallbackStage(3);
      if (track.id) {
        setImgSrc(`https://wsrv.nl/?url=i.ytimg.com/vi/${track.id}/hqdefault.jpg`);
      } else {
        setFallbackStage(4);
      }
    } else {
      setFallbackStage(4);
    }
  };

  const handlePlayClick = (e) => {
    e.stopPropagation();
    if (isCurrent) {
      togglePlayPause();
    } else {
      playTrack(track, queue);
    }
  };

  const handleLikeClick = async (e) => {
    e.stopPropagation();
    const newStatus = await toggleFavorite(track);
    setLiked(newStatus);
  };

  const handleAddToQueueClick = (e) => {
    e.stopPropagation();
    addToQueue(track);
    setAddedQueue(true);
    setTimeout(() => setAddedQueue(false), 2000);
  };

  return (
    <div
      onClick={() => playTrack(track, queue)}
      className={`group relative glass-panel border border-white/10 p-3 rounded-2xl flex flex-col cursor-pointer transition-all duration-300 bg-white/[0.04] hover:bg-white/[0.09] hover:-translate-y-1 shadow-lg ${
        isCurrent ? 'border-white/40 ring-1 ring-white/30' : ''
      }`}
    >
      {/* Artwork Container (Enforces 1:1 HD Square Cover) */}
      <div className="relative aspect-square w-full rounded-xl overflow-hidden mb-3 bg-[#0d0d0d] flex items-center justify-center border border-white/5">
        {fallbackStage < 4 && imgSrc ? (
          <img
            src={imgSrc}
            alt={track.title}
            referrerPolicy="no-referrer"
            className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
            loading="lazy"
            onError={handleImgError}
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center bg-gradient-to-tr from-pink-900/40 via-purple-900/40 to-slate-900/60 text-white/50 border border-white/10">
            <Music size={32} className="text-white/60 mb-1" />
            <span className="text-[10px] font-bold text-white/40 tracking-wider uppercase">DOLCE</span>
          </div>
        )}

        {/* Play Button Overlay */}
        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
          <button
            onClick={handlePlayClick}
            className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-2xl transform scale-90 group-hover:scale-100 hover:scale-105 transition-all"
          >
            {isCurrent && isPlaying ? <Pause size={22} fill="black" /> : <Play size={22} fill="black" className="ml-1" />}
          </button>
        </div>

        {/* Add to Queue Badge (Top Left) */}
        <button
          onClick={handleAddToQueueClick}
          title="Add to Queue"
          className="absolute top-2 left-2 p-1.5 rounded-full bg-black/60 backdrop-blur-md text-white/80 hover:text-blue-400 transition-all opacity-0 group-hover:opacity-100 shadow-md"
        >
          {addedQueue ? <Check size={14} className="text-emerald-400" /> : <ListPlus size={14} />}
        </button>

        {/* Favorite Heart Badge (Top Right) */}
        <button
          onClick={handleLikeClick}
          title={liked ? "Remove from Favorites" : "Add to Favorites"}
          className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 backdrop-blur-md text-white/80 hover:text-pink-500 transition-all opacity-0 group-hover:opacity-100 shadow-md"
        >
          <Heart size={14} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
        </button>
      </div>


      {/* Track Metadata */}
      <div className="flex flex-col min-w-0">
        <h4 className="text-xs lg:text-sm font-bold text-white truncate font-['Plus_Jakarta_Sans']">
          {track.title}
        </h4>
        <p className="text-[11px] text-white/50 truncate mt-0.5 font-medium font-['Plus_Jakarta_Sans']">
          {track.artistName}
        </p>
      </div>
    </div>
  );
};
