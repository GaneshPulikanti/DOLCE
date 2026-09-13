import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, SkipBack, SkipForward, Repeat, Shuffle, 
  Heart, ChevronDown, ChevronUp, Download, MessageSquareQuote, ListMusic,
  Maximize2, Minimize2, X, Radio, FolderPlus, Plus, Check, ListPlus
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { usePlayerStore } from '../store/usePlayerStore';
import { 
  db, toggleFavorite, isFavorite, downloadTrackLocally, isDownloadedLocally,
  getUserPlaylists, createPlaylist, addTrackToPlaylist 
} from '../services/db';
import { fetchLyrics } from '../services/lyrics';

export const PlayerBar = ({ themePalette }) => {
  const { 
    currentTrack, queue, isPlaying, togglePlayPause, 
    playTrack, skipNext, skipPrev, currentTime, duration, seek, 
    isShuffle, repeatMode, cyclePlaybackMode,
    lyricFont, setLyricFont,
    isExpanded, setExpanded 
  } = usePlayerStore();

  const [liked, setLiked] = useState(false);
  const [downloaded, setDownloaded] = useState(false);
  const [lyricsData, setLyricsData] = useState({ synced: [], plain: '' });
  const [loadingLyrics, setLoadingLyrics] = useState(false);
  const [showQueue, setShowQueue] = useState(false);
  const [showPlaylistModal, setShowPlaylistModal] = useState(false);
  const [userPlaylists, setUserPlaylists] = useState([]);
  const [newPlaylistName, setNewPlaylistName] = useState('');
  const [addedSuccessMsg, setAddedSuccessMsg] = useState('');
  const [isFullScreenLyrics, setIsFullScreenLyrics] = useState(false);
  const [inlineLyricY, setInlineLyricY] = useState(0);
  const [userScrolledFullLyrics, setUserScrolledFullLyrics] = useState(false);

  const lyricsContainerRef = useRef(null);
  const inlineListRef = useRef(null);
  const fullLyricsContainerRef = useRef(null);
  const userScrollTimeoutRef = useRef(null);

  const loadPlaylists = async () => {
    const list = await getUserPlaylists();
    setUserPlaylists(list);
  };

  useEffect(() => {
    if (showPlaylistModal) {
      loadPlaylists();
    }
  }, [showPlaylistModal]);

  const handleAddToPlaylist = async (playlistId, playlistName) => {
    if (!currentTrack) return;
    await addTrackToPlaylist(playlistId, currentTrack);
    setAddedSuccessMsg(`Added to "${playlistName}"`);
    loadPlaylists();
    setTimeout(() => setAddedSuccessMsg(''), 2500);
  };

  const handleCreateAndAddPlaylist = async (e) => {
    e.preventDefault();
    if (!newPlaylistName || !newPlaylistName.trim() || !currentTrack) return;
    const created = await createPlaylist(newPlaylistName.trim(), currentTrack);
    if (created) {
      setNewPlaylistName('');
      setAddedSuccessMsg(`Created & Added to "${created.name}"`);
      loadPlaylists();
      setTimeout(() => setAddedSuccessMsg(''), 2500);
    }
  };

  const handleFullLyricsScroll = () => {
    setUserScrolledFullLyrics(true);
    if (userScrollTimeoutRef.current) {
      clearTimeout(userScrollTimeoutRef.current);
    }
    userScrollTimeoutRef.current = setTimeout(() => {
      setUserScrolledFullLyrics(false);
    }, 4000);
  };
  const activeLyricRef = useRef(null);
  const fullActiveLyricRef = useRef(null);

  // Sync favorites & downloads status
  useEffect(() => {
    if (currentTrack?.id) {
      isFavorite(currentTrack.id).then(setLiked);
      isDownloadedLocally(currentTrack.id).then(setDownloaded);
    }
  }, [currentTrack?.id]);

  // Fetch lyrics when track changes (checks offline DB first)
  useEffect(() => {
    if (currentTrack?.id) {
      setLoadingLyrics(true);
      db.downloads.get(currentTrack.id).then((dl) => {
        if (dl && dl.lyrics && (dl.lyrics.synced?.length > 0 || dl.lyrics.plain)) {
          setLyricsData(dl.lyrics);
          setLoadingLyrics(false);
        } else {
          fetchLyrics(currentTrack.title, currentTrack.artistName).then((data) => {
            setLyricsData(data);
            setLoadingLyrics(false);
          });
        }
      }).catch(() => {
        fetchLyrics(currentTrack.title, currentTrack.artistName).then((data) => {
          setLyricsData(data);
          setLoadingLyrics(false);
        });
      });
    }
  }, [currentTrack?.id, currentTrack?.title, currentTrack?.artistName]);

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

  const renderPlaybackModeIcon = () => {
    if (isShuffle) {
      return <Shuffle size={22} className="text-white" />;
    }
    if (repeatMode === 'all') {
      return <Repeat size={22} className="text-white" />;
    }
    if (repeatMode === 'one') {
      return (
        <div className="relative flex flex-col items-center">
          <Repeat size={22} className="text-white" />
          <span className="text-[9px] font-black text-white leading-none -mt-1">1</span>
        </div>
      );
    }
    return <Shuffle size={22} className="text-white/40 hover:text-white" />;
  };

  // ── Auto-center active lyric line for inline & full screen mode ──
  useEffect(() => {
    if (activeLyricIdx >= 0) {
      // 1. Calculate translateY for mini lyric window (using justify-start container alignment)
      if (inlineListRef.current && lyricsContainerRef.current) {
        const containerHeight = lyricsContainerRef.current.clientHeight || 256;
        const activeEl = inlineListRef.current.querySelector(`[data-lyric-index="${activeLyricIdx}"]`);
        if (activeEl) {
          const elOffsetTop = activeEl.offsetTop;
          const elHeight = activeEl.clientHeight;
          const targetY = (containerHeight / 2) - (elOffsetTop + elHeight / 2);
          setInlineLyricY(targetY);
        }
      }

      // 2. Auto-scroll full screen lyrics ONLY when user is not actively reading/scrolling
      if (isFullScreenLyrics && fullLyricsContainerRef.current && !userScrolledFullLyrics) {
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
    } else {
      setInlineLyricY(0);
    }
  }, [activeLyricIdx, isFullScreenLyrics, userScrolledFullLyrics]);

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

  const artworkUrl = currentTrack.artworkUrl || (currentTrack.id ? `https://i.ytimg.com/vi/${currentTrack.id}/hq720.jpg` : '');
  const dominantBg = themePalette?.darkGradient || 'linear-gradient(180deg, rgba(20, 20, 28, 0.85) 0%, rgba(8, 8, 12, 0.95) 50%, rgba(5, 5, 5, 0.98) 100%)';
  const glowShadow = themePalette ? `0 25px 65px -10px rgba(${themePalette.r}, ${themePalette.g}, ${themePalette.b}, 0.55), 0 0 35px rgba(${themePalette.r}, ${themePalette.g}, ${themePalette.b}, 0.3)` : '0 20px 50px rgba(0,0,0,0.8)';
  const activeLyricGlow = themePalette ? `0 0 20px rgba(${themePalette.r}, ${themePalette.g}, ${themePalette.b}, 0.9), 0 0 35px rgba(255, 255, 255, 0.9)` : '0 0 18px rgba(255,255,255,0.85)';

  return (
    <>
      {/* ─── Persistent Mini Player Bar (Original Dart Monochromatic Glass) ─── */}
      <div 
        onClick={() => setExpanded(true)}
        className="fixed bottom-[84px] left-3 right-3 max-w-2xl mx-auto z-[45] glass-panel border border-white/14 p-2.5 lg:p-3 flex items-center justify-between shadow-2xl cursor-pointer bg-[#0d0d0d]/95 backdrop-blur-2xl transition-all duration-300 hover:scale-[1.005]"
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

        {/* Playback Controls & Expand Indicator */}
        <div className="flex items-center gap-2 lg:gap-3" onClick={(e) => e.stopPropagation()}>
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

          <button
            onClick={() => setExpanded(true)}
            className="p-1.5 text-white/40 hover:text-white transition-colors ml-1"
            title="Expand Full Player"
          >
            <ChevronUp size={20} />
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

      {/* ─── Full-Screen Expanded Player Modal (Exact Apple Music & Spotify Glassmorphism) ─── */}
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, y: '100%' }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: '100%' }}
            transition={{ type: 'spring', damping: 26, stiffness: 220 }}
            className="fixed inset-0 z-50 flex flex-col overflow-y-auto select-none font-['Inter']"
            style={{ background: dominantBg }}
          >
            {/* 1. Dynamic Glassmorphic Ambient Artwork Background */}
            <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
              <div 
                className="absolute inset-0 scale-150 bg-cover bg-center opacity-65 filter blur-[75px] transition-all duration-1000"
                style={{ backgroundImage: `url(${artworkUrl})` }}
              />
              <div 
                className="absolute inset-0 transition-all duration-1000"
                style={{ background: dominantBg }}
              />
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
                  onClick={() => setShowPlaylistModal(true)}
                  title="Add to Playlist"
                  className="p-2 text-white/70 hover:text-white transition-colors"
                >
                  <FolderPlus size={20} className="text-white/80 hover:text-white" />
                </button>
              </div>
            </div>

            {/* Main Player Body */}
            <div className="relative z-10 flex-1 max-w-xl w-full mx-auto px-6 py-4 flex flex-col items-center justify-between gap-6">
              
              {/* 3. Cover Artwork Box */}
              <div 
                className="relative w-64 h-64 sm:w-72 sm:h-72 aspect-square rounded-3xl overflow-hidden border border-white/30 bg-[#141416] flex-shrink-0 my-2 flex items-center justify-center transition-all duration-700"
                style={{ boxShadow: glowShadow }}
              >
                <img
                  src={artworkUrl}
                  alt={currentTrack.title}
                  className={`w-full h-full object-cover ${artworkUrl?.includes('ytimg.com') ? 'scale-[1.25]' : ''}`}
                  onError={(e) => {
                    if (currentTrack?.id && !e.target.src.includes('hqdefault.jpg')) {
                      e.target.src = `https://i.ytimg.com/vi/${currentTrack.id}/hqdefault.jpg`;
                    }
                  }}
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
                {/* Combined Playback Mode Button (Shuffle -> Repeat All -> Repeat One -> Off) */}
                <button 
                  onClick={cyclePlaybackMode}
                  className="p-3 transition-colors flex items-center justify-center transform active:scale-90"
                  title={
                    isShuffle ? "Mode: Shuffle" 
                    : repeatMode === 'all' ? "Mode: Repeat All" 
                    : repeatMode === 'one' ? "Mode: Repeat One" 
                    : "Mode: Off (Click to Shuffle)"
                  }
                >
                  {renderPlaybackModeIcon()}
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

                {/* Up Next Queue Toggle Button */}
                <button 
                  onClick={() => setShowQueue(!showQueue)}
                  className={`p-3 transition-colors rounded-full transform active:scale-90 ${
                    showQueue ? 'text-white bg-white/20' : 'text-white/40 hover:text-white'
                  }`}
                  title="Up Next Queue"
                >
                  <ListMusic size={22} />
                </button>
              </div>

              {/* 4. Content Container directly under Player Controls (Queue or Lyrics) */}
              {showQueue ? (
                /* Up Next Queue (Opens right here under player controls) */
                <div className="w-full rounded-3xl p-6 border border-white/10 bg-black/30 backdrop-blur-xl flex flex-col gap-4 text-left shadow-2xl mt-2 mb-6 transition-all">
                  <div className="flex items-center justify-between border-b border-white/10 pb-3">
                    <span className="text-xs uppercase font-extrabold tracking-[0.15em] text-white/80 flex items-center gap-2 font-['Inter']">
                      <ListMusic size={18} className="text-white" />
                      <span>UP NEXT QUEUE ({queue.length})</span>
                    </span>

                    <button
                      onClick={() => setShowQueue(false)}
                      className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 text-xs font-bold text-white transition-all"
                      title="Close Queue & Show Lyrics"
                    >
                      <X size={13} />
                      <span>Close Queue</span>
                    </button>
                  </div>

                  <div className="w-full max-h-72 overflow-y-auto scroll-smooth pr-1 flex flex-col gap-2">
                    {queue.length > 0 ? (
                      queue.map((track, qIdx) => {
                        const isTrackActive = currentTrack.id === track.id;
                        return (
                          <div
                            key={`${track.id}-${qIdx}`}
                            onClick={() => playTrack(track, queue)}
                            className={`flex items-center justify-between p-3 rounded-2xl cursor-pointer transition-all ${
                              isTrackActive
                                ? 'bg-white/20 border border-white/30 text-white font-bold'
                                : 'hover:bg-white/10 text-white/70'
                            }`}
                          >
                            <div className="flex items-center gap-3.5 min-w-0 flex-1">
                              <img
                                src={track.artworkUrl}
                                alt={track.title}
                                className="w-11 h-11 rounded-xl object-cover bg-black border border-white/10 flex-shrink-0"
                              />
                              <div className="flex flex-col min-w-0">
                                <h5 className="text-sm font-bold truncate text-white font-['Inter']">
                                  {track.title}
                                </h5>
                                <p className="text-xs text-white/50 truncate font-medium font-['Inter'] mt-0.5">
                                  {track.artistName}
                                </p>
                              </div>
                            </div>

                            {isTrackActive && (
                              <span className="text-xs font-bold text-white px-3 py-1 rounded-full bg-white/20 border border-white/30 font-['Inter'] flex-shrink-0">
                                Playing
                              </span>
                            )}
                          </div>
                        );
                      })
                    ) : (
                      <div className="py-10 text-center text-white/50 font-bold font-['Inter'] text-sm">
                        No songs in queue
                      </div>
                    )}
                  </div>
                </div>
              ) : (
                /* Spotify-Style Synchronized Lyrics Container (Clean Glass, No White Box Disturbance) */
                <div className="w-full rounded-3xl p-6 border border-white/10 bg-black/30 backdrop-blur-xl flex flex-col gap-4 text-left shadow-2xl mt-2 mb-6 select-none overflow-hidden">
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

                  {/* Strictly non-scrollable inline container - Active line locked to vertical center */}
                  <div 
                    className="w-full h-64 overflow-hidden relative flex flex-col justify-start items-center select-none touch-none pointer-events-none"
                    ref={lyricsContainerRef}
                  >
                    {loadingLyrics ? (
                      <div className="flex flex-col items-center justify-center py-10 text-white/40 animate-pulse">
                        <MessageSquareQuote size={32} className="mb-2 text-white/60" />
                        <p className="text-xs font-bold font-['Inter']">Loading lyrics...</p>
                      </div>
                    ) : lyricsData.synced.length > 0 ? (
                      <motion.div
                        ref={inlineListRef}
                        animate={{ y: inlineLyricY }}
                        transition={{ type: "spring", stiffness: 90, damping: 18, mass: 0.75 }}
                        className="w-full flex flex-col gap-6 text-center px-2 pointer-events-auto"
                      >
                        {lyricsData.synced.map((line, idx) => {
                          const isActive = idx === activeLyricIdx;
                          const dist = Math.abs(idx - activeLyricIdx);

                          return (
                            <motion.p
                              key={idx}
                              data-lyric-index={idx}
                              onClick={() => seek(line.time)}
                              animate={{
                                scale: isActive ? 1.06 : dist === 1 ? 0.94 : 0.86,
                                opacity: isActive ? 1 : dist === 1 ? 0.45 : 0.15,
                                filter: isActive ? 'blur(0px)' : dist >= 2 ? 'blur(1px)' : 'blur(0px)',
                              }}
                              transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
                              style={isActive ? { textShadow: activeLyricGlow } : {}}
                              className={`cursor-pointer transition-colors leading-relaxed font-lyrics ${
                                isActive
                                  ? 'text-white font-black text-xl sm:text-2xl drop-shadow-md'
                                  : 'text-white/60 font-bold text-base sm:text-lg'
                              }`}
                            >
                              {line.text}
                            </motion.p>
                          );
                        })}
                      </motion.div>
                    ) : (
                      <div className="py-6 text-white/70 whitespace-pre-line text-base font-bold font-lyrics leading-relaxed text-center pointer-events-auto">
                        {lyricsData.plain || 'No lyrics available for this track.'}
                      </div>
                    )}
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
            className="fixed inset-0 z-[60] flex flex-col justify-between overflow-hidden font-['Inter'] select-none p-6"
            style={{ background: dominantBg }}
          >
            {/* Ambient Background Blur */}
            <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
              <div 
                className="absolute inset-0 scale-150 bg-cover bg-center opacity-65 filter blur-[80px] transition-all duration-1000"
                style={{ backgroundImage: `url(${artworkUrl})` }}
              />
              <div 
                className="absolute inset-0 transition-all duration-1000"
                style={{ background: dominantBg }}
              />
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
              className="relative z-10 flex-1 w-full max-w-4xl mx-auto my-6 overflow-y-auto scroll-smooth py-20 flex flex-col gap-8 text-center font-lyrics"
              ref={fullLyricsContainerRef}
              onScroll={handleFullLyricsScroll}
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
                    style={idx === activeLyricIdx ? { textShadow: activeLyricGlow } : {}}
                    className={`cursor-pointer transition-all duration-400 text-2xl sm:text-4xl md:text-5xl font-black leading-relaxed tracking-tight ${
                      idx === activeLyricIdx
                        ? 'text-white opacity-100 scale-105'
                        : 'text-white/30 opacity-35 hover:opacity-70 scale-95'
                    }`}
                  >
                    {line.text}
                  </p>
                ))
              ) : (
                <div className="py-20 text-white/80 whitespace-pre-line text-xl sm:text-2xl font-bold font-lyrics leading-relaxed max-w-2xl mx-auto">
                  {lyricsData.plain || 'No lyrics available for this track.'}
                </div>
              )}
            </div>

            {/* Floating Recenter Pill when user is manually scrolling */}
            <AnimatePresence>
              {userScrolledFullLyrics && (
                <div className="fixed bottom-28 left-0 right-0 z-30 flex justify-center pointer-events-none">
                  <motion.button
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 20 }}
                    onClick={() => {
                      setUserScrolledFullLyrics(false);
                      if (fullLyricsContainerRef.current && activeLyricIdx >= 0) {
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
                    }}
                    className="pointer-events-auto px-4 py-2 rounded-full bg-white/15 hover:bg-white/25 backdrop-blur-xl border border-white/20 text-white text-xs font-bold shadow-2xl flex items-center gap-2 transition-all cursor-pointer font-['Inter']"
                  >
                    <Radio size={13} className="text-white/80 animate-pulse" />
                    <span>Sync with song</span>
                  </motion.button>
                </div>
              )}
            </AnimatePresence>

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

      {/* ─── ADD TO PLAYLIST MODAL ─── */}
      <AnimatePresence>
        {showPlaylistModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setShowPlaylistModal(false)}
            className="fixed inset-0 z-[70] bg-black/70 backdrop-blur-md flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.9, y: 20 }}
              onClick={(e) => e.stopPropagation()}
              className="w-full max-w-md rounded-3xl glass-panel p-6 bg-[#121216]/95 border border-white/20 shadow-2xl flex flex-col gap-5 text-left font-['Inter']"
            >
              {/* Modal Header */}
              <div className="flex items-center justify-between border-b border-white/10 pb-3">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-xl overflow-hidden bg-black/40 border border-white/10 flex-shrink-0">
                    <img src={artworkUrl} alt={currentTrack.title} className="w-full h-full object-cover" />
                  </div>
                  <div className="flex flex-col min-w-0">
                    <h3 className="text-base font-bold text-white truncate">Add to Playlist</h3>
                    <p className="text-xs text-white/50 truncate">{currentTrack.title}</p>
                  </div>
                </div>

                <button
                  onClick={() => setShowPlaylistModal(false)}
                  className="p-2 rounded-full hover:bg-white/10 text-white/70 hover:text-white transition-colors"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Success Alert Toast */}
              {addedSuccessMsg && (
                <div className="px-4 py-2.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 text-xs font-bold flex items-center gap-2">
                  <Check size={16} />
                  <span>{addedSuccessMsg}</span>
                </div>
              )}

              {/* Create New Playlist Form */}
              <form onSubmit={handleCreateAndAddPlaylist} className="flex gap-2">
                <input
                  type="text"
                  value={newPlaylistName}
                  onChange={(e) => setNewPlaylistName(e.target.value)}
                  placeholder="Create new playlist..."
                  className="flex-1 h-11 px-4 rounded-xl bg-white/5 border border-white/14 text-xs text-white placeholder-white/40 focus:outline-none focus:border-white/40 font-medium"
                />
                <button
                  type="submit"
                  disabled={!newPlaylistName.trim()}
                  className="h-11 px-4 rounded-xl bg-white text-black text-xs font-bold flex items-center gap-1.5 hover:bg-white/90 disabled:opacity-50 transition-all shadow-md"
                >
                  <Plus size={16} />
                  <span>Create</span>
                </button>
              </form>

              {/* Playlists List */}
              <div className="flex flex-col gap-2">
                <span className="text-xs font-extrabold uppercase tracking-wider text-white/50">Your Playlists</span>
                <div className="max-h-60 overflow-y-auto pr-1 flex flex-col gap-2 no-scrollbar">
                  {userPlaylists.length > 0 ? (
                    userPlaylists.map((pl) => {
                      const isInPlaylist = pl.tracks?.some((t) => t.id === currentTrack.id);
                      return (
                        <button
                          key={pl.id}
                          onClick={() => handleAddToPlaylist(pl.id, pl.name)}
                          className="w-full p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/10 flex items-center justify-between text-left transition-all group"
                        >
                          <div className="flex flex-col">
                            <span className="text-sm font-bold text-white group-hover:text-pink-300 transition-colors">
                              {pl.name}
                            </span>
                            <span className="text-[11px] text-white/50">
                              {pl.tracks?.length || 0} songs
                            </span>
                          </div>
                          {isInPlaylist ? (
                            <span className="text-xs font-bold text-emerald-400 flex items-center gap-1">
                              <Check size={14} />
                              <span>Added</span>
                            </span>
                          ) : (
                            <Plus size={18} className="text-white/40 group-hover:text-white transition-colors" />
                          )}
                        </button>
                      );
                    })
                  ) : (
                    <div className="py-6 text-center text-xs text-white/40 font-medium">
                      No custom playlists yet. Type a name above to create your first playlist!
                    </div>
                  )}
                </div>
              </div>

            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

