import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terratrace/source/routing/app_router.dart';

class CreateProjects {
  final _auth = FirebaseAuth.instance;

  Future<void> createNewProject(projectName, context) async {
    User? user = _auth.currentUser;

    if (projectName != null) {
      if (_auth.currentUser != null) {
        final db = FirebaseFirestore.instance;
        DocumentSnapshot ds =
            await db.collection('projects').doc(projectName).get();
        if (ds.exists == false) {
          db.collection('projects').doc(projectName).set(
            {
              'name': projectName,
              'members': {user?.uid: 'owner'},
            },
          );

          Map? projectMember;
          FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .get()
              .then((DocumentSnapshot documentSnapshot) {
            projectMember = documentSnapshot.get('projects');
            if (projectMember != null) {
              projectMember![projectName] = 'owner';
              db
                  .collection('users')
                  .doc(user?.uid)
                  .update({'projects': projectMember});
            } else {
              projectMember![projectName] = 'owner';
              db
                  .collection('users')
                  .doc(user?.uid)
                  .set({'projects': projectMember});
            }
          });

          context.pushNamed(AppRoute.dataListScreen.name);
        } else {
          Alert(
            title: 'project name already exists',
            context: context,
          ).show();
        }
      } else {
        String email = '';
        String password = '';
        String userName = '';
        Alert(
            context: context,
            title: "User not logged in",
            content: Column(
              children: <Widget>[
                TextField(
                  onChanged: (value) {
                    userName = value;
                  },
                  decoration: InputDecoration(
                    icon: Icon(Icons.lock),
                    labelText: 'UserName',
                  ),
                ),
                TextField(
                  onChanged: (value) {
                    email = value;
                  },
                  decoration: InputDecoration(
                    icon: Icon(Icons.account_circle),
                    labelText: 'Email',
                  ),
                ),
                TextField(
                  onChanged: (value) {
                    password = value;
                  },
                  obscureText: true,
                  decoration: InputDecoration(
                    icon: Icon(Icons.lock),
                    labelText: 'Password',
                  ),
                ),
              ],
            ),
            buttons: [
              DialogButton(
                onPressed: () {
                  Navigator.pop(context);
                  FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: email, password: password);
                },
                child: Text(
                  "LOGIN",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              DialogButton(
                child: Text(
                  'REGISTER',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                onPressed: () async {
                  try {
                    final newUser = await _auth.createUserWithEmailAndPassword(
                        email: email.trim(), password: password);

                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(newUser.user?.uid)
                        .set({
                      'UserName': userName,
                      'UserID': newUser.user?.uid,
                      'UserEmail': newUser.user?.email,
                      'projects': {projectName: 'owner'}
                    });
                    context.pushNamed(AppRoute.projectmanager.name);
                    ;
                  } catch (e) {
                    print(e);
                    context.pushNamed(AppRoute.projectmanager.name);
                  }
                },
              )
            ]).show();
      }
    }
  }

  Future<void> createNewEmptyProject(
      String projectName, BuildContext context, User user) async {
    if (_auth.currentUser != null) {
      final db = FirebaseFirestore.instance;
      DocumentSnapshot ds =
          await db.collection('projects').doc(projectName).get();
      if (ds.exists == false) {
        db.collection('projects').doc(projectName).set(
          {
            'name': projectName,
            'members': {user.uid: 'owner'},
          },
        );

        Map projectMember;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .then((DocumentSnapshot documentSnapshot) {
          projectMember = documentSnapshot.get('projects');
          projectMember[projectName] = 'owner';
          db
              .collection('users')
              .doc(user.uid)
              .update({'projects': projectMember});
        });
        Alert(title: 'New remote project created', context: context, buttons: [
          DialogButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ]).show();
      } else {
        Alert(
          title: 'Project name already exists',
          context: context,
        ).show();
      }
    } else {
      String email = '';
      String password = '';
      String userName = '';
      Alert(
        context: context,
        title: "User not logged in",
        content: Column(
          children: <Widget>[
            TextField(
              onChanged: (value) {
                userName = value;
              },
              decoration: InputDecoration(
                icon: Icon(Icons.lock),
                labelText: 'UserName',
              ),
            ),
            TextField(
              onChanged: (value) {
                email = value;
              },
              decoration: InputDecoration(
                icon: Icon(Icons.account_circle),
                labelText: 'Email',
              ),
            ),
            TextField(
              onChanged: (value) {
                password = value;
              },
              obscureText: true,
              decoration: InputDecoration(
                icon: Icon(Icons.lock),
                labelText: 'Password',
              ),
            ),
          ],
        ),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance
                  .signInWithEmailAndPassword(email: email, password: password);
            },
            child: Text(
              "LOGIN",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          DialogButton(
            child: Text(
              'REGISTER',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            onPressed: () async {
              try {
                final newUser = await _auth.createUserWithEmailAndPassword(
                    email: email.trim(), password: password);

                FirebaseFirestore.instance
                    .collection('users')
                    .doc(newUser.user?.uid)
                    .set({
                  'UserName': userName,
                  'UserID': newUser.user?.uid,
                  'UserEmail': newUser.user?.email,
                  'projects': {projectName: 'owner'}
                });

                Navigator.pushNamed(context, AppRoute.projectmanager.name);
              } catch (e) {
                print(e);
                Navigator.pushNamed(context, AppRoute.projectmanager.name);
              }
            },
          )
        ],
      ).show();
    }
  }
}

final createNewRemoteProjectProvider =
    Provider.autoDispose<CreateProjects>((ref) {
  return CreateProjects();
});
