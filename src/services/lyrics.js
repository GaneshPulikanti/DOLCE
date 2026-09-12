/**
 * Lyrics Service fetching LRC synchronized and plain text lyrics from LRCLIB.
 */

export async function fetchLyrics(title, artist) {
  if (!title) return { synced: [], plain: 'No lyrics available.' };

  const cleanTitle = title.replace(/\(.*?\)|\[.*?\]/g, '').trim();
  const cleanArtist = (artist || '').replace(/\(.*?\)|\[.*?\]/g, '').trim();

  try {
    // 1. Exact match attempt
    const url = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}`;
    const res = await fetch(url);
    if (res.ok) {
      const data = await res.json();
      return parseLyricsData(data);
    }

    // 2. Search fallback attempt
    const searchUrl = `https://lrclib.net/api/search?q=${encodeURIComponent(cleanTitle + ' ' + cleanArtist)}`;
    const searchRes = await fetch(searchUrl);
    if (searchRes.ok) {
      const results = await searchRes.json();
      if (results && results.length > 0) {
        return parseLyricsData(results[0]);
      }
    }
  } catch (e) {
    console.warn(`⚠️ [Lyrics Service] LRCLIB fetch failed: ${e.message}`);
  }

  return {
    synced: [],
    plain: `♪ ${cleanTitle} by ${cleanArtist || 'DOLCE Artist'} ♪\n\n(Lyrics preview unavailable for this track)`
  };
}

function parseLyricsData(data) {
  if (data.syncedLyrics) {
    const lines = parseLrc(data.syncedLyrics);
    if (lines.length > 0) {
      return { synced: lines, plain: data.plainLyrics || '' };
    }
  }

  if (data.plainLyrics) {
    return { synced: [], plain: data.plainLyrics };
  }

  return { synced: [], plain: 'No lyrics available for this song.' };
}

function parseLrc(lrcText) {
  if (!lrcText) return [];
  const lines = lrcText.split('\n');
  const result = [];
  const timeReg = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/;

  for (const line of lines) {
    const match = timeReg.exec(line);
    if (match) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      const millis = parseInt(match[3].padEnd(3, '0'), 10);
      const timeInSec = minutes * 60 + seconds + millis / 1000;
      const text = line.replace(timeReg, '').trim();
      if (text) {
        result.push({ time: timeInSec, text });
      }
    }
  }
  return result.sort((a, b) => a.time - b.time);
}
