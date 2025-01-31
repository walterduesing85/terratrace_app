import 'package:flutter/material.dart';

enum DataType { area, volume, pressure, temperature }

const kSendButtonTextStyle = TextStyle(
  color: Colors.lightBlueAccent,
  fontWeight: FontWeight.bold,
  fontSize: 18.0,
);

const kGreenFluxColor = Color.fromRGBO(180, 211, 175, 1);

// TExtsyyle for the drawer
const kDrawerTextStyle = TextStyle(
  color: Color.fromRGBO(180, 211, 175, 1),
  fontSize: 12,
);

// Textstyle for the cards
// header
const kCardHeadeTextStyle = TextStyle(
  color: Colors.black,
  fontWeight: FontWeight.bold,
  fontSize: 20,
);

// Subtitle Cards

const kCardSubtitleTextStyle = TextStyle(
  color: Colors.black,
  fontSize: 15,
);
const kMessageTextFieldDecoration = InputDecoration(
  contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
  hintText: 'Type your message here...',
  border: InputBorder.none,
);

const kMessageContainerDecoration = BoxDecoration(
  border: Border(
    top: BorderSide(color: Colors.lightBlueAccent, width: 2.0),
  ),
);

const kInputTextField = InputDecoration(
  hintText: 'Enter',
  contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(32.0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blueAccent, width: 1.2),
    borderRadius: BorderRadius.all(Radius.circular(32.0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blueAccent, width: 2.0),
    borderRadius: BorderRadius.all(Radius.circular(32.0)),
  ),
);

const kInputTextFieldEditData = InputDecoration(
  hintText: 'Enter',
  contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(20.0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blueAccent, width: 1.0),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blueAccent, width: 2.0),
    borderRadius: BorderRadius.all(Radius.circular(20.0)),
  ),
);

const kInputFieldTextStyle =
    TextStyle(fontSize: 20, color: Color.fromRGBO(180, 211, 175, 0.93));

String directory = 'storage/emulated/0/fluxmanager/data/';
//this section sets global default values for Pressure and Temperature, which are used if not given by Fluxmanager file

double defaultTemperature = 20;
double defaultPressure = 1000;

String temperature = '';
String pressure = '';

//These parameters are used to calculate the flux in g/d/m2

double chamberVolume = 0.002756; //in cubic meter
double chamberArea = 0.0314;
double gasConstant = 0.0831451;
double molarMassCO2 = 44.0095;
