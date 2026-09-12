/**
 * Dynamic Artwork Color Palette Extractor.
 * Extracts dominant vibrant colors from track artwork images for Apple Music style ambient backdrops.
 */

const colorCache = new Map();

export async function extractArtworkColor(imageUrl) {
  if (!imageUrl) {
    return getDefaultPalette('default');
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
          const brightness = (r + g + b) / 3;

          // Skip extreme darks and extreme lights for rich vibrant tone
          if (brightness > 25 && brightness < 235) {
            rSum += r;
            gSum += g;
            bSum += b;
            count++;

            const max = Math.max(r, g, b);
            const min = Math.min(r, g, b);
            const sat = max === 0 ? 0 : (max - min) / max;

            if (sat > maxSat) {
              maxSat = sat;
              vibrantColor = { r, g, b };
            }
          }
        }

        let r = 139, g = 92, b = 246; // Default fallback
        if (vibrantColor) {
          r = vibrantColor.r;
          g = vibrantColor.g;
          b = vibrantColor.b;
        } else if (count > 0) {
          r = Math.round(rSum / count);
          g = Math.round(gSum / count);
          b = Math.round(bSum / count);
        }

        const palette = buildPaletteFromRgb(r, g, b);
        colorCache.set(imageUrl, palette);
        resolve(palette);
      } catch (e) {
        resolve(getDefaultPalette(imageUrl));
      }
    };

    img.onerror = () => {
      resolve(getDefaultPalette(imageUrl));
    };
  });
}

function buildPaletteFromRgb(r, g, b) {
  const primary = `rgb(${r}, ${g}, ${b})`;
  const secondary = `rgb(${Math.min(255, r + 40)}, ${Math.max(0, g - 20)}, ${Math.min(255, b + 60)})`;
  const dominant = `rgba(${r}, ${g}, ${b}, 0.55)`;
  const glow = `rgba(${r}, ${g}, ${b}, 0.35)`;
  const darkGradient = `linear-gradient(180deg, rgba(${r}, ${g}, ${b}, 0.55) 0%, rgba(${Math.floor(r * 0.25)}, ${Math.floor(g * 0.25)}, ${Math.floor(b * 0.25)}, 0.85) 50%, rgba(5, 5, 5, 0.98) 100%)`;

  return { primary, secondary, dominant, glow, darkGradient, r, g, b };
}

function getDefaultPalette(key = 'default') {
  // String hash algorithm to generate a deterministic, rich HSL color for any song
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = key.charCodeAt(i) + ((hash << 5) - hash);
  }

  const hue = Math.abs(hash) % 360;
  const sat = 75; // 75% vibrant saturation
  const light = 42; // 42% rich lightness

  // HSL to RGB conversion
  const c = (1 - Math.abs(2 * (light / 100) - 1)) * (sat / 100);
  const x = c * (1 - Math.abs(((hue / 60) % 2) - 1));
  const m = light / 100 - c / 2;

  let rPrime = 0, gPrime = 0, bPrime = 0;
  if (hue < 60) { rPrime = c; gPrime = x; bPrime = 0; }
  else if (hue < 120) { rPrime = x; gPrime = c; bPrime = 0; }
  else if (hue < 180) { rPrime = 0; gPrime = c; bPrime = x; }
  else if (hue < 240) { rPrime = 0; gPrime = x; bPrime = c; }
  else if (hue < 300) { rPrime = x; gPrime = 0; bPrime = c; }
  else { rPrime = c; gPrime = 0; bPrime = x; }

  const r = Math.round((rPrime + m) * 255);
  const g = Math.round((gPrime + m) * 255);
  const b = Math.round((bPrime + m) * 255);

  return buildPaletteFromRgb(r, g, b);
}
