import 'package:flutter/material.dart';

class DataCard extends StatelessWidget {
  const DataCard({
    required this.site,
    required this.date,
  });
  final String site;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9,
      child: Card(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8.0,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.0),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
              color: const Color.fromRGBO(64, 75, 96, 1),
              borderRadius: BorderRadius.circular(15)),
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              leading: Container(
                padding: const EdgeInsets.only(
                  right: 24.0,
                ),
                decoration: const BoxDecoration(
                    border: Border(
                        right: BorderSide(width: 1.0, color: Colors.white24))),
                child: SizedBox(
                  width: 30,
                  child: MaterialButton(
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xFFC6FF00),
                    ),
                    onPressed: () {
                      print('Edit button pressed');
                    },
                  ),
                ),
              ),
              title: Text(
                site,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
              // subtitle: Text("Intermediate", style: TextStyle(color: Colors.white)),

              subtitle: Row(
                children: <Widget>[
                  Text(date,
                      style: const TextStyle(color: Colors.white, fontSize: 15))
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.only(
                  left: 16.0,
                ),
                decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(width: 1.0, color: Colors.white24))),
                child: SizedBox(
                  width: 40,
                  child: MaterialButton(
                    child: const Icon(Icons.gps_fixed,
                        color: Colors.white, size: 25.0),
                    onPressed: () {},
                  ),
                ),
              )),
        ),
      ),
    );
  }
}
