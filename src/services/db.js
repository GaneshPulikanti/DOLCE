import Dexie from 'dexie';
import { fetchLyrics } from './lyrics';

export const db = new Dexie('DolceMusicDB');

db.version(4).stores({
  favorites: 'id, title, artistName, artworkUrl, addedAt',
  downloads: 'id, title, artistName, artworkUrl, downloadedAt',
  history: '++id, trackId, title, artistName, playedAt',
  playlists: 'id, name, createdAt',
  recent_searches: 'query, searchedAt',
});

// ─── Favorites ───
export async function toggleFavorite(track) {
  if (!track || !track.id) return false;
  const existing = await db.favorites.get(track.id);
  if (existing) {
    await db.favorites.delete(track.id);
    return false;
  } else {
    await db.favorites.put({
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      artworkUrl: track.artworkUrl,
      duration: track.duration,
      addedAt: Date.now(),
    });
    return true;
  }
}

export async function isFavorite(trackId) {
  if (!trackId) return false;
  const item = await db.favorites.get(trackId);
  return !!item;
}

// ─── Offline Local Downloads ───
export async function downloadTrackLocally(track) {
  if (!track || !track.id) return false;
  const existing = await db.downloads.get(track.id);
  if (existing) {
    await db.downloads.delete(track.id);
    return false;
  } else {
    // Pre-fetch lyrics to save completely offline
    const lyricsData = await fetchLyrics(track.title, track.artistName);
    await db.downloads.put({
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      artworkUrl: track.artworkUrl,
      duration: track.duration || '3:45',
      lyrics: lyricsData,
      downloadedAt: Date.now(),
    });
    return true;
  }
}

export async function isDownloadedLocally(trackId) {
  if (!trackId) return false;
  const item = await db.downloads.get(trackId);
  return !!item;
}

export async function getDownloadedTracks() {
  return await db.downloads.orderBy('downloadedAt').reverse().toArray();
}

// ─── Custom Playlists ───
export async function getUserPlaylists() {
  const list = await db.playlists.orderBy('createdAt').reverse().toArray();
  return list.map(p => ({
    ...p,
    tracks: p.tracks || []
  }));
}

export async function createPlaylist(name, initialTrack = null) {
  if (!name || !name.trim()) return null;
  const id = `pl_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
  const tracks = initialTrack ? [initialTrack] : [];
  const newPl = {
    id,
    name: name.trim(),
    tracks,
    createdAt: Date.now(),
  };
  await db.playlists.put(newPl);
  return newPl;
}

export async function addTrackToPlaylist(playlistId, track) {
  if (!playlistId || !track || !track.id) return false;
  const playlist = await db.playlists.get(playlistId);
  if (!playlist) return false;

  const tracks = playlist.tracks || [];
  if (!tracks.some(t => t.id === track.id)) {
    tracks.push(track);
    await db.playlists.update(playlistId, { tracks });
  }
  return true;
}

export async function removeTrackFromPlaylist(playlistId, trackId) {
  if (!playlistId || !trackId) return false;
  const playlist = await db.playlists.get(playlistId);
  if (!playlist) return false;

  const tracks = (playlist.tracks || []).filter(t => t.id !== trackId);
  await db.playlists.update(playlistId, { tracks });
  return true;
}

// ─── History ───
export async function recordHistory(track) {
  if (!track || !track.id) return;
  try {
    await db.history.add({
      trackId: track.id,
      title: track.title,
      artistName: track.artistName,
      artworkUrl: track.artworkUrl,
      playedAt: Date.now(),
    });
  } catch (e) {
  }
}

export async function getRecentHistory(limit = 20) {
  try {
    const list = await db.history.orderBy('playedAt').reverse().limit(limit).toArray();
    // Unique by trackId
    const seen = new Set();
    const unique = [];
    for (const item of list) {
      if (!seen.has(item.trackId)) {
        seen.add(item.trackId);
        unique.push({
          id: item.trackId,
          title: item.title,
          artistName: item.artistName,
          artworkUrl: item.artworkUrl,
          duration: item.duration || '3:45',
        });
      }
    }
    return unique;
  } catch (e) {
    console.error('Failed to get recent history:', e);
    return [];
  }
}

export async function getTopArtistsFromHistory(limit = 5) {
  try {
    const history = await db.history.orderBy('playedAt').reverse().limit(50).toArray();
    const counts = {};
    for (const item of history) {
      if (!item.artistName || item.artistName.toLowerCase() === 'artist') continue;
      // Clean artist name (e.g. split multi-artists)
      const primaryArtist = item.artistName.split(',')[0].split('&')[0].trim();
      counts[primaryArtist] = (counts[primaryArtist] || 0) + 1;
    }
    const sorted = Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .map(([artist]) => artist);
    return sorted.slice(0, limit);
  } catch (e) {
    return [];
  }
}

// ─── Recent Searches ───
export async function addRecentSearch(query) {
  if (!query || !query.trim()) return;
  const clean = query.trim();
  try {
    await db.recent_searches.put({
      query: clean,
      searchedAt: Date.now(),
    });
  } catch (e) {
    console.error('Failed to record search:', e);
  }
}

export async function getRecentSearches(limit = 6) {
  try {
    const list = await db.recent_searches.orderBy('searchedAt').reverse().limit(limit).toArray();
    return list.map(item => item.query);
  } catch (e) {
    return [];
  }
}

export async function clearRecentSearches() {
  try {
    await db.recent_searches.clear();
  } catch (e) {}
}
