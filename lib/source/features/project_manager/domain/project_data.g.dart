// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectDataAdapter extends TypeAdapter<ProjectData> {
  @override
  final int typeId = 1;

  @override
  ProjectData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectData(
      projectName: fields[0] as String,
      isRemote: fields[1] as bool,
      browseFiles: fields[2] as bool,
      defaultTemperature: fields[3] as double,
      defaultPressure: fields[4] as double,
      chamberVolume: fields[6] as double,
      surfaceArea: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.projectName)
      ..writeByte(1)
      ..write(obj.isRemote)
      ..writeByte(2)
      ..write(obj.browseFiles)
      ..writeByte(3)
      ..write(obj.defaultTemperature)
      ..writeByte(4)
      ..write(obj.defaultPressure)
      ..writeByte(5)
      ..write(obj.surfaceArea)
      ..writeByte(6)
      ..write(obj.chamberVolume);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
