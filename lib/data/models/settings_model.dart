import 'package:hive/hive.dart';

enum UaFamily {
  android,
  ios,
  windows,
  mac,
}

enum NetworkMode {
  direct,
  bridgesObfs4,
  snowflake,
}

/// Persisted user settings (Hive).
///
/// Manual adapter is used to avoid codegen.
class SettingsModel {
  SettingsModel({
    required this.spoofCanvas,
    required this.spoofWebgl,
    required this.spoofAudioContext,
    required this.spoofBattery,
    required this.uaFamily,
    required this.networkMode,
    required this.bridgesObfs4Lines,
    required this.identitySeed,
  });

  final bool spoofCanvas;
  final bool spoofWebgl;
  final bool spoofAudioContext;
  final bool spoofBattery;

  final UaFamily uaFamily;

  final NetworkMode networkMode;
  final String bridgesObfs4Lines;

  /// Bumped on "New Identity" and used to perturb noise seeds.
  final int identitySeed;

  SettingsModel copyWith({
    bool? spoofCanvas,
    bool? spoofWebgl,
    bool? spoofAudioContext,
    bool? spoofBattery,
    UaFamily? uaFamily,
    NetworkMode? networkMode,
    String? bridgesObfs4Lines,
    int? identitySeed,
  }) {
    return SettingsModel(
      spoofCanvas: spoofCanvas ?? this.spoofCanvas,
      spoofWebgl: spoofWebgl ?? this.spoofWebgl,
      spoofAudioContext: spoofAudioContext ?? this.spoofAudioContext,
      spoofBattery: spoofBattery ?? this.spoofBattery,
      uaFamily: uaFamily ?? this.uaFamily,
      networkMode: networkMode ?? this.networkMode,
      bridgesObfs4Lines: bridgesObfs4Lines ?? this.bridgesObfs4Lines,
      identitySeed: identitySeed ?? this.identitySeed,
    );
  }

  static SettingsModel defaults() => SettingsModel(
        spoofCanvas: true,
        spoofWebgl: true,
        spoofAudioContext: true,
        spoofBattery: true,
        uaFamily: UaFamily.windows,
        networkMode: NetworkMode.direct,
        bridgesObfs4Lines: '',
        identitySeed: 1,
      );
}

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 1;

  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    final uaIdx = (fields[4] as int?) ?? UaFamily.windows.index;
    final nmIdx = (fields[5] as int?) ?? NetworkMode.direct.index;

    return SettingsModel(
      spoofCanvas: (fields[0] as bool?) ?? true,
      spoofWebgl: (fields[1] as bool?) ?? true,
      spoofAudioContext: (fields[2] as bool?) ?? true,
      spoofBattery: (fields[3] as bool?) ?? true,
      uaFamily: UaFamily.values[uaIdx.clamp(0, UaFamily.values.length - 1)],
      networkMode: NetworkMode.values[nmIdx.clamp(0, NetworkMode.values.length - 1)],
      bridgesObfs4Lines: (fields[6] as String?) ?? '',
      identitySeed: (fields[7] as int?) ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.spoofCanvas)
      ..writeByte(1)
      ..write(obj.spoofWebgl)
      ..writeByte(2)
      ..write(obj.spoofAudioContext)
      ..writeByte(3)
      ..write(obj.spoofBattery)
      ..writeByte(4)
      ..write(obj.uaFamily.index)
      ..writeByte(5)
      ..write(obj.networkMode.index)
      ..writeByte(6)
      ..write(obj.bridgesObfs4Lines)
      ..writeByte(7)
      ..write(obj.identitySeed);
  }
}

