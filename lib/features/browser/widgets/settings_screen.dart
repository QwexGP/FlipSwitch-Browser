import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/services/profile_manager.dart';
import '../../../data/services/settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.profileKey});
  final String profileKey;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color bg = Color(0xFF000000);
  static const Color accent = Color(0xFFBB86FC);
  static const String mono = 'monospace';

  final TextEditingController ua = TextEditingController();
  final TextEditingController platform = TextEditingController();
  final TextEditingController vendor = TextEditingController();
  final TextEditingController sw = TextEditingController();
  final TextEditingController sh = TextEditingController();
  final TextEditingController cores = TextEditingController();
  final TextEditingController ram = TextEditingController();
  final TextEditingController depth = TextEditingController();
  final TextEditingController bridges = TextEditingController();

  @override
  void dispose() {
    ua.dispose();
    platform.dispose();
    vendor.dispose();
    sw.dispose();
    sh.dispose();
    cores.dispose();
    ram.dispose();
    depth.dispose();
    bridges.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  int _toInt(String s, int fallback) => int.tryParse(s.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        SettingsManager.openBox(),
        ProfileManager.openProfilesBox(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final boxes = snap.data as List;
        final settingsBox = boxes[0] as Box<SettingsModel>;
        final profilesBox = boxes[1] as Box<ProfileModel>;

        final s = settingsBox.get(SettingsManager.key) ?? SettingsModel.defaults();
        final p = profilesBox.get(widget.profileKey) ?? ProfileModel.defaultProfile();

        if (ua.text.isEmpty) ua.text = p.userAgent;
        if (platform.text.isEmpty) platform.text = p.platform;
        if (vendor.text.isEmpty) vendor.text = p.vendor;
        if (sw.text.isEmpty) sw.text = p.screenWidth.toString();
        if (sh.text.isEmpty) sh.text = p.screenHeight.toString();
        if (cores.text.isEmpty) cores.text = p.hardwareConcurrency.toString();
        if (ram.text.isEmpty) ram.text = p.deviceMemory.toString();
        if (depth.text.isEmpty) depth.text = p.colorDepth.toString();
        if (bridges.text.isEmpty) bridges.text = s.bridgesObfs4Lines;

        Future<void> saveProfile() async {
          final updated = ProfileModel(
            name: p.name,
            userAgent: ua.text,
            platform: platform.text,
            vendor: vendor.text,
            screenWidth: _toInt(sw.text, p.screenWidth),
            screenHeight: _toInt(sh.text, p.screenHeight),
            hardwareConcurrency: _toInt(cores.text, p.hardwareConcurrency),
            deviceMemory: _toInt(ram.text, p.deviceMemory),
            colorDepth: _toInt(depth.text, p.colorDepth),
          );
          await profilesBox.put(widget.profileKey, updated);
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            iconTheme: const IconThemeData(color: accent),
            title: const Text('Настройки', style: TextStyle(fontFamily: mono)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Block(
                title: 'Профиль',
                child: Column(
                  children: [
                    _Field(label: 'User-Agent', c: ua, onChanged: (_) => saveProfile()),
                    _Field(label: 'Platform', c: platform, onChanged: (_) => saveProfile()),
                    _Field(label: 'Vendor', c: vendor, onChanged: (_) => saveProfile()),
                    Row(
                      children: [
                        Expanded(child: _Field(label: 'Ширина', c: sw, onChanged: (_) => saveProfile(), keyboard: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _Field(label: 'Высота', c: sh, onChanged: (_) => saveProfile(), keyboard: TextInputType.number)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _Field(label: 'Cores', c: cores, onChanged: (_) => saveProfile(), keyboard: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _Field(label: 'RAM (GB)', c: ram, onChanged: (_) => saveProfile(), keyboard: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _Field(label: 'Depth', c: depth, onChanged: (_) => saveProfile(), keyboard: TextInputType.number)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Block(
                title: 'Приватность',
                child: Column(
                  children: [
                    _SwitchRow(
                      label: 'Canvas',
                      value: s.spoofCanvas,
                      onChanged: (v) => SettingsManager.put(s.copyWith(spoofCanvas: v)),
                    ),
                    _SwitchRow(
                      label: 'WebGL',
                      value: s.spoofWebgl,
                      onChanged: (v) => SettingsManager.put(s.copyWith(spoofWebgl: v)),
                    ),
                    _SwitchRow(
                      label: 'AudioContext',
                      value: s.spoofAudioContext,
                      onChanged: (v) => SettingsManager.put(s.copyWith(spoofAudioContext: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Block(
                title: 'Подключение',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Dropdown<NetworkMode>(
                      label: 'Мосты Tor',
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
                    const SizedBox(height: 10),
                    const Text(
                      'Если стандартное подключение заблокировано, получите мосты одним из способов ниже и вставьте их в поле ввода:',
                      style: TextStyle(fontFamily: mono, color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _BrutalLink(
                            text: 'Получить в Telegram (@GetBridgesBot)',
                            onTap: () => _openUrl('https://t.me/GetBridgesBot'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _BrutalLink(
                            text: 'Сайт Tor Bridges',
                            onTap: () => _openUrl('https://bridges.torproject.org/options'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: 'Строки мостов (obfs4)',
                      c: bridges,
                      maxLines: 6,
                      onChanged: (v) => SettingsManager.put(s.copyWith(bridgesObfs4Lines: v)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFBB86FC), width: 1)),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFBB86FC), fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.c,
    required this.onChanged,
    this.keyboard,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController c;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboard;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'monospace', color: Color(0xFFBB86FC)),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFFBB86FC), width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFFBB86FC), width: 1),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'monospace', color: Colors.white))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFBB86FC),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'monospace', color: Colors.white))),
        DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF000000),
          underline: const SizedBox.shrink(),
          items: items
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontFamily: 'monospace', color: Colors.white))))
              .toList(),
          onChanged: onChanged,
        )
      ],
    );
  }
}

class _BrutalLink extends StatelessWidget {
  const _BrutalLink({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFBB86FC), width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900)),
    );
  }
}

