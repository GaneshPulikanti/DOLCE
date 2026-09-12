import React, { useState, useEffect } from 'react';
import { Play, Pause, Heart } from 'lucide-react';
import { usePlayerStore } from '../store/usePlayerStore';
import { toggleFavorite, isFavorite } from '../services/db';

export const TrackCard = ({ track, queue = [] }) => {
  const { currentTrack, isPlaying, playTrack, togglePlayPause } = usePlayerStore();
  const [liked, setLiked] = useState(false);

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
      className={`group relative glass-card p-3 flex flex-col cursor-pointer transition-all duration-300 ${
        isCurrent ? 'ring-2 ring-purple-500/60 bg-purple-500/10' : ''
      }`}
    >
      {/* Artwork Container */}
      <div className="relative aspect-square w-full rounded-xl overflow-hidden mb-3 bg-black/40">
        <img
          src={track.artworkUrl || `https://i.ytimg.com/vi/${track.id}/hq720.jpg`}
          alt={track.title}
          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
          loading="lazy"
          onError={(e) => {
            if (!e.target.src.includes('sddefault.jpg')) {
              e.target.src = `https://i.ytimg.com/vi/${track.id}/sddefault.jpg`;
            } else if (!e.target.src.includes('hqdefault.jpg')) {
              e.target.src = `https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`;
            }
          }}
        />

        {/* Overlay Dark Blur */}
        <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center gap-2">
          <button
            onClick={handlePlayClick}
            className="w-12 h-12 rounded-full bg-purple-600 text-white flex items-center justify-center shadow-lg transform scale-90 group-hover:scale-100 hover:bg-purple-500 transition-all"
          >
            {isCurrent && isPlaying ? <Pause size={22} fill="white" /> : <Play size={22} fill="white" className="ml-1" />}
          </button>
        </div>

        {/* Favorite Heart Badge */}
        <button
          onClick={handleLikeClick}
          className="absolute top-2 right-2 p-2 rounded-full bg-black/40 backdrop-blur-md text-white/80 hover:text-pink-500 transition-all opacity-0 group-hover:opacity-100"
        >
          <Heart size={16} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
        </button>
      </div>

      {/* Track Metadata */}
      <div className="flex flex-col min-w-0">
        <h4 className="text-sm font-semibold text-white truncate group-hover:text-purple-300 transition-colors">
          {track.title}
        </h4>
        <p className="text-xs text-white/60 truncate mt-0.5 font-medium">
          {track.artistName}
        </p>
      </div>
    </div>
  );
};
