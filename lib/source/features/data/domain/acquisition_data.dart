class AcquisitionData {
  List<String>?
      dataMbus; // this will tell us what parameters were acquired in this FluxData by matching to mbus.json file

  List<String>? flxParams;

  List<String>? epvParams;

  String? numberSensors;

  String? dataSite;
  String? dataLong;
  String? dataLat;

  String? dataCflux; // FLX parameter CO2
  String? dataDate;
  String? dataKey; // dataDate + dataInstrument
  String? dataNote;
  String? dataInstrument;
  String? dataCfluxGram; // FLX parameter CO2

  // Newly added location parameters
  String? dataPoint;
  String? dataEasting;
  String? dataNorthing;
  String? dataZoneNumber;
  String? dataZoneLetter;
  String? dataHemisphere;
  String? dataEPSG;
  String? dataLocationAccuracy;

  // EPV parameters, store their AVG, MIN, MAX, Std. Dev. values
  // SWC, SoilTemp, Battery, BarPr,  AirTemp, RH, CellTemp, CellPress, Flow, WS, WDA, RAD, PAR
  String? dataSwcAvg;
  String? dataSwcMin;
  String? dataSwcMax;
  String? dataSwcStdDev;

  String? dataSoilTempAvg;
  String? dataSoilTempMin;
  String? dataSoilTempMax;
  String? dataSoilTempStdDev;

  String? dataBatteryAvg;
  String? dataBatteryMin;
  String? dataBatteryMax;
  String? dataBatteryStdDev;

  String? dataBarPrAvg;
  String? dataBarPrMin;
  String? dataBarPrMax;
  String? dataBarPrStdDev;

  String? dataAirTempAvg;
  String? dataAirTempMin;
  String? dataAirTempMax;
  String? dataAirTempStdDev;

  String? dataRhAvg;
  String? dataRhMin;
  String? dataRhMax;
  String? dataRhStdDev;

  String? dataCellTempAvg;
  String? dataCellTempMin;
  String? dataCellTempMax;
  String? dataCellTempStdDev;

  String? dataCellPressAvg;
  String? dataCellPressMin;
  String? dataCellPressMax;
  String? dataCellPressStdDev;

  String? dataFlowAvg;
  String? dataFlowMin;
  String? dataFlowMax;
  String? dataFlowStdDev;

  String? dataWsAvg;
  String? dataWsMin;
  String? dataWsMax;
  String? dataWsStdDev;

  String? dataWdaAvg;
  String? dataWdaMin;
  String? dataWdaMax;
  String? dataWdaStdDev;

  String? dataRadAvg;
  String? dataRadMin;
  String? dataRadMax;
  String? dataRadStdDev;

  String? dataParAvg;
  String? dataParMin;
  String? dataParMax;
  String? dataParStdDev;

  // the boundaries set by user for each FLX parameter:  CO2, CO2-HiFs, VOC, CH4, H2O
  String? dataCo2LeftBoundary;
  String? dataCo2RightBoundary;
  String? dataCo2RSquared;
  String? dataCo2Slope;

  String? dataCo2HiFsLeftBoundary;
  String? dataCo2HiFsRightBoundary;
  String? dataCo2HiFsRSquared;
  String? dataCo2HiFsSlope;

  String? dataVocLeftBoundary;
  String? dataVocRightBoundary;
  String? dataVocRSquared;
  String? dataVocSlope;

  String? dataCh4LeftBoundary;
  String? dataCh4RightBoundary;
  String? dataCh4RSquared;
  String? dataCh4Slope;

  String? dataH2oLeftBoundary;
  String? dataH20RightBoundary;
  String? dataH20RSquared;
  String? dataH2oSlope;

  String? dataCo2HiFsflux;
  String? dataCo2HiFsfluxGram;

  String? dataVocflux;
  String? dataVocfluxGram;

  String? dataCh4flux;
  String? dataCh4fluxGram;

  String? dataH2oflux;
  String? dataH2ofluxGram;

  AcquisitionData({
    this.numberSensors,
    this.flxParams,
    this.epvParams,
    this.dataMbus,
    this.dataSite,
    this.dataLong,
    this.dataLat,
    this.dataCflux,
    this.dataDate,
    this.dataKey,
    this.dataNote,
    this.dataInstrument,
    this.dataCfluxGram,
    // newly added params
    this.dataPoint,
    this.dataEasting,
    this.dataNorthing,
    this.dataZoneNumber,
    this.dataZoneLetter,
    this.dataHemisphere,
    this.dataEPSG,
    this.dataLocationAccuracy,
    this.dataCo2LeftBoundary,
    this.dataCo2RightBoundary,
    this.dataCo2RSquared,
    this.dataCo2Slope,
    this.dataCo2HiFsLeftBoundary,
    this.dataCo2HiFsRightBoundary,
    this.dataCo2HiFsRSquared,
    this.dataCo2HiFsSlope,
    this.dataVocLeftBoundary,
    this.dataVocRightBoundary,
    this.dataVocRSquared,
    this.dataVocSlope,
    this.dataCh4LeftBoundary,
    this.dataCh4RightBoundary,
    this.dataCh4RSquared,
    this.dataCh4Slope,
    this.dataH2oLeftBoundary,
    this.dataH20RightBoundary,
    this.dataH20RSquared,
    this.dataH2oSlope,
    this.dataCo2HiFsflux,
    this.dataCo2HiFsfluxGram,
    this.dataVocflux,
    this.dataVocfluxGram,
    this.dataCh4flux,
    this.dataCh4fluxGram,
    this.dataH2oflux,
    this.dataH2ofluxGram,
    this.dataSwcAvg,
    this.dataSwcMin,
    this.dataSwcMax,
    this.dataSwcStdDev,
    this.dataSoilTempAvg,
    this.dataSoilTempMin,
    this.dataSoilTempMax,
    this.dataSoilTempStdDev,
    this.dataBatteryAvg,
    this.dataBatteryMin,
    this.dataBatteryMax,
    this.dataBatteryStdDev,
    this.dataBarPrAvg,
    this.dataBarPrMin,
    this.dataBarPrMax,
    this.dataBarPrStdDev,
    this.dataAirTempAvg,
    this.dataAirTempMin,
    this.dataAirTempMax,
    this.dataAirTempStdDev,
    this.dataRhAvg,
    this.dataRhMin,
    this.dataRhMax,
    this.dataRhStdDev,
    this.dataCellTempAvg,
    this.dataCellTempMin,
    this.dataCellTempMax,
    this.dataCellTempStdDev,
    this.dataCellPressAvg,
    this.dataCellPressMin,
    this.dataCellPressMax,
    this.dataCellPressStdDev,
    this.dataFlowAvg,
    this.dataFlowMin,
    this.dataFlowMax,
    this.dataFlowStdDev,
    this.dataWsAvg,
    this.dataWsMin,
    this.dataWsMax,
    this.dataWsStdDev,
    this.dataWdaAvg,
    this.dataWdaMin,
    this.dataWdaMax,
    this.dataWdaStdDev,
    this.dataRadAvg,
    this.dataRadMin,
    this.dataRadMax,
    this.dataRadStdDev,
    this.dataParAvg,
    this.dataParMin,
    this.dataParMax,
    this.dataParStdDev,
  });
}
