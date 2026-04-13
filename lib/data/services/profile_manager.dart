import 'package:hive/hive.dart';

import '../models/profile_model.dart';

class ProfileManager {
  static const String profilesBoxName = 'profiles_v1';
  static const String stateBoxName = 'app_state_v1';
  static const String _seededKey = 'profiles_seeded_v1';

  static Future<Box<ProfileModel>> openProfilesBox() async {
    return await Hive.openBox<ProfileModel>(profilesBoxName);
  }

  static Future<void> ensureSeeded() async {
    final state = await Hive.openBox(stateBoxName);
    final seeded = (state.get(_seededKey) as bool?) ?? false;
    if (seeded) return;

    final box = await openProfilesBox();
    if (box.isEmpty) {
      final presets = _presets10();
      for (var i = 0; i < presets.length; i++) {
        await box.put('p$i', presets[i]);
      }
    }
    await state.put(_seededKey, true);
  }

  static List<ProfileModel> _presets10() {
    return [
      ProfileModel(
        name: 'iPhone 16 Pro',
        userAgent:
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1',
        platform: 'iPhone',
        vendor: 'Apple Computer, Inc.',
        screenWidth: 1179,
        screenHeight: 2556,
        hardwareConcurrency: 6,
        deviceMemory: 6,
        colorDepth: 24,
      ),
      ProfileModel(
        name: 'Pixel 9 Pro',
        userAgent:
            'Mozilla/5.0 (Linux; Android 15; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
        platform: 'Linux armv8l',
        vendor: 'Google Inc.',
        screenWidth: 1344,
        screenHeight: 2992,
        hardwareConcurrency: 8,
        deviceMemory: 12,
        colorDepth: 24,
      ),
      ProfileModel(
        name: 'Galaxy S25 Ultra',
        userAgent:
            'Mozilla/5.0 (Linux; Android 15; SM-S938B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
        platform: 'Linux armv8l',
        vendor: 'Google Inc.',
        screenWidth: 1440,
        screenHeight: 3120,
        hardwareConcurrency: 8,
        deviceMemory: 12,
        colorDepth: 24,
      ),
      ProfileModel(
        name: 'MacBook Air M3',
        userAgent:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'MacIntel',
        vendor: 'Google Inc.',
        screenWidth: 2560,
        screenHeight: 1664,
        hardwareConcurrency: 8,
        deviceMemory: 16,
        colorDepth: 24,
      ),
      ProfileModel(
        name: 'Windows 11 Chrome',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'Win32',
        vendor: 'Google Inc.',
        screenWidth: 1920,
        screenHeight: 1080,
        hardwareConcurrency: 12,
        deviceMemory: 16,
        colorDepth: 24,
      ),
    ];
  }
}

