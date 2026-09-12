import Dexie from 'dexie';

export const db = new Dexie('DolceMusicDB');

db.version(2).stores({
  favorites: 'id, title, artistName, artworkUrl, addedAt',
  downloads: 'id, title, artistName, artworkUrl, downloadedAt',
  history: '++id, trackId, title, artistName, playedAt',
  playlists: 'id, name, createdAt',
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
    await db.downloads.put({
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      artworkUrl: track.artworkUrl,
      duration: track.duration || '3:45',
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

// ─── History & Playlists ───
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
    console.error('Failed to record history:', e);
  }
}
