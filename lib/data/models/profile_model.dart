import 'package:hive/hive.dart';

part 'profile_model.g.dart';

@HiveType(typeId: 0)
class ProfileModel extends HiveObject {
  ProfileModel({
    required this.name,
    required this.userAgent,
    required this.platform,
    required this.vendor,
    required this.screenWidth,
    required this.screenHeight,
    required this.hardwareConcurrency,
    required this.deviceMemory,
    required this.colorDepth,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  String userAgent;

  @HiveField(2)
  String platform;

  @HiveField(3)
  String vendor;

  @HiveField(4)
  int screenWidth;

  @HiveField(5)
  int screenHeight;

  @HiveField(6)
  int hardwareConcurrency;

  @HiveField(7)
  int deviceMemory;

  @HiveField(8)
  int colorDepth;

  static ProfileModel defaultProfile() {
    return ProfileModel(
      name: 'Windows',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
      platform: 'Win32',
      vendor: 'Google Inc.',
      screenWidth: 1920,
      screenHeight: 1080,
      hardwareConcurrency: 8,
      deviceMemory: 16,
      colorDepth: 24,
    );
  }
}