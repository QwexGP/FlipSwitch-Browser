import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/models/settings_model.dart';
import '../../data/services/settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController bridgesCtrl = TextEditingController();

  @override
  void dispose() {
    bridgesCtrl.dispose();
    super.dispose();
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
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _Section(
                title: 'Fingerprinting',
                children: [
                  _SwitchTile(
                    title: 'Canvas Spoofing',
                    value: s.spoofCanvas,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofCanvas: v)),
                  ),
                  _SwitchTile(
                    title: 'WebGL Spoofing',
                    value: s.spoofWebgl,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofWebgl: v)),
                  ),
                  _SwitchTile(
                    title: 'AudioContext Spoofing',
                    value: s.spoofAudioContext,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofAudioContext: v)),
                  ),
                  _SwitchTile(
                    title: 'Battery Status',
                    value: s.spoofBattery,
                    onChanged: (v) => SettingsManager.put(s.copyWith(spoofBattery: v)),
                  ),
                ],
              ).animate().fadeIn(duration: 220.ms),
              const SizedBox(height: 12),
              _Section(
                title: 'Identity',
                children: [
                  _DropdownTile<UaFamily>(
                    title: 'User-Agent family',
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
              ).animate().fadeIn(duration: 260.ms),
              const SizedBox(height: 12),
              _Section(
                title: 'Network',
                children: [
                  _DropdownTile<NetworkMode>(
                    title: 'Tor routing',
                    value: s.networkMode,
                    items: const [
                      (NetworkMode.direct, 'Direct'),
                      (NetworkMode.bridgesObfs4, 'Bridges (obfs4)'),
                      (NetworkMode.snowflake, 'Snowflake'),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      SettingsManager.put(s.copyWith(networkMode: v));
                    },
                  ),
                  if (s.networkMode == NetworkMode.bridgesObfs4) ...[
                    const SizedBox(height: 8),
                    _GlassCard(
                      child: TextField(
                        controller: bridgesCtrl,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Paste obfs4 bridge lines (one per line)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        ),
                        onChanged: (v) => SettingsManager.put(s.copyWith(bridgesObfs4Lines: v)),
                      ),
                    ),
                  ],
                ],
              ).animate().fadeIn(duration: 300.ms),
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
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
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
          child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.88))),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1DA1F2),
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
          child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.88))),
        ),
        DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF111111),
          underline: const SizedBox.shrink(),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e.$1,
                  child: Text(e.$2, style: const TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

