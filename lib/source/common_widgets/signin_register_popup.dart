import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';

class SigninRegisterPopup {
  static void showAuthPopup(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AuthPopupContent(ref: ref),
        );
      },
    );
  }
}

class AuthPopupContent extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const AuthPopupContent({Key? key, required this.ref}) : super(key: key);

  @override
  ConsumerState<AuthPopupContent> createState() => _AuthPopupContentState();
}

class _AuthPopupContentState extends ConsumerState<AuthPopupContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRegisterMode = false; // Toggle between Sign In / Register

  @override
  Widget build(BuildContext context) {
    // final authManager = widget.ref.watch(authenticationManagerProvider);
    final AuthenticationManager authManager = AuthenticationManager();
    final currentUser = authManager.currentUser;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey, // Wrap the entire form
        child: currentUser == null
            ? _buildAuthForm(authManager, context)
            : _buildLoggedInView(authManager, context, currentUser.email ?? ""),
      ),
    );
  }

  Widget _buildAuthForm(
      AuthenticationManager authManager, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isRegisterMode ? "Register" : "Sign In",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_isRegisterMode)
          TextFormField(
            controller: _userNameController,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (value) => value!.isEmpty ? 'Enter your username' : null,
          ),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) => value!.isEmpty ? 'Enter your email' : null,
        ),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          validator: (value) => value!.isEmpty ? 'Enter your password' : null,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (_isRegisterMode) {
                await authManager.registerWithEmailAndPassword(
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                  _userNameController.text.trim(),
                  // "ProjectName", // Replace with actual project name if needed
                  context,
                );
              } else {
                await authManager.signInWithEmailAndPassword(
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                  context,
                );
              }
              Navigator.pop(context); // Close popup on success
            }
          },
          child: Text(_isRegisterMode ? 'Register' : 'Sign In'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
            });
          },
          child: Text(_isRegisterMode
              ? 'Already have an account? Sign In'
              : 'Don’t have an account? Register'),
        ),
      ],
    );
  }

  Widget _buildLoggedInView(
      AuthenticationManager authManager, BuildContext context, String email) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Signed in as $email"),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            await authManager.signOut();
            setState(() {}); // Refresh UI after signing out
          },
          child: const Text("Sign Out"),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
