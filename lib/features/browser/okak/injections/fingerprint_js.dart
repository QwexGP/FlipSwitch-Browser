import '../../../../data/models/profile_model.dart';

/// Full (non-truncated) fingerprint injection.
///
/// - Overrides `navigator` surface (UA/platform/hw/memory).
/// - Overrides `screen` dimensions and DPR.
/// - Adds deterministic Canvas noise based on [ProfileModel.canvasSeed].
/// - Exposes synthetic "build props" at `navigator.buildProps` (non-standard).
///
/// Security note: The goal is consistency and per-profile stability.
/// Changing many independent APIs at random increases detectability.
String buildFingerprintInjection(ProfileModel p) {
  // Keep the JS as a single IIFE, no minification here (readability / audit).
  final buildPropsJson = _jsonStringifyMap(p.buildProps);

  return '''
(function() {
  'use strict';

  const PROFILE = Object.freeze({
    userAgent: ${_jsString(p.userAgent)},
    platform: ${_jsString(p.platform)},
    hardwareConcurrency: ${p.hardwareConcurrency},
    deviceMemory: ${p.deviceMemory},
    screen: Object.freeze({
      width: ${p.screen.width},
      height: ${p.screen.height},
      availWidth: ${p.screen.width},
      availHeight: ${p.screen.height},
      colorDepth: 24,
      pixelDepth: 24,
      devicePixelRatio: ${p.screen.devicePixelRatio.toStringAsFixed(3)}
    }),
    canvasSeed: ${p.canvasSeed},
    buildProps: ${buildPropsJson}
  });

  function defineProp(obj, prop, value) {
    try {
      Object.defineProperty(obj, prop, {
        get: function() { return value; },
        configurable: false,
        enumerable: true
      });
      return true;
    } catch (e) {}
    try {
      Object.defineProperty(obj, prop, {
        value: value,
        configurable: false,
        enumerable: true,
        writable: false
      });
      return true;
    } catch (e) {}
    return false;
  }

  // ------- navigator surface -------
  (function patchNavigator() {
    const navProto = Navigator && Navigator.prototype;
    if (!navProto) return;

    defineProp(navProto, 'userAgent', PROFILE.userAgent);
    defineProp(navProto, 'appVersion', PROFILE.userAgent);
    defineProp(navProto, 'platform', PROFILE.platform);
    defineProp(navProto, 'hardwareConcurrency', PROFILE.hardwareConcurrency);
    defineProp(navProto, 'deviceMemory', PROFILE.deviceMemory);

    // Non-standard: expose build props for internal scripts.
    // Keep enumerable so it can be read easily by our own code.
    try { defineProp(navProto, 'buildProps', PROFILE.buildProps); } catch (e) {}

    // Reduce entropy leaks from webdriver (do NOT claim false if real true in some contexts).
    try {
      if ('webdriver' in navProto) {
        Object.defineProperty(navProto, 'webdriver', {
          get: function() { return undefined; },
          configurable: false,
          enumerable: true
        });
      }
    } catch (e) {}
  })();

  // ------- screen surface -------
  (function patchScreen() {
    const sProto = Screen && Screen.prototype;
    if (!sProto) return;

    const s = PROFILE.screen;
    defineProp(sProto, 'width', s.width);
    defineProp(sProto, 'height', s.height);
    defineProp(sProto, 'availWidth', s.availWidth);
    defineProp(sProto, 'availHeight', s.availHeight);
    defineProp(sProto, 'colorDepth', s.colorDepth);
    defineProp(sProto, 'pixelDepth', s.pixelDepth);

    // devicePixelRatio is on Window, not Screen.
    try {
      const wProto = Window && Window.prototype;
      if (wProto) defineProp(wProto, 'devicePixelRatio', s.devicePixelRatio);
    } catch (e) {}
  })();

  // ------- deterministic PRNG (xorshift32) -------
  function makeRng(seed) {
    let x = (seed | 0) ^ 0xA5A5A5A5;
    if (x === 0) x = 0x12345678;
    return function() {
      // xorshift32
      x ^= (x << 13);
      x ^= (x >>> 17);
      x ^= (x << 5);
      // convert to [0,1)
      return ((x >>> 0) / 4294967296);
    };
  }

  // ------- canvas noise -------
  (function patchCanvas() {
    const seed = PROFILE.canvasSeed | 0;
    const rng = makeRng(seed);

    function clamp255(v) {
      v = v | 0;
      return v < 0 ? 0 : (v > 255 ? 255 : v);
    }

    function applyNoiseToImageData(imageData) {
      // ImageData.data is Uint8ClampedArray RGBA
      const data = imageData && imageData.data;
      if (!data || !data.length) return imageData;

      // Small noise budget: subtle and deterministic (avoid obvious artifacts).
      // We perturb a subset of pixels to keep runtime low.
      const len = data.length;
      const step = 16; // every 4 pixels (RGBA*4)
      for (let i = 0; i < len; i += step) {
        const n = (rng() - 0.5) * 6; // [-3..3)
        data[i]     = clamp255(data[i]     + n); // R
        data[i + 1] = clamp255(data[i + 1] + n); // G
        data[i + 2] = clamp255(data[i + 2] + n); // B
        // alpha untouched
      }
      return imageData;
    }

    // Patch 2D context getImageData/putImageData (most common fingerprint path).
    try {
      const ctxProto = CanvasRenderingContext2D && CanvasRenderingContext2D.prototype;
      if (ctxProto && ctxProto.getImageData) {
        const _getImageData = ctxProto.getImageData;
        Object.defineProperty(ctxProto, 'getImageData', {
          value: function(sx, sy, sw, sh) {
            const img = _getImageData.apply(this, arguments);
            try { return applyNoiseToImageData(img); } catch (e) {}
            return img;
          },
          configurable: false,
          enumerable: true,
          writable: false
        });
      }
    } catch (e) {}

    // Patch toDataURL and toBlob on HTMLCanvasElement.
    try {
      const cProto = HTMLCanvasElement && HTMLCanvasElement.prototype;
      if (cProto && cProto.toDataURL) {
        const _toDataURL = cProto.toDataURL;
        Object.defineProperty(cProto, 'toDataURL', {
          value: function() {
            try {
              // Touch pixels deterministically before export.
              const ctx = this.getContext && this.getContext('2d');
              if (ctx && ctx.getImageData && ctx.putImageData) {
                const w = Math.min(this.width || 0, 256);
                const h = Math.min(this.height || 0, 256);
                if (w > 0 && h > 0) {
                  const img = ctx.getImageData(0, 0, w, h);
                  applyNoiseToImageData(img);
                  ctx.putImageData(img, 0, 0);
                }
              }
            } catch (e) {}
            return _toDataURL.apply(this, arguments);
          },
          configurable: false,
          enumerable: true,
          writable: false
        });
      }
    } catch (e) {}

    // Patch WebGL readPixels (very common for "canvas/webgl fingerprint").
    try {
      const glProto = WebGLRenderingContext && WebGLRenderingContext.prototype;
      if (glProto && glProto.readPixels) {
        const _readPixels = glProto.readPixels;
        Object.defineProperty(glProto, 'readPixels', {
          value: function(x, y, width, height, format, type, pixels) {
            const r = _readPixels.apply(this, arguments);
            try {
              if (pixels && pixels.length) {
                // Light deterministic perturbation on a subset of bytes.
                const step = 32;
                for (let i = 0; i < pixels.length; i += step) {
                  const n = ((rng() - 0.5) * 3) | 0; // {-1,0,1}
                  pixels[i] = clamp255(pixels[i] + n);
                }
              }
            } catch (e) {}
            return r;
          },
          configurable: false,
          enumerable: true,
          writable: false
        });
      }
    } catch (e) {}
  })();

  // Mark injection (internal).
  try { window.__FLIPSWITCH_FP__ = true; } catch (e) {}
})();
''';
}

String _jsString(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

String _jsonStringifyMap(Map<String, String> map) {
  final entries = map.entries.map((e) => '${_jsString(e.key)}:${_jsString(e.value)}').join(',');
  return '{${entries}}';
}

