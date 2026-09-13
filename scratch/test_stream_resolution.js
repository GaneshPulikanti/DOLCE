async function testStreamResolution(videoId) {
  console.log(`Testing stream resolution for videoId: "${videoId}"...`);
  
  const endpoints = [
    `https://pipedapi.kavin.rocks/streams/${videoId}`,
    `https://api.piped.video/streams/${videoId}`,
    `https://invidious.drgns.space/api/v1/videos/${videoId}?local=true`,
    `https://yewtu.be/api/v1/videos/${videoId}?local=true`,
    `https://inv.nadeko.net/api/v1/videos/${videoId}?local=true`,
    `https://invidious.nerdvpn.de/api/v1/videos/${videoId}?local=true`,
    `https://inv.tux.pizza/api/v1/videos/${videoId}?local=true`,
    `https://invidious.no-fuss-tech.com/api/v1/videos/${videoId}?local=true`,
    `https://invidious.privacyredirect.com/api/v1/videos/${videoId}?local=true`,
  ];

  for (const ep of endpoints) {
    try {
      const start = Date.now();
      const res = await fetch(ep);
      const ms = Date.now() - start;
      if (res.ok) {
        const data = await res.json();
        let audioUrl = null;
        if (data.audioStreams && data.audioStreams.length > 0) {
          audioUrl = data.audioStreams[0].url;
        } else if (data.adaptiveFormats) {
          const audio = data.adaptiveFormats.filter(a => a.type?.includes('audio'));
          if (audio.length > 0) audioUrl = audio[0].url;
        }
        if (audioUrl) {
          console.log(`✅ SUCCESS from ${ep} (${ms}ms) -> Stream length: ${audioUrl.length}`);
          return audioUrl;
        } else {
          console.log(`⚠️ OK from ${ep} (${ms}ms) but no audio streams found`);
        }
      } else {
        console.log(`❌ FAIL from ${ep} (${ms}ms) -> Status ${res.status}`);
      }
    } catch (e) {
      console.log(`💥 ERROR from ${ep} -> ${e.message}`);
    }
  }

  return null;
}

testStreamResolution('KWuyx6yZ21U').catch(console.error);
