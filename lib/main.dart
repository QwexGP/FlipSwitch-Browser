import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/models/profile_model.dart';
import 'data/services/profile_manager.dart';
import 'features/browser/okak/okak_engine.dart';
import 'features/browser/okak/tor/tor_status.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  // Инициализация Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация БД Hive
  await Hive.initFlutter();
  
  // Регистрация адаптера (ручной, без codegen)
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ProfileModelAdapter());
  }

  await ProfileManager.ensureSeeded();
  
  runApp(const FlipSwitchApp());
}

class FlipSwitchApp extends StatefulWidget {
  const FlipSwitchApp({super.key});

  @override
  State<FlipSwitchApp> createState() => _FlipSwitchAppState();
}

class _FlipSwitchAppState extends State<FlipSwitchApp> {
  BrowserMode mode = BrowserMode.normal;
  String selectedProfileId = 'pixel9pro';
  final TextEditingController address = TextEditingController(text: 'https://whoer.net');
  String pageTitle = 'FlipSwitch';
  String _lastResolvedUrl = 'https://whoer.net';

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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: FutureBuilder(
        future: ProfileManager.openProfilesBox(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final box = snap.data!;
          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final profiles = box.values.toList(growable: false);
              final selected = box.get(selectedProfileId) ?? profiles.first;
              if (box.get(selectedProfileId) == null && profiles.isNotEmpty) {
                selectedProfileId = profiles.first.id;
              }

              return Scaffold(
                body: SafeArea(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          children: [
                            _ProfilesStrip(
                              profiles: profiles,
                              selectedId: selectedProfileId,
                              onSelect: (id) {
                                setState(() {
                                  selectedProfileId = id;
                                });
                              },
                            ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.1, end: 0),
                            const SizedBox(height: 12),
                            _GlassToggle(
                              leftLabel: 'Normal Mode',
                              rightLabel: 'Dark Mode',
                              accent: const Color(0xFF1DA1F2),
                              value: mode == BrowserMode.dark,
                              onChanged: (v) {
                                setState(() {
                                  mode = v ? BrowserMode.dark : BrowserMode.normal;
                                  // Dark mode often pairs with Tor-like profile defaults.
                                  if (mode == BrowserMode.dark && box.containsKey('dark_tor_generic')) {
                                    selectedProfileId = 'dark_tor_generic';
                                  }
                                });
                              },
                            ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.06, end: 0),
                            const SizedBox(height: 14),
                            _AddressBar(
                              controller: address,
                              accent: const Color(0xFF1DA1F2),
                              onGo: () {
                                final input = address.text.trim();
                                final resolved = _resolveAddressInput(input, mode);
                                address.text = resolved;
                                address.selection = TextSelection.fromPosition(
                                  TextPosition(offset: resolved.length),
                                );
                                setState(() {
                                  _lastResolvedUrl = resolved;
                                });
                              },
                            ).animate().fadeIn(duration: 360.ms).slideY(begin: -0.04, end: 0),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 26,
                                      offset: const Offset(0, 14),
                                    )
                                  ],
                                ),
                                child: OkakEngine(
                                  key: ValueKey('${selected.id}:${mode.name}:${_lastResolvedUrl}'),
                                  mode: mode,
                                  profile: selected,
                                  initialUrl: _lastResolvedUrl.trim().isEmpty ? 'https://whoer.net' : _lastResolvedUrl.trim(),
                                  onTitleChanged: (t) => setState(() => pageTitle = t),
                                ),
                              ).animate().fadeIn(duration: 420.ms),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pageTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: _TorIndicator(mode: mode),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _resolveAddressInput(String input, BrowserMode mode) {
  if (input.isEmpty) return 'https://whoer.net';

  final lower = input.toLowerCase();
  final hasScheme = lower.startsWith('http://') || lower.startsWith('https://');

  // Quick heuristics: treat as URL if it has a dot, localhost, or an IPv4.
  final looksLikeIpv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/.*)?$').hasMatch(lower);
  final looksLikeHost = lower == 'localhost' || lower.startsWith('localhost:') || lower.startsWith('localhost/');
  final hasDot = lower.contains('.');

  final looksLikeUrl = hasScheme || looksLikeIpv4 || looksLikeHost || hasDot;
  if (!looksLikeUrl) {
    final q = Uri.encodeQueryComponent(input);
    if (mode == BrowserMode.dark) {
      return 'https://duckduckgo.com/?q=$q';
    }
    return 'https://www.google.com/search?q=$q';
  }

  if (hasScheme) return input;
  return 'https://$input';
}

class _ProfilesStrip extends StatelessWidget {
  const _ProfilesStrip({
    required this.profiles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ProfileModel> profiles;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = profiles[i];
          final selected = p.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(p.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(p.avatarGradientA),
                    Color(p.avatarGradientB),
                  ],
                ),
                border: Border.all(
                  color: selected ? const Color(0xFF1DA1F2) : Colors.white.withOpacity(0.12),
                  width: selected ? 2.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0xFF1DA1F2).withOpacity(0.35)
                        : Colors.black.withOpacity(0.35),
                    blurRadius: selected ? 18 : 10,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  p.name.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String leftLabel;
  final String rightLabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              label: leftLabel,
              active: !value,
              accent: accent,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleChip(
              label: rightLabel,
              active: value,
              accent: accent,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? accent.withOpacity(0.20) : Colors.white.withOpacity(0.04),
          border: Border.all(color: active ? accent.withOpacity(0.65) : Colors.white.withOpacity(0.10)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.white.withOpacity(0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.onGo,
    required this.accent,
  });

  final TextEditingController controller;
  final VoidCallback onGo;
  final Color accent;

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
          const Icon(Icons.lock_outline, size: 18, color: Color(0xFF1DA1F2)),
          const SizedBox(width: 10),
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onGo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: accent.withOpacity(0.22),
                border: Border.all(color: accent.withOpacity(0.70)),
              ),
              child: const Text('Go', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TorIndicator extends StatelessWidget {
  const _TorIndicator({required this.mode});

  final BrowserMode mode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: TorStatusController.instance.stream,
      initialData: TorStatusController.instance.state,
      builder: (context, snap) {
        final s = snap.data ?? TorState.unavailable;
        final show = mode == BrowserMode.dark;
        if (!show) return const SizedBox.shrink();

        final (label, color) = switch (s) {
          TorState.ready => ('Tor: ready', const Color(0xFF00FFA8)),
          TorState.connecting => ('Tor: connecting', const Color(0xFF1DA1F2)),
          TorState.unavailable => ('Tor: unavailable', Colors.orange),
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600)),
            ],
          ),
        ).animate().fadeIn(duration: 220.ms);
      },
    );
  }
}