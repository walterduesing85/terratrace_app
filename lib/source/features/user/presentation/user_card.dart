import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terratrace/source/constants/constants.dart';

class UserCard extends StatefulWidget {
  UserCard({
    required this.userName,
    required this.userMail,
    required this.userID,
    this.projectName,
    this.index,
    this.boxKey,
    this.userProjects,
  });
  final String userName;
  final String userMail;
  final String? projectName;
  final int? index;
  final String? boxKey;
  final String userID;
  final Map? userProjects;

  @override
  _UserCardState createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  String truncateWithEllipsis(String str, int maxLength) {
    return (str.length <= maxLength)
        ? str
        : '${str.substring(0, maxLength - 3)}...';
  }

  Future<Map> memberStatus() async {
    var collection = FirebaseFirestore.instance.collection('users');
    var docSnapshot = await collection.doc(widget.userID).get();

    Map data = docSnapshot.data()!;
    Map projects = data['projects']; // <-- The value you want to retrieve.
    // Call setState if needed.

    return projects;
  }

  checkIsMember() {
    if (widget.userProjects![widget.projectName] == 'owner') {
      isMember = Icon(Icons.card_membership, color: kGreenFluxColor);
      setState(() {});
    } else if (widget.userProjects![widget.projectName] == 'collaborator') {
      isMember = Icon(Icons.how_to_reg, color: kGreenFluxColor);
      setState(() {});
    } else if (widget.userProjects![widget.projectName] == 'applicant') {
      isMember = Icon(Icons.contact_mail, color: kGreenFluxColor);
      setState(() {});
    } else if (widget.userProjects![widget.projectName] == null) {
      isMember = Icon(Icons.person_add_disabled, color: Colors.redAccent);
      setState(() {});
    }
  }

  Icon? isMember;

  @override
  void initState() {
    checkIsMember();
    super.initState();
  }

  bool? confirmedByUser;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.0),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              leading: Container(
                padding: EdgeInsets.only(
                  right: 24.0,
                ),
                decoration: BoxDecoration(
                    border: Border(
                        right: BorderSide(width: 1.0, color: Colors.white24))),
                child: SizedBox(
                  width: 30,
                  child: MaterialButton(
                    child: isMember,
                    onPressed: () {},
                  ),
                ),
              ),
              title: Text(
                truncateWithEllipsis(widget.userName, 20),
                style: kCardHeadeTextStyle,
              ),
              // subtitle: Text("Intermediate", style: TextStyle(color: Colors.white)),

              subtitle: Row(
                children: <Widget>[
                  Text(truncateWithEllipsis(widget.userMail, 15),
                      style: kCardSubtitleTextStyle),
                ],
              ),
              trailing: Container(
                padding: EdgeInsets.only(
                  left: 16.0,
                ),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(width: 1.0, color: Colors.white24))),
                child: SizedBox(
                  width: 40,
                  child: MaterialButton(
                    child: Icon(Icons.add, color: Colors.white, size: 25.0),
                    onPressed: () async {
                      final String userName = widget.userName;
                      final db = FirebaseFirestore.instance;
                      await Alert(
                          title:
                              'Are you sure you want to share your data with $userName?',
                          context: context,
                          buttons: [
                            DialogButton(
                              onPressed: () {
                                confirmedByUser = false;
                                setState(() {});
                                Navigator.pop(context);
                              },
                              child: Text(
                                'No',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                            DialogButton(
                              onPressed: () {
                                confirmedByUser = true;
                                Navigator.pop(context);
                                setState(() {});
                              },
                              child: Text(
                                'Yes',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                          ]).show();
// Get document with ID totalVisitors in collection dashboard
                      if (confirmedByUser == true) {
                        Map projectMember;
                        await db
                            .collection('projects')
                            .doc(widget.projectName)
                            .get()
                            .then((DocumentSnapshot documentSnapshot) {
                          // Get value of field date from document dashboard/totalVisitors

                          projectMember = documentSnapshot.get('members');

                          projectMember[widget.userID] = 'collaborator';

                          db
                              .collection('projects')
                              .doc(widget.projectName)
                              .update({'members': projectMember});
                        });

                        widget.userProjects![widget.projectName] =
                            'collaborator';

                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userID)
                            .update({'projects': widget.userProjects});

                        setState(() {
                          checkIsMember();
                        });
                      }
                    },
                  ),
                ),
              )),
        ),
      ),
    );
  }
}
