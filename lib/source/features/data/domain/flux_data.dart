class FluxData {
  List<String>?
      dataMbus; // this will tell us what parameters were acquired in this FluxData by matching to mbus.json file

  String? dataSite;
  String? dataLong;
  String? dataLat;
  String? dataTemp;
  String? dataPress;
  String? dataCflux; // FLX parameter CO2
  String? dataDate;
  String?
      dataKey; // dataDate + dataInstrument //TODO id you dont need it remove it it might be useful to later connect to the Timeseries data if they have the same key
  String? dataNote;
  String? dataSoilTemp;
  String? dataInstrument;
  String? dataCfluxGram; // FLX parameter CO2

  // Newly added location parameters
  String? dataPoint;
  String? dataLocationAccuracy;

  // EPV parameters, store their AVG, MIN, MAX, Std. Dev. values
  // SWC, SoilTemp, Battery, BarPr, AirTemp, RH, CellTemp, CellPress, Flow, WS, WDA, RAD, PAR
  String? dataSoilTempAvg;
  String? dataBarPrAvg;
  String? dataAirTempAvg;
  String? dataRhAvg;
  String? dataCellPressAvg;
  String? dataFlowAvg;

  String? dataCo2RSquared;
  String? dataCo2Slope;
  String? dataCo2HiFsRSquared;
  String? dataVocRSquared;
  String? dataCh4RSquared;
  String? dataH20RSquared;

  String? dataCo2HiFsflux; // What is this?
  String?
      dataCo2HiFsfluxGram; // same here, is this the sensor that is taking water flux into account and is more accurate?

  String? dataVocflux;
  String? dataVocfluxGram;

  String? dataCh4flux;
  String? dataCh4fluxGram;

  String? dataH2oflux;
  String? dataH2ofluxGram;

  FluxData({
    this.dataMbus,
      this.dataSite,
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
      // newly added params
      this.dataPoint,
      this.dataLocationAccuracy,
    this.dataSoilTempAvg,
    this.dataBarPrAvg,
    this.dataAirTempAvg,
    this.dataRhAvg,
    this.dataCellPressAvg,
    this.dataFlowAvg,
      this.dataCo2RSquared,
      this.dataCo2Slope,
      this.dataCo2HiFsRSquared,
      this.dataVocRSquared,
      this.dataCh4RSquared,
      this.dataH20RSquared,
      this.dataCo2HiFsflux,
      this.dataCo2HiFsfluxGram,
      this.dataVocflux,
      this.dataVocfluxGram,
      this.dataCh4flux,
      this.dataCh4fluxGram,
      this.dataH2oflux,
      this.dataH2ofluxGram,
  });
}
