import 'package:hive/hive.dart';

part 'project_data.g.dart';

@HiveType(typeId: 1)
class ProjectData {
  @HiveField(0)
  String projectName;
  @HiveField(1)
  bool isRemote;
  @HiveField(2)
  bool browseFiles;
  @HiveField(3)
  double defaultTemperature;
  @HiveField(4)
  double defaultPressure;
  @HiveField(5)
  double surfaceArea;
  @HiveField(6)
  double chamberVolume;
  ProjectData(
      {this.projectName,
      this.isRemote,
      this.browseFiles,
      this.defaultTemperature,
      this.defaultPressure,
      this.chamberVolume,
      this.surfaceArea});
}
