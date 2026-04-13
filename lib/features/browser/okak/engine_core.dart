import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/services/profile_manager.dart';
import '../../../data/services/settings_manager.dart';
import '../../../services/tor_bridge_service.dart';
import 'injections/fingerprint_modules.dart';
import 'proxy_handler.dart';

/// Core browser engine (WebView + network + modular injections).
class OkakEngineCore extends StatefulWidget {
  const OkakEngineCore({
    super.key,
    required this.initialUrl,
    required this.onTitleChanged,
    required this.onControllerReady,
  });

  final String initialUrl;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<InAppWebViewController?> onControllerReady;

  @override
  State<OkakEngineCore> createState() => _OkakEngineCoreState();
}

class _OkakEngineCoreState extends State<OkakEngineCore> {
  InAppWebViewController? _controller;
  final Completer<void> _ready = Completer<void>();

  Box<SettingsModel>? _settingsBox;
  Box<ProfileModel>? _profilesBox;

  @override
  void initState() {
    super.initState();
    unawaited(_initBoxes());
  }

  Future<void> _initBoxes() async {
    final sBox = await SettingsManager.openBox();
    final pBox = await ProfileManager.openProfilesBox();
    if (!mounted) return;
    setState(() {
      _settingsBox = sBox;
      _profilesBox = pBox;
    });
  }

  @override
  void dispose() {
    widget.onControllerReady(null);
    super.dispose();
  }

  Future<ProfileModel> _resolveProfile(SettingsModel s) async {
    final box = _profilesBox ?? await ProfileManager.openProfilesBox();

    // Map UA families to our built-in presets (keep stable for now).
    final id = switch (s.uaFamily) {
      UaFamily.android => 'pixel9pro',
      UaFamily.ios => 'iphone16pro',
      UaFamily.mac => 'macbookairm3',
      UaFamily.windows => 'win11chrome',
    };

    return box.get(id) ?? box.values.first;
  }

  Future<void> _applyAll(SettingsModel s, ProfileModel p) async {
    // Apply proxy routing (Android only).
    await ProxyHandler.apply(s);

    // Configure Tor bridges/snowflake via rust_core (best effort), then bootstrap.
    if (s.networkMode != NetworkMode.direct) {
      await TorBridgeService.instance.applyNetworkSettings(s);
    }

    // Apply JS injections after controller is ready.
    if (!_ready.isCompleted) return;
    await _ready.future;
    final c = _controller;
    if (c == null) return;
    for (final js in buildInjections(profile: p, settings: s)) {
      await c.evaluateJavascript(source: js);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = _settingsBox;
    final profilesBox = _profilesBox;
    if (settingsBox == null || profilesBox == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder(
      valueListenable: settingsBox.listenable(keys: [SettingsManager.key]),
      builder: (context, _, __) {
        final s = settingsBox.get(SettingsManager.key) ?? SettingsModel.defaults();

        return FutureBuilder(
          future: _resolveProfile(s),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final p = snap.data!;

            // WebView settings (incognito when not direct).
            final incognito = s.networkMode != NetworkMode.direct;
            final wvSettings = InAppWebViewSettings(
              userAgent: p.userAgent,
              javaScriptEnabled: true,
              transparentBackground: true,
              disableContextMenu: true,
              supportZoom: false,
              useOnLoadResource: false,
              mediaPlaybackRequiresUserGesture: false,
              incognito: incognito,
              cacheEnabled: !incognito,
              // helps older GPUs/drivers; platform view still renders natively.
              hardwareAcceleration: false,
            );

            // Apply changes eagerly.
            unawaited(_applyAll(s, p));

            return InAppWebView(
              key: ValueKey(
                [
                  widget.initialUrl,
                  s.uaFamily.name,
                  s.networkMode.name,
                  s.spoofCanvas,
                  s.spoofWebgl,
                  s.spoofAudioContext,
                  s.spoofBattery,
                  s.identitySeed,
                ].join(':'),
              ),
              initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
              initialSettings: wvSettings,
              onWebViewCreated: (controller) async {
                _controller = controller;
                widget.onControllerReady(controller);
                if (!_ready.isCompleted) _ready.complete();
                await _applyAll(s, p);
              },
              onLoadStart: (controller, url) async {
                await _applyAll(s, p);
              },
              onLoadStop: (controller, url) async {
                await _applyAll(s, p);
              },
              onTitleChanged: (controller, title) {
                if (title != null && title.isNotEmpty) widget.onTitleChanged(title);
              },
            );
          },
        );
      },
    );
  }
}

/// Panic button: clear storage and blank the tab.
Future<void> panicClearAndCloseTab(InAppWebViewController? controller) async {
  try {
    await CookieManager.instance().deleteAllCookies();
  } catch (_) {}
  try {
    await WebStorageManager.instance().deleteAllData();
  } catch (_) {}
  try {
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
  } catch (_) {}
}

