import { db, getRecentHistory, getTopArtistsFromHistory } from './db.js';
import {
  fetchTrackRadio,
  fetchCollectionTracks,
  fetchBrowseHomeSections,
  searchSongs,
  isValidAudioSong,
} from './catalog.js';

const HOME_FEED_CACHE_KEY = 'DOLCE_HOME_FEED_V4';
const CACHE_TTL_MS = 1000 * 60 * 30; // 30 minutes

const EDITORIAL_PLAYLISTS = [
  {
    title: "Today's Top Hits",
    subtitle: 'Global Pop & Chartbusters',
    category: 'charts',
    browseId: 'VLRDCLAK5uy_nmS3YoxSwVVQk9lEQJ0UX4ZCjXsW_psU8',
  },
  {
    title: 'Tollywood Hitlist',
    subtitle: 'Top Telugu Trending Hits',
    category: 'telugu',
    browseId: 'VLRDCLAK5uy_lyVnWI5JnuwKJiuE-n1x-Un0mj9WlEyZw',
  },
  {
    title: 'Bollywood Hitlist',
    subtitle: 'Hottest Hindi Chart Toppers',
    category: 'hindi',
    browseId: 'VLRDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g',
  },
  {
    title: 'Lofi Loft & Chill',
    subtitle: 'Late Night Beats & Focus',
    category: 'chill',
    browseId: 'VLRDCLAK5uy_kb7EBi6y3GrtJri4_ZH56Ms786DFEimbM',
  },
  {
    title: 'Romantic Hindi Essentials',
    subtitle: 'Timeless Love Ballads',
    category: 'romance',
    browseId: 'VLRDCLAK5uy_ly0ZHQ7uutQ76YAUjYks4rEG9dOhL9Rfw',
  },
  {
    title: 'Workout & High Energy',
    subtitle: 'High-BPM Gym Anthems',
    category: 'workout',
    browseId: 'VLRDCLAK5uy_m-YJyz6cquN8dHWwbuwWJpoY7gC2dSaVo',
  },
  {
    title: 'Pop Hits 2025',
    subtitle: 'Fresh Pop Favorites',
    category: 'charts',
    browseId: 'VLRDCLAK5uy_mmJfIyWtaX2HEYZlnsdRFW-5vUnodSa-U',
  },
];

function dedupeTracks(tracks = []) {
  const seen = new Set();
  const out = [];
  for (const t of tracks) {
    if (!t || !t.id || seen.has(t.id)) continue;
    if (!isValidAudioSong(t)) continue;
    seen.add(t.id);
    out.push(t);
  }
  return out;
}

export function clearHomeFeedCache() {
  try {
    localStorage.removeItem(HOME_FEED_CACHE_KEY);
  } catch (_) {}
}

/**
 * Generates Spotify-equal personalized Home Feed:
 * - Quick Picks combining recent user taste + YTM `FEmusic_home`
 * - Track-Radio personalized mixes ("More Like X", "This Is Y")
 * - New Albums & Singles from YTM `FEmusic_explore`
 * - Curated Official YTM Editorial Playlists (`VLRDCLAK5uy_...`) categorized by vibe/language
 */
