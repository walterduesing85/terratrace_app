// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

class RoundedButton extends StatelessWidget {
  const RoundedButton({
   
    @required this.buttonColor,
    @required this.buttonText,
    @required this.goTo,
  });

  final Color buttonColor;
  final String buttonText;
  final VoidCallback goTo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Material(
        elevation: 5.0,
        color: buttonColor,
        borderRadius: BorderRadius.circular(20.0),
        child: MaterialButton(
          onPressed: goTo,
          minWidth: 50.0,
          height: 42.0,
          child: Text(
            buttonText,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
