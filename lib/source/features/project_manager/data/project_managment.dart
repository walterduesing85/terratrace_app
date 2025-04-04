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
          name: doc.id, //['name'],
          members: doc['members'],
          // Other properties...
        );
      }).toList();
    });
  }

  Stream<List<Project>> getUserProjects(String userId) {
    return projectCollection
        .where('members.$userId',
            isEqualTo: 'owner') // or just check existence with isNull: false
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Project(
          name: doc.id, //['name'],
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
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return FluxData(
          dataSite: doc['dataSite'],
          dataLong: doc['dataLong'],
          dataLat: doc['dataLat'],
          // dataPress: doc['dataPress'],
          // dataTemp: doc['dataTemp'],
          dataDate: doc['dataDate'],
          dataNote: doc['dataNote'] ?? 'none',
          dataInstrument: doc['dataInstrument'],
          dataCflux: doc['dataCflux'],
          // dataSoilTemp: doc['dataSoilTemp'] ?? 'none',
          dataCfluxGram: doc['dataCfluxGram'],
          dataKey: doc['dataKey'],

          // Newly added location parameters
          dataPoint: data['dataPoint'] ?? 'none',
          dataLocationAccuracy: data['dataLocationAccuracy'] ?? 'none',

          // Statistical parameters with default values
          dataSwcAvg: data['dataSwcAvg'] ?? '',
          dataSoilTempAvg: data['dataSoilTempAvg'] ?? '',
          dataBarPrAvg: data['dataBarPrAvg'] ?? '',
          dataAirTempAvg: data['dataAirTempAvg'] ?? '',
          dataRhAvg: data['dataRhAvg'] ?? '',
          dataCellTempAvg: data['dataCellTempAvg'] ?? '',
          dataCellPressAvg: data['dataCellPressAvg'] ?? '',
          dataWsAvg: data['dataWsAvg'] ?? '',
          dataWdaAvg: data['dataWdaAvg'] ?? '',
          dataRadAvg: data['dataRadAvg'] ?? '',
          dataParAvg: data['dataParAvg'] ?? '',

          dataMbus: (data['dataMbus'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          // MAX values for FLX params
          dataCh4max: data['dataCh4max'] ?? '',
          dataCo2HiFsmax: data['dataCo2HiFsmax'] ?? '',
          dataCo2max: data['dataCo2max'] ?? '',
          dataH2omax: data['dataH2omax'] ?? '',
          dataVocmax: data['dataVocmax'] ?? '',
          // Statistical parameters for FLX data
          dataCo2RSquared: data['dataCo2RSquared'] ?? 'none',
          dataCo2Slope: data['dataCo2Slope'] ?? 'none',

          dataCo2HiFsRSquared: data['dataCo2HiFsRSquared'] ?? 'none',
          dataCo2HiFsSlope: data['dataCo2HiFsSlope'] ?? 'none',

          dataVocRSquared: data['dataVocRSquared'] ?? 'none',
          dataVocSlope: data['dataVocSlope'] ?? 'none',

          dataCh4RSquared: data['dataCh4RSquared'] ?? 'none',
          dataCh4Slope: data['dataCh4Slope'] ?? 'none',

          dataH20RSquared: data['dataH20RSquared'] ?? 'none',
          dataH2oSlope: data['dataH2oSlope'] ?? 'none',

          // Flux data
          dataCo2HiFsflux: data['dataCo2HiFsflux'] ?? 'none',
          dataCo2HiFsfluxGram: data['dataCo2HiFsfluxGram'] ?? 'none',

          dataVocflux: data['dataVocflux'] ?? 'none',
          dataVocfluxGram: data['dataVocfluxGram'] ?? 'none',

          dataCh4flux: data['dataCh4flux'] ?? 'none',
          dataCh4fluxGram: data['dataCh4fluxGram'] ?? 'none',

          dataH2oflux: data['dataH2oflux'] ?? 'none',
          dataH2ofluxGram: data['dataH2ofluxGram'] ?? 'none',
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
      final projectDoc = await projectCollection.doc(projectName).get();

      if (!projectDoc.exists) {
        throw Exception("Project does not exist.");
      }

      final projectData = projectDoc.data();
      final members = projectData?['members'] ?? {}; // Get project members

      // Start a batch operation to delete references efficiently
      // final batch = FirebaseFirestore.instance.batch();

      // Remove project reference from each user's "projects" field
      for (String userId in members.keys) {
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(userId);
        userDocRef.update({
          'projects.$projectName': FieldValue.delete(),
        });
        // batch.update(userDocRef, {
        //   'projects.$projectName': FieldValue.delete(),
        // });
      }

      await projectCollection.doc(projectName).delete();
      // // Delete the project document
      // batch.delete(projectCollection.doc(projectName));

      // // Commit batch operation
      // await batch.commit();
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

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);

      // Filter projects where the user is a member
      return projectManagement.getUserProjects(user.uid).map((projects) {
        debugPrint('User: ${user.uid}');

        return projects.map((project) {
          final userMembership = project.members?[user.uid];

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
    loading: () => Stream.value([]),
    error: (error, stack) {
      debugPrint('Error fetching user data: $error');
      return Stream.value([]);
    },
  );
});

// final remoteProjectsCardStreamProvider2 =
//     StreamProvider.autoDispose<List<RemoteProjectCard>>((ref) {
//   final projectManagement = ref.watch(projectManagementProvider);
//   final userAsync = ref.watch(currentUserStateProvider);
//   // Transform userAsync into a stream of RemoteProjectCards
//   return userAsync.when(
//     data: (user) {
//       // Stream transformation for valid user data
//       return projectManagement.projectsStream.map((projects) {
//         debugPrint('User: $user');
//         return projects.map((project) {
//           final userMembership =
//               user == null ? null : project.members?[user.uid];

//           final membershipStatus = userMembership == 'owner'
//               ? const Icon(Icons.card_membership, color: Colors.green)
//               : userMembership == 'collaborator'
//                   ? const Icon(Icons.how_to_reg, color: Colors.blue)
//                   : const Icon(Icons.person, color: Colors.grey);

//           return RemoteProjectCard(
//             project: project.name ?? 'Unnamed Project',
//             membershipStatus: membershipStatus,
//           );
//         }).toList();
//       });
//     },
//     loading: () {
//       // Return a stream with an empty list while loading
//       return Stream.value([]);
//     },
//     error: (error, stack) {
//       debugPrint('Error fetching user data: $error');
//       // Return a stream with an empty list on error
//       return Stream.value([]);
//     },
//   );
// });
