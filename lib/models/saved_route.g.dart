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
    // Backward-compatible reads: provide safe defaults when legacy entries
    // are missing fields or contain nulls, and normalize numeric types.
    final name = fields[0] as String? ?? '';
    final points = (fields[1] as List?)?.cast<LatLngData>() ?? <LatLngData>[];
    final loopClosed = (fields[2] as bool?) ?? false;
    final savedAt = (fields[3] as DateTime?) ?? DateTime.now();
    final description = fields[4] as String?;
    final distance = (fields[5] is num)
        ? (fields[5] as num?)?.toDouble()
        : fields[5] as double?;
    final isPublic = (fields[6] as bool?) ?? false;
    final userId = fields[7] as String?;
    final firestoreId = fields[8] as String?;
    final lastSynced = fields[9] as DateTime?;

    return SavedRoute(
      name: name,
      points: points,
      loopClosed: loopClosed,
      savedAt: savedAt,
      description: description,
      distance: distance,
      isPublic: isPublic,
      userId: userId,
      firestoreId: firestoreId,
      lastSynced: lastSynced,
    );
  }

  @override
  void write(BinaryWriter writer, SavedRoute obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.distance)
      ..writeByte(6)
      ..write(obj.isPublic)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.firestoreId)
      ..writeByte(9)
      ..write(obj.lastSynced);
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
