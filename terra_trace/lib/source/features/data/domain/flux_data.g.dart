// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flux_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FluxDataAdapter extends TypeAdapter<FluxData> {
  @override
  final int typeId = 4;

  @override
  FluxData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FluxData(
      dataSite: fields[0] as String,
      dataLong: fields[1] as String,
      dataLat: fields[2] as String,
      dataTemp: fields[3] as String,
      dataPress: fields[4] as String,
      dataCflux: fields[5] as String,
      dataDate: fields[6] as String,
      dataKey: fields[7] as String,
      dataNote: fields[8] as String,
      dataSoilTemp: fields[9] as String,
      dataInstrument: fields[10] as String,
      dataCfluxGram: fields[11] as String,
      dataOrigin: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FluxData obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.dataSite)
      ..writeByte(1)
      ..write(obj.dataLong)
      ..writeByte(2)
      ..write(obj.dataLat)
      ..writeByte(3)
      ..write(obj.dataTemp)
      ..writeByte(4)
      ..write(obj.dataPress)
      ..writeByte(5)
      ..write(obj.dataCflux)
      ..writeByte(6)
      ..write(obj.dataDate)
      ..writeByte(7)
      ..write(obj.dataKey)
      ..writeByte(8)
      ..write(obj.dataNote)
      ..writeByte(9)
      ..write(obj.dataSoilTemp)
      ..writeByte(10)
      ..write(obj.dataInstrument)
      ..writeByte(11)
      ..write(obj.dataCfluxGram)
      ..writeByte(12)
      ..write(obj.dataOrigin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FluxDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
