import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';

class User {
  final String? userName;
  final String? userMail;
  final String? userID;
  final Map<String, String>? projects;

  User({this.userName, this.userMail, this.userID, this.projects});

  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
      userName: doc['UserName'],
      userMail: doc['UserEmail'],
      userID: doc['UserID'],
      projects: Map<String, String>.from(doc['projects']),
    );
  }
}

// Define the StreamProvider for fetching users as User objects
final firebaseUsersProvider = StreamProvider<List<User>>((ref) {
  final projectManager = ref.watch(projectManagementProvider);
  return projectManager.usersStream;
});

final userSearchValueProvider = StateProvider<String>((ref) => '');
