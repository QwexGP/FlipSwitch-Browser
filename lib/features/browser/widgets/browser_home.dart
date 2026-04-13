import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../data/models/settings_model.dart';
import '../../../data/services/settings_manager.dart';
import '../okak/engine_core.dart';
import '../okak/tor/tor_status.dart';
import 'settings_screen.dart';

class BrowserHome extends StatefulWidget {
  const BrowserHome({super.key});

  @override
  State<BrowserHome> createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> {
  final TextEditingController address = TextEditingController(
    text: 'https://check.torproject.org/',
  );
  String currentUrl = 'https://check.torproject.org/';
  InAppWebViewController? controller;
  String title = 'FlipSwitch';

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  Future<void> _newIdentity() async {
    final box = await SettingsManager.openBox();
    final s = box.get(SettingsManager.key) ?? SettingsModel.defaults();
    await box.put(SettingsManager.key, s.copyWith(identitySeed: s.identitySeed + 1));
    await panicClearAndCloseTab(controller);
    setState(() {});
  }

  Future<void> _go() async {
    final input = address.text.trim();
    final resolved = await _resolveInputWithSettings(input);
    address.text = resolved;
    address.selection = TextSelection.fromPosition(TextPosition(offset: resolved.length));
    setState(() => currentUrl = resolved);
  }

  Future<String> _resolveInputWithSettings(String input) async {
    if (input.isEmpty) return currentUrl;

    final lower = input.toLowerCase();
    final hasScheme = lower.startsWith('http://') || lower.startsWith('https://');
    final hasDot = lower.contains('.');
    final looksLikeIpv4 =
        RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/.*)?$').hasMatch(lower);
    final looksLikeHost =
        lower == 'localhost' || lower.startsWith('localhost:') || lower.startsWith('localhost/');

    final looksLikeUrl = hasScheme || hasDot || looksLikeIpv4 || looksLikeHost;
    if (looksLikeUrl) return hasScheme ? input : 'https://$input';

    final box = await SettingsManager.openBox();
    final s = box.get(SettingsManager.key) ?? SettingsModel.defaults();
    final q = Uri.encodeQueryComponent(input);
    final isTor = s.networkMode != NetworkMode.direct;
    return isTor ? 'https://duckduckgo.com/?q=$q' : 'https://www.google.com/search?q=$q';
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  _ShieldButton(onPressed: () => _showTorStatus(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassAddressBar(
                      controller: address,
                      onGo: _go,
                      onNewIdentity: _newIdentity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.menu),
                    color: Colors.white.withOpacity(0.92),
                    tooltip: 'Настройки',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlipEngine(
                    initialUrl: currentUrl,
                    onTitleChanged: (t) => setState(() => title = t),
                    onControllerReady: (c) => controller = c,
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 74),
                        child: AnimatedOpacity(
                          opacity: currentUrl.isEmpty ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _FlipSwitchLogo(),
                              const SizedBox(height: 10),
                              Text(
                                'FlipSwitch',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Colors.white.withOpacity(0.90),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 180.ms);
  }

  void _showTorStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder(
            stream: TorStatusController.instance.stream,
            initialData: TorStatusController.instance.state,
            builder: (context, snap) {
              final s = snap.data ?? TorState.unavailable;
              final (label, color) = switch (s) {
                TorState.ready => ('Tor: ready', const Color(0xFF00FFA8)),
                TorState.connecting => ('Tor: connecting', const Color(0xFF1DA1F2)),
                TorState.unavailable => ('Tor: unavailable', Colors.orange),
              };
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Щит', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'monospace')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Управление отпечатком находится в настройках.',
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontFamily: 'monospace'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ShieldButton extends StatelessWidget {
  const _ShieldButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: const Icon(Icons.shield_outlined, color: Color(0xFFBB86FC)),
      ),
    );
  }
}

class _GlassAddressBar extends StatelessWidget {
  const _GlassAddressBar({
    required this.controller,
    required this.onGo,
    required this.onNewIdentity,
  });

  final TextEditingController controller;
  final VoidCallback onGo;
  final VoidCallback onNewIdentity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => onGo(),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Введите адрес или запрос',
                hintStyle: TextStyle(color: Colors.white54, fontFamily: 'monospace'),
              ),
            ),
          ),
          IconButton(
            onPressed: onNewIdentity,
            icon: const Icon(Icons.autorenew),
            color: Colors.white.withOpacity(0.92),
            tooltip: 'Новая личность',
          ),
        ],
      ),
    );
  }
}

class _FlipSwitchLogo extends StatelessWidget {
  const _FlipSwitchLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBB86FC), Color(0xFF6A00FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBB86FC).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Center(
        child: Text(
          'F',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white.withOpacity(0.95),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

