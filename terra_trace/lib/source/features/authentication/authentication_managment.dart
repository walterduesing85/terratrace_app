import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:riverpod/riverpod.dart';

class AuthenticationManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signInWithEmailAndPassword(
      String email, String password, context) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      await Alert(
        title: e.message,
        context: context,
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ).show();
    }
  }

  Future<void> registerWithEmailAndPassword(String email, String password,
      String projectName, String userName, context) async {
    try {
      final newUser = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(newUser.user?.uid);

      final userData = {
        'UserName': userName,
        'UserID': newUser.user?.uid,
        'UserEmail': newUser.user?.email,
        'projects': {projectName: 'owner'}
        // Modify the logic as needed
      };

      await userDocRef.set(userData);

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      await Alert(
        title: e.message,
        context: context,
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ).show();
    }
  }

  final user = FirebaseAuth.instance.currentUser;
}

class AuthenticationService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}

final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  return AuthenticationService();
});

final authenticationManagerProvider = Provider<AuthenticationManager>((ref) {
  return AuthenticationManager();
});

final currentUserProvider = Provider<User>((ref) {
  return ref.watch(authenticationManagerProvider).user!;
});

final currentUserStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authenticationServiceProvider);
  return authService.authStateChanges;
});

final firebaseAuthStreamProvider = StreamProvider.autoDispose<User?>((ref) {
  // Access the FirebaseAuth instance
  final auth = FirebaseAuth.instance;
  // Return a stream that listens to the authentication state changes

  return auth.authStateChanges();
});
