import 'package:hive/hive.dart';

/// Primary persisted identity for fingerprinting.
///
/// NOTE: Adapter is implemented manually to keep the project compiling
/// without build_runner codegen.
class ProfileModel extends HiveObject {
  ProfileModel({
    required this.id,
    required this.name,
    required this.userAgent,
    required this.platform,
    required this.hardwareConcurrency,
    required this.deviceMemory,
    required this.canvasSeed,
    required this.buildProps,
    required this.screen,
    required this.avatarGradientA,
    required this.avatarGradientB,
  });

  /// Stable key in Hive (also used as UI selection id).
  final String id;

  final String name;
  final String userAgent;

  /// What JS sees in `navigator.platform`.
  final String platform;

  final int hardwareConcurrency;
  final int deviceMemory;

  /// Seed for deterministic canvas noise.
  final int canvasSeed;

  /// Synthetic "build properties" used by injection layer.
  /// Keep keys stable (e.g. BRAND/MODEL/DEVICE/PRODUCT/MANUFACTURER).
  final Map<String, String> buildProps;

  final ScreenModel screen;

  /// UI-only (stored to keep profile avatars stable).
  final int avatarGradientA;
  final int avatarGradientB;
}

class ScreenModel {
  const ScreenModel({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  final int width;
  final int height;
  final double devicePixelRatio;
}

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 0;

  @override
  ProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    final screenWidth = (fields[8] as int?) ?? 1080;
    final screenHeight = (fields[9] as int?) ?? 2400;
    final dpr = (fields[10] as double?) ?? 3.0;

    return ProfileModel(
      id: (fields[0] as String?) ?? 'default',
      name: (fields[1] as String?) ?? 'Default',
      userAgent: (fields[2] as String?) ?? '',
      platform: (fields[3] as String?) ?? '',
      hardwareConcurrency: (fields[4] as int?) ?? 4,
      deviceMemory: (fields[5] as int?) ?? 4,
      canvasSeed: (fields[6] as int?) ?? 1,
      buildProps: (fields[7] as Map?)?.cast<String, String>() ?? const {},
      screen: ScreenModel(
        width: screenWidth,
        height: screenHeight,
        devicePixelRatio: dpr,
      ),
      avatarGradientA: (fields[11] as int?) ?? 0xFF1DA1F2,
      avatarGradientB: (fields[12] as int?) ?? 0xFF7C4DFF,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.userAgent)
      ..writeByte(3)
      ..write(obj.platform)
      ..writeByte(4)
      ..write(obj.hardwareConcurrency)
      ..writeByte(5)
      ..write(obj.deviceMemory)
      ..writeByte(6)
      ..write(obj.canvasSeed)
      ..writeByte(7)
      ..write(obj.buildProps)
      ..writeByte(8)
      ..write(obj.screen.width)
      ..writeByte(9)
      ..write(obj.screen.height)
      ..writeByte(10)
      ..write(obj.screen.devicePixelRatio)
      ..writeByte(11)
      ..write(obj.avatarGradientA)
      ..writeByte(12)
      ..write(obj.avatarGradientB);
  }
}