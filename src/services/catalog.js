import { Capacitor, CapacitorHttp } from '@capacitor/core';

async function customFetch(url, options = {}) {
  const method = options.method || 'GET';
  const headers = options.headers || {};
  let body = options.body;

  if (Capacitor.isNativePlatform()) {
    try {
      let data = body;
      if (typeof body === 'string') {
        const contentType = headers['Content-Type'] || headers['content-type'] || '';
        if (contentType.includes('application/json')) {
          try { data = JSON.parse(body); } catch (_) {}
        }
      }

      const response = await CapacitorHttp.request({
        url,
        method,
        headers,
        data,
      });

      return {
        ok: response.status >= 200 && response.status < 300,
        status: response.status,
        json: async () => (typeof response.data === 'string' ? JSON.parse(response.data) : response.data),
        text: async () => (typeof response.data === 'string' ? response.data : JSON.stringify(response.data)),
      };
    } catch (e) {
      console.warn('⚡ [CapacitorHttp] Native fetch error, falling back to fetch:', e);
    }
  }

  return fetch(url, options);
}

/**
 * DOLCE Audio Catalog & Search Service.
 * Eliminates video junk files, validates HD covers, and supports multi-category search (Songs, Albums, Playlists, Artists).
 */

function isUnwantedVideoItem(title, artist) {
  if (!title) return true;
  const lowerTitle = title.toLowerCase();
  const lowerArtist = (artist || '').toLowerCase();

  // 🚫 REJECT Unofficial DJ / Fan Channel uploads (e.g., "DJ Kawal", "Shubhadip Dey")
  if (lowerArtist.startsWith('dj ') || lowerArtist.includes(' dj') || lowerArtist.includes('dj ') || lowerArtist === 'dj') {
    if (!lowerArtist.includes('snake') && !lowerArtist.includes('khaled')) {
      return true;
    }
  }

  // 🚫 REJECT Fan mashups (e.g., "Raabta x Tum Ho Toh")
  if (lowerTitle.includes(' x ') || lowerTitle.includes(' × ') || lowerTitle.includes(' X ')) {
    return true;
  }

  if (lowerArtist === 'video' || lowerArtist.startsWith('video') || lowerArtist.includes('video •')) {
    return true;
  }
  if (lowerTitle === 'video' || lowerTitle.startsWith('video') || lowerTitle.includes('video •')) {
    return true;
  }

  // 🚫 REJECT Podcast / Episode items
  if (lowerArtist === 'episode' || lowerArtist.startsWith('episode') || lowerArtist.includes('episode •') || lowerArtist.includes('podcast')) {
    return true;
  }
  if (lowerTitle === 'episode' || lowerTitle.startsWith('episode') || lowerTitle.includes('episode •') || lowerTitle.includes('podcast')) {
    return true;
  }

  const junkKeywords = [
    'mashup',
    'mash up',
    'remix',
    're-mix',
    'bootleg',
    'slowed',
    'reverb',
    '8d',
    '3d audio',
    'fan edit',
    'fan cover',
    'cover song',
    'dance cover',
    'lofi remix',
    'status video',
    'whatsapp status',
    'instagram status',
    'reels',
    'shorts',
    'reaction',
    'full movie',
    'vlog',
    'teaser',
    'trailer',
    'gameplay',
    'review',
    'tutorial',
    'behind the scenes',
    'making of',
    'bloopers',
    'funny moments',
    'tiktok',
    'full video song',
    'official video song',
    'lyric video',
    'video song',
    'full episode',
    'podcast episode',
    'episode'
  ];

  for (const kw of junkKeywords) {
    if (lowerTitle.includes(kw) || lowerArtist.includes(kw)) {
      return true;
    }
  }

  return false;
}

