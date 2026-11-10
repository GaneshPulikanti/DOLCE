import { searchSongs, isValidAudioSong, fetchTrackRadio, cleanSongTitle } from './catalog.js';
import { getRecentHistory, getTopArtistsFromHistory, db } from './db.js';

/**
 * Spotify-Grade Personalized Recommendation Engine for DOLCE.
 * Combines RDAMVM track radio intelligence, user history, favorites, and diverse global shelves.
 */

export async function getPersonalizedHomeFeed() {
  try {
    // 1. Fetch user context from IndexedDB
    const [historyTracks, topArtists, favorites] = await Promise.all([
      getRecentHistory(15),
      getTopArtistsFromHistory(3),
      db.favorites.orderBy('addedAt').reverse().limit(15).toArray()
    ]);

    const usedTrackIds = new Set();
    const createSection = (title, tracks) => {
      const filtered = (tracks || []).filter(t => {
        if (!t || !t.id || usedTrackIds.has(t.id)) return false;
        usedTrackIds.add(t.id);
        return isValidAudioSong(t);
      });
      if (filtered.length >= 3) {
        return { title, tracks: filtered.slice(0, 15) };
      }
      return null;
    };

    // Prepare all query tasks concurrently
    const queryTasks = [];

    // Task 1: Primary Seed Song Radio
    if (historyTracks.length > 0) {
      const recentTrack = historyTracks[0];
      const cleanTitle = cleanSongTitle(recentTrack.title);
      queryTasks.push({
        title: `✨ More Like "${cleanTitle}"`,
        promise: fetchTrackRadio(recentTrack.id).then(r => r.length > 0 ? r : searchSongs(`${recentTrack.artistName} ${cleanTitle} radio`)),
        prepend: [recentTrack]
      });
    }

    // Task 2: Favorites / Liked Songs Radio
    if (favorites.length > 0) {
      const favSample = favorites[Math.floor(Math.random() * favorites.length)];
      queryTasks.push({
        title: `❤️ Inspired by Your Liked Songs`,
        promise: fetchTrackRadio(favSample.id).then(r => r.length > 0 ? r : searchSongs(`${favSample.artistName} top songs`)),
        prepend: favorites.slice(0, 3)
      });
    }

    // Task 3: Top Artist Mix
    if (topArtists.length > 0) {
      const primaryArtist = topArtists[0];
      queryTasks.push({
        title: `🎧 Best of ${primaryArtist}`,
        promise: searchSongs(`${primaryArtist} top hits songs`)
      });
    }

    // Task 4: Secondary Seed Song Radio
    if (historyTracks.length > 1) {
      const seedTrack = historyTracks[1];
      const cleanTitle = cleanSongTitle(seedTrack.title);
      queryTasks.push({
        title: `⚡ Radio Based on "${cleanTitle}"`,
        promise: fetchTrackRadio(seedTrack.id).then(r => r.length > 0 ? r : searchSongs(`${cleanTitle} audio songs`))
      });
    }

    // Task 5: Diverse Curated Global & Mood Categories
    const diverseCategories = [
      { title: "🔥 Today's Top Hits", query: 'global top hits music songs' },
      { title: '⚡ Global Viral 50', query: 'viral hits music songs' },
      { title: '🎧 Pop & Hip-Hop Essentials', query: 'pop hip hop hits songs' },
      { title: '❤️ Romantic Melodies', query: 'romantic love songs hits' },
      { title: '🌙 Late Night Lo-Fi & Chill', query: 'chill lofi beats relaxing songs' },
      { title: '⚡ Workout & High Energy', query: 'workout gym motivation songs' },
    ];

    diverseCategories.forEach(cat => {
      queryTasks.push({
        title: cat.title,
        promise: searchSongs(cat.query)
      });
    });

    // Execute queries in parallel
    const results = await Promise.allSettled(queryTasks.map(t => t.promise));

    const sections = [];
    queryTasks.forEach((task, idx) => {
      if (results[idx].status === 'fulfilled' && results[idx].value) {
        const rawTracks = task.prepend ? [...task.prepend, ...results[idx].value] : results[idx].value;
        const section = createSection(task.title, rawTracks);
        if (section) sections.push(section);
      }
    });

    // Build Quick Picks (6 items for Jump Back In)
    const quickPickCandidates = [];
    const qpSeen = new Set();
    [...historyTracks, ...favorites].forEach(t => {
      if (t && t.id && !qpSeen.has(t.id) && isValidAudioSong(t)) {
        qpSeen.add(t.id);
        quickPickCandidates.push(t);
      }
    });

    // If new user has fewer than 6, fill from first section
    if (quickPickCandidates.length < 6 && sections.length > 0) {
      sections[0].tracks.forEach(t => {
        if (quickPickCandidates.length < 6 && !qpSeen.has(t.id)) {
          qpSeen.add(t.id);
          quickPickCandidates.push(t);
        }
      });
    }

    const quickPicks = quickPickCandidates.slice(0, 6);
    const feed = { quickPicks, sections };

    // Save cache locally for instant startup
    if (typeof localStorage !== 'undefined') {
      try {
        localStorage.setItem('DOLCE_HOME_FEED_V3', JSON.stringify(feed));
      } catch (_) {}
    }

    return feed;
  } catch (e) {
    console.error('Failed to build personalized home feed:', e);
    return { quickPicks: [], sections: [] };
  }
}
