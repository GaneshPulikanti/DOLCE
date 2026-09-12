import React, { useState, useEffect } from 'react';
import { Play, Pause, Heart, Music } from 'lucide-react';
import { usePlayerStore } from '../store/usePlayerStore';
import { toggleFavorite, isFavorite } from '../services/db';

export const TrackCard = ({ track, queue = [] }) => {
  const { currentTrack, isPlaying, playTrack, togglePlayPause } = usePlayerStore();
  const [liked, setLiked] = useState(false);
  const [imgError, setImgError] = useState(false);

  const isCurrent = currentTrack?.id === track.id;

  useEffect(() => {
    isFavorite(track.id).then(setLiked);
  }, [track.id]);

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

  return (
    <div
      onClick={() => playTrack(track, queue)}
      className={`group relative glass-panel border border-white/10 p-3 rounded-2xl flex flex-col cursor-pointer transition-all duration-300 bg-white/[0.04] hover:bg-white/[0.09] hover:-translate-y-1 shadow-lg ${
        isCurrent ? 'border-white/40 ring-1 ring-white/30' : ''
      }`}
    >
      {/* Artwork Container (Enforces 1:1 HD Square Cover) */}
      <div className="relative aspect-square w-full rounded-xl overflow-hidden mb-3 bg-[#0d0d0d] flex items-center justify-center border border-white/5">
        {!imgError && track.artworkUrl ? (
          <img
            src={track.artworkUrl}
            alt={track.title}
            className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
            loading="lazy"
            onError={() => setImgError(true)}
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center bg-white/5 text-white/40">
            <Music size={32} />
          </div>
        )}

        {/* Play Button Overlay (White Circle Button matching Dart UI) */}
        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
          <button
            onClick={handlePlayClick}
            className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-2xl transform scale-90 group-hover:scale-100 hover:scale-105 transition-all"
          >
            {isCurrent && isPlaying ? <Pause size={22} fill="black" /> : <Play size={22} fill="black" className="ml-1" />}
          </button>
        </div>

        {/* Favorite Heart Badge */}
        <button
          onClick={handleLikeClick}
          className="absolute top-2 right-2 p-1.5 rounded-full bg-black/50 backdrop-blur-md text-white/80 hover:text-pink-500 transition-all opacity-0 group-hover:opacity-100"
        >
          <Heart size={15} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
        </button>
      </div>

      {/* Track Metadata */}
      <div className="flex flex-col min-w-0">
        <h4 className="text-xs lg:text-sm font-bold text-white truncate font-['Inter']">
          {track.title}
        </h4>
        <p className="text-[11px] text-white/50 truncate mt-0.5 font-medium font-['Inter']">
          {track.artistName}
        </p>
      </div>
    </div>
  );
};
