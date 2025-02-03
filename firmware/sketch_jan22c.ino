#include <ArduinoBLE.h>


// BLE Services
BLEService commonService("180D");  // Common Service UUID
BLEService service1("181A");       // MBU1 UUID
BLEService service2("182A");       // MBU2 UUID

// Common Characteristics
BLEBoolCharacteristic batteryAlarmChar("2A39", BLERead | BLENotify);  // Battery alarm
BLEBoolCharacteristic acOpenChar("2A3A", BLERead | BLENotify);        // AC open
BLEBoolCharacteristic acClosedChar("2A3B", BLERead | BLENotify);      // AC closed
BLEBoolCharacteristic flowAlarmChar("2A41", BLERead | BLENotify);     // Flow alarm

BLEIntCharacteristic openACCommand("2A3C", BLEWrite);         // Open AC command
BLEIntCharacteristic closeACCommand("2A3D", BLEWrite);        // Close AC command
BLEIntCharacteristic setPumpStatusCommand("2A3E", BLEWrite);  // Set pump status

// Service 1 Characteristics
BLEFloatCharacteristic co2Char("2A37", BLERead | BLENotify);                 // CO2 value
BLEFloatCharacteristic batteryChar("2A38", BLERead | BLENotify);             // Battery voltage
BLEFloatCharacteristic barometricPressureChar("2A42", BLERead | BLENotify);  // Barometric pressure
BLEFloatCharacteristic airTemperatureChar("2A43", BLERead | BLENotify);      // Air temperature
BLEFloatCharacteristic airHumidityChar("2A44", BLERead | BLENotify);         // Air humidity

BLEIntCharacteristic setFilterValueCommand("2A3F", BLEWrite);  // Set filter value
BLEIntCharacteristic setCO2ValueCommand("2A40", BLEWrite);     // Set CO2 value

// Service 2 Characteristics
BLEFloatCharacteristic ch4Char("2A45", BLERead | BLENotify);  // CH4 value
BLEFloatCharacteristic vocChar("2A46", BLERead | BLENotify);  // VOC value

// Parameters
float co2 = 0.0, batteryVoltage = 0.0, barometricPressure = 0.0;
float airTemperature = 0.0, airHumidity = 0.0;
float ch4 = 0.0, voc = 0.0;
bool batteryAlarm = false, acOpen = false, acClosed = false;
bool flowAlarm = false, pumpStatus = false;
int filterValue = 0;

// Timer variables
unsigned long lastCO2Update = 0, lastBatteryUpdate = 0;
unsigned long lastCH4VOCUpdate = 0, lastEnvUpdate = 0;

void setup() {
  Serial.begin(9600);
  while (!Serial)
    ;

  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1)
      ;
  }

  // Common Service Setup
  BLE.setLocalName("Terratrace");
  BLE.setAdvertisedService(commonService);

  commonService.addCharacteristic(batteryAlarmChar);
  commonService.addCharacteristic(acOpenChar);
  commonService.addCharacteristic(acClosedChar);
  commonService.addCharacteristic(flowAlarmChar);

  commonService.addCharacteristic(openACCommand);
  commonService.addCharacteristic(closeACCommand);
  commonService.addCharacteristic(setPumpStatusCommand);

  BLE.addService(commonService);

  // Service 1 Setup
  service1.addCharacteristic(co2Char);
  service1.addCharacteristic(batteryChar);
  service1.addCharacteristic(barometricPressureChar);
  service1.addCharacteristic(airTemperatureChar);
  service1.addCharacteristic(airHumidityChar);

  service1.addCharacteristic(setFilterValueCommand);
  service1.addCharacteristic(setCO2ValueCommand);

  BLE.addService(service1);

  // Service 2 Setup
  service2.addCharacteristic(ch4Char);
  service2.addCharacteristic(vocChar);

  BLE.addService(service2);

  // Initialize characteristic values
  co2Char.writeValue(co2);
  batteryChar.writeValue(batteryVoltage);
  barometricPressureChar.writeValue(barometricPressure);
  airTemperatureChar.writeValue(airTemperature);
  airHumidityChar.writeValue(airHumidity);
  ch4Char.writeValue(ch4);
  vocChar.writeValue(voc);
  batteryAlarmChar.writeValue(batteryAlarm);
  acOpenChar.writeValue(acOpen);
  acClosedChar.writeValue(acClosed);
  flowAlarmChar.writeValue(flowAlarm);

  BLE.advertise();
  Serial.println("BLE device is now advertising!");
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) {
      if (pumpStatus && acOpen) {
        // Update Service 1: CO2, Battery, Environmental Data
        if (millis() - lastCO2Update >= 1000) {

          co2 = randomFloat(0, 100);  // Simulate CO2 reading
          co2Char.writeValue(co2);

          lastCO2Update = millis();
        }

        if (millis() - lastBatteryUpdate >= 1000) {
          batteryVoltage += 0.1;  // Simulate battery reading
          if (batteryVoltage > 30.0) batteryVoltage = 0.0;
          batteryChar.writeValue(batteryVoltage);
          lastBatteryUpdate = millis();
        }

        if (millis() - lastEnvUpdate >= 1000) {
          barometricPressure = randomFloat(0, 1060);
          if (barometricPressure > 1060) barometricPressure = 0.0;
          barometricPressureChar.writeValue(barometricPressure);

          airTemperature = randomFloat(0, 100);
          if (airTemperature > 100) airTemperature = 0.0;
          airTemperatureChar.writeValue(airTemperature);

          airHumidity = randomFloat(0, 100);
          if (airHumidity > 100) airHumidity = 0.0;
          airHumidityChar.writeValue(airHumidity);

          lastEnvUpdate = millis();
        }

        // Update Service 2: CH4, VOC
        if (millis() - lastCH4VOCUpdate >= 1000) {
          ch4 = randomFloat(0, 10000);  // Simulate CH4 reading
          if (ch4 > 10000) ch4 = 0.0;
          ch4Char.writeValue(ch4);

          voc = randomFloat(0, 1000000);  // Simulate VOC reading
          if (voc > 1000000) voc = 0.0;
          vocChar.writeValue(voc);

          lastCH4VOCUpdate = millis();
        }
      }
              // Handle Commands
        if (openACCommand.written()) {
          acOpen = true;
          acClosed = false;
          acOpenChar.writeValue(acOpen);
          acClosedChar.writeValue(acClosed);
          Serial.print("acOpen: ");
          Serial.println(acOpen);
        }

        if (closeACCommand.written()) {
          acOpen = false;
          acClosed = true;
          pumpStatus = false;
          acOpenChar.writeValue(acOpen);
          acClosedChar.writeValue(acClosed);
          Serial.print("acClosed: ");
          Serial.println(acClosed);
        }

        if (setPumpStatusCommand.written()) {
          Serial.print("Pump value set to: ");
          Serial.println(setPumpStatusCommand.value());
          pumpStatus = true;
          // pumpStatus = setPumpStatusCommand.value();
        }

        if (setFilterValueCommand.written()) {
          filterValue = setFilterValueCommand.value();
          Serial.print("Filter value set to: ");
          Serial.println(filterValue);
        }

        if (setCO2ValueCommand.written()) {
          co2 = setCO2ValueCommand.value();
          co2Char.writeValue(co2);
        }
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}

float randomFloat(float min, float max) {
  // Generate a random float in the range [min, max)
  return min + ((float)random() / (float)RAND_MAX) * (max - min);
}
