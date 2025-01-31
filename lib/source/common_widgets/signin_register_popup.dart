import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';

class SigninRegisterPopup {
  SigninRegisterPopup({required this.projectName});
  final String projectName;

  Future<void> openPopup(BuildContext context) async {
    final AuthenticationManager authManager = AuthenticationManager();
    final currentUser = authManager.currentUser;

    String email =
        currentUser?.email ?? ''; // Get current user's email if signed in
    String password = ''; // Declare password variable
    String userName = ''; // Declare username variable

    Alert(
      context: context,
      title:
          currentUser == null ? "User not logged in" : "User already signed in",
      content: Column(
        children: <Widget>[
          if (currentUser == null) ...[
            TextField(
              onChanged: (value) {
                userName = value;
              },
              decoration: const InputDecoration(
                icon: Icon(Icons.account_circle),
                labelText: 'UserName',
              ),
            ),
            TextField(
              onChanged: (value) {
                email = value;
              },
              decoration: const InputDecoration(
                icon: Icon(Icons.account_circle),
                labelText: 'Email',
              ),
            ),
            TextField(
              onChanged: (value) {
                password = value;
              },
              obscureText: true,
              decoration: const InputDecoration(
                icon: Icon(Icons.lock),
                labelText: 'Password',
              ),
            ),
          ] else ...[
            Text('Signed in as $email'),
          ],
        ],
      ),
      buttons: [
        if (currentUser == null) ...[
          DialogButton(
            onPressed: () async {
              if (email.isNotEmpty && password.isNotEmpty) {
                await authManager.signInWithEmailAndPassword(
                    email, password, context);
                Navigator.pop(context);
              } else {
                // Show error message if email or password is empty
                _showErrorMessage(
                    context, 'Please enter both email and password.');
              }
            },
            child: const Text(
              "LOGIN",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          DialogButton(
            onPressed: () async {
              if (email.isNotEmpty &&
                  password.isNotEmpty &&
                  userName.isNotEmpty) {
                await authManager.registerWithEmailAndPassword(
                    email, password, userName, projectName, context);
                Navigator.pop(context);
              } else {
                // Show error message if email, password, or username is empty
                _showErrorMessage(context,
                    'Please fill in all fields (email, password, username) to register.');
              }
            },
            child: const Text(
              'REGISTER',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ] else ...[
          DialogButton(
            onPressed: () async {
              await authManager.signOut();
              Navigator.pop(context);
              openPopup(
                  context); // Reopen the popup for sign-in/register after sign-out
            },
            child: const Text(
              'SIGN OUT',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ],
    ).show();
  }

  void _showErrorMessage(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
