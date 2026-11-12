import React, { useState, useEffect } from 'react';
import { Music } from 'lucide-react';
import { getHDArtworkUrl } from '../services/catalog';

const YOUTUBE_VIDEO_ID_RE = /^[A-Za-z0-9_-]{11}$/;

/**
 * Shared artwork renderer that repairs mangled YouTube thumbnail URLs,
 * rejects YouTube's 120x90 grey missing-cover placeholder, and renders a
 * clean DOLCE music tile if no valid cover is available.
 */
export const CoverImage = ({
  src,
  trackId,
  alt = '',
  className = 'w-full h-full object-cover',
  loading = 'lazy',
  iconSize = 24,
  showBrand = false,
  brandLabel = 'DOLCE',
  fallbackClassName = '',
}) => {
  const hasValidVideoId = typeof trackId === 'string' && YOUTUBE_VIDEO_ID_RE.test(trackId);
  const normalizedSrc = getHDArtworkUrl(src, hasValidVideoId ? trackId : '');

  const [imgSrc, setImgSrc] = useState(normalizedSrc);
  const [stage, setStage] = useState(normalizedSrc ? 0 : 3);

  useEffect(() => {
    const nextSrc = getHDArtworkUrl(src, hasValidVideoId ? trackId : '');
    setImgSrc(nextSrc);
    setStage(nextSrc ? 0 : 3);
  }, [src, trackId, hasValidVideoId]);

  const advanceFallback = (failedSrc) => {
    const current = failedSrc || imgSrc || '';
    const isYt = current.includes('ytimg.com') || current.includes('youtube.com');
    const canonicalYt = hasValidVideoId ? `https://i.ytimg.com/vi/${trackId}/hqdefault.jpg` : '';

    // Never proxy ytimg URLs through wsrv.nl (it turns YouTube 404 grey 120x90 icons into 200 OK)
    if (stage === 0 && !isYt && normalizedSrc && !normalizedSrc.includes('wsrv.nl') && !normalizedSrc.startsWith('/')) {
      setStage(1);
      setImgSrc(`https://wsrv.nl/?url=${encodeURIComponent(normalizedSrc)}&w=400&h=400&fit=cover`);
      return;
    }

    if (stage < 2 && canonicalYt && current !== canonicalYt) {
      setStage(2);
      setImgSrc(canonicalYt);
      return;
    }

    setStage(3);
  };

  const handleLoad = (e) => {
    const img = e.currentTarget;
    const activeUrl = img.currentSrc || img.src || '';
    const isYt = activeUrl.includes('ytimg.com') || activeUrl.includes('youtube.com');
    // YouTube returns a 120x90 grey [•••] image for missing/deleted covers
    if (img.naturalWidth === 0 || (isYt && img.naturalWidth <= 120 && img.naturalHeight <= 90)) {
      advanceFallback(activeUrl);
    }
  };

  if (stage >= 3 || !imgSrc) {
    return (
      <div
        className={`w-full h-full flex flex-col items-center justify-center bg-gradient-to-tr from-pink-900/40 via-purple-900/40 to-slate-900/60 text-white/50 ${fallbackClassName}`}
      >
        <Music size={iconSize} className="text-white/60" />
        {showBrand && (
          <span className="text-[10px] font-bold text-white/45 tracking-wider uppercase mt-1">
            {brandLabel}
          </span>
        )}
      </div>
    );
  }

  return (
    <img
      src={imgSrc}
      alt={alt}
      referrerPolicy="no-referrer"
      className={className}
      loading={loading}
      onLoad={handleLoad}
      onError={(e) => advanceFallback(e.currentTarget.currentSrc || e.currentTarget.src)}
    />
  );
};

