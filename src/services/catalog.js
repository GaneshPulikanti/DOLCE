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

function isDevotionalTerm(text) {
  if (!text) return false;
  const lower = text.toLowerCase();
  const devTerms = [
    'bhajan', 'bhajans', 'aarti', 'chalisa', 'stotram', 'stotra', 
    'mantra', 'suprabhatam', 'devotional', 'kirtan', 'amritwani', 
    'sloka', 'shlokam', 'bhakti', 'stuti', 'jaap'
  ];
  return devTerms.some(t => lower.includes(t));
}

function isUnwantedVideoItem(title, artist, queryContext = '') {
  if (!title) return true;
  const lowerTitle = title.toLowerCase();
  const lowerArtist = (artist || '').toLowerCase();
  const lowerQuery = (queryContext || '').toLowerCase();

  // Strict devotional isolation: only reject devotional songs if user query is not devotional
  const isDevotionalContext = isDevotionalTerm(lowerQuery) || lowerQuery.includes('god') || lowerQuery.includes('bhakti');
  if (!isDevotionalContext) {
    if (isDevotionalTerm(lowerTitle) || isDevotionalTerm(lowerArtist)) {
      return true;
    }
  }

  // Reject placeholder channels
  if (lowerArtist === 'video' || lowerArtist === 'videos' || lowerArtist === 'episode' || lowerArtist === 'podcast') {
    return true;
  }

  // Reject non-music video content & low-quality fan uploads
  const junkKeywords = [
    'official trailer',
    'trailer',
    'official teaser',
    'teaser',
    'full movie',
    'movie scene',
    'comedy scene',
    'reaction',
    'movie review',
    'gameplay',
    'walkthrough',
    'tutorial',
    'behind the scenes',
    'making of',
    'bloopers',
    'funny moments',
    'status video',
    'whatsapp status',
    'instagram reels',
    'tiktok',
    'vlog',
    'podcast episode',
    'full episode',
    'cut song',
    'ringtone',
    'ring tone'
  ];

  for (const kw of junkKeywords) {
    if (lowerTitle.includes(kw)) {
      return true;
    }
  }

  // Reject fan edits, karaoke, slowed+reverb, 8D, smashups unless explicitly queried
  const conditionalJunk = [
    { kw: 'slowed', allowIf: ['slowed', 'reverb', 'lofi'] },
    { kw: 'reverb', allowIf: ['slowed', 'reverb', 'lofi'] },
    { kw: 'sped up', allowIf: ['sped up', 'nightcore'] },
    { kw: 'nightcore', allowIf: ['nightcore', 'sped up'] },
    { kw: 'karaoke', allowIf: ['karaoke', 'instrumental'] },
    { kw: '8d audio', allowIf: ['8d'] },
    { kw: '8d', allowIf: ['8d'] },
    { kw: 'bass boosted', allowIf: ['bass'] },
    { kw: '1 hour', allowIf: ['1 hour', 'hour'] },
    { kw: 'tribute to', allowIf: ['tribute'] },
    { kw: 'concert', allowIf: ['concert', 'live'] }
  ];

  for (const { kw, allowIf } of conditionalJunk) {
    if (lowerTitle.includes(kw) && !allowIf.some(a => lowerQuery.includes(a))) {
      return true;
    }
  }

  if ((lowerTitle.includes(' x ') || lowerTitle.includes(' × ')) && !lowerQuery.includes(' x ') && !lowerQuery.includes('mashup')) {
    return true;
  }

  return false;
}

function parseDurationMeta(durText) {
  if (!durText || typeof durText !== 'string') {
    return { duration: '3:30', durationMs: 210000 };
  }
  const clean = durText.trim();
  const parts = clean.split(':').map(n => parseInt(n, 10));
  if (parts.some(isNaN)) {
    return { duration: '3:30', durationMs: 210000 };
  }
  let seconds = 0;
  if (parts.length === 2) seconds = parts[0] * 60 + parts[1];
  else if (parts.length === 3) seconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
  return {
    duration: clean,
    durationMs: (seconds || 210) * 1000
  };
}

function extractDurationFromRuns(runs = []) {
  for (let i = runs.length - 1; i >= 0; i--) {
    const t = (runs[i]?.text || '').trim();
    if (/^\d{1,2}:\d{2}(:\d{2})?$/.test(t)) {
      return parseDurationMeta(t);
    }
  }
  return { duration: '3:30', durationMs: 210000 };
}

