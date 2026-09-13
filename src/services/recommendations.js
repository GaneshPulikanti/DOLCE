import { searchSongs, isValidAudioSong } from './catalog';
import { getRecentHistory, getTopArtistsFromHistory, db } from './db';

/**
 * Personalized YouTube-style Recommendation Engine for DOLCE.
 * Dynamically builds Home feed sections tailored to the user's listening history and favorites.
 */

export async function getPersonalizedHomeFeed() {
  try {
    // 1. Fetch user context from IndexedDB
    const [historyTracks, topArtists, favorites] = await Promise.all([
      getRecentHistory(15),
      getTopArtistsFromHistory(3),
      db.favorites.orderBy('addedAt').reverse().limit(10).toArray()
    ]);

    const sections = [];
    const usedTrackIds = new Set();

    // Helper to add unique tracks to section
    const createSection = (title, tracks) => {
      const filtered = tracks.filter(t => {
        if (!t || !t.id || usedTrackIds.has(t.id)) return false;
        usedTrackIds.add(t.id);
        return isValidAudioSong(t);
      });
      if (filtered.length >= 3) {
        return { title, tracks: filtered.slice(0, 12) };
      }
      return null;
    };

    // ── SECTION 1: Quick Picks (Based on Recent Listening or Favorites) ──
    if (historyTracks.length > 0) {
      const recentTrack = historyTracks[0];
      const quickPicks = await searchSongs(`${recentTrack.artistName} ${recentTrack.title} songs`);
      const s = createSection('⚡ Quick Picks for You', [...historyTracks, ...quickPicks]);
      if (s) sections.push(s);
    }

    // ── SECTION 2: Based on your Top Artist ──
    if (topArtists.length > 0) {
      const primaryArtist = topArtists[0];
      const artistTracks = await searchSongs(`${primaryArtist} top hits songs`);
      const s = createSection(`🎧 Similar to ${primaryArtist}`, artistTracks);
      if (s) sections.push(s);
    }

    // ── SECTION 3: Based on Last Listened Song ──
    if (historyTracks.length > 1) {
      const seedTrack = historyTracks[1];
      const relatedTracks = await searchSongs(`${seedTrack.title} ${seedTrack.artistName} radio mix`);
      const s = createSection(`✨ More Like "${seedTrack.title}"`, relatedTracks);
      if (s) sections.push(s);
    }

    // ── SECTION 4: Favorites & Deep Cuts ──
    if (favorites.length > 0) {
      const favSample = favorites[Math.floor(Math.random() * favorites.length)];
      const favMatches = await searchSongs(`${favSample.artistName} best audio songs`);
      const s = createSection(`❤️ Inspired by Your Liked Songs`, [...favorites, ...favMatches]);
      if (s) sections.push(s);
    }

    // ── SECTION 5: Dynamic Trending & Genre Discovery (Always fresh) ──
    const trendingQueries = [
      { title: '🔥 Trending Music Hits', query: 'top hits music songs' },
      { title: '🌧️ Rain & Chill Lo-Fi', query: 'lofi chill beats songs' },
      { title: '⚡ High Energy Workout', query: 'workout motivation songs' },
      { title: '❤️ Romantic Acoustic Melodies', query: 'romantic acoustic love songs' },
    ];

    // Pick 2-3 trending queries dynamically
    const selectedTrending = trendingQueries.sort(() => 0.5 - Math.random()).slice(0, 3);
    for (const item of selectedTrending) {
      if (sections.length >= 5) break;
      const tTracks = await searchSongs(item.query);
      const s = createSection(item.title, tTracks);
      if (s) sections.push(s);
    }

    // Fallback if no history yet
    if (sections.length === 0) {
      for (const item of trendingQueries) {
        const tTracks = await searchSongs(item.query);
        const s = createSection(item.title, tTracks);
        if (s) sections.push(s);
      }
    }

    return sections.filter(Boolean);
  } catch (e) {
    console.error('Failed to build personalized home feed:', e);
    return [];
  }
}
