/**
 * Dynamic Artwork Color Palette Extractor.
 * Uses 12-Bucket HSL Color Histogram Quantization & Multi-Proxy Fallback
 * to extract exact dominant vibrant album cover colors (Blue, Purple, Yellow, Green, Pink, Red, Grey, Black).
 */

const colorCache = new Map();

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0, s = 0, l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  return { h: h * 360, s: s * 100, l: l * 100 };
}

function loadImageCanvas(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.src = url;

    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 32;
        canvas.height = 32;

        if (url.includes('ytimg.com') || url.includes('youtube.com')) {
          // Crop top and bottom 12.5% letterbox black bars for 16:9 YouTube thumbnails
          const srcW = img.naturalWidth || 480;
          const srcH = img.naturalHeight || 360;
          const cropY = Math.floor(srcH * 0.125);
          const cropH = Math.floor(srcH * 0.75);
          ctx.drawImage(img, 0, cropY, srcW, cropH, 0, 0, 32, 32);
        } else {
          ctx.drawImage(img, 0, 0, 32, 32);
        }

        const imgData = ctx.getImageData(0, 0, 32, 32).data;
        resolve(imgData);
      } catch (e) {
        reject(e);
      }
    };

    img.onerror = (e) => reject(e);
  });
}

export async function extractArtworkColor(imageUrl) {
  if (!imageUrl) {
    return getDefaultPalette();
  }

  if (colorCache.has(imageUrl)) {
    return colorCache.get(imageUrl);
  }

  let imgData = null;

  // 1. Direct same-origin / CORS load
  try {
    imgData = await loadImageCanvas(imageUrl);
  } catch (e1) {
    // 2. Same-origin local app proxy route (/api/corsproxy)
    try {
      const appProxyUrl = `/api/corsproxy?url=${encodeURIComponent(imageUrl)}`;
      imgData = await loadImageCanvas(appProxyUrl);
    } catch (e2) {
      // 3. Google OpenSocial Gadget Proxy
      try {
        const proxyUrl2 = `https://images1-focus-opensocial.googleusercontent.com/gadgets/proxy?container=focus&refresh=2592000&url=${encodeURIComponent(imageUrl)}`;
        imgData = await loadImageCanvas(proxyUrl2);
      } catch (e3) {
        return getDefaultPalette();
      }
    }
  }

  if (!imgData) {
    return getDefaultPalette();
  }

  // 12 Hue Buckets (30-degree slices: Red, Orange, Yellow, Green, Teal, Blue, Purple, Pink, etc.)
  const buckets = Array.from({ length: 12 }, () => ({ count: 0, rSum: 0, gSum: 0, bSum: 0, maxSat: 0 }));
  let rTotal = 0, gTotal = 0, bTotal = 0, totalCount = 0;

  for (let i = 0; i < imgData.length; i += 4) {
    const r = imgData[i];
    const g = imgData[i + 1];
    const b = imgData[i + 2];
    const a = imgData[i + 3];

    if (a < 128) continue; // Ignore transparent pixels

    rTotal += r;
    gTotal += g;
    bTotal += b;
    totalCount++;

    const { h, s, l } = rgbToHsl(r, g, b);

    // Filter out extreme darks & extreme lights for vibrant color bucketing
    if (l > 12 && l < 88 && s > 15) {
      const bucketIdx = Math.floor(h / 30) % 12;
      const bkt = buckets[bucketIdx];
      bkt.count += 1;
      bkt.rSum += r;
      bkt.gSum += g;
      bkt.bSum += b;
      if (s > bkt.maxSat) bkt.maxSat = s;
    }
  }

  // Find the winning bucket (highest weighted frequency = count * (1 + maxSat / 100))
  let winningBucket = null;
  let maxWeight = -1;

  for (const bkt of buckets) {
    if (bkt.count > 0) {
      const weight = bkt.count * (1 + bkt.maxSat / 100);
      if (weight > maxWeight) {
        maxWeight = weight;
        winningBucket = bkt;
      }
    }
  }

  let finalR = 28, finalG = 30, finalB = 38;

  if (winningBucket && winningBucket.count >= 6) {
    // True dominant color bucket wins
    finalR = Math.round(winningBucket.rSum / winningBucket.count);
    finalG = Math.round(winningBucket.gSum / winningBucket.count);
    finalB = Math.round(winningBucket.bSum / winningBucket.count);
  } else if (totalCount > 0) {
    // For dark, monochrome or neutral grey artwork, use true average RGB
    finalR = Math.round(rTotal / totalCount);
    finalG = Math.round(gTotal / totalCount);
    finalB = Math.round(bTotal / totalCount);
  }

  const palette = buildPaletteFromRgb(finalR, finalG, finalB);
  colorCache.set(imageUrl, palette);
  return palette;
}

function buildPaletteFromRgb(r, g, b) {
  // Clamp extreme brightness for ambient player backdrops
  const brightness = (r + g + b) / 3;
  let bgR = r;
  let bgG = g;
  let bgB = b;

  if (brightness > 165) {
    const factor = 135 / brightness;
    bgR = Math.round(r * factor);
    bgG = Math.round(g * factor);
    bgB = Math.round(b * factor);
  }

  const primary = `rgb(${bgR}, ${bgG}, ${bgB})`;
  const dominant = `rgba(${bgR}, ${bgG}, ${bgB}, 0.65)`;
  const glow = `rgba(${bgR}, ${bgG}, ${bgB}, 0.45)`;
  const darkGradient = `linear-gradient(180deg, rgba(${bgR}, ${bgG}, ${bgB}, 0.75) 0%, rgba(${Math.floor(bgR * 0.25)}, ${Math.floor(bgG * 0.25)}, ${Math.floor(bgB * 0.25)}, 0.92) 55%, rgba(5, 5, 5, 0.98) 100%)`;

  return { primary, dominant, glow, darkGradient, r: bgR, g: bgG, b: bgB };
}

function getDefaultPalette() {
  // Neutral dark charcoal palette matching Apple Music dark player backdrop
  return buildPaletteFromRgb(28, 30, 38);
}
