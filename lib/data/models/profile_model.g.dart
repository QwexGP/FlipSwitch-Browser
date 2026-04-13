// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 0;

  @override
  ProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileModel(
      name: fields[0] as String,
      userAgent: fields[1] as String,
      platform: fields[2] as String,
      width: fields[3] as int,
      height: fields[4] as int,
      hardwareConcurrency: fields[5] as int,
      deviceMemory: fields[6] as int,
      canvasSeed: fields[7] as int,
      buildProps: (fields[8] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.userAgent)
      ..writeByte(2)
      ..write(obj.platform)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.hardwareConcurrency)
      ..writeByte(6)
      ..write(obj.deviceMemory)
      ..writeByte(7)
      ..write(obj.canvasSeed)
      ..writeByte(8)
      ..write(obj.buildProps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
