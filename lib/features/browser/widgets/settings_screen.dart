import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/settings_model.dart';
import '../../../data/services/settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color bg = Color(0xFF000000);
  static const Color accent = Color(0xFFBB86FC);
  static const String mono = 'monospace';

  final TextEditingController bridgesCtrl = TextEditingController();

  @override
  void dispose() {
    bridgesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SettingsManager.openBox(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final box = snap.data!;
        final s = box.get(SettingsManager.key) ?? SettingsModel.defaults();
        if (bridgesCtrl.text.isEmpty && s.bridgesObfs4Lines.isNotEmpty) {
          bridgesCtrl.text = s.bridgesObfs4Lines;
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            title: const Text('Настройки', style: TextStyle(fontFamily: mono)),
            iconTheme: const IconThemeData(color: accent),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _Section(
                title: 'Приватность',
                children: [
                  _SwitchTile(
                    title: 'Canvas',
                    value: s.spoofCanvas,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofCanvas: v)),
                  ),
                  _SwitchTile(
                    title: 'WebGL',
                    value: s.spoofWebgl,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofWebgl: v)),
                  ),
                  _SwitchTile(
                    title: 'AudioContext',
                    value: s.spoofAudioContext,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofAudioContext: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Личность',
                children: [
                  _DropdownTile<UaFamily>(
                    title: 'User-Agent',
                    value: s.uaFamily,
                    items: const [
                      (UaFamily.android, 'Android'),
                      (UaFamily.ios, 'iOS'),
                      (UaFamily.windows, 'Windows'),
                      (UaFamily.mac, 'Mac'),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      SettingsManager.put(s.copyWith(uaFamily: v));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Подключение',
                children: [
                  _DropdownTile<NetworkMode>(
                    title: 'Мосты Tor',
                    value: s.networkMode,
                    items: const [
                      (NetworkMode.direct, 'Direct'),
                      (NetworkMode.bridgesObfs4, 'obfs4'),
                      (NetworkMode.snowflake, 'Snowflake'),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      SettingsManager.put(s.copyWith(networkMode: v));
                    },
                  ),
                  if (s.networkMode == NetworkMode.bridgesObfs4) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Если стандартное подключение заблокировано, получите мосты одним из способов ниже и вставьте их в поле ввода:',
                      style: TextStyle(
                        fontFamily: mono,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _BrutalButton(
                            text: 'Получить в Telegram (@GetBridgesBot)',
                            onPressed: () => _openUrl('https://t.me/GetBridgesBot'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _BrutalButton(
                            text: 'Сайт Tor Bridges',
                            onPressed: () => _openUrl('https://bridges.torproject.org/options'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: TextField(
                        controller: bridgesCtrl,
                        maxLines: 6,
                        style: const TextStyle(color: Colors.white, fontFamily: mono),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Вставьте строки мостов obfs4 (по одной на строку)',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.40),
                            fontFamily: mono,
                          ),
                        ),
                        onChanged: (v) => SettingsManager.put(s.copyWith(bridgesObfs4Lines: v)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white.withOpacity(0.92),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontFamily: 'monospace',
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFBB86FC),
        ),
      ],
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontFamily: 'monospace',
            ),
          ),
        ),
        DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF111111),
          underline: const SizedBox.shrink(),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e.$1,
                  child: Text(
                    e.$2,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BrutalButton extends StatelessWidget {
  const _BrutalButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFBB86FC), width: 2),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }
}