function cleanSongTitle(rawTitle) {
  if (!rawTitle) return '';
  return rawTitle
    .replace(/[\(\[]\s*(official\s*(music\s*)?video|official\s*audio|lyric\s*video|full\s*video(\s*song)?|4k|8k|hd|video|audio)\s*[\)\]]/gi, '')
    .replace(/official\s*(music\s*)?video/gi, '')
    .replace(/full\s*video\s*song/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function isValidAudioSong(track) {
  if (!track || !track.id || !track.title) return false;
  if (!track.artworkUrl || typeof track.artworkUrl !== 'string' || track.artworkUrl.trim() === '') return false;
  if (track.artworkUrl.includes('null') || track.artworkUrl.includes('undefined')) return false;

  const lowerArtist = (track.artistName || '').toLowerCase();
  if (lowerArtist === 'video' || lowerArtist.startsWith('video') || lowerArtist.includes('video •')) return false;
  if (lowerArtist === 'episode' || lowerArtist.startsWith('episode') || lowerArtist.includes('episode •') || lowerArtist.includes('podcast')) return false;

  if (isUnwantedVideoItem(track.title, track.artistName)) return false;
  return true;
}

/**
 * Searches songs catalog using DOLCE Gateway with Lyric Matching & Multi-pass resolution.
 * Finds pure audio songs by title, artist, AND matching lyric lines.
 */
export async function searchSongs(query) {
  const result = await searchCatalog(query);
  return result.songs || [];
}

async function fetchYtMusicSearch(query) {
  const apiKey = import.meta.env.VITE_DOLCE_SERVICE_KEY || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const body = JSON.stringify({
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20260526.04.00',
        gl: 'IN',
        hl: 'en'
      }
    },
    query: query
  });
  const headers = { 'Content-Type': 'application/json' };

  // 1. Direct YouTube Music API (Instant 200 OK for Android Capacitor APK via native CapacitorHttp)
  try {
    const res1 = await customFetch(`https://music.youtube.com/youtubei/v1/search?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res1.ok) {
      const json = await res1.json();
      if (json) return json;
    }
  } catch (_) {}

  // 2. Relative gateway proxy (Vite dev server)
  try {
    const res2 = await customFetch(`/api/gateway/youtubei/v1/search?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res2.ok) {
      const json = await res2.json();
      if (json) return json;
    }
  } catch (_) {}

  return null;
}

async function fetchYtMusicBrowse(browseId) {
  const apiKey = import.meta.env.VITE_DOLCE_SERVICE_KEY || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const body = JSON.stringify({
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20260526.04.00',
        gl: 'IN',
        hl: 'en'
      }
    },
    browseId: browseId
  });
  const headers = { 'Content-Type': 'application/json' };

  try {
    const res1 = await customFetch(`https://music.youtube.com/youtubei/v1/browse?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res1.ok) {
      const json = await res1.json();
      if (json) return json;
    }
  } catch (_) {}

  try {
    const res2 = await customFetch(`/api/gateway/youtubei/v1/browse?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res2.ok) {
      const json = await res2.json();
      if (json) return json;
    }
  } catch (_) {}

  return null;
}

/**
 * Multi-Category Search Engine (Songs, Albums, Playlists, Artists).
 */
