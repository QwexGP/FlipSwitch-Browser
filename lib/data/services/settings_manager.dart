import 'package:hive/hive.dart';

import '../models/settings_model.dart';

class SettingsManager {
  static const String boxName = 'settings_v1';
  static const String key = 'settings';

  static Future<Box<SettingsModel>> openBox() async {
    return await Hive.openBox<SettingsModel>(boxName);
  }

  static Future<SettingsModel> getOrCreate() async {
    final box = await openBox();
    final existing = box.get(key);
    if (existing != null) return existing;
    final defaults = SettingsModel.defaults();
    await box.put(key, defaults);
    return defaults;
  }

  static Future<void> put(SettingsModel s) async {
    final box = await openBox();
    await box.put(key, s);
  }
}

