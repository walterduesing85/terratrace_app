import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/project_manager/domain/project.dart';
import 'package:terratrace/source/features/project_manager/presentation/remote_project_card.dart';
import 'package:terratrace/source/features/user/domain/user_managment.dart';

class ProjectManagement {
  final projectCollection = FirebaseFirestore.instance.collection('projects');
  final userCollection = FirebaseFirestore.instance.collection('users');

  // Stream for Projects
  Stream<List<Project>> get projectsStream {
    return projectCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Project(
          name: doc['name'],
          members: doc['members'],
          // Other properties...
        );
      }).toList();
    });
  }

  // Stream for Flux Data
  Stream<List<FluxData>> getFluxDataStream(String project) {
    return projectCollection
        .doc(project)
        .collection('data')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FluxData(
          dataSite: doc['dataSite'],
          dataLong: doc['dataLong'],
          dataLat: doc['dataLat'],
          dataPress: doc['dataPress'],
          dataTemp: doc['dataTemp'],
          dataDate: doc['dataDate'],
          dataNote: doc['dataNote'] ?? 'none',
          dataInstrument: doc['dataInstrument'],
          dataCflux: doc['dataCflux'],
          dataSoilTemp: doc['dataSoilTemp'] ?? 'none',
          dataCfluxGram: doc['dataCfluxGram'],
          dataOrigin: doc['dataOrigin'],
          dataKey: doc['dataKey'],
        );
      }).toList();
    });
  }

  // User Stream
  Stream<List<User>> get usersStream {
    return userCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return User.fromDocument(doc);
      }).toList();
    });
  }

  Future<void> createFireStoreProject(String projectName) async {
    try {
      await projectCollection.doc(projectName).set({});
    } catch (e) {
      debugPrint('Error creating project: $e');
    }
  }

  Future<void> deleteFireStoreProject(
      String projectName, BuildContext context) async {
    try {
      await projectCollection.doc(projectName).delete();
    } catch (e) {
      _showErrorDialog(context, e.toString());
    }
  }

  Future<void> updateFluxData(String projectName, String dataKey,
      Map<String, dynamic> updatedFields) async {
    try {
      await projectCollection
          .doc(projectName)
          .collection('data')
          .doc(dataKey)
          .update(updatedFields);
    } catch (e) {
      debugPrint('Error updating FluxData: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

final projectManagementProvider = Provider<ProjectManagement>((ref) {
  return ProjectManagement();
});

final remoteProjectStreamProvider =
    StreamProvider.autoDispose<List<Project>>((ref) {
  final projectManagement = ref.watch(projectManagementProvider);
  return projectManagement.projectsStream;
});

final remoteProjectsCardStreamProvider2 =
    StreamProvider.autoDispose<List<RemoteProjectCard>>((ref) {
  final projectManagement = ref.watch(projectManagementProvider);
  final userAsync = ref.watch(currentUserStateProvider);
  // Transform userAsync into a stream of RemoteProjectCards
  return userAsync.when(
    data: (user) {
      // Stream transformation for valid user data
      return projectManagement.projectsStream.map((projects) {
        debugPrint('User: $user');
        return projects.map((project) {
          final userMembership =
              user == null ? null : project.members?[user.uid];

          final membershipStatus = userMembership == 'owner'
              ? const Icon(Icons.card_membership, color: Colors.green)
              : userMembership == 'collaborator'
                  ? const Icon(Icons.how_to_reg, color: Colors.blue)
                  : const Icon(Icons.person, color: Colors.grey);

          return RemoteProjectCard(
            project: project.name ?? 'Unnamed Project',
            membershipStatus: membershipStatus,
          );
        }).toList();
      });
    },
    loading: () {
      // Return a stream with an empty list while loading
      return Stream.value([]);
    },
    error: (error, stack) {
      debugPrint('Error fetching user data: $error');
      // Return a stream with an empty list on error
      return Stream.value([]);
    },
  );
});
