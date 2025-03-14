class FluxData {
  List<String>?
      dataMbus; // this will tell us what parameters were acquired in this FluxData by matching to mbus.json file

  String? dataSite;
  String? dataLong;
  String? dataLat;
  String? dataDate;
  String? dataKey; // dataDate + dataInstrument
  String? dataNote;
  String? dataInstrument;

  // Newly added location parameters
  String? dataPoint; // index number of each acquisition point
  String? dataLocationAccuracy;

  // Averages of non FLX parameters
  String? dataSwcAvg; // Soil Water Content
  String? dataSoilTempAvg;
  String? dataBarPrAvg;
  String? dataAirTempAvg;
  String? dataRhAvg; // Relative Humidity
  String? dataCellTempAvg;
  String? dataCellPressAvg;
  String? dataWsAvg; // Wind Speed
  String? dataWdaAvg; // Wind Direction
  String? dataRadAvg; // Absolute radiance
  String? dataParAvg; // Photosynthesis Active Radiance

  // FLX params MAX values
  String? dataCo2max;
  String? dataCo2HiFsmax;
  String? dataCh4max;
  String? dataVocmax;
  String? dataH2omax;

  // Fluxes of FLX parameters: CO2, CO2-HiFs, VOC, CH4, H2O
  String? dataCflux; // FLX parameter CO2
  String? dataCfluxGram; // FLX parameter CO2

  String? dataCo2HiFsflux;
  String? dataCo2HiFsfluxGram;

  String? dataVocflux;
  String? dataVocfluxGram;

  String? dataCh4flux;
  String? dataCh4fluxGram;

  String? dataH2oflux;
  String? dataH2ofluxGram;

  // r2 and slope from the boundaries set by user for each FLX parameter:  CO2, CO2-HiFs, VOC, CH4, H2O
  String? dataCo2RSquared;
  String? dataCo2Slope;

  String? dataCo2HiFsRSquared;
  String? dataCo2HiFsSlope;

  String? dataVocRSquared;
  String? dataVocSlope;

  String? dataCh4RSquared;
  String? dataCh4Slope;

  String? dataH20RSquared;
  String? dataH2oSlope;

  FluxData(
      {this.dataMbus,
      this.dataSite,
      this.dataLong,
      this.dataLat,
      // this.dataTemp,
      // this.dataPress,
      this.dataCflux,
      this.dataDate,
      this.dataKey,
      this.dataNote,
      // this.dataSoilTemp,
      this.dataInstrument,
      this.dataCfluxGram,
      // newly added params
      this.dataPoint,
      this.dataLocationAccuracy,
      this.dataCo2RSquared,
      this.dataCo2Slope,
      this.dataCo2HiFsRSquared,
      this.dataCo2HiFsSlope,
      this.dataVocRSquared,
      this.dataVocSlope,
      this.dataCh4RSquared,
      this.dataCh4Slope,
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
      this.dataSoilTempAvg,
      this.dataBarPrAvg,
      this.dataAirTempAvg,
      this.dataRhAvg,
      this.dataCellTempAvg,
      this.dataCellPressAvg,
      this.dataWsAvg,
      this.dataWdaAvg,
      this.dataRadAvg,
      this.dataParAvg,
      this.dataCh4max,
      this.dataCo2HiFsmax,
      this.dataCo2max,
      this.dataH2omax,
      this.dataVocmax});
}
