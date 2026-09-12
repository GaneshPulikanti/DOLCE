import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, SkipBack, SkipForward, Repeat, Shuffle, 
  Volume2, VolumeX, Heart, ChevronDown, ListMusic, Download,
  MessageSquareQuote, Disc
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { usePlayerStore } from '../store/usePlayerStore';
import { toggleFavorite, isFavorite, downloadTrackLocally, isDownloadedLocally } from '../services/db';
import { fetchLyrics } from '../services/lyrics';

export const PlayerBar = ({ themePalette }) => {
  const { 
    currentTrack, queue, currentIndex, isPlaying, togglePlayPause, 
    playTrack, skipNext, skipPrev, currentTime, duration, seek, 
    volume, setVolume, isMuted, toggleMute, 
    isShuffle, toggleShuffle, repeatMode, cycleRepeatMode,
    isExpanded, setExpanded 
  } = usePlayerStore();

  const [liked, setLiked] = useState(false);
  const [downloaded, setDownloaded] = useState(false);
  const [modalTab, setModalTab] = useState('artwork'); // 'artwork' | 'lyrics' | 'queue'
  const [lyricsData, setLyricsData] = useState({ synced: [], plain: '' });
  const [loadingLyrics, setLoadingLyrics] = useState(false);
  const lyricsContainerRef = useRef(null);

  // Sync favorites & downloads status
  useEffect(() => {
    if (currentTrack?.id) {
      isFavorite(currentTrack.id).then(setLiked);
      isDownloadedLocally(currentTrack.id).then(setDownloaded);
    }
  }, [currentTrack?.id]);

  // Fetch lyrics when track changes or modal tab opens
  useEffect(() => {
    if (currentTrack?.id && modalTab === 'lyrics') {
      setLoadingLyrics(true);
      fetchLyrics(currentTrack.title, currentTrack.artistName).then((data) => {
        setLyricsData(data);
        setLoadingLyrics(false);
      });
    }
  }, [currentTrack?.id, modalTab]);

  if (!currentTrack) return null;

  const progressPct = duration > 0 ? (currentTime / duration) * 100 : 0;

  const formatTime = (secs) => {
    if (!secs || isNaN(secs)) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const handleLike = async (e) => {
    e.stopPropagation();
    const newStatus = await toggleFavorite(currentTrack);
    setLiked(newStatus);
  };

  const handleDownload = async (e) => {
    e.stopPropagation();
    const newStatus = await downloadTrackLocally(currentTrack);
    setDownloaded(newStatus);
  };

  const accentColor = themePalette?.primary || '#8b5cf6';
  const shadowColor = themePalette?.glow || 'rgba(139, 92, 246, 0.4)';
  const modalBg = themePalette ? {
    background: `radial-gradient(circle at 50% 30%, ${themePalette.dominant} 0%, rgba(5, 5, 8, 0.96) 80%)`
  } : {
    background: 'rgba(5, 5, 8, 0.95)'
  };

  // Find active synchronized lyric index
  let activeLyricIdx = -1;
  if (lyricsData.synced && lyricsData.synced.length > 0) {
    for (let i = 0; i < lyricsData.synced.length; i++) {
      if (currentTime >= lyricsData.synced[i].time) {
        activeLyricIdx = i;
      } else {
        break;
      }
    }
  }

  return (
    <>
      {/* ─── Persistent Mini Player Bar ─── */}
      <div 
        onClick={() => setExpanded(true)}
        className="fixed bottom-[60px] md:bottom-4 left-3 right-3 lg:left-6 lg:right-6 z-40 glass-panel border border-white/15 p-2.5 lg:p-3 flex items-center justify-between shadow-2xl cursor-pointer bg-black/85 backdrop-blur-2xl transition-all duration-500 hover:scale-[1.005]"
        style={{
          boxShadow: `0 10px 30px -5px ${shadowColor}`
        }}
      >
        {/* Track Thumbnail & Titles */}
        <div className="flex items-center gap-3.5 min-w-0 flex-1">
          <img
            src={currentTrack.artworkUrl || `https://i.ytimg.com/vi/${currentTrack.id}/hq720.jpg`}
            alt={currentTrack.title}
            className="w-12 h-12 lg:w-14 lg:h-14 rounded-xl object-cover shadow-lg bg-black/60"
            onError={(e) => {
              if (!e.target.src.includes('sddefault.jpg')) {
                e.target.src = `https://i.ytimg.com/vi/${currentTrack.id}/sddefault.jpg`;
              } else if (!e.target.src.includes('hqdefault.jpg')) {
                e.target.src = `https://i.ytimg.com/vi/${currentTrack.id}/hqdefault.jpg`;
              }
            }}
          />
          <div className="flex flex-col min-w-0">
            <h4 className="text-sm lg:text-base font-bold text-white truncate">
              {currentTrack.title}
            </h4>
            <p className="text-xs text-white/60 truncate font-medium">
              {currentTrack.artistName}
            </p>
          </div>
        </div>

        {/* Playback Controls */}
        <div className="flex items-center gap-3 lg:gap-5" onClick={(e) => e.stopPropagation()}>
          <button 
            onClick={skipPrev} 
            className="hidden sm:block text-white/70 hover:text-white transition-colors"
          >
            <SkipBack size={20} />
          </button>

          <button
            onClick={togglePlayPause}
            className="w-11 h-11 rounded-full text-white flex items-center justify-center shadow-lg transition-all scale-100 active:scale-95"
            style={{ backgroundColor: accentColor, boxShadow: `0 4px 20px ${shadowColor}` }}
          >
            {isPlaying ? <Pause size={20} fill="white" /> : <Play size={20} fill="white" className="ml-0.5" />}
          </button>

          <button 
            onClick={skipNext} 
            className="text-white/70 hover:text-white transition-colors"
          >
            <SkipForward size={20} />
          </button>

          <button
            onClick={handleLike}
            className="hidden md:block p-2 text-white/70 hover:text-pink-500 transition-colors"
          >
            <Heart size={20} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
          </button>
        </div>

        {/* Progress Bar (Bottom Hairline) */}
        <div className="absolute bottom-0 left-0 right-0 h-1 bg-white/10 rounded-b-full overflow-hidden">
          <div 
            className="h-full transition-all duration-300"
            style={{ 
              width: `${progressPct}%`,
              background: `linear-gradient(90deg, ${accentColor}, #ec4899)`
            }}
          />
        </div>
      </div>

      {/* ─── Full-Screen Expanded Modal (Apple Music Dynamic Backdrop) ─── */}
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, y: '100%' }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="fixed inset-0 z-50 backdrop-blur-3xl flex flex-col p-6 lg:p-12 overflow-y-auto transition-colors duration-700"
            style={modalBg}
          >
            {/* Ambient Animated Fluid Glow Mesh Overlay */}
            <div className="absolute inset-0 pointer-events-none overflow-hidden opacity-40 z-0">
              <div 
                className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full filter blur-[100px] animate-pulse"
                style={{ background: themePalette?.secondary || '#ec4899' }}
              />
            </div>

            {/* Top Bar Header & View Switcher */}
            <div className="relative z-10 flex items-center justify-between mb-6">
              <button 
                onClick={() => setExpanded(false)}
                className="p-3 rounded-full glass-card text-white/80 hover:text-white transition-all"
              >
                <ChevronDown size={24} />
              </button>

              {/* View Switcher Tabs */}
              <div className="flex items-center gap-1 p-1 glass-card rounded-full">
                <button
                  onClick={() => setModalTab('artwork')}
                  className={`px-3 py-1.5 rounded-full text-xs font-bold transition-all flex items-center gap-1.5 ${
                    modalTab === 'artwork' ? 'bg-white/25 text-white' : 'text-white/60 hover:text-white'
                  }`}
                >
                  <Disc size={14} />
                  <span>Cover</span>
                </button>

                <button
                  onClick={() => setModalTab('lyrics')}
                  className={`px-3 py-1.5 rounded-full text-xs font-bold transition-all flex items-center gap-1.5 ${
                    modalTab === 'lyrics' ? 'bg-white/25 text-white' : 'text-white/60 hover:text-white'
                  }`}
                >
                  <MessageSquareQuote size={14} />
                  <span>Lyrics</span>
                </button>

                <button
                  onClick={() => setModalTab('queue')}
                  className={`px-3 py-1.5 rounded-full text-xs font-bold transition-all flex items-center gap-1.5 ${
                    modalTab === 'queue' ? 'bg-white/25 text-white' : 'text-white/60 hover:text-white'
                  }`}
                >
                  <ListMusic size={14} />
                  <span>Queue ({queue.length})</span>
                </button>
              </div>

              <div className="w-10" />
            </div>

            {/* Main Content Body */}
            <div className="relative z-10 flex-1 max-w-lg w-full mx-auto flex flex-col items-center justify-center">
              
              {/* TAB 1: ARTWORK COVER */}
              {modalTab === 'artwork' && (
                <div 
                  className="relative w-64 h-64 sm:w-80 sm:h-80 lg:w-96 lg:h-96 rounded-3xl overflow-hidden mb-8 border border-white/20 bg-black transition-all duration-700"
                  style={{
                    boxShadow: `0 25px 70px -10px ${shadowColor}`
                  }}
                >
                  <img
                    src={currentTrack.artworkUrl || `https://i.ytimg.com/vi/${currentTrack.id}/hq720.jpg`}
                    alt={currentTrack.title}
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      if (!e.target.src.includes('sddefault.jpg')) {
                        e.target.src = `https://i.ytimg.com/vi/${currentTrack.id}/sddefault.jpg`;
                      } else if (!e.target.src.includes('hqdefault.jpg')) {
                        e.target.src = `https://i.ytimg.com/vi/${currentTrack.id}/hqdefault.jpg`;
                      }
                    }}
                  />
                </div>
              )}

              {/* TAB 2: SYNCHRONIZED LYRICS */}
              {modalTab === 'lyrics' && (
                <div className="w-full h-80 sm:h-96 rounded-3xl p-6 glass-card border border-white/15 overflow-y-auto mb-8 flex flex-col items-center justify-start text-center scroll-smooth" ref={lyricsContainerRef}>
                  {loadingLyrics ? (
                    <div className="flex flex-col items-center justify-center h-full text-white/50 animate-pulse">
                      <MessageSquareQuote size={36} className="mb-2 text-purple-400" />
                      <p className="text-sm font-semibold">Loading synchronized lyrics...</p>
                    </div>
                  ) : lyricsData.synced.length > 0 ? (
                    <div className="flex flex-col gap-6 py-6 w-full">
                      {lyricsData.synced.map((line, idx) => (
                        <p
                          key={idx}
                          onClick={() => seek(line.time)}
                          className={`cursor-pointer transition-all duration-300 text-lg sm:text-2xl font-bold leading-relaxed ${
                            idx === activeLyricIdx
                              ? 'text-white scale-105 opacity-100 drop-shadow-[0_0_15px_rgba(255,255,255,0.8)]'
                              : 'text-white/40 opacity-50 hover:opacity-80 scale-95'
                          }`}
                        >
                          {line.text}
                        </p>
                      ))}
                    </div>
                  ) : (
                    <div className="flex flex-col items-center justify-center h-full text-white/70 whitespace-pre-line text-sm sm:text-base leading-relaxed py-6">
                      {lyricsData.plain}
                    </div>
                  )}
                </div>
              )}

              {/* TAB 3: UP NEXT QUEUE */}
              {modalTab === 'queue' && (
                <div className="w-full h-80 sm:h-96 rounded-3xl p-4 glass-card border border-white/15 overflow-y-auto mb-8 flex flex-col gap-2">
                  <span className="text-xs uppercase font-extrabold tracking-wider text-purple-300 px-2 py-1">
                    Up Next ({queue.length} Tracks)
                  </span>
                  {queue.map((track, qIdx) => {
                    const isTrackActive = currentTrack.id === track.id;
                    return (
                      <div
                        key={`${track.id}-${qIdx}`}
                        onClick={() => playTrack(track, queue)}
                        className={`flex items-center justify-between p-2.5 rounded-2xl cursor-pointer transition-all ${
                          isTrackActive ? 'bg-purple-500/25 border border-purple-500/40 text-white' : 'hover:bg-white/10 text-white/70'
                        }`}
                      >
                        <div className="flex items-center gap-3 min-w-0 flex-1">
                          <img
                            src={track.artworkUrl}
                            alt={track.title}
                            className="w-10 h-10 rounded-lg object-cover"
                          />
                          <div className="flex flex-col min-w-0">
                            <h5 className="text-sm font-bold truncate text-white">
                              {track.title}
                            </h5>
                            <p className="text-xs text-white/50 truncate font-medium">
                              {track.artistName}
                            </p>
                          </div>
                        </div>

                        {isTrackActive && (
                          <span className="text-xs font-bold text-purple-400 px-2 py-1 rounded-full bg-purple-500/20">
                            Playing
                          </span>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Title, Artist, Like & Download Bar */}
              <div className="w-full flex items-center justify-between mb-6">
                <div className="min-w-0 pr-4">
                  <h2 className="text-2xl sm:text-3xl font-extrabold text-white truncate">
                    {currentTrack.title}
                  </h2>
                  <p className="text-base sm:text-lg text-white/70 font-medium truncate mt-1">
                    {currentTrack.artistName}
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  {/* Download Locally Toggle Button */}
                  <button
                    onClick={handleDownload}
                    title={downloaded ? 'Saved Offline' : 'Download for Offline'}
                    className={`p-3 rounded-full glass-card transition-all ${
                      downloaded ? 'text-purple-400 bg-purple-500/20 border border-purple-500/30' : 'text-white/80 hover:text-white'
                    }`}
                  >
                    <Download size={22} color={downloaded ? '#c084fc' : 'currentColor'} />
                  </button>

                  {/* Favorite Like Button */}
                  <button
                    onClick={handleLike}
                    className="p-3 rounded-full glass-card text-white/80 hover:text-pink-500 transition-all"
                  >
                    <Heart size={24} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
                  </button>
                </div>
              </div>

              {/* Progress Scrubber */}
              <div className="w-full mb-6">
                <input
                  type="range"
                  min={0}
                  max={duration || 100}
                  value={currentTime}
                  onChange={(e) => seek(parseFloat(e.target.value))}
                  className="w-full h-2 rounded-lg bg-white/20 appearance-none cursor-pointer"
                  style={{ accentColor: accentColor }}
                />
                <div className="flex justify-between text-xs text-white/60 font-semibold mt-2">
                  <span>{formatTime(currentTime)}</span>
                  <span>{formatTime(duration)}</span>
                </div>
              </div>

              {/* Playback Controls */}
              <div className="w-full flex items-center justify-between mb-8">
                <button 
                  onClick={toggleShuffle}
                  className={`p-3 rounded-full transition-colors ${
                    isShuffle ? 'text-white' : 'text-white/40 hover:text-white'
                  }`}
                >
                  <Shuffle size={22} />
                </button>

                <button 
                  onClick={skipPrev}
                  className="p-3 text-white/80 hover:text-white transition-colors"
                >
                  <SkipBack size={32} />
                </button>

                <button
                  onClick={togglePlayPause}
                  className="w-20 h-20 rounded-full text-white flex items-center justify-center shadow-2xl hover:scale-105 transition-all"
                  style={{ backgroundColor: accentColor, boxShadow: `0 10px 30px ${shadowColor}` }}
                >
                  {isPlaying ? <Pause size={36} fill="white" /> : <Play size={36} fill="white" className="ml-1" />}
                </button>

                <button 
                  onClick={skipNext}
                  className="p-3 text-white/80 hover:text-white transition-colors"
                >
                  <SkipForward size={32} />
                </button>

                <button 
                  onClick={cycleRepeatMode}
                  className={`p-3 rounded-full transition-colors ${
                    repeatMode !== 'off' ? 'text-white' : 'text-white/40 hover:text-white'
                  }`}
                >
                  <Repeat size={22} />
                  {repeatMode === 'one' && <span className="text-[10px] font-bold block -mt-1">1</span>}
                </button>
              </div>

              {/* Volume Scrubber */}
              <div className="w-full flex items-center gap-3 px-4 py-2.5 glass-card rounded-full max-w-xs">
                <button onClick={toggleMute} className="text-white/60 hover:text-white">
                  {isMuted || volume === 0 ? <VolumeX size={18} /> : <Volume2 size={18} />}
                </button>
                <input
                  type="range"
                  min={0}
                  max={100}
                  value={isMuted ? 0 : volume}
                  onChange={(e) => setVolume(parseInt(e.target.value))}
                  className="w-full h-1.5 rounded-lg bg-white/20 appearance-none cursor-pointer"
                  style={{ accentColor: accentColor }}
                />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};
