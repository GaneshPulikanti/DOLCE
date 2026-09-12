/**
 * Dynamic Artwork Color Palette Extractor.
 * Extracts dominant vibrant colors from track artwork images for Apple Music style ambient backdrops.
 */

const colorCache = new Map();

export async function extractArtworkColor(imageUrl) {
  if (!imageUrl) {
    return getDefaultPalette();
  }

  if (colorCache.has(imageUrl)) {
    return colorCache.get(imageUrl);
  }

  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.src = imageUrl;

    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 32;
        canvas.height = 32;
        ctx.drawImage(img, 0, 0, 32, 32);

        const imgData = ctx.getImageData(0, 0, 32, 32).data;
        let rSum = 0, gSum = 0, bSum = 0, count = 0;
        let maxSat = -1;
        let vibrantColor = null;

        for (let i = 0; i < imgData.length; i += 16) {
          const r = imgData[i];
          const g = imgData[i + 1];
          const b = imgData[i + 2];
          const a = imgData[i + 3];

          if (a < 128) continue; // Skip transparent pixels

          rSum += r;
          gSum += g;
          bSum += b;
          count++;

          const max = Math.max(r, g, b);
          const min = Math.min(r, g, b);
          const sat = max === 0 ? 0 : (max - min) / max;
          const brightness = (r + g + b) / 3;

          // Pick the color with highest saturation among non-extreme pixels
          if (brightness > 20 && brightness < 240 && sat > maxSat) {
            maxSat = sat;
            vibrantColor = { r, g, b };
          }
        }

        let r = 25, g = 28, b = 35; // Sleek neutral dark charcoal fallback

        if (count > 0) {
          const avgR = Math.round(rSum / count);
          const avgG = Math.round(gSum / count);
          const avgB = Math.round(bSum / count);

          if (vibrantColor && maxSat > 0.18) {
            // Use vibrant color for colored artwork
            r = vibrantColor.r;
            g = vibrantColor.g;
            b = vibrantColor.b;
          } else {
            // For dark, black, grey, or monochrome artwork, use true extracted average RGB
            r = avgR;
            g = avgG;
            b = avgB;
          }
        }

        const palette = buildPaletteFromRgb(r, g, b);
        colorCache.set(imageUrl, palette);
        resolve(palette);
      } catch (e) {
        // Fallback for CORS canvas read error
        resolve(getDefaultPalette());
      }
    };

    img.onerror = () => {
      resolve(getDefaultPalette());
    };
  });
}

function buildPaletteFromRgb(r, g, b) {
  // Clamp extreme brightness for ambient player backdrops
  const brightness = (r + g + b) / 3;
  let bgR = r;
  let bgG = g;
  let bgB = b;

  if (brightness > 180) {
    const factor = 140 / brightness;
    bgR = Math.round(r * factor);
    bgG = Math.round(g * factor);
    bgB = Math.round(b * factor);
  }

  const primary = `rgb(${bgR}, ${bgG}, ${bgB})`;
  const dominant = `rgba(${bgR}, ${bgG}, ${bgB}, 0.55)`;
  const glow = `rgba(${bgR}, ${bgG}, ${bgB}, 0.35)`;
  const darkGradient = `linear-gradient(180deg, rgba(${bgR}, ${bgG}, ${bgB}, 0.65) 0%, rgba(${Math.floor(bgR * 0.3)}, ${Math.floor(bgG * 0.3)}, ${Math.floor(bgB * 0.3)}, 0.88) 50%, rgba(5, 5, 5, 0.98) 100%)`;

  return { primary, dominant, glow, darkGradient, r: bgR, g: bgG, b: bgB };
}

function getDefaultPalette() {
  // Neutral dark charcoal palette matching Apple Music dark player backdrop
  return buildPaletteFromRgb(28, 30, 38);
}
