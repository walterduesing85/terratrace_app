import 'package:firebase_auth/firebase_auth.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:riverpod/riverpod.dart';

final firebaseAuthStreamProvider = StreamProvider.autoDispose<User>((ref) {
  // Access the FirebaseAuth instance
  final auth = FirebaseAuth.instance;
  // Return a stream that listens to the authentication state changes

  return auth.authStateChanges();
});

final appBarTitleProvider = FutureProvider.autoDispose<String>((ref) async {
  final userAsyncValue = ref.watch(firebaseAuthStreamProvider);
  final isConnectedAsyncValue = ref.watch(internetConnectionProvider);

  if (userAsyncValue is AsyncData && userAsyncValue.value != null) {
    // If user is signed in, return the user's email
    return userAsyncValue.value.email ?? 'No email available';
  } else if (isConnectedAsyncValue is AsyncData &&
      !isConnectedAsyncValue.value) {
    // If not connected to the internet, return 'No Internet Connection'
    return 'No Internet Connection';
  } else {
    // If not signed in and connected to the internet, return 'Not Signed In'
    return 'Not Signed In';
  }
});

final internetConnectionProvider = FutureProvider<bool>((ref) async {
  final isConnected = await InternetConnectionChecker().hasConnection;
  return isConnected;
});

final userProjectsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  // Access user information from FirebaseAuth instance
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  // Fetch user projects if the user is authenticated
  if (user != null) {
    // Simulated fetching of user projects from Firebase (replace with your implementation)
    await Future.delayed(const Duration(seconds: 2)); // Simulating delay
    return [
      'Project 1',
      'Project 2',
      'Project 3'
    ]; // Replace with actual user projects
  } else {
    return []; // Return empty list if user is not authenticated
  }
});
