import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/services/profile_manager.dart';
import '../../../data/services/settings_manager.dart';
import '../../browser/okak/tor/tor_status.dart';

class FlipEngine extends StatefulWidget {
  const FlipEngine({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.profileKey,
    required this.onControllerReady,
  });

  final String tabId;
  final String initialUrl;
  final String profileKey;
  final ValueChanged<InAppWebViewController?> onControllerReady;

  @override
  State<FlipEngine> createState() => _FlipEngineState();
}

class _FlipEngineState extends State<FlipEngine> {
  Box<SettingsModel>? _settingsBox;
  Box<ProfileModel>? _profilesBox;

  InAppWebViewController? _controller;
  double _torProgress = 0.0;
  Timer? _progressTimer;

  String _lastSig = '';

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _bindTorProgress();
  }

  @override
  void didUpdateWidget(covariant FlipEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileKey != widget.profileKey) {
      unawaited(_reloadNow());
    }
  }

  @override
  void dispose() {
    widget.onControllerReady(null);
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    final s = await SettingsManager.openBox();
    final p = await ProfileManager.openProfilesBox();
    if (!mounted) return;
    setState(() {
      _settingsBox = s;
      _profilesBox = p;
    });
  }

  void _bindTorProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final st = TorStatusController.instance.state;
      if (st == TorState.ready) {
        if (_torProgress != 1.0) setState(() => _torProgress = 1.0);
        return;
      }
      if (st == TorState.unavailable) {
        if (_torProgress != 0.0) setState(() => _torProgress = 0.0);
        return;
      }
      final next = (_torProgress + 0.02).clamp(0.0, 0.9);
      if (next != _torProgress) setState(() => _torProgress = next);
    });
  }

  Future<void> _reloadNow() async {
    try {
      await _controller?.reload();
    } catch (_) {}
  }

  Future<void> _applyIfChanged(ProfileModel prof, SettingsModel s) async {
    final sig = [
      widget.profileKey,
      prof.userAgent,
      prof.platform,
      prof.vendor,
      prof.screenWidth,
      prof.screenHeight,
      prof.hardwareConcurrency,
      prof.deviceMemory,
      prof.colorDepth,
      s.networkMode.name,
      s.identitySeed,
      s.spoofCanvas,
      s.spoofWebgl,
      s.spoofAudioContext,
    ].join('|');

    if (sig == _lastSig) return;
    _lastSig = sig;

    final c = _controller;
    if (c == null) return;

    try {
      await c.setSettings(
        settings: InAppWebViewSettings(
          userAgent: prof.userAgent,
          incognito: s.networkMode != NetworkMode.direct,
          cacheEnabled: s.networkMode == NetworkMode.direct,
          javaScriptEnabled: true,
          hardwareAcceleration: false,
        ),
      );
    } catch (_) {}

    await _reloadNow();
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

        return ValueListenableBuilder(
          valueListenable: profilesBox.listenable(keys: [widget.profileKey]),
          builder: (context, _, __) {
            final prof = profilesBox.get(widget.profileKey) ?? ProfileModel.defaultProfile();

            final wvSettings = InAppWebViewSettings(
              userAgent: prof.userAgent,
              javaScriptEnabled: true,
              incognito: s.networkMode != NetworkMode.direct,
              cacheEnabled: s.networkMode == NetworkMode.direct,
              transparentBackground: true,
              hardwareAcceleration: false,
            );

            unawaited(_applyIfChanged(prof, s));

            return Column(
              children: [
                LinearProgressIndicator(
                  value: _torProgress,
                  minHeight: 3,
                  backgroundColor: Colors.black,
                  color: const Color(0xFFBB86FC),
                ),
                Expanded(
                  child: InAppWebView(
                    key: ValueKey('${widget.tabId}:${widget.profileKey}:${_lastSig}'),
                    initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                    initialSettings: wvSettings,
                    onWebViewCreated: (c) {
                      _controller = c;
                      widget.onControllerReady(c);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

