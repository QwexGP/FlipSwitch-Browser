import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/services/profile_manager.dart';
import '../engine/flip_engine.dart';
import 'settings_screen.dart';

class BrowserHome extends StatefulWidget {
  const BrowserHome({super.key});

  @override
  State<BrowserHome> createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> with TickerProviderStateMixin {
  static const Color bg = Color(0xFF000000);
  static const Color accent = Color(0xFFBB86FC);
  static const String mono = 'monospace';

  TabController? _tabController;
  final List<_TabData> _tabs = [
    _TabData(id: 't0', url: 'https://check.torproject.org/'),
  ];

  String _activeProfileKey = 'p0';
  final Map<String, InAppWebViewController?> _controllers = {};

  late final TextEditingController _address = TextEditingController(text: _tabs.first.url);

  @override
  void initState() {
    super.initState();
    _ensureDefaultProfile();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) return;
      setState(() {
        _address.text = _tabs[_tabController!.index].url;
      });
    });
  }

  Future<void> _ensureDefaultProfile() async {
    final box = await ProfileManager.openProfilesBox();
    if (box.isEmpty) {
      await box.put('p0', ProfileModel.defaultProfile());
    }
    if (!box.containsKey(_activeProfileKey)) {
      setState(() => _activeProfileKey = box.keys.first.toString());
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _address.dispose();
    super.dispose();
  }

  InAppWebViewController? get _activeController {
    final idx = _tabController?.index ?? 0;
    final tabId = _tabs[idx].id;
    return _controllers[tabId];
  }

  Future<void> _go() async {
    final idx = _tabController?.index ?? 0;
    final url = _normalizeInput(_address.text.trim());
    setState(() {
      _tabs[idx] = _tabs[idx].copyWith(url: url);
      _address.text = url;
    });
    try {
      await _activeController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (_) {}
  }

  String _normalizeInput(String input) {
    if (input.isEmpty) return 'about:blank';
    final lower = input.toLowerCase();
    final hasScheme = lower.startsWith('http://') || lower.startsWith('https://');
    final hasDot = lower.contains('.');
    if (!hasScheme && !hasDot) {
      final q = Uri.encodeQueryComponent(input);
      return 'https://duckduckgo.com/?q=$q';
    }
    return hasScheme ? input : 'https://$input';
  }

  Future<void> _back() async {
    try {
      await _activeController?.goBack();
    } catch (_) {}
  }

  Future<void> _forward() async {
    try {
      await _activeController?.goForward();
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      await _activeController?.reload();
    } catch (_) {}
  }

  Future<void> _newTab() async {
    final nextId = 't${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _tabs.add(_TabData(id: nextId, url: 'about:blank'));
      _tabController?.dispose();
      _tabController = TabController(length: _tabs.length, vsync: this);
      _tabController!.index = _tabs.length - 1;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(profileKey: _activeProfileKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ProfileManager.openProfilesBox(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final box = snap.data as Box<ProfileModel>;

        final profiles = box.keys.map((k) => k.toString()).toList(growable: false);
        if (profiles.isNotEmpty && !box.containsKey(_activeProfileKey)) {
          _activeProfileKey = profiles.first;
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            title: Text('FlipSwitch', style: const TextStyle(fontFamily: mono)),
            actions: [
              IconButton(onPressed: _openSettings, icon: const Icon(Icons.menu), color: accent),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: accent, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: accent,
                        labelColor: accent,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(fontFamily: mono),
                        tabs: [
                          for (final t in _tabs) Tab(text: t.id),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _newTab,
                      icon: const Icon(Icons.add),
                      color: accent,
                      tooltip: 'Новая вкладка',
                    )
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Container(
                height: 40,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: accent, width: 1)),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final key = profiles[i];
                    final p = box.get(key);
                    final selected = key == _activeProfileKey;
                    return GestureDetector(
                      onTap: () => setState(() => _activeProfileKey = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: accent, width: 1),
                          color: selected ? accent.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          p?.name ?? key,
                          style: TextStyle(
                            fontFamily: mono,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: accent, width: 1)),
                ),
                child: Row(
                  children: [
                    IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back), color: accent),
                    IconButton(onPressed: _forward, icon: const Icon(Icons.arrow_forward), color: accent),
                    IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), color: accent),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.shield), color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _address,
                        style: const TextStyle(fontFamily: mono, color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: accent, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: accent, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: accent, width: 1),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onSubmitted: (_) => _go(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _go,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accent, width: 1),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('GO', style: TextStyle(fontFamily: mono, fontWeight: FontWeight.w900)),
                    )
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final tab in _tabs)
                      FlipEngine(
                        tabId: tab.id,
                        initialUrl: tab.url,
                        profileKey: _activeProfileKey,
                        onControllerReady: (c) => _controllers[tab.id] = c,
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

class _TabData {
  const _TabData({required this.id, required this.url});
  final String id;
  final String url;
  _TabData copyWith({String? id, String? url}) => _TabData(id: id ?? this.id, url: url ?? this.url);
}