export async function getPersonalizedHomeFeed() {
  let favorites = [];
  let recentHistory = [];
  let topArtists = [];

  try {
    [favorites, recentHistory, topArtists] = await Promise.all([
      db.favorites.orderBy('addedAt').reverse().limit(12).toArray().catch(() => []),
      getRecentHistory(16).catch(() => []),
      getTopArtistsFromHistory(3).catch(() => []),
    ]);
  } catch (_) {}

  // Build seed tracks for personalized Song Radio shelves
  const seedCandidates = dedupeTracks([...favorites, ...recentHistory]);
  const seedTrack1 = seedCandidates[0] || null;
  const seedTrack2 = seedCandidates.find(
    (t) => t.id !== seedTrack1?.id && t.artistName !== seedTrack1?.artistName
  ) || seedCandidates[1] || null;
  const primaryArtist = topArtists[0] || '';

  const personalizationTasks = [];

  if (seedTrack1) {
    personalizationTasks.push({
      title: `More Like ${seedTrack1.title}`,
      subtitle: `Inspired by ${seedTrack1.artistName}`,
      category: 'made_for_you',
      promise: fetchTrackRadio(seedTrack1.id),
    });
  }

  if (seedTrack2) {
    personalizationTasks.push({
      title: 'Inspired by Your Listening',
      subtitle: `Starring ${seedTrack2.artistName} & similar artists`,
      category: 'made_for_you',
      promise: fetchTrackRadio(seedTrack2.id),
    });
  }

  if (primaryArtist) {
    personalizationTasks.push({
      title: `This Is ${primaryArtist}`,
      subtitle: 'Essential tracks & features',
      category: 'made_for_you',
      promise: searchSongs(primaryArtist).then((list) => {
        const lowerA = primaryArtist.toLowerCase();
        const own = list.filter((t) => (t.artistName || '').toLowerCase().includes(lowerA));
        return own.length >= 4 ? own : list;
      }),
    });
  }

  const [browseRes, personalResults, editorialResults] = await Promise.all([
    fetchBrowseHomeSections().catch(() => ({ quickPicks: [], newAlbums: [] })),
    Promise.allSettled(personalizationTasks.map((t) => t.promise)),
    Promise.allSettled(EDITORIAL_PLAYLISTS.map((p) => fetchCollectionTracks(p.browseId))),
  ]);

  const sections = [];

  // 1. Insert Personalized "Made For You" shelves first when user has history/favorites
  personalResults.forEach((res, idx) => {
    if (res.status === 'fulfilled' && Array.isArray(res.value)) {
      const tracks = dedupeTracks(res.value).slice(0, 18);
      if (tracks.length >= 4) {
        sections.push({
          title: personalizationTasks[idx].title,
          subtitle: personalizationTasks[idx].subtitle,
          category: personalizationTasks[idx].category,
          tracks,
        });
      }
    }
  });

  // 2. Insert Official Editorial Playlists cleanly categorized
  editorialResults.forEach((res, idx) => {
    if (res.status === 'fulfilled' && Array.isArray(res.value)) {
      const tracks = dedupeTracks(res.value).slice(0, 20);
      if (tracks.length > 0) {
        sections.push({
          title: EDITORIAL_PLAYLISTS[idx].title,
          subtitle: EDITORIAL_PLAYLISTS[idx].subtitle,
          category: EDITORIAL_PLAYLISTS[idx].category,
          browseId: EDITORIAL_PLAYLISTS[idx].browseId,
          tracks,
        });
      }
    }
  });

  // 3. Also include YTM live Quick Picks as a browsable shelf if user has lots of local history
  const browseQuickPicks = dedupeTracks(browseRes?.quickPicks || []);
  const quickPicks = dedupeTracks([
    ...recentHistory.slice(0, 3),
    ...favorites.slice(0, 2),
    ...browseQuickPicks,
    ...(sections.find((s) => s.category === 'charts')?.tracks || []),
  ]).slice(0, 6);

  if (browseQuickPicks.length >= 6 && (recentHistory.length > 0 || favorites.length > 0)) {
    sections.splice(Math.min(1, sections.length), 0, {
      title: 'Quick Picks For Today',
      subtitle: 'Fresh studio tracks picked right now',
      category: 'made_for_you',
      tracks: browseQuickPicks.slice(0, 18),
    });
  }

  const feed = {
    quickPicks,
    newAlbums: browseRes?.newAlbums || [],
    sections,
    timestamp: Date.now(),
  };

  // Persist fresh feed cache if valid
  if (feed.sections.length > 0 || feed.quickPicks.length > 0) {
    try {
      localStorage.setItem(HOME_FEED_CACHE_KEY, JSON.stringify(feed));
    } catch (_) {}
  } else {
    // Fallback to unexpired cache if temporarily offline
    try {
      const cached = localStorage.getItem(HOME_FEED_CACHE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached);
        if (parsed && (Date.now() - (parsed.timestamp || 0) < CACHE_TTL_MS || parsed.sections?.length > 0)) {
          return parsed;
        }
      }
    } catch (_) {}
  }

  return feed;
}
