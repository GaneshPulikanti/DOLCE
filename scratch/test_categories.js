async function testSearchAndBrowse() {
  const apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  const query = 'Lover Taylor Swift';

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
      query: query
    })
  });

  const data = await res.json();
  const contents = data?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];

  let albumBrowseId = null;

  function findAlbum(obj) {
    if (!obj || typeof obj !== 'object') return;
    if (obj.musicResponsiveListItemRenderer) {
      const r = obj.musicResponsiveListItemRenderer;
      const title = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const runs = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
      const subtitle = runs.map(r => r.text).join('');
      const nav = r.navigationEndpoint || r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint;
      const bId = nav?.browseEndpoint?.browseId;

      if (subtitle.toLowerCase().includes('album') && bId) {
        console.log(`Found Album: "${title}", browseId="${bId}"`);
        albumBrowseId = bId;
        return;
      }
    }
    for (const key in obj) {
      if (obj.hasOwnProperty(key) && typeof obj[key] === 'object' && !albumBrowseId) {
        findAlbum(obj[key]);
      }
    }
  }

  findAlbum(contents);

  if (albumBrowseId) {
    console.log(`\nBrowsing Album ID: ${albumBrowseId}...`);
    const bRes = await fetch(`https://music.youtube.com/youtubei/v1/browse?key=${apiKey}&alt=json`, {
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
        browseId: albumBrowseId
      })
    });
    const bData = await bRes.json();
    const tracks = [];
    function findTracks(obj) {
      if (!obj || typeof obj !== 'object') return;
      if (obj.musicResponsiveListItemRenderer) {
        const r = obj.musicResponsiveListItemRenderer;
        const videoId = r.playlistItemData?.videoId || 
                        r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
                        r.navigationEndpoint?.watchEndpoint?.videoId;
        const trackTitle = r.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const artist = r.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || 'Artist';

        if (videoId && trackTitle) {
          tracks.push({ videoId, trackTitle, artist });
        }
      }
      for (const key in obj) {
        if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
          findTracks(obj[key]);
        }
      }
    }
    findTracks(bData);
    console.log(`Fetched ${tracks.length} tracks from album:`);
    console.log(tracks.slice(0, 5));
  }
}

testSearchAndBrowse().catch(console.error);
