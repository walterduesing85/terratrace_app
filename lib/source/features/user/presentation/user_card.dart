import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/user/domain/user_managment.dart';

class UserCard extends StatefulWidget {
  const UserCard({
    required this.userName,
    required this.userMail,
    required this.userID,
    this.projectName,
    this.index,
    this.boxKey,
    this.userProjects,
    Key? key,
  }) : super(key: key);

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
  Icon? isMember;

  @override
  void initState() {
    checkIsMember();
    super.initState();
    checkIsMember();
  }

  void checkIsMember() {
    final projectRole = widget.userProjects?[widget.projectName];
    setState(() {
      isMember = projectRole == 'owner'
          ? Icon(Icons.card_membership, color: kGreenFluxColor)
          : projectRole == 'collaborator'
              ? Icon(Icons.how_to_reg, color: kGreenFluxColor)
              : projectRole == 'applicant'
                  ? Icon(Icons.contact_mail, color: kGreenFluxColor)
                  : Icon(Icons.person_add_disabled, color: Colors.redAccent);
    });
  }

  Future<void> _addUserToProject(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final String userName = widget.userName;
    bool? confirmedByUser = await Alert(
      title: 'Share data with $userName?',
      context: context,
      buttons: [
        DialogButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              Text('No', style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
        DialogButton(
          onPressed: () => Navigator.pop(context, true),
          child:
              Text('Yes', style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      ],
    ).show();

    if (confirmedByUser == true) {
      final projectRef = db.collection('projects').doc(widget.projectName);
      final userRef = db.collection('users').doc(widget.userID);

      final docSnapshot = await projectRef.get();
      if (docSnapshot.exists) {
        final projectMembers = docSnapshot.get('members') as Map;
        projectMembers[widget.userID] = 'collaborator';
        await projectRef.update({'members': projectMembers});
        widget.userProjects![widget.projectName] = 'collaborator';
        await userRef.update({'projects': widget.userProjects});

        setState(() => checkIsMember());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black45,
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Colors.white, width: 0.8), // **Thin white border**
        ),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 4, // **Slight elevation for a "floating" effect**
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            /// **👤 Membership Icon**
            CircleAvatar(
              backgroundColor: Colors.transparent,
              child: isMember,
            ),

            /// **📛 User Info**
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: kUserCardHeadeTextStyle.copyWith(
                      fontSize: 14,
                      color: Colors
                          .white, // **Ensures visibility on dark background**
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.userMail,
                    style: kUserCardSubtitleTextStyle.copyWith(
                      fontSize: 12,
                      color: Colors
                          .white70, // **Slightly dimmed for better contrast**
                    ),
                    overflow: TextOverflow.ellipsis,
                ),
                ],
              ),
            ),

            /// **➕ Add User Button**
            Consumer(
              builder: (context, ref, child) {
                final currentUserAsync = ref.watch(currentUserStateProvider);

                return currentUserAsync.when(
                  data: (currentUser) {
                    if (currentUser == null) {
                      return const SizedBox(); // Handle case where user is not logged in
                    }

                    return MaterialButton(
                      child: Icon(
                        Icons.add,
                        color: Colors.blueGrey,
                        size: 30,
                              ),
                      onPressed: () async {
                        await _addUserToProject(context);
                        await ref.read(userProvider).addCollaborator(
                              currentUser.uid, // Correct way to access userID
                              widget.userID,
                            );
                      },
                    );
                  },
                  loading: () =>
                      CircularProgressIndicator(), // Show a loader while fetching user
                  error: (error, stack) => Text("Error loading user"),
                );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
