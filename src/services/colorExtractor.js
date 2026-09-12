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

        let r = 139, g = 92, b = 246; // Default Purple fallback
        if (vibrantColor) {
          r = vibrantColor.r;
          g = vibrantColor.g;
          b = vibrantColor.b;
        } else if (count > 0) {
          r = Math.round(rSum / count);
          g = Math.round(gSum / count);
          b = Math.round(bSum / count);
        }

        const primary = `rgb(${r}, ${g}, ${b})`;
        const secondary = `rgb(${Math.min(255, r + 45)}, ${Math.max(0, g - 25)}, ${Math.min(255, b + 65)})`;
        const dominant = `rgba(${r}, ${g}, ${b}, 0.55)`;
        const glow = `rgba(${r}, ${g}, ${b}, 0.35)`;
        const darkGradient = `linear-gradient(180deg, rgba(${r}, ${g}, ${b}, 0.45) 0%, rgba(5, 5, 8, 0.95) 75%)`;

        const palette = { primary, secondary, dominant, glow, darkGradient, r, g, b };
        colorCache.set(imageUrl, palette);
        resolve(palette);
      } catch (e) {
        resolve(getDefaultPalette());
      }
    };

    img.onerror = () => {
      resolve(getDefaultPalette());
    };
  });
}

function getDefaultPalette() {
  return {
    primary: 'rgb(139, 92, 246)',
    secondary: 'rgb(236, 72, 153)',
    dominant: 'rgba(139, 92, 246, 0.55)',
    glow: 'rgba(139, 92, 246, 0.35)',
    darkGradient: 'linear-gradient(180deg, rgba(139, 92, 246, 0.35) 0%, rgba(5, 5, 8, 0.95) 75%)',
    r: 139, g: 92, b: 246,
  };
}
