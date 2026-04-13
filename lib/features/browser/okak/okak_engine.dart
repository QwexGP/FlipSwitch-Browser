import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../data/models/profile_model.dart';
import 'injections/fingerprint_js.dart';

enum BrowserMode {
  normal,
  dark,
}

class OkakEngine extends StatefulWidget {
  const OkakEngine({
    super.key,
    required this.mode,
    required this.profile,
    required this.initialUrl,
    required this.onTitleChanged,
  });

  final BrowserMode mode;
  final ProfileModel profile;
  final String initialUrl;
  final ValueChanged<String> onTitleChanged;

  @override
  State<OkakEngine> createState() => _OkakEngineState();
}

class _OkakEngineState extends State<OkakEngine> {
  InAppWebViewController? _controller;
  final Completer<void> _controllerReady = Completer<void>();

  @override
  void initState() {
    super.initState();
    unawaited(_applyNetworkMode());
  }

  @override
  void didUpdateWidget(covariant OkakEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.mode != widget.mode || oldWidget.profile.id != widget.profile.id;
    if (changed) {
      unawaited(_applyNetworkMode());
      _hardReloadWithNewIdentity();
    }
  }

  Future<void> _applyNetworkMode() async {
    // Data isolation:
    // - iOS: `incognito:true` uses WKWebsiteDataStore.nonPersistent (isolated).
    // - Android: true isolation isn't supported by the native WebView; we still
    //   enable `incognito` to avoid persistence and reduce cross-mode leakage.
    //
    // Tor proxy:
    // - Android: use WebView ProxyController if the feature is supported.
    // - Other platforms: keep settings consistent (actual proxying is platform-dependent).
    final isDark = widget.mode == BrowserMode.dark;

    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final supported =
            await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
        if (!supported) return;

        final proxyController = ProxyController.instance();
        if (isDark) {
          await proxyController.clearProxyOverride();
          await proxyController.setProxyOverride(
            settings: ProxySettings(
              proxyRules: const [
                ProxyRule(url: 'socks5://127.0.0.1:9050'),
              ],
              bypassRules: const [],
            ),
          );
        } else {
          await proxyController.clearProxyOverride();
        }
      } catch (_) {}
    }
  }

  Future<void> _hardReloadWithNewIdentity() async {
    try {
      if (!_controllerReady.isCompleted) return;
      await _controllerReady.future;
      // Re-apply injection ASAP and reload.
      await _applyInjections();
      await _controller?.reload();
    } catch (_) {}
  }

  Future<void> _applyInjections() async {
    final c = _controller;
    if (c == null) return;

    // Primary fingerprint injection (navigator/screen/canvas).
    final fp = buildFingerprintInjection(widget.profile);
    await c.evaluateJavascript(source: fp);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.mode == BrowserMode.dark;
    final settings = InAppWebViewSettings(
      userAgent: widget.profile.userAgent,
      javaScriptEnabled: true,
      transparentBackground: true,
      disableContextMenu: true,
      supportZoom: false,
      useOnLoadResource: false,
      mediaPlaybackRequiresUserGesture: false,
      incognito: isDark,
      cacheEnabled: !isDark,
      // Helps on older GPUs/drivers; webview still uses platform rendering.
      hardwareAcceleration: false,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
        initialSettings: settings,
        onWebViewCreated: (controller) async {
          _controller = controller;
          if (!_controllerReady.isCompleted) _controllerReady.complete();
          await _applyInjections();
        },
        onLoadStart: (controller, url) async {
          await _applyInjections();
        },
        onLoadStop: (controller, url) async {
          await _applyInjections();
        },
        onTitleChanged: (controller, title) {
          if (title != null && title.isNotEmpty) widget.onTitleChanged(title);
        },
      ),
    );
  }
}

