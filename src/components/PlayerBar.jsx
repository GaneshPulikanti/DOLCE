import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, SkipBack, SkipForward, Repeat, Shuffle, 
  Heart, ChevronDown, Download, MessageSquareQuote, ListMusic,
  Maximize2, Minimize2, X
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { usePlayerStore } from '../store/usePlayerStore';
import { toggleFavorite, isFavorite, downloadTrackLocally, isDownloadedLocally } from '../services/db';
import { fetchLyrics } from '../services/lyrics';

export const PlayerBar = ({ themePalette }) => {
  const { 
    currentTrack, queue, isPlaying, togglePlayPause, 
    playTrack, skipNext, skipPrev, currentTime, duration, seek, 
    isShuffle, toggleShuffle, repeatMode, cycleRepeatMode,
    isExpanded, setExpanded 
  } = usePlayerStore();

  const [liked, setLiked] = useState(false);
  const [downloaded, setDownloaded] = useState(false);
  const [lyricsData, setLyricsData] = useState({ synced: [], plain: '' });
  const [loadingLyrics, setLoadingLyrics] = useState(false);
  const [showQueue, setShowQueue] = useState(false);
  const [isFullScreenLyrics, setIsFullScreenLyrics] = useState(false);

  const lyricsContainerRef = useRef(null);
  const fullLyricsContainerRef = useRef(null);
  const activeLyricRef = useRef(null);
  const fullActiveLyricRef = useRef(null);

  // Sync favorites & downloads status
  useEffect(() => {
    if (currentTrack?.id) {
      isFavorite(currentTrack.id).then(setLiked);
      isDownloadedLocally(currentTrack.id).then(setDownloaded);
    }
  }, [currentTrack?.id]);

  // Fetch lyrics when track changes
  useEffect(() => {
    if (currentTrack?.id) {
      setLoadingLyrics(true);
      fetchLyrics(currentTrack.title, currentTrack.artistName).then((data) => {
        setLyricsData(data);
        setLoadingLyrics(false);
      });
    }
  }, [currentTrack?.id]);

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

  // ── Auto-scroll active lyric line to VERTICAL CENTER of container ──
  useEffect(() => {
    if (activeLyricIdx >= 0) {
      // 1. Scroll in embedded lyrics card
      if (lyricsContainerRef.current) {
        const container = lyricsContainerRef.current;
        const activeEl = container.querySelector(`[data-lyric-index="${activeLyricIdx}"]`);
        if (activeEl) {
          const containerHeight = container.clientHeight;
          const elOffsetTop = activeEl.offsetTop;
          const elHeight = activeEl.clientHeight;
          const targetScroll = elOffsetTop - (containerHeight / 2) + (elHeight / 2);
          container.scrollTo({ top: Math.max(0, targetScroll), behavior: 'smooth' });
        }
      }

      // 2. Scroll in full screen lyrics modal
      if (isFullScreenLyrics && fullLyricsContainerRef.current) {
        const container = fullLyricsContainerRef.current;
        const activeEl = container.querySelector(`[data-full-lyric-index="${activeLyricIdx}"]`);
        if (activeEl) {
          const containerHeight = container.clientHeight;
          const elOffsetTop = activeEl.offsetTop;
          const elHeight = activeEl.clientHeight;
          const targetScroll = elOffsetTop - (containerHeight / 2) + (elHeight / 2);
          container.scrollTo({ top: Math.max(0, targetScroll), behavior: 'smooth' });
        }
      }
    }
  }, [activeLyricIdx, isFullScreenLyrics]);

  const artworkUrl = currentTrack.artworkUrl || '';

  return (
    <>
      {/* ─── Persistent Mini Player Bar (Original Dart Monochromatic Glass) ─── */}
      <div 
        onClick={() => setExpanded(true)}
        className="fixed bottom-[68px] md:bottom-4 left-3 right-3 lg:left-6 lg:right-6 z-40 glass-panel border border-white/14 p-2.5 lg:p-3 flex items-center justify-between shadow-2xl cursor-pointer bg-[#0d0d0d]/90 backdrop-blur-2xl transition-all duration-300 hover:scale-[1.002]"
      >
        {/* Track Thumbnail & Titles */}
        <div className="flex items-center gap-3.5 min-w-0 flex-1">
          <div className="w-11 h-11 lg:w-12 lg:h-12 rounded-xl overflow-hidden border border-white/14 bg-[#141416] flex-shrink-0 shadow-md flex items-center justify-center">
            {artworkUrl ? (
              <img
                src={artworkUrl}
                alt={currentTrack.title}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center bg-white/5 text-white/50">
                ♪
              </div>
            )}
          </div>

          <div className="flex flex-col min-w-0">
            <h4 className="text-sm lg:text-base font-bold text-white truncate font-['Inter']">
              {currentTrack.title}
            </h4>
            <p className="text-xs text-white/60 truncate font-medium font-['Inter'] mt-0.5">
              {currentTrack.artistName}
            </p>
          </div>
        </div>

        {/* Playback Controls */}
        <div className="flex items-center gap-2 lg:gap-4" onClick={(e) => e.stopPropagation()}>
          <button 
            onClick={skipPrev} 
            className="hidden sm:block p-1.5 text-white/70 hover:text-white transition-colors"
          >
            <SkipBack size={18} />
          </button>

          <button
            onClick={togglePlayPause}
            className="w-10 h-10 rounded-full bg-white hover:bg-white/90 text-black flex items-center justify-center shadow-lg transition-all transform active:scale-95"
          >
            {isPlaying ? <Pause size={18} fill="black" /> : <Play size={18} fill="black" className="ml-0.5" />}
          </button>

          <button 
            onClick={skipNext} 
            className="p-1.5 text-white/70 hover:text-white transition-colors"
          >
            <SkipForward size={18} />
          </button>

          <button
            onClick={handleLike}
            className="hidden md:block p-2 text-white/70 hover:text-pink-500 transition-colors"
          >
            <Heart size={18} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
          </button>
        </div>

        {/* Progress Bar (Bottom Hairline) */}
        <div className="absolute bottom-0 left-0 right-0 h-1 bg-white/10 rounded-b-full overflow-hidden">
          <div 
            className="h-full bg-white transition-all duration-300"
            style={{ width: `${progressPct}%` }}
          />
        </div>
      </div>

      {/* ─── Full-Screen Expanded Player Modal (Exact Original Dart UI) ─── */}
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, y: '100%' }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: '100%' }}
            transition={{ type: 'spring', damping: 26, stiffness: 220 }}
            className="fixed inset-0 z-50 bg-[#050505] flex flex-col overflow-y-auto select-none font-['Inter']"
          >
            {/* 1. Dynamic Glassmorphic Ambient Artwork Background */}
            <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
              <div 
                className="absolute inset-0 scale-125 bg-cover bg-center opacity-45 filter blur-[65px] transition-all duration-1000"
                style={{ backgroundImage: `url(${artworkUrl})` }}
              />
              <div className="absolute inset-0 bg-gradient-to-b from-[#080808]/40 via-[#111111]/75 to-[#050505]/95" />
            </div>

            {/* 2. Top Header Row (Chevron, NOW PLAYING, Actions) */}
            <div className="relative z-10 flex items-center justify-between px-6 pt-6 pb-2 max-w-xl w-full mx-auto">
              <button 
                onClick={() => setExpanded(false)}
                className="p-2 text-white/80 hover:text-white transition-colors"
              >
                <ChevronDown size={30} />
              </button>

              <span className="text-xs uppercase font-bold tracking-[0.2em] text-white/70 font-['Inter']">
                NOW PLAYING
              </span>

              <div className="flex items-center gap-1">
                <button
                  onClick={handleDownload}
                  title={downloaded ? 'Saved Offline' : 'Download Offline'}
                  className="p-2 text-white/70 hover:text-white transition-colors"
                >
                  <Download size={20} color={downloaded ? '#c084fc' : 'currentColor'} />
                </button>

                <button
                  onClick={() => setShowQueue(!showQueue)}
                  title="Toggle Queue"
                  className="p-2 text-white/70 hover:text-white transition-colors"
                >
                  <ListMusic size={20} color={showQueue ? '#ffffff' : 'currentColor'} />
                </button>
              </div>
            </div>

            {/* Main Player Body */}
            <div className="relative z-10 flex-1 max-w-xl w-full mx-auto px-6 py-4 flex flex-col items-center justify-between gap-6">
              
              {/* 3. Cover Artwork Box */}
              <div className="relative aspect-square w-full max-w-[340px] rounded-3xl overflow-hidden border border-white/20 shadow-[0_20px_50px_rgba(0,0,0,0.8)] bg-black my-auto">
                <img
                  src={artworkUrl}
                  alt={currentTrack.title}
                  className="w-full h-full object-cover"
                />
              </div>

              {/* Track Title & Artist Name with Like Button */}
              <div className="w-full flex items-center justify-between pt-2">
                <div className="flex flex-col min-w-0 pr-4">
                  <h2 className="text-xl sm:text-2xl font-extrabold text-white truncate font-['Inter'] tracking-tight">
                    {currentTrack.title}
                  </h2>
                  <p className="text-sm sm:text-base text-white/60 truncate font-semibold font-['Inter'] mt-1">
                    {currentTrack.artistName}
                  </p>
                </div>

                <button
                  onClick={handleLike}
                  className="p-2.5 text-white/70 hover:text-pink-500 transition-all transform active:scale-95"
                >
                  <Heart size={26} fill={liked ? '#ec4899' : 'none'} color={liked ? '#ec4899' : 'currentColor'} />
                </button>
              </div>

              {/* Progress Scrubber & Timestamps */}
              <div className="w-full">
                <input
                  type="range"
                  min={0}
                  max={duration || 100}
                  value={currentTime}
                  onChange={(e) => seek(parseFloat(e.target.value))}
                  className="w-full h-1.5 rounded-lg bg-white/20 appearance-none cursor-pointer accent-white"
                />
                <div className="flex justify-between text-xs text-white/60 font-bold mt-2 font-['Inter']">
                  <span>{formatTime(currentTime)}</span>
                  <span>{formatTime(duration)}</span>
                </div>
              </div>

              {/* Playback Controls Row */}
              <div className="w-full flex items-center justify-between py-2">
                <button 
                  onClick={toggleShuffle}
                  className={`p-3 transition-colors ${
                    isShuffle ? 'text-white' : 'text-white/40 hover:text-white'
                  }`}
                >
                  <Shuffle size={22} />
                </button>

                <button 
                  onClick={skipPrev}
                  className="p-3 text-white/80 hover:text-white transition-colors transform active:scale-90"
                >
                  <SkipBack size={32} />
                </button>

                {/* White Circle Play/Pause Button (Original Dart UI) */}
                <button
                  onClick={togglePlayPause}
                  className="w-20 h-20 rounded-full bg-white text-black flex items-center justify-center shadow-2xl hover:scale-105 transition-all transform active:scale-95"
                >
                  {isPlaying ? <Pause size={36} fill="black" /> : <Play size={36} fill="black" className="ml-1" />}
                </button>

                <button 
                  onClick={skipNext}
                  className="p-3 text-white/80 hover:text-white transition-colors transform active:scale-90"
                >
                  <SkipForward size={32} />
                </button>

                <button 
                  onClick={cycleRepeatMode}
                  className={`p-3 transition-colors ${
                    repeatMode !== 'off' ? 'text-white' : 'text-white/40 hover:text-white'
                  }`}
                >
                  <Repeat size={22} />
                  {repeatMode === 'one' && <span className="text-[10px] font-bold block -mt-1">1</span>}
                </button>
              </div>

              {/* 4. Spotify-Style Synchronized Lyrics Container (Directly Under Player Controls) */}
              <div className="w-full rounded-3xl p-6 glass-panel border border-white/14 bg-white/[0.08] backdrop-blur-2xl flex flex-col gap-4 text-left shadow-2xl mt-2 mb-6">
                <div className="flex items-center justify-between border-b border-white/10 pb-3">
                  <span className="text-xs uppercase font-extrabold tracking-[0.15em] text-white/80 flex items-center gap-2 font-['Inter']">
                    <MessageSquareQuote size={18} className="text-white" />
                    <span>LYRICS</span>
                  </span>

                  {/* Full Screen Mode Toggle Button */}
                  <button
                    onClick={() => setIsFullScreenLyrics(true)}
                    className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 text-xs font-bold text-white transition-all"
                  >
                    <Maximize2 size={13} />
                    <span>Full Screen</span>
                  </button>
                </div>

                <div 
                  className="w-full max-h-72 overflow-y-auto scroll-smooth pr-2 flex flex-col gap-5 relative"
                  ref={lyricsContainerRef}
                >
                  {loadingLyrics ? (
                    <div className="flex flex-col items-center justify-center py-10 text-white/40 animate-pulse">
                      <MessageSquareQuote size={32} className="mb-2 text-white/60" />
                      <p className="text-xs font-bold font-['Inter']">Loading lyrics...</p>
                    </div>
                  ) : lyricsData.synced.length > 0 ? (
                    lyricsData.synced.map((line, idx) => (
                      <p
                        key={idx}
                        data-lyric-index={idx}
                        onClick={() => seek(line.time)}
                        className={`cursor-pointer transition-all duration-300 text-lg sm:text-2xl leading-relaxed font-['Inter'] ${
                          idx === activeLyricIdx
                            ? 'text-white font-black opacity-100 drop-shadow-[0_0_18px_rgba(255,255,255,0.85)] scale-[1.02]'
                            : 'text-white/35 font-bold opacity-45 hover:opacity-75'
                        }`}
                      >
                        {line.text}
                      </p>
                    ))
                  ) : (
                    <div className="py-6 text-white/70 whitespace-pre-line text-base font-bold font-['Inter'] leading-relaxed">
                      {lyricsData.plain || 'No lyrics available for this track.'}
                    </div>
                  )}
                </div>
              </div>

              {/* 5. Up Next Queue Drawer (When Toggle Enabled) */}
              {showQueue && (
                <div className="w-full rounded-3xl p-5 glass-panel border border-white/14 bg-white/[0.08] backdrop-blur-2xl flex flex-col gap-3 mb-8">
                  <div className="flex items-center justify-between border-b border-white/10 pb-2.5">
                    <span className="text-xs uppercase font-bold tracking-widest text-white/80 flex items-center gap-2 font-['Inter']">
                      <ListMusic size={18} className="text-white" />
                      <span>UP NEXT QUEUE ({queue.length})</span>
                    </span>
                  </div>

                  <div className="flex flex-col gap-2 max-h-60 overflow-y-auto">
                    {queue.map((track, qIdx) => {
                      const isTrackActive = currentTrack.id === track.id;
                      return (
                        <div
                          key={`${track.id}-${qIdx}`}
                          onClick={() => playTrack(track, queue)}
                          className={`flex items-center justify-between p-2.5 rounded-2xl cursor-pointer transition-all ${
                            isTrackActive ? 'bg-white/20 border border-white/30 text-white font-bold' : 'hover:bg-white/10 text-white/70'
                          }`}
                        >
                          <div className="flex items-center gap-3 min-w-0 flex-1">
                            <img
                              src={track.artworkUrl}
                              alt={track.title}
                              className="w-10 h-10 rounded-xl object-cover bg-black"
                            />
                            <div className="flex flex-col min-w-0">
                              <h5 className="text-sm font-bold truncate text-white font-['Inter']">
                                {track.title}
                              </h5>
                              <p className="text-xs text-white/50 truncate font-medium font-['Inter']">
                                {track.artistName}
                              </p>
                            </div>
                          </div>

                          {isTrackActive && (
                            <span className="text-xs font-bold text-white px-2.5 py-1 rounded-full bg-white/20 font-['Inter']">
                              Playing
                            </span>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ─── FULL SCREEN IMMERSIVE LYRICS MODAL ─── */}
      <AnimatePresence>
        {isFullScreenLyrics && (
          <motion.div
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.96 }}
            transition={{ duration: 0.3 }}
            className="fixed inset-0 z-[60] bg-[#050505] flex flex-col justify-between overflow-hidden font-['Inter'] select-none p-6"
          >
            {/* Ambient Background Blur */}
            <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
              <div 
                className="absolute inset-0 scale-150 bg-cover bg-center opacity-40 filter blur-[80px]"
                style={{ backgroundImage: `url(${artworkUrl})` }}
              />
              <div className="absolute inset-0 bg-gradient-to-b from-[#080808]/70 via-[#050505]/90 to-[#050505]" />
            </div>

            {/* Top Bar (Track Info & Exit Button) */}
            <div className="relative z-10 flex items-center justify-between border-b border-white/10 pb-4 max-w-4xl w-full mx-auto">
              <div className="flex items-center gap-4 min-w-0">
                <img 
                  src={artworkUrl} 
                  alt={currentTrack.title} 
                  className="w-12 h-12 rounded-xl object-cover border border-white/20 shadow-lg"
                />
                <div className="flex flex-col min-w-0">
                  <h3 className="text-lg font-extrabold text-white truncate">{currentTrack.title}</h3>
                  <p className="text-xs font-semibold text-white/60 truncate">{currentTrack.artistName}</p>
                </div>
              </div>

              <button
                onClick={() => setIsFullScreenLyrics(false)}
                className="p-3 rounded-full bg-white/10 hover:bg-white/20 text-white transition-all"
                title="Exit Full Screen Lyrics"
              >
                <Minimize2 size={22} />
              </button>
            </div>

            {/* Full Screen Scrollable Lyrics Container (Centered Lines) */}
            <div 
              className="relative z-10 flex-1 w-full max-w-4xl mx-auto my-6 overflow-y-auto scroll-smooth py-20 flex flex-col gap-8 text-center"
              ref={fullLyricsContainerRef}
            >
              {loadingLyrics ? (
                <div className="flex flex-col items-center justify-center h-full text-white/40 animate-pulse">
                  <MessageSquareQuote size={48} className="mb-3 text-white/60" />
                  <p className="text-sm font-bold font-['Inter']">Loading full screen lyrics...</p>
                </div>
              ) : lyricsData.synced.length > 0 ? (
                lyricsData.synced.map((line, idx) => (
                  <p
                    key={idx}
                    data-full-lyric-index={idx}
                    onClick={() => seek(line.time)}
                    className={`cursor-pointer transition-all duration-400 text-2xl sm:text-4xl md:text-5xl font-black leading-relaxed tracking-tight ${
                      idx === activeLyricIdx
                        ? 'text-white opacity-100 scale-105 drop-shadow-[0_0_30px_rgba(255,255,255,0.9)]'
                        : 'text-white/30 opacity-35 hover:opacity-70 scale-95'
                    }`}
                  >
                    {line.text}
                  </p>
                ))
              ) : (
                <div className="py-20 text-white/80 whitespace-pre-line text-xl sm:text-2xl font-bold font-['Inter'] leading-relaxed max-w-2xl mx-auto">
                  {lyricsData.plain || 'No lyrics available for this track.'}
                </div>
              )}
            </div>

            {/* Bottom Scrubber & Mini Controls */}
            <div className="relative z-10 max-w-3xl w-full mx-auto bg-white/[0.08] backdrop-blur-2xl border border-white/14 rounded-3xl p-4 flex flex-col gap-3">
              <input
                type="range"
                min={0}
                max={duration || 100}
                value={currentTime}
                onChange={(e) => seek(parseFloat(e.target.value))}
                className="w-full h-1.5 rounded-lg bg-white/20 appearance-none cursor-pointer accent-white"
              />
              
              <div className="flex items-center justify-between px-2">
                <span className="text-xs font-bold text-white/60">{formatTime(currentTime)}</span>
                
                <div className="flex items-center gap-6">
                  <button onClick={skipPrev} className="text-white/80 hover:text-white transition-colors">
                    <SkipBack size={24} />
                  </button>

                  <button
                    onClick={togglePlayPause}
                    className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-lg transition-transform active:scale-95"
                  >
                    {isPlaying ? <Pause size={24} fill="black" /> : <Play size={24} fill="black" className="ml-0.5" />}
                  </button>

                  <button onClick={skipNext} className="text-white/80 hover:text-white transition-colors">
                    <SkipForward size={24} />
                  </button>
                </div>

                <span className="text-xs font-bold text-white/60">{formatTime(duration)}</span>
              </div>
            </div>

          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};
