import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/models/profile_model.dart';
import 'data/models/settings_model.dart';
import 'data/services/profile_manager.dart';
import 'data/services/settings_manager.dart';
import 'features/browser/okak/tor/tor_status.dart';
import 'features/browser/widgets/browser_home.dart';

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
  @override
  void initState() {
    super.initState();
    TorStatusController.instance.start();
  }

  @override
  void dispose() {
    TorStatusController.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF000000)),
      home: const BrowserHome(),
    );
  }
}