export function cleanSongTitle(rawTitle) {
  if (!rawTitle) return '';
  let title = rawTitle;

  // 1. Remove hashtags (#shorts, #trending, etc.)
  title = title.replace(/#\S+/g, '');

  // 2. Remove (From "Movie") or [From "Movie"]
  title = title.replace(/[\(\[]\s*From\s*["“][^"”]+["”]\s*[\)\]]/gi, '');

  // 3. Remove parenthesized/bracketed video descriptors
  title = title.replace(/[\(\[]\s*(official\s*(music\s*)?(video|audio)|lyric(al)?\s*video|full\s*(video|audio)(\s*song)?|video\s*song|audio\s*song|4k|8k|hd|ultra\s*hd|remastered|visualizer|extended|special\s*version)\s*[\)\]]/gi, '');

  // 4. Remove trailing suffixes like " - Full Video ...", " - Official Video", etc.
  title = title.replace(/\s*[-–|:]\s*(full\s*)?(official\s*)?(music\s*)?(video|audio|lyric|lyrical)(\s*song)?\b.*/gi, '');

  // 5. If pipe delimiter exists with movie/channel info (e.g., "Song | Movie | Label"), keep the first meaningful part
  if (title.includes('|')) {
    const parts = title.split('|');
    if (parts[0].trim().length >= 2) {
      title = parts[0];
    }
  }

  // 6. Clean standalone descriptor words
  title = title
    .replace(/\bofficial\s*(music\s*)?video\b/gi, '')
    .replace(/\bfull\s*video(\s*song)?\b/gi, '')
    .replace(/\bvideo\s*song\b/gi, '')
    .replace(/\blyric(al)?\s*video\b/gi, '')
    .replace(/\b(4k|8k|ultra\s*hd)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();

  // 7. Remove trailing hyphens or colons
  title = title.replace(/[-–:]\s*$/, '').trim();

  return title || rawTitle;
}

export function isValidAudioSong(track) {
  if (!track || !track.id || !track.title) return false;
  if (!track.artworkUrl || typeof track.artworkUrl !== 'string' || track.artworkUrl.trim() === '') return false;
  if (track.artworkUrl.includes('null') || track.artworkUrl.includes('undefined')) return false;

  // Must have a valid artwork URL with genuine length
  if (track.artworkUrl.length < 15) return false;

  const lowerArtist = (track.artistName || '').toLowerCase();
  if (lowerArtist === 'video' || lowerArtist === 'episode' || lowerArtist === 'podcast') return false;

  if (isUnwantedVideoItem(track.title, track.artistName)) return false;
  return true;
}

/**
 * YouTube Music Track Radio Engine (RDAMVM Recommendation Graph).
 * Generates official 50-track Spotify-grade recommendations for any given song.
 */
const trackRadioCache = new Map();

export async function fetchTrackRadio(videoId) {
  if (!videoId) return [];
  if (trackRadioCache.has(videoId)) {
    return trackRadioCache.get(videoId);
  }

  const apiKey = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_DOLCE_SERVICE_KEY) || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20260526.04.00',
        gl: 'IN',
        hl: 'en'
      }
    },
    playlistId: `RDAMVM${videoId}`,
    isAudioOnly: true
  };
  const body = JSON.stringify(payload);
  const headers = { 'Content-Type': 'application/json' };

  let data = null;
  // 1. Direct YouTube Music API (CapacitorHttp native for Android or CORS proxy)
  try {
    const res1 = await customFetch(`https://music.youtube.com/youtubei/v1/next?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res1.ok) {
      data = await res1.json();
    }
  } catch (_) {}

  // 2. Relative gateway proxy (Vite dev server)
  if (!data) {
    try {
      const res2 = await customFetch(`/api/gateway/youtubei/v1/next?key=${apiKey}&alt=json`, {
        method: 'POST',
        headers,
        body
      });
      if (res2.ok) {
        data = await res2.json();
      }
    } catch (_) {}
  }

  if (!data) return [];

  try {
    const tabs = data?.contents?.singleColumnMusicWatchNextResultsRenderer?.tabbedRenderer?.watchNextTabbedResultsRenderer?.tabs;
    const items = tabs?.[0]?.tabRenderer?.content?.musicQueueRenderer?.content?.playlistPanelRenderer?.contents || [];

    const atvTracks = [];
    const fallbackTracks = [];
    const seenKeys = new Set();

    for (const item of items) {
      const r = item.playlistPanelVideoRenderer;
      if (!r || !r.videoId || r.videoId === videoId) continue;

      const musicVideoType = r.navigationEndpoint?.watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType || '';
      if (musicVideoType === 'MUSIC_VIDEO_TYPE_UGC' || musicVideoType === 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE') {
        continue;
      }

      const rawTitle = r.title?.runs?.[0]?.text;
      if (!rawTitle) continue;

      const artist = r.shortBylineText?.runs?.[0]?.text || r.longBylineText?.runs?.[0]?.text || 'Artist';
      const { duration, durationMs } = parseDurationMeta(r.lengthText?.runs?.[0]?.text);
      const thumbs = r.thumbnail?.thumbnails;
      const rawThumb = thumbs?.[thumbs.length - 1]?.url;
      const hdArtwork = getHDArtworkUrl(rawThumb, r.videoId);

      const title = cleanSongTitle(rawTitle);
      const dedupeKey = `${title.toLowerCase().replace(/[^a-z0-9]/g, '')}|${artist.toLowerCase().split(/[,&]/)[0].trim()}`;
      if (seenKeys.has(dedupeKey)) continue;

      const track = {
        id: r.videoId,
        title,
        artistName: artist,
        artworkUrl: hdArtwork,
        duration,
        durationMs,
        _isAtv: musicVideoType === 'MUSIC_VIDEO_TYPE_ATV',
      };

      if (isValidAudioSong(track)) {
        seenKeys.add(dedupeKey);
        if (track._isAtv) {
          atvTracks.push(track);
        } else {
          fallbackTracks.push(track);
        }
      }
    }

    // Prefer pure studio ATV audio; append clean OMV/untyped fallback only if ATV list is thin
    const tracks = atvTracks.length >= 8
      ? atvTracks
      : [...atvTracks, ...fallbackTracks];

    trackRadioCache.set(videoId, tracks);
    return tracks;
  } catch (e) {
    console.error('Failed to parse track radio:', e);
    return [];
  }
}

/**
 * YouTube Music Live Predictive Search Autocomplete Engine (like Spotify).
 * Returns instant query suggestions as the user types.
 */
const suggestionsCache = new Map();

export async function fetchSearchSuggestions(query) {
  if (!query || !query.trim() || query.trim().length < 2) return [];
  const cleanQuery = query.trim();
  const cacheKey = cleanQuery.toLowerCase();

  if (suggestionsCache.has(cacheKey)) {
    return suggestionsCache.get(cacheKey);
  }

  const apiKey = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_DOLCE_SERVICE_KEY) || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20260526.04.00',
        gl: 'IN',
        hl: 'en'
      }
    },
    input: cleanQuery
  };
  const body = JSON.stringify(payload);
  const headers = { 'Content-Type': 'application/json' };

  let data = null;
  try {
    const res = await customFetch(`https://music.youtube.com/youtubei/v1/music/get_search_suggestions?key=${apiKey}&alt=json`, {
      method: 'POST',
      headers,
      body
    });
    if (res.ok) data = await res.json();
  } catch (_) {}

  if (!data) {
    try {
      const res2 = await customFetch(`/api/gateway/youtubei/v1/music/get_search_suggestions?key=${apiKey}&alt=json`, {
        method: 'POST',
        headers,
        body
      });
      if (res2.ok) data = await res2.json();
    } catch (_) {}
  }

  if (!data) return [];

  try {
    const contents = data?.contents?.[0]?.searchSuggestionsSectionRenderer?.contents || [];
    const suggestions = [];
    for (const item of contents) {
      const runs = item.searchSuggestionRenderer?.suggestion?.runs || [];
      const text = runs.map(r => r.text).join('').trim();
      if (text && !suggestions.includes(text)) {
        suggestions.push(text);
      }
    }
    const result = suggestions.slice(0, 6);
    suggestionsCache.set(cacheKey, result);
    return result;
  } catch (e) {
    return [];
  }
}

/**
 * Searches songs catalog using DOLCE Gateway.
 */
export async function searchSongs(query) {
  const result = await searchCatalog(query);
  return result.songs || [];
}

async function fetchYtMusicSearch(query, params = null) {
  const apiKey = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_DOLCE_SERVICE_KEY) || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20260526.04.00',
        gl: 'IN',
        hl: 'en'
      }
    },
    query: query
  };
  if (params) {
    payload.params = params;
  }
  const body = JSON.stringify(payload);
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
  const apiKey = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_DOLCE_SERVICE_KEY) || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
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

