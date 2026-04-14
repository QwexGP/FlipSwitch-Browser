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
      vendor: fields[3] as String,
      screenWidth: fields[4] as int,
      screenHeight: fields[5] as int,
      hardwareConcurrency: fields[6] as int,
      deviceMemory: fields[7] as int,
      colorDepth: fields[8] as int,
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
      ..write(obj.vendor)
      ..writeByte(4)
      ..write(obj.screenWidth)
      ..writeByte(5)
      ..write(obj.screenHeight)
      ..writeByte(6)
      ..write(obj.hardwareConcurrency)
      ..writeByte(7)
      ..write(obj.deviceMemory)
      ..writeByte(8)
      ..write(obj.colorDepth);
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
