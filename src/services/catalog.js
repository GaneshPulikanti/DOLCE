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

  // Reject non-music video content (trailers, teasers, full movies, commentary, etc.)
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
    'ring tone',
    'slowed+reverb',
    'slowed and reverb',
    '8d audio'
  ];

  for (const kw of junkKeywords) {
    if (lowerTitle.includes(kw)) {
      return true;
    }
  }

  return false;
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

    const tracks = [];
    for (const item of items) {
      const r = item.playlistPanelVideoRenderer;
      if (!r || !r.videoId || r.videoId === videoId) continue;

      const rawTitle = r.title?.runs?.[0]?.text;
      if (!rawTitle) continue;

      const artist = r.shortBylineText?.runs?.[0]?.text || r.longBylineText?.runs?.[0]?.text || 'Artist';
      const duration = r.lengthText?.runs?.[0]?.text || '3:30';
      const thumbs = r.thumbnail?.thumbnails;
      const rawThumb = thumbs?.[thumbs.length - 1]?.url;
      const hdArtwork = getHDArtworkUrl(rawThumb, r.videoId);

      const title = cleanSongTitle(rawTitle);
      const track = {
        id: r.videoId,
        title,
        artistName: artist,
        artworkUrl: hdArtwork,
        duration,
        durationMs: 210000,
      };

      if (isValidAudioSong(track)) {
        tracks.push(track);
      }
    }

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

/**
 * Multi-Category Search Engine (Songs, Albums, Playlists, Artists).
 */
