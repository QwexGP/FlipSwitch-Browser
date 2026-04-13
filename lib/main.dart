import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/models/profile_model.dart';
import 'data/models/settings_model.dart';
import 'data/services/profile_manager.dart';
import 'data/services/settings_manager.dart';
import 'features/browser/okak/engine_core.dart';
import 'features/browser/okak/tor/tor_status.dart';
import 'ui/settings/settings_screen.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ProfileModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(SettingsModelAdapter());
  }

  await ProfileManager.ensureSeeded();
  await SettingsManager.getOrCreate();
  
  runApp(const FlipSwitchApp());
}

class FlipSwitchApp extends StatefulWidget {
  const FlipSwitchApp({super.key});

  @override
  State<FlipSwitchApp> createState() => _FlipSwitchAppState();
}

class _FlipSwitchAppState extends State<FlipSwitchApp> {
  final TextEditingController address = TextEditingController(text: 'https://check.torproject.org/');
  String pageTitle = 'FlipSwitch';
  String currentUrl = 'https://check.torproject.org/';
  InAppWebViewController? controller;

  @override
  void initState() {
    super.initState();
    TorStatusController.instance.start();
  }

  @override
  void dispose() {
    address.dispose();
    TorStatusController.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF000000)),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                controller: address,
                onGo: () async {
                  final input = address.text.trim();
                  final resolved = await _resolveInputWithSettings(input);
                  address.text = resolved;
                  address.selection = TextSelection.fromPosition(TextPosition(offset: resolved.length));
                  setState(() => currentUrl = resolved);
                },
                onShield: () => _showShieldSheet(context),
                onNewIdentity: () async {
                  final box = await SettingsManager.openBox();
                  final s = box.get(SettingsManager.key) ?? SettingsModel.defaults();
                  await box.put(SettingsManager.key, s.copyWith(identitySeed: s.identitySeed + 1));
                  await panicClearAndCloseTab(controller);
                  setState(() {});
                },
                onMenu: () => _showMenuSheet(context),
              ),
              Expanded(
                child: OkakEngineCore(
                  initialUrl: currentUrl,
                  onTitleChanged: (t) => setState(() => pageTitle = t),
                  onControllerReady: (c) => controller = c,
                ),
              ),
            ],
          ),
        ),
      ),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
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
    if (looksLikeUrl) {
      return hasScheme ? input : 'https://$input';
    }

    final box = await SettingsManager.openBox();
    final s = box.get(SettingsManager.key) ?? SettingsModel.defaults();
    final q = Uri.encodeQueryComponent(input);
    final isTor = s.networkMode != NetworkMode.direct;
    return isTor ? 'https://duckduckgo.com/?q=$q' : 'https://www.google.com/search?q=$q';
  }

  void _showShieldSheet(BuildContext context) {
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
              final label = switch (s) {
                TorState.ready => 'Tor ready',
                TorState.connecting => 'Tor connecting',
                TorState.unavailable => 'Tor unavailable',
              };
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 12),
                  FutureBuilder(
                    future: SettingsManager.openBox(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final box = snap.data!;
                      final st = box.get(SettingsManager.key) ?? SettingsModel.defaults();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill('Canvas', st.spoofCanvas),
                          _pill('WebGL', st.spoofWebgl),
                          _pill('Audio', st.spoofAudioContext),
                          _pill('Battery', st.spoofBattery),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _pill(String text, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: on ? const Color(0xFF1DA1F2).withOpacity(0.18) : Colors.white.withOpacity(0.06),
        border: Border.all(color: on ? const Color(0xFF1DA1F2).withOpacity(0.55) : Colors.white.withOpacity(0.10)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600)),
    );
  }

  void _showMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                title: const Text('Panic Button'),
                subtitle: const Text('Clear cookies/storage and close tab'),
                onTap: () async {
                  Navigator.pop(context);
                  await panicClearAndCloseTab(controller);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onGo,
    required this.onShield,
    required this.onNewIdentity,
    required this.onMenu,
  });

  final TextEditingController controller;
  final VoidCallback onGo;
  final VoidCallback onShield;
  final VoidCallback onNewIdentity;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onShield,
              icon: const Icon(Icons.shield_outlined),
              color: const Color(0xFF1DA1F2),
              tooltip: 'Protection status',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onGo(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search or enter address',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                ),
              ),
            ),
            TextButton(
              onPressed: onGo,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1DA1F2).withOpacity(0.22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onNewIdentity,
              icon: const Icon(Icons.autorenew),
              color: Colors.white.withOpacity(0.9),
              tooltip: 'New Identity',
            ),
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu),
              color: Colors.white.withOpacity(0.9),
              tooltip: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}