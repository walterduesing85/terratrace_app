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
      String email, String password, BuildContext context) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      debugPrint('User signed in: ${userCredential.user?.email}');
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(context, e.message);
    }
  }

  Future<void> registerWithEmailAndPassword(String email, String password,
      String projectName, String userName, BuildContext context) async {
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
      };

      await userDocRef.set(userData);

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(context, e.message);
    }
  }

  void _showErrorDialog(BuildContext context, String? errorMessage) {
    Alert(
      title: errorMessage,
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

  User? get currentUser => _auth.currentUser;
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

final currentUserStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authenticationServiceProvider);
  return authService.authStateChanges;
});

class UserStateNotifier extends StateNotifier<User?> {
  UserStateNotifier() : super(null);

  void updateUser(User? user) => state = user;
}

final userStateProvider =
    StateNotifierProvider<UserStateNotifier, User?>((ref) {
  return UserStateNotifier();
});
