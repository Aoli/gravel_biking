// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_route.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedRouteAdapter extends TypeAdapter<SavedRoute> {
  @override
  final int typeId = 0;

  @override
  SavedRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedRoute(
      name: fields[0] as String,
      points: (fields[1] as List).cast<LatLngData>(),
      loopClosed: fields[2] as bool,
      savedAt: fields[3] as DateTime,
      description: fields[4] as String?,
      distance: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedRoute obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.points)
      ..writeByte(2)
      ..write(obj.loopClosed)
      ..writeByte(3)
      ..write(obj.savedAt)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.distance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LatLngDataAdapter extends TypeAdapter<LatLngData> {
  @override
  final int typeId = 1;

  @override
  LatLngData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LatLngData(fields[0] as double, fields[1] as double);
  }

  @override
  void write(BinaryWriter writer, LatLngData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLngDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
