import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:terratrace/source/constants/constants.dart';

import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/user/presentation/user_card.dart';

class TabUser extends StatefulWidget {
  @override
  _TabUserState createState() => _TabUserState();
}

class _TabUserState extends State<TabUser> {
  String? searchValue;
  var _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer(builder: (context, WidgetRef ref, _) {
        return Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  style: TextStyle(
                    fontSize: 25,
                    color: Colors.white70,
                  ),
                  controller: _controller,
                  onChanged: (value) {
                    setState(() {
                      searchValue = value;
                    });
                  },
                  decoration: kInputTextField.copyWith(
                      suffixIcon: CircleIconButton(onPressed: () {
                        setState(() {
                          _controller.clear();
                          searchValue = null;
                          FocusScopeNode currentFocus = FocusScope.of(context);
                          if (!currentFocus.hasPrimaryFocus &&
                              currentFocus.focusedChild != null) {
                            currentFocus.focusedChild?.unfocus();
                          }
                        });
                      }),
                      hintText: 'search user',
                      hintStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      )),
                ),
              ),
            ),
            Expanded(
                child: StreamBuilder(
              //TODO make the search functionality work
              stream: searchValue == null || searchValue?.isEmpty == true
                  ? FirebaseFirestore.instance.collection('users').snapshots()
                  : FirebaseFirestore.instance
                      .collection('users')
                      .where('userName', isGreaterThanOrEqualTo: searchValue)
                      .where('userName',
                          isLessThanOrEqualTo: (searchValue ?? '') + '\uf8ff')
                      .snapshots(),
              builder: (ctx, streamSnapshot) {
                if (streamSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!streamSnapshot.hasData) {
                  return Center(
                    child: Text('No users found'),
                  );
                }

                final documents = streamSnapshot.data?.docs ?? [];

                return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (ctx, index) => UserCard(
                          projectName: ref.read(projectNameProvider),
                          userID: documents[index]['UserID'],
                          userName: documents[index]['UserName'],
                          userMail: documents[index]['UserEmail'],
                          userProjects: documents[index]['projects'],
                        ));
              },
            )),
          ],
        );
      }),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final double size;
  final Function() onPressed;
  final IconData icon;

  CircleIconButton(
      {this.size = 30.0, this.icon = Icons.clear, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onPressed,
        child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment(0.0, 0.0), // all centered
              children: <Widget>[
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.grey[300]),
                ),
                Icon(
                  icon,
                  size: size * 0.6, // 60% width for icon
                )
              ],
            )));
  }
}
