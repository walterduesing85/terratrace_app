import 'package:hive/hive.dart';

part 'flux_data.g.dart';

@HiveType(typeId: 4)
class FluxData {
  @HiveField(0)
  String? dataSite;
  @HiveField(1)
  String? dataLong;
  @HiveField(2)
  String? dataLat;
  @HiveField(3)
  String? dataTemp;
  @HiveField(4)
  String? dataPress;
  @HiveField(5)
  String? dataCflux;
  @HiveField(6)
  String? dataDate;
  @HiveField(7)
  String? dataKey;
  @HiveField(8)
  String? dataNote;
  @HiveField(9)
  String? dataSoilTemp;
  @HiveField(10)
  String? dataInstrument;
  @HiveField(11)
  String? dataCfluxGram;
  @HiveField(12)
  String? dataOrigin;

  FluxData(
      {this.dataSite,
      this.dataLong,
      this.dataLat,
      this.dataTemp,
      this.dataPress,
      this.dataCflux,
      this.dataDate,
      this.dataKey,
      this.dataNote,
      this.dataSoilTemp,
      this.dataInstrument,
      this.dataCfluxGram,
      this.dataOrigin});
}
