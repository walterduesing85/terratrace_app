const int kMaxLineToFindCo2 = 100;

class FluxRegExp {
  final RegExp expLat = RegExp(r"LATITUDE:\s*(.*)\w$", multiLine: true);
  final RegExp expSite = RegExp(r"SITE:\s*(.*)$", multiLine: true);
  final RegExp expNote = RegExp(r"NOTE:\s*(.*)$", multiLine: true);
  final RegExp expLong = RegExp(r"LONGITUDE:\s*(.*)\w$", multiLine: true);
  final RegExp expPress =
      RegExp(r"PRESSURE \D\D\D\D\D:\s*(.*)$", multiLine: true);
  final RegExp expTemp =
      RegExp(r"TEMPERATURE \D\D\D\D:\s*(.*)$", multiLine: true);
  final RegExp expDate = RegExp(r"TIME:\s*(.*)\w$", multiLine: true);
  final RegExp expInstrument =
      RegExp(r"INSTRUMENT S/N:\s*(.*)\w$", multiLine: true);
}
