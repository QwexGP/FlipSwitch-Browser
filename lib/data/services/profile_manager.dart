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
      for (final p in presets) {
        await box.put(p.id, p);
      }
    }
    await state.put(_seededKey, true);
  }

  static List<ProfileModel> _presets10() {
    return [
      ProfileModel(
        id: 'iphone16pro',
        name: 'iPhone 16 Pro',
        userAgent:
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1',
        platform: 'iPhone',
        hardwareConcurrency: 6,
        deviceMemory: 6,
        canvasSeed: 160016,
        buildProps: const {
          'BRAND': 'Apple',
          'MODEL': 'iPhone 16 Pro',
          'DEVICE': 'iPhone16,2',
          'PRODUCT': 'iPhone OS',
          'MANUFACTURER': 'Apple',
        },
        screen: const ScreenModel(width: 1179, height: 2556, devicePixelRatio: 3),
        avatarGradientA: 0xFF1DA1F2,
        avatarGradientB: 0xFF00C2FF,
      ),
      ProfileModel(
        id: 'pixel9pro',
        name: 'Pixel 9 Pro',
        userAgent:
            'Mozilla/5.0 (Linux; Android 15; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
        platform: 'Linux armv8l',
        hardwareConcurrency: 8,
        deviceMemory: 12,
        canvasSeed: 900900,
        buildProps: const {
          'BRAND': 'Google',
          'MODEL': 'Pixel 9 Pro',
          'DEVICE': 'caiman',
          'PRODUCT': 'caiman',
          'MANUFACTURER': 'Google',
        },
        screen: const ScreenModel(width: 1344, height: 2992, devicePixelRatio: 3.5),
        avatarGradientA: 0xFF7C4DFF,
        avatarGradientB: 0xFF1DA1F2,
      ),
      ProfileModel(
        id: 'galaxys25u',
        name: 'Galaxy S25 Ultra',
        userAgent:
            'Mozilla/5.0 (Linux; Android 15; SM-S938B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
        platform: 'Linux armv8l',
        hardwareConcurrency: 8,
        deviceMemory: 12,
        canvasSeed: 252525,
        buildProps: const {
          'BRAND': 'Samsung',
          'MODEL': 'SM-S938B',
          'DEVICE': 's25u',
          'PRODUCT': 's25u',
          'MANUFACTURER': 'Samsung',
        },
        screen: const ScreenModel(width: 1440, height: 3120, devicePixelRatio: 4),
        avatarGradientA: 0xFF00D4FF,
        avatarGradientB: 0xFF7C4DFF,
      ),
      ProfileModel(
        id: 'macbookairm3',
        name: 'MacBook Air M3',
        userAgent:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'MacIntel',
        hardwareConcurrency: 8,
        deviceMemory: 16,
        canvasSeed: 303030,
        buildProps: const {
          'BRAND': 'Apple',
          'MODEL': 'MacBookAir',
          'DEVICE': 'Mac14,15',
          'PRODUCT': 'macOS',
          'MANUFACTURER': 'Apple',
        },
        screen: const ScreenModel(width: 2560, height: 1664, devicePixelRatio: 2),
        avatarGradientA: 0xFF1DA1F2,
        avatarGradientB: 0xFF00FFA8,
      ),
      ProfileModel(
        id: 'win11chrome',
        name: 'Windows 11 Chrome',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'Win32',
        hardwareConcurrency: 12,
        deviceMemory: 16,
        canvasSeed: 110011,
        buildProps: const {
          'BRAND': 'Microsoft',
          'MODEL': 'Windows 11',
          'DEVICE': 'PC',
          'PRODUCT': 'Windows',
          'MANUFACTURER': 'Microsoft',
        },
        screen: const ScreenModel(width: 1920, height: 1080, devicePixelRatio: 1),
        avatarGradientA: 0xFF7C4DFF,
        avatarGradientB: 0xFF00D4FF,
      ),
      ProfileModel(
        id: 'linuxchrome',
        name: 'Linux Chrome',
        userAgent:
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'Linux x86_64',
        hardwareConcurrency: 8,
        deviceMemory: 16,
        canvasSeed: 404040,
        buildProps: const {
          'BRAND': 'Generic',
          'MODEL': 'Linux',
          'DEVICE': 'Desktop',
          'PRODUCT': 'Linux',
          'MANUFACTURER': 'Generic',
        },
        screen: const ScreenModel(width: 1920, height: 1200, devicePixelRatio: 1),
        avatarGradientA: 0xFF00FFA8,
        avatarGradientB: 0xFF1DA1F2,
      ),
      ProfileModel(
        id: 'ipadpro',
        name: 'iPad Pro',
        userAgent:
            'Mozilla/5.0 (iPad; CPU OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1',
        platform: 'iPad',
        hardwareConcurrency: 8,
        deviceMemory: 8,
        canvasSeed: 181818,
        buildProps: const {
          'BRAND': 'Apple',
          'MODEL': 'iPad Pro',
          'DEVICE': 'iPad16,4',
          'PRODUCT': 'iPad OS',
          'MANUFACTURER': 'Apple',
        },
        screen: const ScreenModel(width: 2048, height: 2732, devicePixelRatio: 2),
        avatarGradientA: 0xFF00C2FF,
        avatarGradientB: 0xFF7C4DFF,
      ),
      ProfileModel(
        id: 'androidtablet',
        name: 'Android Tablet',
        userAgent:
            'Mozilla/5.0 (Linux; Android 15; SM-X900) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        platform: 'Linux armv8l',
        hardwareConcurrency: 8,
        deviceMemory: 12,
        canvasSeed: 909090,
        buildProps: const {
          'BRAND': 'Samsung',
          'MODEL': 'SM-X900',
          'DEVICE': 'tablet',
          'PRODUCT': 'tablet',
          'MANUFACTURER': 'Samsung',
        },
        screen: const ScreenModel(width: 2800, height: 1752, devicePixelRatio: 2.5),
        avatarGradientA: 0xFF1DA1F2,
        avatarGradientB: 0xFF7C4DFF,
      ),
      ProfileModel(
        id: 'firefoxwin',
        name: 'Windows 11 Firefox',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0',
        platform: 'Win32',
        hardwareConcurrency: 8,
        deviceMemory: 16,
        canvasSeed: 135135,
        buildProps: const {
          'BRAND': 'Mozilla',
          'MODEL': 'Firefox',
          'DEVICE': 'PC',
          'PRODUCT': 'Windows',
          'MANUFACTURER': 'Microsoft',
        },
        screen: const ScreenModel(width: 1920, height: 1080, devicePixelRatio: 1),
        avatarGradientA: 0xFFFF6A00,
        avatarGradientB: 0xFF1DA1F2,
      ),
      ProfileModel(
        id: 'dark_tor_generic',
        name: 'Dark (Tor-like)',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0',
        platform: 'Win32',
        hardwareConcurrency: 2,
        deviceMemory: 2,
        canvasSeed: 777777,
        buildProps: const {
          'BRAND': 'Mozilla',
          'MODEL': 'Tor Browser',
          'DEVICE': 'PC',
          'PRODUCT': 'Windows',
          'MANUFACTURER': 'Generic',
        },
        screen: const ScreenModel(width: 1000, height: 1000, devicePixelRatio: 1),
        avatarGradientA: 0xFF6A00FF,
        avatarGradientB: 0xFF1DA1F2,
      ),
    ];
  }
}

