import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/constants/constants.dart';

class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({Key? key}) : super(key: key);

  @override
  ConsumerState<SignInForm> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<SignInForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRegisterMode = false; // Toggles between Sign In and Register

  @override
  Widget build(BuildContext context) {
    final authManager = ref.watch(authenticationManagerProvider);
    final currentUser = authManager.currentUser;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: currentUser == null
            ? _buildAuthForm(authManager, context)
            : _buildLoggedInView(currentUser.email ?? ""),
      ),
      // ),
    );
  }

  Widget _buildAuthForm(
      AuthenticationManager authManager, BuildContext context) {
    return SingleChildScrollView(
        child: Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo Image
          Image.asset(
            'images/TT_Logo.png', // Your logo path here
            // height: 150, // Adjust height as needed
            // width: 150, // Adjust width as needed
          ),
          const SizedBox(height: 30),
          if (_isRegisterMode)
            TextFormField(
              controller: _userNameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: kGreenFluxColor),
              ),
              style: const TextStyle(color: kGreenFluxColor),
              validator: (value) =>
                  value!.isEmpty ? 'Enter your username' : null,
            ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: kGreenFluxColor),
            ),
            style: const TextStyle(color: kGreenFluxColor),
            validator: (value) => value!.isEmpty ? 'Enter your email' : null,
          ),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: kGreenFluxColor),
            ),
            style: const TextStyle(color: kGreenFluxColor),
            obscureText: true,
            validator: (value) => value!.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 20),
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
      ),
    ));
  }

  Widget _buildLoggedInView(String email) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Signed in as $email"),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            await ref.read(authenticationManagerProvider).signOut();
            setState(() {}); // Refresh UI after signing out
          },
          child: const Text("Sign Out"),
        ),
      ],
    );
  }
}
