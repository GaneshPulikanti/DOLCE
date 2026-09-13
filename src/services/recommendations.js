import { searchSongs, isValidAudioSong } from './catalog.js';
import { getRecentHistory, getTopArtistsFromHistory, db } from './db.js';

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

    const usedTrackIds = new Set();
    const createSection = (title, tracks) => {
      const filtered = (tracks || []).filter(t => {
        if (!t || !t.id || usedTrackIds.has(t.id)) return false;
        usedTrackIds.add(t.id);
        return isValidAudioSong(t);
      });
      if (filtered.length >= 3) {
        return { title, tracks: filtered.slice(0, 12) };
      }
      return null;
    };

    // Prepare all promise queries concurrently
    const queryTasks = [];

    // Task 1: Quick Picks
    let quickPicksIndex = -1;
    if (historyTracks.length > 0) {
      const recentTrack = historyTracks[0];
      quickPicksIndex = queryTasks.length;
      queryTasks.push({
        title: '⚡ Quick Picks for You',
        promise: searchSongs(`${recentTrack.artistName} ${recentTrack.title} songs`),
        prepend: historyTracks
      });
    }

    // Task 2: Top Artist
    if (topArtists.length > 0) {
      const primaryArtist = topArtists[0];
      queryTasks.push({
        title: `🎧 Similar to ${primaryArtist}`,
        promise: searchSongs(`${primaryArtist} top hits songs`)
      });
    }

    // Task 3: Seed Song
    if (historyTracks.length > 1) {
      const seedTrack = historyTracks[1];
      queryTasks.push({
        title: `✨ More Like "${seedTrack.title}"`,
        promise: searchSongs(`${seedTrack.title} ${seedTrack.artistName} radio mix`)
      });
    }

    // Task 4: Favorites
    if (favorites.length > 0) {
      const favSample = favorites[Math.floor(Math.random() * favorites.length)];
      queryTasks.push({
        title: `❤️ Inspired by Your Liked Songs`,
        promise: searchSongs(`${favSample.artistName} best audio songs`),
        prepend: favorites
      });
    }

    // Task 5: Regional Trending Categories (Telugu & Hindi Hits)
    const defaultTrending = [
      { title: '🔥 Telugu Chartbusters 2026', query: 'telugu top hits songs aditya music' },
      { title: '❤️ Telugu Love Melodies', query: 'telugu romantic love songs sid sriram' },
      { title: '⚡ Mass Beats & Party', query: 'telugu mass songs thaman dsp' },
      { title: '🎧 Bollywood Blockbusters', query: 'top hindi songs hits arijit singh' },
      { title: '🌧️ Telugu Rain & Lo-Fi Chill', query: 'telugu lofi songs chill' },
    ];

    defaultTrending.forEach(item => {
      queryTasks.push({
        title: item.title,
        promise: searchSongs(item.query)
      });
    });

    // Execute ALL queries in parallel (Ultra-fast load!)
    const results = await Promise.allSettled(queryTasks.map(t => t.promise));

    const sections = [];
    queryTasks.forEach((task, idx) => {
      if (results[idx].status === 'fulfilled' && results[idx].value) {
        const rawTracks = task.prepend ? [...task.prepend, ...results[idx].value] : results[idx].value;
        const section = createSection(task.title, rawTracks);
        if (section) sections.push(section);
      }
    });

    const finalSections = sections.filter(Boolean).slice(0, 5);

    // Save cache locally for 0ms instant startup on next app open
    if (typeof localStorage !== 'undefined' && finalSections.length > 0) {
      try {
        localStorage.setItem('DOLCE_HOME_FEED_CACHE_V2', JSON.stringify(finalSections));
      } catch (_) {}
    }

    return finalSections;
  } catch (e) {
    console.error('Failed to build personalized home feed:', e);
    return [];
  }
}