export async function searchCatalog(query) {
  if (!query || !query.trim()) {
    return { songs: [], albums: [], playlists: [], artists: [] };
  }

  const cleanQuery = query.trim();

  const tracksMap = new Map();
  const albumsMap = new Map();
  const playlistsMap = new Map();
  const artistsMap = new Map();

  const parseInnerTubeContents = (data) => {
    const contents = data?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents;
    if (!contents) return;

    function findItems(obj) {
      if (!obj || typeof obj !== 'object') return;
      if (obj.musicResponsiveListItemRenderer) {
        const r = obj.musicResponsiveListItemRenderer;
        const videoId = r.playlistItemData?.videoId || 
                        r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
                        r.navigationEndpoint?.watchEndpoint?.videoId;
        const navEndpoint = r.navigationEndpoint || r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint;
        const browseId = navEndpoint?.browseEndpoint?.browseId;

        const rawTitle = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const runs = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const subtitle = runs.map(x => x.text).join('').trim();
        let artist = runs[0]?.text || 'Artist';

        const lowerSub = subtitle.toLowerCase();
        const lowerArtist0 = (runs[0]?.text || '').toLowerCase();

        // 🚫 STRICTLY REJECT VIDEO & EPISODE / PODCAST ITEMS
        if (
          lowerArtist0 === 'video' || lowerSub === 'video' || lowerSub.startsWith('video') || lowerSub.includes('video •') ||
          lowerArtist0 === 'episode' || lowerSub === 'episode' || lowerSub.startsWith('episode') || lowerSub.includes('episode •') || lowerSub.includes('podcast')
        ) {
          return;
        }

        if (artist.toLowerCase() === 'song') {
          artist = runs[2]?.text || runs[1]?.text || 'Artist';
        }

        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawUrl = thumbs?.[thumbs.length - 1]?.url;
        const hdArtwork = getHDArtworkUrl(rawUrl, videoId);

        if (rawTitle && isUnwantedVideoItem(rawTitle, artist)) return;

        // 1. Artist
        if (lowerSub.includes('artist') && browseId && !artistsMap.has(browseId)) {
          artistsMap.set(browseId, {
            id: browseId,
            name: rawTitle,
            subtitle: subtitle,
            artworkUrl: hdArtwork,
          });
        }
        // 2. Album / Single / EP
        else if ((lowerSub.includes('album') || lowerSub.includes('single') || lowerSub.includes('ep')) && browseId && !albumsMap.has(browseId)) {
          albumsMap.set(browseId, {
            id: browseId,
            title: rawTitle,
            artistName: artist,
            subtitle: subtitle,
            artworkUrl: hdArtwork,
          });
        }
        // 3. Playlist
        else if (lowerSub.includes('playlist') && browseId && !playlistsMap.has(browseId)) {
          playlistsMap.set(browseId, {
            id: browseId,
            title: rawTitle,
            author: artist,
            subtitle: subtitle,
            artworkUrl: hdArtwork,
          });
        }
        // 4. Song / Track
        else if (videoId && rawTitle && !tracksMap.has(videoId)) {
          const title = cleanSongTitle(rawTitle);
          const track = {
            id: videoId,
            title: title,
            artistName: artist,
            artworkUrl: hdArtwork,
            duration: '3:45',
            durationMs: 225000,
          };
          if (isValidAudioSong(track)) {
            tracksMap.set(videoId, track);
          }
        }
      }

      for (const key in obj) {
        if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
          findItems(obj[key]);
        }
      }
    }

    findItems(contents);
  };

  // Concurrent Fetch: Multi-Pass YouTube Music Search + LrcLib Lyric Match Search
  const [ytData, lrcResult] = await Promise.allSettled([
    fetchYtMusicSearch(cleanQuery),
    customFetch(`https://lrclib.net/api/search?q=${encodeURIComponent(cleanQuery)}`).then(r => r.ok ? r.json() : null)
  ]);

  if (ytData.status === 'fulfilled' && ytData.value) {
    parseInnerTubeContents(ytData.value);
  }

  // Backup search if initial pass returned few songs
  if (tracksMap.size < 5) {
    try {
      const backupData = await fetchYtMusicSearch(`${cleanQuery} songs`);
      if (backupData) parseInnerTubeContents(backupData);
    } catch (_) {}
  }

  // Process LrcLib Lyric Matches for additional song tracks
  if (lrcResult.status === 'fulfilled' && Array.isArray(lrcResult.value) && lrcResult.value.length > 0) {
    const lyricMatches = lrcResult.value.slice(0, 5);
    for (const match of lyricMatches) {
      if (match.trackName && match.artistName) {
        const q = `${match.trackName} ${match.artistName}`;
        try {
          const matchData = await fetchYtMusicSearch(q);
          if (matchData) parseInnerTubeContents(matchData);
        } catch (_) {}
      }
    }
  }

  return {
    songs: Array.from(tracksMap.values()).filter(isValidAudioSong),
    albums: Array.from(albumsMap.values()),
    playlists: Array.from(playlistsMap.values()),
    artists: Array.from(artistsMap.values()),
  };
}

/**
 * Fetches tracklist for an Album or Playlist by browseId.
 */
export async function fetchCollectionTracks(browseId) {
  if (!browseId) return [];

  try {
    const data = await fetchYtMusicBrowse(browseId);
    if (!data) return [];

    const tracks = [];

    function findTracks(obj) {
      if (!obj || typeof obj !== 'object') return;
      if (obj.musicResponsiveListItemRenderer) {
        const r = obj.musicResponsiveListItemRenderer;
        const videoId = r.playlistItemData?.videoId || 
                        r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
                        r.navigationEndpoint?.watchEndpoint?.videoId;
        const rawTitle = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const runs = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const subtitle = runs.map(x => x.text).join('').trim();
        let artist = runs[0]?.text || 'Artist';

        const lowerSub = subtitle.toLowerCase();
        const lowerArtist0 = (runs[0]?.text || '').toLowerCase();
        if (
          lowerArtist0 === 'video' || lowerSub === 'video' || lowerSub.startsWith('video') || lowerSub.includes('video •') ||
          lowerArtist0 === 'episode' || lowerSub === 'episode' || lowerSub.startsWith('episode') || lowerSub.includes('episode •') || lowerSub.includes('podcast')
        ) {
          return;
        }

        if (artist.toLowerCase() === 'song') {
          artist = runs[2]?.text || runs[1]?.text || 'Artist';
        }

        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawUrl = thumbs?.[thumbs.length - 1]?.url;

        if (videoId && rawTitle) {
          const track = {
            id: videoId,
            title: cleanSongTitle(rawTitle),
            artistName: artist,
            artworkUrl: getHDArtworkUrl(rawUrl, videoId),
            duration: '3:45',
            durationMs: 225000,
          };
          if (isValidAudioSong(track)) {
            tracks.push(track);
          }
        }
      }
      for (const key in obj) {
        if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
          findTracks(obj[key]);
        }
      }
    }

    findTracks(data);
    return tracks;
  } catch (e) {
    console.error('Failed to fetch collection tracks:', e);
    return [];
  }
}

