import '../../../../data/models/profile_model.dart';
import '../../../../data/models/settings_model.dart';

String buildNavigatorScreenInjection(ProfileModel p) {
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
    buildProps: ${buildPropsJson}
  });

  function defineProp(obj, prop, value) {
    try {
      Object.defineProperty(obj, prop, { get: function(){ return value; }, configurable: false, enumerable: true });
      return true;
    } catch (e) {}
    try {
      Object.defineProperty(obj, prop, { value: value, configurable: false, enumerable: true, writable: false });
      return true;
    } catch (e) {}
    return false;
  }

  (function patchNavigator() {
    const navProto = Navigator && Navigator.prototype;
    if (!navProto) return;
    defineProp(navProto, 'userAgent', PROFILE.userAgent);
    defineProp(navProto, 'appVersion', PROFILE.userAgent);
    defineProp(navProto, 'platform', PROFILE.platform);
    defineProp(navProto, 'hardwareConcurrency', PROFILE.hardwareConcurrency);
    defineProp(navProto, 'deviceMemory', PROFILE.deviceMemory);
    try { defineProp(navProto, 'buildProps', PROFILE.buildProps); } catch (e) {}
    try {
      if ('webdriver' in navProto) {
        Object.defineProperty(navProto, 'webdriver', { get: function(){ return undefined; }, configurable: false, enumerable: true });
      }
    } catch (e) {}
  })();

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
    try {
      const wProto = Window && Window.prototype;
      if (wProto) defineProp(wProto, 'devicePixelRatio', s.devicePixelRatio);
    } catch (e) {}
  })();

  try { window.__FLIPSWITCH_NAV__ = true; } catch(e) {}
})();
''';
}

String buildCanvasInjection(int seed) {
  return _noiseWrapper(seed, '''
  (function patchCanvas() {
    function clamp255(v) { v = v|0; return v < 0 ? 0 : (v > 255 ? 255 : v); }
    function applyNoiseToImageData(imageData, rng) {
      const data = imageData && imageData.data;
      if (!data || !data.length) return imageData;
      const len = data.length;
      const step = 16;
      for (let i = 0; i < len; i += step) {
        const n = (rng() - 0.5) * 6;
        data[i] = clamp255(data[i] + n);
        data[i+1] = clamp255(data[i+1] + n);
        data[i+2] = clamp255(data[i+2] + n);
      }
      return imageData;
    }

    try {
      const ctxProto = CanvasRenderingContext2D && CanvasRenderingContext2D.prototype;
      if (ctxProto && ctxProto.getImageData) {
        const _getImageData = ctxProto.getImageData;
        Object.defineProperty(ctxProto, 'getImageData', {
          value: function() {
            const img = _getImageData.apply(this, arguments);
            try { return applyNoiseToImageData(img, __fs_rng); } catch(e) {}
            return img;
          },
          configurable: false, enumerable: true, writable: false
        });
      }
    } catch(e) {}

    try {
      const cProto = HTMLCanvasElement && HTMLCanvasElement.prototype;
      if (cProto && cProto.toDataURL) {
        const _toDataURL = cProto.toDataURL;
        Object.defineProperty(cProto, 'toDataURL', {
          value: function() {
            try {
              const ctx = this.getContext && this.getContext('2d');
              if (ctx && ctx.getImageData && ctx.putImageData) {
                const w = Math.min(this.width || 0, 256);
                const h = Math.min(this.height || 0, 256);
                if (w > 0 && h > 0) {
                  const img = ctx.getImageData(0, 0, w, h);
                  applyNoiseToImageData(img, __fs_rng);
                  ctx.putImageData(img, 0, 0);
                }
              }
            } catch(e) {}
            return _toDataURL.apply(this, arguments);
          },
          configurable: false, enumerable: true, writable: false
        });
      }
    } catch(e) {}
  })();
''');
}

String buildWebglInjection(int seed) {
  return _noiseWrapper(seed ^ 0x6A09E667, '''
  (function patchWebGL() {
    function clamp255(v) { v = v|0; return v < 0 ? 0 : (v > 255 ? 255 : v); }
    try {
      const glProto = WebGLRenderingContext && WebGLRenderingContext.prototype;
      if (glProto && glProto.readPixels) {
        const _readPixels = glProto.readPixels;
        Object.defineProperty(glProto, 'readPixels', {
          value: function(x, y, width, height, format, type, pixels) {
            const r = _readPixels.apply(this, arguments);
            try {
              if (pixels && pixels.length) {
                const step = 32;
                for (let i = 0; i < pixels.length; i += step) {
                  const n = ((__fs_rng() - 0.5) * 3) | 0;
                  pixels[i] = clamp255(pixels[i] + n);
                }
              }
            } catch (e) {}
            return r;
          },
          configurable: false, enumerable: true, writable: false
        });
      }
    } catch(e) {}
  })();
''');
}

String buildAudioContextInjection(int seed) {
  // A conservative, deterministic perturbation for getFloatFrequencyData.
  return _noiseWrapper(seed ^ 0x3C6EF372, '''
  (function patchAudio() {
    try {
      const aProto = AnalyserNode && AnalyserNode.prototype;
      if (!aProto || !aProto.getFloatFrequencyData) return;
      const _orig = aProto.getFloatFrequencyData;
      Object.defineProperty(aProto, 'getFloatFrequencyData', {
        value: function(array) {
          const r = _orig.apply(this, arguments);
          try {
            if (array && array.length) {
              const step = 16;
              for (let i = 0; i < array.length; i += step) {
                const n = (__fs_rng() - 0.5) * 0.35; // subtle dB noise
                array[i] = array[i] + n;
              }
            }
          } catch(e) {}
          return r;
        },
        configurable: false, enumerable: true, writable: false
      });
    } catch(e) {}
  })();
''');
}

String buildBatteryInjection() {
  // Hide Battery Status API (common privacy posture).
  return '''
(function() {
  'use strict';
  try {
    if (navigator && navigator.getBattery) {
      Object.defineProperty(navigator, 'getBattery', {
        value: undefined,
        configurable: false,
        enumerable: true,
        writable: false
      });
    }
  } catch(e) {}
})();
''';
}

List<String> buildInjections({
  required ProfileModel profile,
  required SettingsModel settings,
}) {
  final seed = (profile.canvasSeed ^ settings.identitySeed) & 0x7fffffff;

  final scripts = <String>[];
  scripts.add(buildNavigatorScreenInjection(profile));
  if (settings.spoofCanvas) scripts.add(buildCanvasInjection(seed));
  if (settings.spoofWebgl) scripts.add(buildWebglInjection(seed));
  if (settings.spoofAudioContext) scripts.add(buildAudioContextInjection(seed));
  if (settings.spoofBattery) scripts.add(buildBatteryInjection());
  return scripts;
}

String _noiseWrapper(int seed, String body) {
  return '''
(function() {
  'use strict';
  function __fs_makeRng(seed) {
    let x = (seed | 0) ^ 0xA5A5A5A5;
    if (x === 0) x = 0x12345678;
    return function() {
      x ^= (x << 13);
      x ^= (x >>> 17);
      x ^= (x << 5);
      return ((x >>> 0) / 4294967296);
    };
  }
  const __fs_rng = __fs_makeRng(${seed});
  ${body}
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
  final entries =
      map.entries.map((e) => '${_jsString(e.key)}:${_jsString(e.value)}').join(',');
  return '{${entries}}';
}

