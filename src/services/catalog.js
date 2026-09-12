/**
 * DOLCE Audio Catalog Engine.
 * High-performance music streaming gateway client with HD Album Cover processing.
 */

/**
 * Searches songs catalog using DOLCE Gateway.
 */
export async function searchSongs(query) {
  if (!query || !query.trim()) return [];

  const cleanQuery = query.trim();

  const apiKey = import.meta.env.VITE_DOLCE_SERVICE_KEY || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

  // 1. Try Local Vite Proxy / Vercel Serverless Gateway
  try {
    const res = await fetch(`/api/gateway/youtubei/v1/search?key=${apiKey}&alt=json`, {
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
  } catch (_) {}

  // 2. Direct Media Engine Gateway Search
  try {
    const res = await fetch(`https://music.youtube.com/youtubei/v1/search?key=${apiKey}&alt=json`, {
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
  } catch (_) {}

  // 3. Fallback High Availability Mirror API
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
        const songs = items
          .map(item => {
            const vId = item.videoId || extractVideoId(item.url);
            const rawUrl = item.thumbnail || item.videoThumbnails?.[0]?.url;
            return {
              id: vId,
              title: item.title,
              artistName: item.author || item.uploaderName || 'Artist',
              artworkUrl: getHDArtworkUrl(rawUrl, vId),
              duration: formatDurationSeconds(item.lengthSeconds || item.duration),
              durationMs: (item.lengthSeconds || item.duration || 225) * 1000,
            };
          })
          .filter(s => s.id);
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

/**
 * Transforms raw thumbnail URLs into high-definition artwork URLs (540x540 / 720p).
 * Always returns a valid artwork URL string for guaranteed display.
 */
export function getHDArtworkUrl(url, videoId) {
  let hdUrl = url || '';

  // Official YouTube Music Audio Cover hosts (lh3.googleusercontent.com, yt3.googleusercontent.com, yt3.ggpht.com)
  if (hdUrl.includes('googleusercontent.com') || hdUrl.includes('ggpht.com')) {
    hdUrl = hdUrl.replace(/=w\d+-h\d+-[^?]+/, '=w540-h540-l90-rj');
    hdUrl = hdUrl.replace(/=w\d+-h\d+/, '=w540-h540-l90-rj');
    hdUrl = hdUrl.replace(/=s\d+-[^?]+/, '=s540-c');
    hdUrl = hdUrl.replace(/=s\d+$/, '=s540');
    return hdUrl;
  }

  // For YouTube thumbnail URLs, hqdefault.jpg is 100% guaranteed to exist (200 OK) without 404
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

/**
 * Parses InnerTube WEB_REMIX search responses.
 */
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

        const hdArtwork = getHDArtworkUrl(rawThumbUrl, videoId);

        if (videoId && title) {
          tracks.push({
            id: videoId,
            title: title,
            artistName: artist || 'YouTube Artist',
            artworkUrl: hdArtwork,
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
