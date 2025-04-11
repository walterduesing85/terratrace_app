import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/user/presentation/user_card.dart';

class User {
  final String? userName;
  final String? userMail;
  final String? userID;
  final Map<String, String>? projects;
  final List<String>
      collaborators; // Updated to List<String> for Firebase array

  User({
    this.userName,
    this.userMail,
    this.userID,
    this.projects,
    this.collaborators = const [], // Default empty list for collaborators
  });

  factory User.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      print("⚠️ Document has no data: ${doc.id}");
      return User();
    }

    final collaboratorsRaw = data['Collaborators'];

    if (collaboratorsRaw == null) {
      print("⚠️ Document ${doc.id} has no 'Collaborators' field.");
    }

    return User(
      userName: data['UserName'] ?? 'Unknown User',
      userMail: data['UserEmail'] ?? 'No email',
      userID: data['UserID'] ?? '',
      projects: Map<String, String>.from(data['projects'] ?? {}),
      collaborators:
          collaboratorsRaw != null ? List<String>.from(collaboratorsRaw) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'UserName': userName,
      'UserEmail': userMail,
      'UserID': userID,
      'projects': projects ?? {},
      'Collaborators': collaborators,
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

  Future<List<String>> getCollaboratorIDs(String userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null && data.containsKey('Collaborators')) {
      return List<String>.from(data['Collaborators']);
    } else {
      return [];
    }
  }
}

final userProvider = Provider<User>((ref) {
  return User();
});

final userCardsProvider = StreamProvider<List<UserCard>>((ref) async* {
  final currentUser = await ref.watch(currentUserStateProvider.future);
  final searchQuery = ref.watch(userSearchValueProvider);
  final currentProjectName = ref.watch(projectNameProvider);

  if (currentUser == null) {
    print("⚠️ No current user found.");
    yield [];
    return;
  }

  final userId = currentUser.uid;
  final usersStream =
      FirebaseFirestore.instance.collection('users').snapshots();

  List<String> collaboratorIDs = [];

  if (searchQuery.isEmpty) {
    collaboratorIDs = await ref.watch(userProvider).getCollaboratorIDs(userId);
    print("👥 Collaborators of current user: $collaboratorIDs");
  }

  await for (var snapshot in usersStream) {
    print("📦 Fetched ${snapshot.docs.length} users from Firestore");

    final userCards =
        snapshot.docs.map((doc) => User.fromDocument(doc)).where((user) {
      if (searchQuery.isEmpty) {
        final isCollaborator = collaboratorIDs.contains(user.userID);
        if (!isCollaborator) {
          print("❌ Skipping non-collaborator ${user.userID}");
        }
        return isCollaborator;
      } else {
        // if searching, include everyone
        return true;
      }
    }).map((user) {
      final projectRole = user.projects?[currentProjectName];
      Icon? userIcon;

      if (projectRole == 'owner') {
        userIcon = Icon(Icons.card_membership, color: kGreenFluxColor);
      } else if (projectRole == 'collaborator') {
        userIcon = Icon(Icons.how_to_reg, color: kGreenFluxColor);
      } else if (projectRole == 'applicant') {
        userIcon = Icon(Icons.contact_mail, color: kGreenFluxColor);
      } else {
        userIcon = Icon(Icons.person_add_disabled, color: Colors.redAccent);
      }

      return UserCard(
        userName: user.userName ?? 'Unknown User',
        userMail: user.userMail ?? 'No email',
        userID: user.userID ?? '',
        projectName: currentProjectName,
        userProjects: user.projects ?? {},
        userIcon: userIcon,
      );
    }).toList();

    if (searchQuery.isNotEmpty) {
      final queryLower = searchQuery.toLowerCase();
      final filtered = userCards.where((userCard) {
        return userCard.userName.toLowerCase().contains(queryLower) ||
            userCard.userMail.toLowerCase().contains(queryLower);
      }).toList();

      print(
          "🔍 Search query '${searchQuery}': matched ${filtered.length} users.");
      yield filtered;
    } else {
      yield userCards;
    }
  }
});

final userSearchValueProvider = StateProvider<String>((ref) => '');