import { getPersonalizedHomeFeed } from './recommendations';

/**
 * Fetches Home Feed curated sections powered by YouTube-style personalization & user listening history.
 */
export async function getHomeFeed() {
  try {
    const personalized = await getPersonalizedHomeFeed();
    if (personalized && personalized.length > 0) {
      return personalized;
    }
  } catch (e) {
    console.error('Personalized home feed error, falling back:', e);
  }

  const defaultCategories = [
    { title: '🔥 Trending Music Hits', query: 'top hits music songs' },
    { title: '🌧️ Rain Therapy & Chill', query: 'chill lofi beats songs' },
    { title: '⚡ Workout & Energy', query: 'workout motivation songs' },
    { title: '❤️ Romantic Melodies', query: 'romantic love songs' },
  ];

  try {
    const sections = await Promise.all(
      defaultCategories.map(async (cat) => {
        const tracks = await searchSongs(cat.query);
        const validTracks = tracks.filter(isValidAudioSong);
        return {
          title: cat.title,
          tracks: validTracks.slice(0, 10),
        };
      })
    );

    return sections.filter(s => s.tracks.length > 0);
  } catch (e) {
    console.error(`🔴 [YTMusic Service] Home feed error: ${e.message}`);
    return [];
  }
}

/**
 * Resolves direct audio stream URL for native playing.
 */
export async function getStreamUrl(videoId) {
  if (!videoId) return null;

  const invidiousNodes = [
    'https://invidious.drgns.space',
    'https://yewtu.be',
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
  ];

  for (const node of invidiousNodes) {
    try {
      const res = await fetch(`${node}/api/v1/videos/${videoId}?local=true`);
      if (res.ok) {
        const data = await res.json();
        const adaptive = data.adaptiveFormats || [];
        const audio = adaptive.filter(a => a.type?.includes('audio'));
        if (audio.length > 0) {
          audio.sort((a, b) => (parseInt(b.bitrate) || 0) - (parseInt(a.bitrate) || 0));
          return audio[0].url;
        }
      }
    } catch (_) {}
  }

  return null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

export function getHDArtworkUrl(url, videoId) {
  let hdUrl = url || '';

  if (hdUrl.includes('googleusercontent.com') || hdUrl.includes('ggpht.com')) {
    hdUrl = hdUrl.replace(/=w\d+-h\d+-[^?]+/, '=w540-h540-l90-rj');
    hdUrl = hdUrl.replace(/=w\d+-h\d+/, '=w540-h540-l90-rj');
    hdUrl = hdUrl.replace(/=s\d+-[^?]+/, '=s540-c');
    hdUrl = hdUrl.replace(/=s\d+$/, '=s540');
    return hdUrl;
  }

  if (hdUrl.includes('ytimg.com') || hdUrl.includes('youtube.com')) {
    hdUrl = hdUrl.replace(/(mqdefault|sddefault|default|hq720)\.jpg/, 'hqdefault.jpg');
    return hdUrl;
  }

  if (videoId) {
    return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
  }

  return hdUrl || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
}

function extractVideoId(url) {
  if (!url) return '';
  const match = url.match(/(?:v=|\/embed\/|\/watch\?v=|\/)([\w-]{11})/);
  return match ? match[1] : url.replace('/watch?v=', '');
}

function formatDurationSeconds(seconds) {
  if (!seconds || isNaN(seconds)) return '3:30';
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}

