/**
 * YouTube Music API Client for DOLCE React Application.
 * Supports Vercel Serverless Edge API rewrites and fallback CORS proxying.
 */

const isVercel = typeof window !== 'undefined' && 
  (window.location.hostname.includes('vercel.app') || 
   (!window.location.hostname.includes('localhost') && !window.location.hostname.includes('127.0.0.1')));

/**
 * Searches songs catalog using InnerTube API / YouTube Music.
 */
export async function searchSongs(query) {
  if (!query || !query.trim()) return [];

  const cleanQuery = query.trim();
  console.log(`🔎 [YTMusic Service] Searching songs for: "${cleanQuery}"`);

  // 1. Try Local Vite Proxy / Vercel Serverless Proxy
  try {
    const res = await fetch(`/api/ytmusic/youtubei/v1/search?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&alt=json`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20260526.04.00',
            gl: 'IN',
            hl: 'en'
          }
        },
        query: cleanQuery,
        params: 'Eg-KAQwIARAAGAAgACgAMABqChAEEAMQCRAFEAo='
      })
    });

    if (res.ok) {
      const data = await res.json();
      const songs = parseInnerTubeSearchSongs(data);
      if (songs.length > 0) return songs;
    }
  } catch (e) {
    console.warn(`⚠️ [YTMusic Service] Proxy search failed: ${e.message}. Trying direct YT Music...`);
  }

  // 2. Direct YouTube Music InnerTube Search (works on Mobile Native / CORS enabled)
  try {
    const res = await fetch(`https://music.youtube.com/youtubei/v1/search?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&alt=json`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20260526.04.00',
            gl: 'IN',
            hl: 'en'
          }
        },
        query: cleanQuery,
        params: 'Eg-KAQwIARAAGAAgACgAMABqChAEEAMQCRAFEAo='
      })
    });

    if (res.ok) {
      const data = await res.json();
      const songs = parseInnerTubeSearchSongs(data);
      if (songs.length > 0) return songs;
    }
  } catch (e) {
    console.warn(`⚠️ [YTMusic Service] Direct search failed: ${e.message}.`);
  }

  // 3. Fallback Piped / Invidious API
  const backupEndpoints = [
    `https://pipedapi.kavin.rocks/search?q=${encodeURIComponent(cleanQuery)}&filter=music_songs`,
    `https://invidious.drgns.space/api/v1/search?q=${encodeURIComponent(cleanQuery)}&type=video`,
  ];

  for (const endpoint of backupEndpoints) {
    try {
      const res = await fetch(endpoint);
      if (res.ok) {
        const data = await res.json();
        const items = Array.isArray(data) ? data : (data.items || []);
        const songs = items.map(item => {
          const vId = item.videoId || extractVideoId(item.url);
          const rawUrl = item.thumbnail || item.videoThumbnails?.[0]?.url;
          return {
            id: vId,
            title: item.title,
            artistName: item.author || item.uploaderName || 'Unknown Artist',
            artworkUrl: getHDArtworkUrl(rawUrl, vId),
            duration: formatDurationSeconds(item.lengthSeconds || item.duration),
            durationMs: (item.lengthSeconds || item.duration || 225) * 1000,
          };
        }).filter(s => s.id);
        if (songs.length > 0) return songs;
      }
    } catch (_) {}
  }

  return [];
}

/**
 * Fetches Home Feed curated sections.
 */
export async function getHomeFeed() {
  const defaultCategories = [
    { title: '🔥 Trending Music Hits', query: 'top hits 2026' },
    { title: '🌧️ Rain Therapy & Chill', query: 'chill lofi music' },
    { title: '⚡ Workout & Energy', query: 'workout motivation music' },
    { title: '❤️ Romantic Melodies', query: 'romantic love songs' },
  ];

  try {
    const sections = await Promise.all(
      defaultCategories.map(async (cat) => {
        const tracks = await searchSongs(cat.query);
        return {
          title: cat.title,
          tracks: tracks.slice(0, 10),
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
 * Resolves direct audio stream URL for native playing if needed.
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
  } else if (hdUrl.includes('ytimg.com') || hdUrl.includes('youtube.com')) {
    hdUrl = hdUrl.replace(/(hqdefault|mqdefault|sddefault|default)\.jpg/, 'hq720.jpg');
  }

  if ((!hdUrl || hdUrl.includes('default.jpg')) && videoId) {
    hdUrl = `https://i.ytimg.com/vi/${videoId}/hq720.jpg`;
  }
  return hdUrl;
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

function parseInnerTubeSearchSongs(data) {
  try {
    const contents = data?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents;
    if (!contents) return [];

    const tracks = [];
    for (const sec of contents) {
      const items = sec.musicShelfRenderer?.contents || sec.musicCardShelfRenderer?.contents || [];
      for (const item of items) {
        const r = item.musicResponsiveListItemRenderer;
        if (!r) continue;

        const videoId = r.playlistItemData?.videoId || r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
        const title = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const artist = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
        const rawThumbUrl = thumbs?.[thumbs.length - 1]?.url;

        if (videoId && title) {
          tracks.push({
            id: videoId,
            title: title,
            artistName: artist || 'YouTube Artist',
            artworkUrl: getHDArtworkUrl(rawThumbUrl, videoId),
            duration: '3:45',
            durationMs: 225000,
          });
        }
      }
    }
    return tracks;
  } catch (e) {
    console.error('Failed to parse InnerTube search response:', e);
    return [];
  }
}