const searchCacheMap = new Map();

function normalizeSearchKey(str) {
  return (str || '')
    .toLowerCase()
    .replace(/[\(\[][^\)\]]*[\)\]]/g, '')
    .replace(/[^a-z0-9]/g, '');
}

async function fetchItunesChartSignals(query) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 1600);
  try {
    const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=song&limit=8&country=IN`;
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return [];
    const json = await res.json();
    return Array.isArray(json?.results) ? json.results : [];
  } catch (_) {
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Multi-Category Search Engine (Songs, Albums, Playlists, Artists).
 * Combines YouTube Music filtered endpoints + Top Result card + iTunes chart signals.
 */
export async function searchCatalog(query) {
  if (!query || !query.trim()) {
    return { topResult: null, songs: [], albums: [], playlists: [], artists: [] };
  }

  const cleanQuery = query.trim();
  const cacheKey = cleanQuery.toLowerCase();

  if (searchCacheMap.has(cacheKey)) {
    return searchCacheMap.get(cacheKey);
  }

  const tracksMap = new Map();
  const albumsMap = new Map();
  const playlistsMap = new Map();
  const artistsMap = new Map();
  let parseSeq = 0;

  // Normalize query variations (e.g., "one nenokkadine" -> "1 nenokkadine", "no. 1 nenokkadine")
  const lowerQuery = cleanQuery.toLowerCase();
  const compactQuery = normalizeSearchKey(cleanQuery);
  const normalizedQuery = lowerQuery
    .replace(/\bone\b/g, '1')
    .replace(/\btwo\b/g, '2')
    .replace(/\bthree\b/g, '3')
    .replace(/\bno\.?\s*/g, '')
    .trim();

  const queryWords = lowerQuery.split(/\s+/).filter(w => w.length > 2);
  const normWords = normalizedQuery.split(/\s+/).filter(w => w.length > 2);
  const mainWords = [...new Set([...queryWords, ...normWords])];

  const extractSubtitleArtist = (runs = []) => {
    for (const run of runs) {
      const t = (run?.text || '').trim();
      const lt = t.toLowerCase();
      if (
        !t || t === '•' || t === '&' || t === ',' ||
        lt === 'song' || lt === 'single' || lt === 'ep' || lt === 'album' ||
        lt === 'playlist' || lt === 'artist' || lt === 'video' ||
        /^\d{1,2}:\d{2}(:\d{2})?$/.test(t) ||
        lt.includes('views') || lt.includes('plays') || lt.includes('listeners')
      ) {
        continue;
      }
      return t;
    }
    return 'Artist';
  };

  const parseInnerTubeContents = (data, sourceTag = 'all') => {
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
        const fixedRuns = r.fixedColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const subtitle = runs.map(x => x.text).join('').trim();
        const lowerSub = subtitle.toLowerCase();
        const lowerArtist0 = (runs[0]?.text || '').toLowerCase().trim();

        // Strictly reject video & episode / podcast items
        if (
          lowerArtist0 === 'video' || lowerSub === 'video' || lowerSub.startsWith('video') || lowerSub.includes('video •') ||
          lowerArtist0 === 'episode' || lowerSub === 'episode' || lowerSub.startsWith('episode') || lowerSub.includes('episode •') || lowerSub.includes('podcast')
        ) {
          return;
        }

        const watchEndpoint = r.playlistItemData?.watchEndpoint ||
                              r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint ||
                              r.navigationEndpoint?.watchEndpoint;
        const musicVideoType = watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType || '';

        if (musicVideoType === 'MUSIC_VIDEO_TYPE_UGC' || musicVideoType === 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE') {
          return;
        }
        // Only allow OMV if returned by the dedicated filtered Songs tab (rare official singles); prefer ATV everywhere else
        if (musicVideoType === 'MUSIC_VIDEO_TYPE_OMV' && sourceTag !== 'songs') {
          return;
        }

        // Video uploads with view counts and no song/album/plays metadata are rejected
        if (lowerSub.includes('views') && !lowerSub.includes('album') && !lowerSub.includes('song') && musicVideoType !== 'MUSIC_VIDEO_TYPE_ATV') {
          return;
        }

        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        if (!thumbs || thumbs.length === 0) return;
        const rawUrl = thumbs[thumbs.length - 1]?.url;
        if (!rawUrl || typeof rawUrl !== 'string' || rawUrl.trim() === '') return;

        const artist = extractSubtitleArtist(runs);
        const hdArtwork = getHDArtworkUrl(rawUrl, videoId);
        if (!hdArtwork || hdArtwork.length < 15) return;

        if (rawTitle && isUnwantedVideoItem(rawTitle, artist, cleanQuery)) return;

        const rank = parseSeq++;

        // 1. Artist
        if ((sourceTag === 'artists' || lowerSub.includes('artist')) && browseId && browseId.startsWith('UC') && !artistsMap.has(browseId)) {
          artistsMap.set(browseId, {
            id: browseId,
            name: rawTitle,
            subtitle: subtitle || 'Artist',
            artworkUrl: hdArtwork,
            _rank: rank,
          });
        }
        // 2. Album / Single / EP
        else if ((sourceTag === 'albums' || lowerSub.includes('album') || lowerSub.includes('single') || lowerSub.includes('ep')) && browseId && browseId.startsWith('MPREb_') && !albumsMap.has(browseId)) {
          albumsMap.set(browseId, {
            id: browseId,
            title: rawTitle,
            artistName: artist,
            subtitle: subtitle || 'Album',
            artworkUrl: hdArtwork,
            _rank: rank,
          });
        }
        // 3. Playlist
        else if ((sourceTag === 'playlists' || lowerSub.includes('playlist')) && browseId && (browseId.startsWith('VL') || browseId.startsWith('PL')) && !playlistsMap.has(browseId)) {
          playlistsMap.set(browseId, {
            id: browseId,
            title: rawTitle,
            author: artist,
            subtitle: subtitle || 'Playlist',
            artworkUrl: hdArtwork,
            _rank: rank,
          });
        }
        // 4. Song / Track
        else if (videoId && rawTitle) {
          const isAtv = musicVideoType === 'MUSIC_VIDEO_TYPE_ATV';
          const existing = tracksMap.get(videoId);
          // Upgrade existing non-ATV entry if filtered Songs tab confirms ATV
          if (existing && (!existing._isAtv && isAtv)) {
            existing._isAtv = true;
            existing._rank = Math.min(existing._rank, rank);
          } else if (!existing) {
            const title = cleanSongTitle(rawTitle);
            const { duration, durationMs } = extractDurationFromRuns([...runs, ...fixedRuns]);
            const track = {
              id: videoId,
              title,
              artistName: artist,
              artworkUrl: hdArtwork,
              duration,
              durationMs,
              _isAtv: isAtv,
              _sourceTag: sourceTag,
              _rank: rank,
            };
            if (isValidAudioSong(track)) {
              tracksMap.set(videoId, track);
            }
          }
        }
      }

      for (const key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key) && typeof obj[key] === 'object') {
          findItems(obj[key]);
        }
      }
    }

    findItems(contents);
  };

  let topResult = null;

  const parseTopCard = (data) => {
    if (topResult) return;
    const sec0 = data?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents?.[0];
    const card = sec0?.musicCardShelfRenderer;
    if (!card) return;

    const rawTitle = card.title?.runs?.[0]?.text;
    if (!rawTitle) return;
    const subtitleRuns = card.subtitle?.runs || [];
    const subtitle = subtitleRuns.map(r => r.text).join('').trim();
    const lowerSub = subtitle.toLowerCase();

    if (lowerSub.includes('episode') || lowerSub.includes('podcast')) return;

    const thumbs = card.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
    const rawThumb = thumbs?.[thumbs.length - 1]?.url;

    const watchEndpoint = card.onTap?.watchEndpoint;
    const browseEndpoint = card.onTap?.browseEndpoint;
    const cardMusicType = watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType || '';

    if (watchEndpoint?.videoId && cardMusicType !== 'MUSIC_VIDEO_TYPE_UGC') {
      const videoId = watchEndpoint.videoId;
      const artist = extractSubtitleArtist(subtitleRuns);
      const { duration, durationMs } = extractDurationFromRuns(subtitleRuns);
      const cleanTitle = cleanSongTitle(rawTitle);
      if (!isUnwantedVideoItem(cleanTitle, artist, cleanQuery)) {
        topResult = {
          id: videoId,
          title: cleanTitle,
          artistName: artist,
          subtitle,
          artworkUrl: getHDArtworkUrl(rawThumb, videoId),
          duration,
          durationMs,
          _isAtv: cardMusicType === 'MUSIC_VIDEO_TYPE_ATV',
          type: 'song',
        };
      }
    } else if (browseEndpoint?.browseId) {
      const browseId = browseEndpoint.browseId;
      const hdArtwork = getHDArtworkUrl(rawThumb);
      if (lowerSub.includes('artist')) {
        topResult = {
          id: browseId,
          name: rawTitle,
          subtitle: subtitle || 'Artist',
          artworkUrl: hdArtwork,
          type: 'artist',
        };
      } else if (lowerSub.includes('album') || lowerSub.includes('single') || lowerSub.includes('ep')) {
        topResult = {
          id: browseId,
          title: rawTitle,
          artistName: extractSubtitleArtist(subtitleRuns),
          subtitle: subtitle || 'Album',
          artworkUrl: hdArtwork,
          type: 'album',
        };
      } else if (lowerSub.includes('playlist')) {
        topResult = {
          id: browseId,
          title: rawTitle,
          author: extractSubtitleArtist(subtitleRuns),
          subtitle: subtitle || 'Playlist',
          artworkUrl: hdArtwork,
          type: 'playlist',
        };
      }
    }
  };

  // Dedicated parallel YTM Music Search + iTunes chart signal calls
  const callSpecs = [
    { tag: 'songs', promise: fetchYtMusicSearch(cleanQuery, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D') },
    { tag: 'all', promise: fetchYtMusicSearch(cleanQuery) },
    { tag: 'albums', promise: fetchYtMusicSearch(cleanQuery, 'EgWKAQIYAWoKEAkQChAFEAMQBA%3D%3D') },
    { tag: 'artists', promise: fetchYtMusicSearch(cleanQuery, 'EgWKAQIgAWoKEAkQChAFEAMQBA%3D%3D') },
    { tag: 'playlists', promise: fetchYtMusicSearch(cleanQuery, 'EgeKAQQoADgBagwQDhAKEAMQBRAJEAQ%3D') },
  ];

  if (normalizedQuery !== lowerQuery) {
    callSpecs.push({ tag: 'songs', promise: fetchYtMusicSearch(normalizedQuery, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D') });
    callSpecs.push({ tag: 'all', promise: fetchYtMusicSearch(normalizedQuery) });
  }

  const [settledYtm, itunesHits] = await Promise.all([
    Promise.allSettled(callSpecs.map(c => c.promise)),
    fetchItunesChartSignals(cleanQuery),
  ]);

  settledYtm.forEach((res, idx) => {
    if (res.status === 'fulfilled' && res.value) {
      const tag = callSpecs[idx].tag;
      if (tag === 'all') parseTopCard(res.value);
      parseInnerTubeContents(res.value, tag);
    }
  });

  // Canonical Spelling & Soundtrack Rescue:
  // If iTunes #1 hit (e.g., "Buttabomma" when searching "Butta Bomma") is missing from ATV results,
  // first inspect any matching soundtrack album already found, then fall back to YTM canonical query.
  if (itunesHits.length > 0) {
    const topHit = itunesHits[0];
    const cleanHitTitle = cleanSongTitle(topHit.trackName);
    const hitKey = normalizeSearchKey(cleanHitTitle);
    const hitArtistWord = (topHit.artistName || '').toLowerCase().split(/[\s,&]+/).find(w => w.length > 2) || '';
    const alreadyPresent = Array.from(tracksMap.values()).some(t => {
      const tKey = normalizeSearchKey(t.title);
      const aLower = (t.artistName || '').toLowerCase();
      return tKey === hitKey && (!hitArtistWord || aLower.includes(hitArtistWord));
    });

    if (!alreadyPresent && cleanHitTitle && topHit.artistName) {
      const hitAlbumClean = normalizeSearchKey(cleanSongTitle(topHit.collectionName || ''));
      const matchedAlbum = Array.from(albumsMap.values()).find(a => {
        const aNorm = normalizeSearchKey(a.title);
        return hitAlbumClean && aNorm && (aNorm.includes(hitAlbumClean) || hitAlbumClean.includes(aNorm));
      });

      let rescued = false;
      if (matchedAlbum?.id) {
        try {
          const albumTracks = await fetchCollectionTracks(matchedAlbum.id);
          for (const tr of albumTracks) {
            if (!tracksMap.has(tr.id) && normalizeSearchKey(tr.title) === hitKey) {
              tracksMap.set(tr.id, { ...tr, _isAtv: true, _sourceTag: 'songs', _rank: 0 });
              rescued = true;
            }
          }
        } catch (_) {}
      }

      if (!rescued) {
        try {
          const primaryArtist = topHit.artistName.split(/[,&]/)[0].trim();
          const rescueData = await fetchYtMusicSearch(`${cleanHitTitle} ${primaryArtist}`, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D');
          if (rescueData) parseInnerTubeContents(rescueData, 'songs');
        } catch (_) {}
      }
    }
  }

  // Build normalized iTunes popularity lookup
  const itunesChartMap = itunesHits.map((hit, idx) => ({
    rank: idx,
    normTitle: normalizeSearchKey(hit.trackName),
    artistTokens: (hit.artistName || '').toLowerCase().split(/[\s,&/]+/).filter(w => w.length > 2),
  }));

  function getItunesBoost(item) {
    if (!item.title || !item.artistName || itunesChartMap.length === 0) return 0;
    const itemTitleNorm = normalizeSearchKey(item.title);
    const itemArtistLower = item.artistName.toLowerCase();

    for (const hit of itunesChartMap) {
      const titleMatch = itemTitleNorm === hit.normTitle ||
        (hit.normTitle.length >= 3 && itemTitleNorm.includes(hit.normTitle)) ||
        (itemTitleNorm.length >= 3 && hit.normTitle.includes(itemTitleNorm));
      if (!titleMatch) continue;

      const artistOverlap = hit.artistTokens.some(tok => itemArtistLower.includes(tok));
      if (artistOverlap) {
        return (8 - hit.rank) * 5000;
      }
    }
    return 0;
  }

  function scorePriority(item) {
    let score = 0;
    const title = (item.title || item.name || '').toLowerCase();
    const compactTitle = normalizeSearchKey(title);
    const artist = (item.artistName || item.author || item.subtitle || '').toLowerCase();

    // 1. Studio ATV audio & Top Card track preference
    if (item._isAtv) score += 12000;
    if (item._sourceTag === 'all') score += 2000;

    // 2. Exact & Normalized Match Boost
    if (title === lowerQuery || title === normalizedQuery || (compactQuery && compactTitle === compactQuery)) {
      score += 50000;
    } else if (title.startsWith(lowerQuery) || (normalizedQuery && title.startsWith(normalizedQuery))) {
      score += 25000;
    } else if (title.includes(lowerQuery) || (compactQuery && compactTitle.includes(compactQuery))) {
      score += 14000;
    } else if (normalizedQuery && (title.includes(normalizedQuery) || normalizedQuery.includes(title))) {
      score += 11000;
    }

    // 3. Multi-word Match Boost
    let matchedWordsCount = 0;
    mainWords.forEach(w => {
      if (title.includes(w)) {
        matchedWordsCount++;
        score += 3000;
      } else if (artist.includes(w)) {
        matchedWordsCount++;
        score += 1500;
      }
    });
    if (mainWords.length > 1 && matchedWordsCount >= mainWords.length) {
      score += 10000;
    }

    // 4. Artist Match Boost (Strongest when user explicitly searched an Artist name)
    const searchedArtistName = topResult?.type === 'artist' ? (topResult.name || '').toLowerCase() : '';
    if (artist === lowerQuery || artist === normalizedQuery || (searchedArtistName && artist.includes(searchedArtistName))) {
      score += topResult?.type === 'artist' ? 70000 : 22000;
    } else if (artist.startsWith(lowerQuery) || (normalizedQuery && artist.startsWith(normalizedQuery))) {
      score += topResult?.type === 'artist' ? 40000 : 12000;
    } else if (artist.includes(lowerQuery) || (normalizedQuery && artist.includes(normalizedQuery))) {
      score += 4000;
    }

    // 5. Real-world chart / streaming popularity boost
    score += getItunesBoost(item);

    // 6. Small tie-break preserving YTM relevance order (higher for earlier items)
    if (typeof item._rank === 'number') {
      score += Math.max(0, 600 - item._rank * 15);
    }

    return score;
  }

  const sortByRelevance = (list) => {
    return list.sort((a, b) => {
      const scoreDiff = scorePriority(b) - scorePriority(a);
      if (scoreDiff !== 0) return scoreDiff;
      return (a._rank ?? 9999) - (b._rank ?? 9999);
    });
  };

  const stripMeta = ({ _rank, _isAtv, _sourceTag, ...rest }) => rest;

  const allSongs = sortByRelevance(Array.from(tracksMap.values()).filter(isValidAudioSong)).map(stripMeta);
  const allAlbums = sortByRelevance(Array.from(albumsMap.values())).map(stripMeta);
  const allPlaylists = sortByRelevance(Array.from(playlistsMap.values())).map(stripMeta);
  const allArtists = sortByRelevance(Array.from(artistsMap.values())).map(stripMeta);

  // If topResult is a Song (especially an OMV/video card), upgrade it to its pure ATV studio counterpart if present
  if (topResult && topResult.type === 'song') {
    const topNorm = normalizeSearchKey(topResult.title);
    const matchingAtv = allSongs.find(s => normalizeSearchKey(s.title) === topNorm &&
      (s.artistName || '').toLowerCase().includes((topResult.artistName || '').toLowerCase().split(/[,&]/)[0].trim()));
    if (matchingAtv) {
      topResult = { ...matchingAtv, subtitle: topResult.subtitle || `Song • ${matchingAtv.artistName}`, type: 'song' };
    } else {
      topResult = stripMeta(topResult);
      if (isValidAudioSong(topResult) && !allSongs.some(s => s.id === topResult.id)) {
        allSongs.unshift({
          id: topResult.id,
          title: topResult.title,
          artistName: topResult.artistName,
          artworkUrl: topResult.artworkUrl,
          duration: topResult.duration,
          durationMs: topResult.durationMs,
        });
      }
    }
  } else if (!topResult) {
    const exactArtist = allArtists.find(a => (a.name || '').toLowerCase() === lowerQuery);
    if (exactArtist) {
      topResult = { ...exactArtist, type: 'artist' };
    } else if (allSongs.length > 0) {
      topResult = { ...allSongs[0], type: 'song' };
    } else if (allAlbums.length > 0) {
      topResult = { ...allAlbums[0], type: 'album' };
    } else if (allArtists.length > 0) {
      topResult = { ...allArtists[0], type: 'artist' };
    }
  }

  const finalResult = {
    topResult,
    songs: allSongs,
    albums: allAlbums,
    playlists: allPlaylists,
    artists: allArtists,
  };

  searchCacheMap.set(cacheKey, finalResult);
  return finalResult;
}

const collectionCacheMap = new Map();

/**
 * Fetches tracklist for an Album, Artist Top Songs, or Playlist by browseId.
 * Extracts album header artwork & artist fallback so MPREb_ album tracks retain crisp square covers.
 */
export async function fetchCollectionTracks(browseId) {
  if (!browseId) return [];
  if (collectionCacheMap.has(browseId)) {
    return collectionCacheMap.get(browseId);
  }

  try {
    const data = await fetchYtMusicBrowse(browseId);
    if (!data) return [];

    // Extract collection-level artwork & artist from responsive or detail header
    const sec0 = data?.contents?.twoColumnBrowseResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents?.[0];
    const headerRenderer =
      sec0?.musicResponsiveHeaderRenderer ||
      data?.header?.musicDetailHeaderRenderer ||
      data?.header?.musicVisualHeaderRenderer ||
      data?.header?.musicImmersiveHeaderRenderer ||
      null;

    const headerThumbs =
      headerRenderer?.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails ||
      headerRenderer?.thumbnail?.croppedSquareThumbnailRenderer?.thumbnail?.thumbnails ||
      [];
    const headerRawThumb = headerThumbs[headerThumbs.length - 1]?.url || '';
    const headerArtwork = headerRawThumb ? getHDArtworkUrl(headerRawThumb) : '';

    const headerRuns =
      headerRenderer?.straplineTextOne?.runs ||
      headerRenderer?.subtitle?.runs ||
      [];
    let headerArtist = '';
    for (const run of headerRuns) {
      const t = (run?.text || '').trim();
      const lt = t.toLowerCase();
      if (t && t !== '•' && lt !== 'album' && lt !== 'single' && lt !== 'ep' && lt !== 'playlist' && !/^\d{4}$/.test(t)) {
        headerArtist = t;
        break;
      }
    }

    const tracks = [];
    const seenIds = new Set();

    function findTracks(obj) {
      if (!obj || typeof obj !== 'object') return;
      if (obj.musicResponsiveListItemRenderer) {
        const r = obj.musicResponsiveListItemRenderer;
        const videoId = r.playlistItemData?.videoId ||
                        r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
                        r.navigationEndpoint?.watchEndpoint?.videoId;
        const rawTitle = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const runs = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const fixedRuns = r.fixedColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const subtitle = runs.map(x => x.text).join('').trim();

        const lowerSub = subtitle.toLowerCase();
        const lowerArtist0 = (runs[0]?.text || '').toLowerCase().trim();
        if (
          lowerArtist0 === 'video' || lowerSub === 'video' || lowerSub.startsWith('video') || lowerSub.includes('video •') ||
          lowerArtist0 === 'episode' || lowerSub === 'episode' || lowerSub.startsWith('episode') || lowerSub.includes('episode •') || lowerSub.includes('podcast')
        ) {
          return;
        }

        const watchEndpoint = r.playlistItemData?.watchEndpoint ||
                              r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint ||
                              r.navigationEndpoint?.watchEndpoint;
        const musicVideoType = watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType || '';
        if (musicVideoType === 'MUSIC_VIDEO_TYPE_UGC' || musicVideoType === 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE') {
          return;
        }

        let artist = '';
        for (const run of runs) {
          const t = (run?.text || '').trim();
          const lt = t.toLowerCase();
          if (t && t !== '•' && lt !== 'song' && !/^\d{1,2}:\d{2}(:\d{2})?$/.test(t) && !lt.includes('plays') && !lt.includes('views')) {
            artist = t;
            break;
          }
        }
        if (!artist) artist = headerArtist || 'Artist';

        const { duration, durationMs } = extractDurationFromRuns([...runs, ...fixedRuns]);
        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawUrl = thumbs?.[thumbs.length - 1]?.url || headerRawThumb;

        if (videoId && rawTitle && !seenIds.has(videoId)) {
          const track = {
            id: videoId,
            title: cleanSongTitle(rawTitle),
            artistName: artist,
            artworkUrl: rawUrl ? getHDArtworkUrl(rawUrl, videoId) : (headerArtwork || getHDArtworkUrl('', videoId)),
            duration,
            durationMs,
          };
          if (isValidAudioSong(track)) {
            seenIds.add(videoId);
            tracks.push(track);
          }
        }
      }
      for (const key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key) && typeof obj[key] === 'object') {
          findTracks(obj[key]);
        }
      }
    }

    findTracks(data);
    if (tracks.length > 0) {
      collectionCacheMap.set(browseId, tracks);
    }
    return tracks;
  } catch (e) {
    console.error('Failed to fetch collection tracks:', e);
    return [];
  }
}

let cachedBrowseHome = null;
let cachedBrowseHomeAt = 0;

/**
 * Fetches live YouTube Music editorial Quick Picks (`FEmusic_home`) & New Albums/Singles (`FEmusic_explore`).
 */
export async function fetchBrowseHomeSections() {
  if (cachedBrowseHome && Date.now() - cachedBrowseHomeAt < 1000 * 60 * 15) {
    return cachedBrowseHome;
  }

  const [homeRes, exploreRes] = await Promise.allSettled([
    fetchYtMusicBrowse('FEmusic_home'),
    fetchYtMusicBrowse('FEmusic_explore'),
  ]);

  const quickPicks = [];
  const seenQp = new Set();
  const newAlbums = [];
  const seenAlbums = new Set();

  if (homeRes.status === 'fulfilled' && homeRes.value) {
    const sections = homeRes.value?.contents?.singleColumnBrowseResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
    for (const sec of sections) {
      const shelf = sec.musicCarouselShelfRenderer || sec.musicShelfRenderer;
      if (!shelf) continue;
      for (const item of shelf.contents || []) {
        const r = item.musicResponsiveListItemRenderer;
        if (!r) continue;
        const videoId = r.playlistItemData?.videoId ||
                        r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
        const rawTitle = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const runs = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const watchEndpoint = r.playlistItemData?.watchEndpoint ||
                              r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint;
        const mvt = watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType || '';
        if (mvt === 'MUSIC_VIDEO_TYPE_UGC' || mvt === 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE' || mvt === 'MUSIC_VIDEO_TYPE_OMV') {
          continue;
        }
        const subtitle = runs.map(x => x.text).join('').toLowerCase();
        if (subtitle.includes('views') && mvt !== 'MUSIC_VIDEO_TYPE_ATV') continue;

        let artist = 'Artist';
        for (const run of runs) {
          const t = (run?.text || '').trim();
          const lt = t.toLowerCase();
          if (t && t !== '•' && lt !== 'song' && !/^\d{1,2}:\d{2}/.test(t) && !lt.includes('plays')) {
            artist = t;
            break;
          }
        }
        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawUrl = thumbs?.[thumbs.length - 1]?.url;
        const { duration, durationMs } = extractDurationFromRuns(runs);

        if (videoId && rawTitle && !seenQp.has(videoId)) {
          const track = {
            id: videoId,
            title: cleanSongTitle(rawTitle),
            artistName: artist,
            artworkUrl: getHDArtworkUrl(rawUrl, videoId),
            duration,
            durationMs,
          };
          if (isValidAudioSong(track)) {
            seenQp.add(videoId);
            quickPicks.push(track);
          }
        }
      }
    }
  }

  if (exploreRes.status === 'fulfilled' && exploreRes.value) {
    const sections = exploreRes.value?.contents?.singleColumnBrowseResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
    for (const sec of sections) {
      const carousel = sec.musicCarouselShelfRenderer;
      if (!carousel) continue;
      for (const item of carousel.contents || []) {
        const twoRow = item.musicTwoRowItemRenderer;
        if (!twoRow) continue;
        const browseId = twoRow.navigationEndpoint?.browseEndpoint?.browseId;
        if (!browseId || (!browseId.startsWith('MPREb_') && !browseId.startsWith('VL'))) continue;
        const title = twoRow.title?.runs?.[0]?.text;
        const subRuns = twoRow.subtitle?.runs || [];
        const subtitle = subRuns.map(x => x.text).join('').trim();
        let artistName = 'Artist';
        for (const run of subRuns) {
          const t = (run?.text || '').trim();
          const lt = t.toLowerCase();
          if (t && t !== '•' && lt !== 'album' && lt !== 'single' && lt !== 'ep') {
            artistName = t;
            break;
          }
        }
        const thumbs = twoRow.thumbnailRenderer?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawUrl = thumbs?.[thumbs.length - 1]?.url;
        if (
          title && rawUrl && !seenAlbums.has(browseId) &&
          !isDevotionalTerm(title) && !isDevotionalTerm(artistName) && !isUnwantedVideoItem(title, artistName)
        ) {
          seenAlbums.add(browseId);
          newAlbums.push({
            id: browseId,
            title,
            artistName,
            subtitle: subtitle || 'Album',
            artworkUrl: getHDArtworkUrl(rawUrl),
            type: 'album',
          });
        }
      }
    }
  }

  cachedBrowseHome = { quickPicks: quickPicks.slice(0, 16), newAlbums: newAlbums.slice(0, 16) };
  cachedBrowseHomeAt = Date.now();
  return cachedBrowseHome;
}

import { getPersonalizedHomeFeed } from './recommendations.js';

/**
 * Fetches Home Feed curated sections powered by Spotify-style editorial playlists, YTM Quick Picks & listening history.
 */
export async function getHomeFeed() {
  try {
    const personalized = await getPersonalizedHomeFeed();
    if (personalized && (personalized.sections?.length > 0 || personalized.quickPicks?.length > 0)) {
      return personalized;
    }
    if (Array.isArray(personalized) && personalized.length > 0) {
      return { quickPicks: [], newAlbums: [], sections: personalized };
    }
  } catch (e) {
    console.error('Personalized home feed error, falling back:', e);
  }

  try {
    const [browseData, globalHits, bollywoodHits] = await Promise.all([
      fetchBrowseHomeSections(),
      fetchCollectionTracks('VLRDCLAK5uy_nmS3YoxSwVVQk9lEQJ0UX4ZCjXsW_psU8'),
      fetchCollectionTracks('VLRDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g'),
    ]);

    const sections = [
      globalHits.length > 0 ? { title: "Today's Top Hits", category: 'charts', tracks: globalHits.slice(0, 16) } : null,
      bollywoodHits.length > 0 ? { title: 'Bollywood Hitlist', category: 'hindi', tracks: bollywoodHits.slice(0, 16) } : null,
    ].filter(Boolean);

    const quickPicks = (browseData.quickPicks.length > 0 ? browseData.quickPicks : globalHits).slice(0, 6);
    return {
      quickPicks,
      newAlbums: browseData.newAlbums || [],
      sections,
    };
  } catch (e) {
    console.error(`🔴 [YTMusic Service] Home feed error: ${e.message}`);
    return { quickPicks: [], newAlbums: [], sections: [] };
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

  if (!hdUrl && videoId) {
    return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
  }

  // Enforce https protocol
  if (hdUrl.startsWith('http://')) {
    hdUrl = hdUrl.replace('http://', 'https://');
  } else if (hdUrl.startsWith('//')) {
    hdUrl = `https:${hdUrl}`;
  }

  if (hdUrl.includes('googleusercontent.com') || hdUrl.includes('ggpht.com')) {
    const baseUrl = hdUrl.split('=')[0];
    return `${baseUrl}=w500-h500-l90-rj`;
  }

  if (hdUrl.includes('ytimg.com') || hdUrl.includes('youtube.com')) {
    hdUrl = hdUrl.replace(/(mqdefault|sddefault|default|hq720)\.jpg/, 'hqdefault.jpg');
    return hdUrl;
  }

  return hdUrl || (videoId ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg` : '');
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