export async function searchCatalog(query) {
  if (!query || !query.trim()) {
    return { songs: [], albums: [], playlists: [], artists: [] };
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

        // Check watch endpoint music configs
        const watchEndpoint = r.playlistItemData?.watchEndpoint ||
                              r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint ||
                              r.navigationEndpoint?.watchEndpoint;
        const musicVideoType = watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType;
        if (musicVideoType === 'MUSIC_VIDEO_TYPE_UGC' || musicVideoType === 'MUSIC_VIDEO_TYPE_OMV') {
          return;
        }

        // Strictly verify thumbnails (Must have actual artwork, eliminate video items without square covers)
        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        if (!thumbs || thumbs.length === 0) return;
        const rawUrl = thumbs[thumbs.length - 1]?.url;
        if (!rawUrl || typeof rawUrl !== 'string' || rawUrl.trim() === '') return;

        // Video items often have view counts in subtitle (e.g. "12M views") without album info
        if (lowerSub.includes('views') && !lowerSub.includes('album') && !lowerSub.includes('song')) {
          return;
        }

        if (artist.toLowerCase() === 'song') {
          artist = runs[2]?.text || runs[1]?.text || 'Artist';
        }

        const hdArtwork = getHDArtworkUrl(rawUrl, videoId);
        if (!hdArtwork || hdArtwork.length < 15) return;

        if (rawTitle && isUnwantedVideoItem(rawTitle, artist, cleanQuery)) return;

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

  // Normalize query variations (e.g., "one nenokkadine" -> "1 nenokkadine", "no. 1 nenokkadine")
  const lowerQuery = cleanQuery.toLowerCase();
  const normalizedQuery = lowerQuery
    .replace(/\bone\b/g, '1')
    .replace(/\btwo\b/g, '2')
    .replace(/\bthree\b/g, '3')
    .replace(/\bno\.?\s*/g, '')
    .trim();

  const queryWords = lowerQuery.split(/\s+/).filter(w => w.length > 2);
  const normWords = normalizedQuery.split(/\s+/).filter(w => w.length > 2);
  const mainWords = [...new Set([...queryWords, ...normWords])];

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

    // Skip episode cards
    if (lowerSub.includes('episode') || lowerSub.includes('podcast')) return;

    const thumbs = card.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
    const rawThumb = thumbs?.[thumbs.length - 1]?.url;

    const watchEndpoint = card.onTap?.watchEndpoint;
    const browseEndpoint = card.onTap?.browseEndpoint;

    if (watchEndpoint?.videoId) {
      const videoId = watchEndpoint.videoId;
      let artist = 'Artist';
      for (const r of subtitleRuns) {
        const t = (r.text || '').trim();
        if (t && t !== '•' && t !== 'Song' && t !== 'Video' && !t.includes('views') && !t.includes(':')) {
          artist = t;
          break;
        }
      }
      topResult = {
        id: videoId,
        title: cleanSongTitle(rawTitle),
        artistName: artist,
        subtitle: subtitle,
        artworkUrl: getHDArtworkUrl(rawThumb, videoId),
        duration: '3:30',
        durationMs: 210000,
        type: 'song',
      };
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
          artistName: subtitleRuns[0]?.text || 'Artist',
          subtitle: subtitle || 'Album',
          artworkUrl: hdArtwork,
          type: 'album',
        };
      } else if (lowerSub.includes('playlist')) {
        topResult = {
          id: browseId,
          title: rawTitle,
          author: subtitleRuns[0]?.text || 'Playlist',
          subtitle: subtitle || 'Playlist',
          artworkUrl: hdArtwork,
          type: 'playlist',
        };
      }
    }
  };

  const searchPromises = [
    fetchYtMusicSearch(cleanQuery, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D'), // Pure audio songs filter
    fetchYtMusicSearch(cleanQuery), // Albums, artists, playlists, top results
    customFetch(`https://lrclib.net/api/search?q=${encodeURIComponent(cleanQuery)}`).then(r => r.ok ? r.json() : null)
  ];

  if (normalizedQuery !== lowerQuery) {
    searchPromises.push(fetchYtMusicSearch(normalizedQuery, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D'));
    searchPromises.push(fetchYtMusicSearch(normalizedQuery));
  }

  const results = await Promise.allSettled(searchPromises);

  results.forEach(res => {
    if (res.status === 'fulfilled' && res.value) {
      parseTopCard(res.value);
      parseInnerTubeContents(res.value);
    }
  });

  // Process LrcLib Lyric Matches for additional song tracks
  const lrcResult = results[2];
  if (lrcResult && lrcResult.status === 'fulfilled' && Array.isArray(lrcResult.value) && lrcResult.value.length > 0) {
    const lyricMatches = lrcResult.value.slice(0, 3);
    for (const match of lyricMatches) {
      if (match.trackName && match.artistName) {
        const q = `${match.trackName} ${match.artistName}`;
        try {
          const matchData = await fetchYtMusicSearch(q, 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D');
          if (matchData) parseInnerTubeContents(matchData);
        } catch (_) {}
      }
    }
  }

  function scorePriority(item) {
    let score = 0;
    const title = (item.title || item.name || '').toLowerCase();
    const artist = (item.artistName || item.author || item.subtitle || '').toLowerCase();

    // 🏆 1. Exact & Prefix Match Boost
    if (title === lowerQuery || title === normalizedQuery) {
      score += 50000;
    } else if (title.startsWith(lowerQuery) || (normalizedQuery && title.startsWith(normalizedQuery))) {
      score += 25000;
    } else if (title.includes(lowerQuery) || lowerQuery.includes(title)) {
      score += 15000;
    } else if (normalizedQuery && (title.includes(normalizedQuery) || normalizedQuery.includes(title))) {
      score += 12000;
    }

    // 🏆 2. Multi-word Match Boost
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

    // 🏆 3. Artist Match Boost
    if (artist === lowerQuery || artist === normalizedQuery) {
      score += 20000;
    } else if (artist.startsWith(lowerQuery) || (normalizedQuery && artist.startsWith(normalizedQuery))) {
      score += 10000;
    } else if (artist.includes(lowerQuery) || (normalizedQuery && artist.includes(normalizedQuery))) {
      score += 4000;
    }

    return score;
  }

  const sortStatically = (list) => {
    return list.sort((a, b) => {
      const scoreDiff = scorePriority(b) - scorePriority(a);
      if (scoreDiff !== 0) return scoreDiff;
      const titleA = (a.title || a.name || '').toLowerCase();
      const titleB = (b.title || b.name || '').toLowerCase();
      return titleA.localeCompare(titleB);
    });
  };

  const allSongs = sortStatically(Array.from(tracksMap.values()).filter(isValidAudioSong));
  let allAlbums = sortStatically(Array.from(albumsMap.values()));
  const allPlaylists = sortStatically(Array.from(playlistsMap.values()));
  const allArtists = sortStatically(Array.from(artistsMap.values()));

  // 🎵 Synthetic Album Promotion: If searching for a soundtrack/collection
  allPlaylists.forEach(pl => {
    const plTitle = (pl.title || '').toLowerCase();
    if (plTitle.includes(lowerQuery) || (normalizedQuery && plTitle.includes(normalizedQuery))) {
      if (!allAlbums.some(a => (a.title || '').toLowerCase().includes(normalizedQuery))) {
        allAlbums.unshift({
          id: pl.id,
          title: pl.title,
          artistName: pl.author || 'Soundtrack / Collection',
          subtitle: pl.subtitle || 'Album / Playlist',
          artworkUrl: pl.artworkUrl,
        });
      }
    }
  });

  // Spotify-style Top Result fallback
  if (!topResult) {
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

import { getPersonalizedHomeFeed } from './recommendations.js';

/**
 * Fetches Home Feed curated sections powered by YouTube-style personalization & user listening history.
 */
export async function getHomeFeed() {
  try {
    const personalized = await getPersonalizedHomeFeed();
    if (personalized && (personalized.sections?.length > 0 || personalized.quickPicks?.length > 0)) {
      return personalized;
    }
    if (Array.isArray(personalized) && personalized.length > 0) {
      return { quickPicks: [], sections: personalized };
    }
  } catch (e) {
    console.error('Personalized home feed error, falling back:', e);
  }

  const defaultCategories = [
    { title: "🔥 Today's Top Hits", query: 'global top hits music songs' },
    { title: '⚡ Global Viral 50', query: 'viral hits music songs' },
    { title: '🎧 Pop & Hip-Hop Essentials', query: 'pop hip hop hits songs' },
    { title: '❤️ Romantic Melodies', query: 'romantic love songs hits' },
    { title: '🌙 Late Night Lo-Fi & Chill', query: 'chill lofi beats relaxing songs' },
    { title: '⚡ Workout & High Energy', query: 'workout gym motivation songs' },
  ];

  try {
    const sections = await Promise.all(
      defaultCategories.map(async (cat) => {
        const tracks = await searchSongs(cat.query);
        const validTracks = tracks.filter(isValidAudioSong);
        return {
          title: cat.title,
          tracks: validTracks.slice(0, 12),
        };
      })
    );

    const validSections = sections.filter(s => s.tracks.length > 0);
    const quickPicks = validSections[0]?.tracks?.slice(0, 6) || [];
    return { quickPicks, sections: validSections };
  } catch (e) {
    console.error(`🔴 [YTMusic Service] Home feed error: ${e.message}`);
    return { quickPicks: [], sections: [] };
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

