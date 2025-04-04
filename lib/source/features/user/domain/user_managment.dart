import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

class User {
  final String? userName;
  final String? userMail;
  final String? userID;
  final Map<String, String>? projects;
  final Map<String, String>? collaborators; // New field for collaborators

  User(
      {this.userName,
      this.userMail,
      this.userID,
      this.projects,
      this.collaborators});

  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
      userName: doc['UserName'],
      userMail: doc['UserEmail'],
      userID: doc['UserID'],
      projects: Map<String, String>.from(doc['projects']),
      collaborators: doc['collaborators'] != null
          ? Map<String, String>.from(doc['collaborators'])
          : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'UserName': userName,
      'UserEmail': userMail,
      'UserID': userID,
      'projects': projects ?? {},
      'collaborators': collaborators ?? {},
    };
  }

  Future<void> addCollaborator(String ownerId, String collaboratorId) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Update owner's document
      await firestore.collection('users').doc(ownerId).update({
        "Collaborators": FieldValue.arrayUnion([collaboratorId]),
      });

      // Update collaborator's document
      await firestore.collection('users').doc(collaboratorId).update({
        "Collaborators": FieldValue.arrayUnion([ownerId]),
      });

      print("✅ Collaborators updated successfully.");
    } catch (e) {
      print("❌ Error adding collaborator: $e");
    }
  }
}

// Define the StreamProvider for fetching users as User objects
final firebaseUsersProvider = StreamProvider<List<User>>((ref) {
  final projectManager = ref.watch(projectManagementProvider.notifier);
  return projectManager.usersStream;
});

final userProvider = Provider<User>((ref) {
  return User();
});

final userSearchValueProvider = StateProvider<String>((ref) => '');
//TODO assign to user also the chamber volume and area
