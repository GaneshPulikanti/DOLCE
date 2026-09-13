import React, { useEffect, useState } from 'react';
import { Search as SearchIcon, Music, Disc, ListMusic, User, Play, Loader2, Sparkles } from 'lucide-react';
import { searchCatalog, fetchCollectionTracks } from '../services/catalog';
import { TrackCard } from '../components/TrackCard';
import { useSearchStore } from '../store/useSearchStore';
import { usePlayerStore } from '../store/usePlayerStore';

export const Search = () => {
  const { searchQuery, setSearchQuery, filterCategory, setFilterCategory } = useSearchStore();
  const { playTrack } = usePlayerStore();
  const [catalogResults, setCatalogResults] = useState({ songs: [], albums: [], playlists: [], artists: [] });
  const [loading, setLoading] = useState(false);
  const [loadingCollectionId, setLoadingCollectionId] = useState(null);

  useEffect(() => {
    if (!searchQuery || !searchQuery.trim()) {
      setCatalogResults({ songs: [], albums: [], playlists: [], artists: [] });
      return;
    }

    const timer = setTimeout(async () => {
      setLoading(true);
      const res = await searchCatalog(searchQuery);
      setCatalogResults(res);
      setLoading(false);
    }, 350);

    return () => clearTimeout(timer);
  }, [searchQuery]);

  const handlePlayCollection = async (browseId) => {
    if (!browseId) return;
    setLoadingCollectionId(browseId);
    const collectionTracks = await fetchCollectionTracks(browseId);
    setLoadingCollectionId(null);
    if (collectionTracks.length > 0) {
      playTrack(collectionTracks[0], collectionTracks);
    }
  };

  // Spotify-Authentic Matte Solid Colors (No AI gradients, no icons)
  const popularGenres = [
    { name: 'Telugu Hits', query: 'Telugu Top Hits', bgColor: 'bg-[#8d67ab]' },
    { name: 'Hindi Melodies', query: 'Hindi Melodies Hits', bgColor: 'bg-[#e8115b]' },
    { name: 'English Pop', query: 'English Pop Songs', bgColor: 'bg-[#148a08]' },
    { name: 'Tamil Beats', query: 'Tamil Hits', bgColor: 'bg-[#bc5900]' },
    { name: 'Punjabi Energy', query: 'Punjabi Hits', bgColor: 'bg-[#d84000]' },
    { name: 'Romantic Love', query: 'Romantic Love Songs', bgColor: 'bg-[#dc148c]' },
    { name: 'Lofi & Chill', query: 'Chill Lofi Songs', bgColor: 'bg-[#27856a]' },
    { name: 'Workout & Gym', query: 'Workout Motivation Songs', bgColor: 'bg-[#7d4b32]' },
    { name: 'Devotional', query: 'Devotional Songs', bgColor: 'bg-[#503750]' },
    { name: 'Party & EDM', query: 'Party Dance Hits', bgColor: 'bg-[#8400e7]' },
  ];

  const categories = [
    { id: 'all', label: 'All Results' },
    { id: 'songs', label: 'Tracks' },
    { id: 'albums', label: 'Albums' },
    { id: 'playlists', label: 'Playlists' },
    { id: 'artists', label: 'Artists' },
  ];

  const hasAnyResults = catalogResults.songs.length > 0 || 
                        catalogResults.albums.length > 0 || 
                        catalogResults.playlists.length > 0 || 
                        catalogResults.artists.length > 0;

  return (
    <div className="w-full min-h-screen pb-40 px-4 lg:px-12 pt-6 flex flex-col gap-6 font-['Inter']">
      {/* Search Header */}
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl lg:text-3xl font-black text-white tracking-tight">Search Catalog & Lyrics</h1>

        {/* Search Input Bar (No autoFocus so mobile keyboard does not pop up automatically) */}
        <div className="relative w-full flex items-center max-w-2xl">
          <SearchIcon size={20} className="absolute left-4 text-white/40 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search songs, albums, artists, or genres..."
            className="w-full h-12 pl-11 pr-5 rounded-2xl bg-white/5 border border-white/15 text-sm text-white placeholder-white/40 focus:outline-none focus:border-white/40 focus:bg-white/10 transition-all font-medium shadow-inner"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-4 text-xs font-bold text-white/50 hover:text-white transition-colors"
            >
              Clear
            </button>
          )}
        </div>

        {/* Category Filter Chips (Shown when searching) */}
        {searchQuery && (
          <div className="flex items-center gap-2 overflow-x-auto pb-2 no-scrollbar">
            {categories.map((cat) => (
              <button
                key={cat.id}
                onClick={() => setFilterCategory(cat.id)}
                className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
                  filterCategory === cat.id
                    ? 'bg-white text-black font-bold shadow-lg shadow-white/10 scale-105'
                    : 'bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10'
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* ── SPOTIFY MATTE GENRES GRID (Shown when search is empty) ── */}
      {!searchQuery && (
        <div className="flex flex-col gap-4 mt-2">
          <h2 className="text-lg lg:text-xl font-extrabold text-white flex items-center gap-2">
            <span>Browse Popular Genres & Languages</span>
          </h2>

          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3.5 sm:gap-5">
            {popularGenres.map((genre, idx) => (
              <div
                key={idx}
                onClick={() => setSearchQuery(genre.query)}
                className={`group relative h-24 sm:h-28 rounded-2xl ${genre.bgColor} p-4 flex flex-col justify-start overflow-hidden cursor-pointer shadow-lg transition-all duration-200 hover:scale-[1.02] border border-white/10`}
              >
                <span className="text-base sm:text-lg font-black text-white leading-tight font-['Inter'] drop-shadow-sm z-10">
                  {genre.name}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Loading Skeletons */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6 mt-4">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) => (
            <div key={i} className="h-52 rounded-2xl bg-white/5 animate-pulse" />
          ))}
        </div>
      ) : hasAnyResults ? (
        <div className="flex flex-col gap-10 mt-2">

          {/* ── SONGS SECTION ── */}
          {(filterCategory === 'all' || filterCategory === 'songs') && catalogResults.songs.length > 0 && (
            <section className="flex flex-col gap-4">
              <h2 className="text-xl font-bold text-white flex items-center gap-2">
                <Music size={20} className="text-pink-400" />
                <span>Songs</span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
                {catalogResults.songs.map((track) => (
                  <TrackCard key={track.id} track={track} queue={catalogResults.songs} />
                ))}
              </div>
            </section>
          )}

          {/* ── ALBUMS SECTION ── */}
          {(filterCategory === 'all' || filterCategory === 'albums') && catalogResults.albums.length > 0 && (
            <section className="flex flex-col gap-4">
              <h2 className="text-xl font-bold text-white flex items-center gap-2">
                <Disc size={20} className="text-purple-400" />
                <span>Albums</span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
                {catalogResults.albums.map((album) => (
                  <div
                    key={album.id}
                    onClick={() => handlePlayCollection(album.id)}
                    className="group relative rounded-2xl glass-panel p-3 bg-white/[0.03] border border-white/10 hover:bg-white/[0.08] hover:border-white/25 transition-all duration-300 cursor-pointer flex flex-col gap-2.5 shadow-lg"
                  >
                    <div className="relative aspect-square w-full rounded-xl overflow-hidden bg-black/40">
                      <img
                        src={album.artworkUrl}
                        alt={album.title}
                        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                        {loadingCollectionId === album.id ? (
                          <Loader2 size={32} className="text-white animate-spin" />
                        ) : (
                          <div className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-xl scale-90 group-hover:scale-100 transition-transform">
                            <Play size={20} fill="black" className="ml-0.5" />
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-col min-w-0">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-pink-300 transition-colors">
                        {album.title}
                      </h4>
                      <p className="text-xs text-white/50 truncate mt-0.5">
                        {album.artistName || album.subtitle}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* ── PLAYLISTS SECTION ── */}
          {(filterCategory === 'all' || filterCategory === 'playlists') && catalogResults.playlists.length > 0 && (
            <section className="flex flex-col gap-4">
              <h2 className="text-xl font-bold text-white flex items-center gap-2">
                <ListMusic size={20} className="text-blue-400" />
                <span>Playlists</span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
                {catalogResults.playlists.map((playlist) => (
                  <div
                    key={playlist.id}
                    onClick={() => handlePlayCollection(playlist.id)}
                    className="group relative rounded-2xl glass-panel p-3 bg-white/[0.03] border border-white/10 hover:bg-white/[0.08] hover:border-white/25 transition-all duration-300 cursor-pointer flex flex-col gap-2.5 shadow-lg"
                  >
                    <div className="relative aspect-square w-full rounded-xl overflow-hidden bg-black/40">
                      <img
                        src={playlist.artworkUrl}
                        alt={playlist.title}
                        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                        {loadingCollectionId === playlist.id ? (
                          <Loader2 size={32} className="text-white animate-spin" />
                        ) : (
                          <div className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-xl scale-90 group-hover:scale-100 transition-transform">
                            <Play size={20} fill="black" className="ml-0.5" />
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-col min-w-0">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-blue-300 transition-colors">
                        {playlist.title}
                      </h4>
                      <p className="text-xs text-white/50 truncate mt-0.5">
                        {playlist.author || playlist.subtitle}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* ── ARTISTS SECTION ── */}
          {(filterCategory === 'all' || filterCategory === 'artists') && catalogResults.artists.length > 0 && (
            <section className="flex flex-col gap-4">
              <h2 className="text-xl font-bold text-white flex items-center gap-2">
                <User size={20} className="text-emerald-400" />
                <span>Artists</span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4 lg:gap-6">
                {catalogResults.artists.map((artist) => (
                  <div
                    key={artist.id}
                    onClick={async () => {
                      setSearchQuery(artist.name);
                      setFilterCategory('songs');
                    }}
                    className="group relative rounded-2xl glass-panel p-4 bg-white/[0.03] border border-white/10 hover:bg-white/[0.08] transition-all duration-300 cursor-pointer flex flex-col items-center text-center gap-3 shadow-lg"
                  >
                    <div className="relative w-28 h-28 rounded-full overflow-hidden border-2 border-white/20 group-hover:border-white/50 transition-all shadow-md">
                      <img
                        src={artist.artworkUrl}
                        alt={artist.name}
                        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                      />
                    </div>
                    <div className="flex flex-col items-center min-w-0">
                      <h4 className="text-sm font-bold text-white truncate w-full group-hover:text-emerald-300 transition-colors">
                        {artist.name}
                      </h4>
                      <p className="text-[11px] text-white/50 truncate mt-0.5">
                        {artist.subtitle || 'Artist'}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

        </div>
      ) : (
        searchQuery && (
          <div className="flex flex-col items-center justify-center py-20 text-center text-white/50">
            <Music size={48} className="mb-4 text-white/30" />
            <h3 className="text-lg font-bold text-white mb-1">No results found</h3>
            <p className="text-xs">Try searching for a different track, album, playlist, or artist name</p>
          </div>
        )
      )}
    </div>
  );
};
