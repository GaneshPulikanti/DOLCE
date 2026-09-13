async function testYouTubeEmbed(videoId) {
  const embedUrl = `https://www.youtube-nocookie.com/embed/${videoId}?enablejsapi=1&autoplay=1&playsinline=1`;
  const res = await fetch(embedUrl);
  console.log(`YouTube Embed status for ${videoId}: ${res.status}`);
}

testYouTubeEmbed('KWuyx6yZ21U').catch(console.error);
