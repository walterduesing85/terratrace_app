// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:csv/csv.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:terratrace/source/features/authentication/authentication_managment.dart';
// import 'package:terratrace/source/features/data/domain/flux_data.dart';
// import 'package:terratrace/source/features/project_manager/domain/project.dart';
// import 'package:terratrace/source/features/project_manager/presentation/remote_project_card.dart';
// import 'package:terratrace/source/features/user/domain/user_managment.dart';

// class ProjectManagement {
//   final projectCollection = FirebaseFirestore.instance.collection('projects');
//   final userCollection = FirebaseFirestore.instance.collection('users');

//   Timer? _simulationTimer;
//   List<FluxData> _sortedFluxData = [];
//   int _currentIndex = 0;

//   /// **Load and parse CSV, then sort data by date**
//   Future<void> loadAndSortFluxData() async {
//     final csvData = await rootBundle.loadString("assets/flux_data.csv");
//     final List<List<dynamic>> csvTable =
//         const CsvToListConverter().convert(csvData);

//     // Remove header row
//     csvTable.removeAt(0);

//     // Parse rows into `FluxData`
//     _sortedFluxData = csvTable
//         .map((row) => FluxData(
//               dataSite: row[0].toString(),
//               dataLat: row[1].toString(),
//               dataLong: row[2].toString(),
//               dataTemp: row[3].toString(),
//               dataPress: row[4].toString(),
//               dataCflux: row[5].toString(),
//               dataDate: row[9].toString(),
//               dataNote: row[7].toString(),
//               dataInstrument: row[8].toString(),
//               dataCfluxGram: row[10].toString(),
//               dataOrigin: "Simulated",
//               dataKey: DateTime.now()
//                   .millisecondsSinceEpoch
//                   .toString(), // Unique key
//             ))
//         .toList();

//     // **Sort by date (oldest first)**
//     DateFormat dateFormat = DateFormat("dd-MM-yyyy HH:mm:s");
//     _sortedFluxData.sort((a, b) {
//       DateTime dateA = dateFormat.parse(a.dataDate!);
//       DateTime dateB = dateFormat.parse(b.dataDate!);
//       return dateA.compareTo(dateB);
//     });

//     _currentIndex = 0;
//   }

//   /// **Simulate real-time flux data injection to Firestore**
//   void startFluxSimulation(String projectName) {
//     print(
//         "Starting simulation... and sorted data length is ${_sortedFluxData.length}");
//     _simulationTimer?.cancel(); // Cancel existing simulation if running

//     _simulationTimer =
//         Timer.periodic(const Duration(seconds: 5), (timer) async {
//       if (_currentIndex < _sortedFluxData.length) {
//         await addFluxDataToFirebase(
//             projectName, _sortedFluxData[_currentIndex]);
//         _currentIndex++;
//       } else {
//         timer.cancel(); // Stop when all data has been uploaded
//       }
//     });
//   }

//   /// **Stop the simulation**
//   void stopFluxSimulation() {
//     _simulationTimer?.cancel();
//   }

//   /// **Add individual flux data points to Firebase**
//   Future<void> addFluxDataToFirebase(String projectName, FluxData data) async {
//     try {
//       await projectCollection.doc(projectName).collection('data').doc().set({
//         'dataSite': data.dataSite,
//         'dataLong': data.dataLong,
//         'dataLat': data.dataLat,
//         'dataTemp': data.dataTemp,
//         'dataPress': data.dataPress,
//         'dataCflux': data.dataCflux,
//         'dataDate': data.dataDate,
//         'dataNote': data.dataNote,
//         'dataSoilTemp': "null",
//         'dataInstrument': data.dataInstrument,
//         'dataCfluxGram': data.dataCfluxGram,
//         'dataOrigin': data.dataOrigin,
//         'dataKey': data.dataKey,
//       });
//     } catch (e) {
//       debugPrint('Error adding flux data: $e');
//     }
//   }

//   // Stream for Projects
//   Stream<List<Project>> get projectsStream {
//     return projectCollection.snapshots().map((snapshot) {
//       return snapshot.docs.map((doc) {
//         return Project(
//           name: doc['name'],
//           members: doc['members'],
//           // Other properties...
//         );
//       }).toList();
//     });
//   }

//   Stream<List<Project>> getUserProjects(String userId) {
//     return projectCollection
//         .where('members.$userId',
//             isEqualTo: 'owner') // or just check existence with isNull: false
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) {
//         return Project(
//           name: doc['name'],
//           members: doc['members'],
//           // Other properties...
//         );
//       }).toList();
//     });
//   }

//   // Stream for Flux Data
//   Stream<List<FluxData>> getFluxDataStream(String project) {
//     return projectCollection
//         .doc(project)
//         .collection('data')
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) {
//         return FluxData(
//           dataSite: doc['dataSite'],
//           dataLong: doc['dataLong'],
//           dataLat: doc['dataLat'],
//           dataPress: doc['dataPress'],
//           dataTemp: doc['dataTemp'],
//           dataDate: doc['dataDate'],
//           dataNote: doc['dataNote'] ?? 'none',
//           dataInstrument: doc['dataInstrument'],
//           dataCflux: doc['dataCflux'],
//           dataSoilTemp: doc['dataSoilTemp'] ?? 'none',
//           dataCfluxGram: doc['dataCfluxGram'],
//           dataOrigin: doc['dataOrigin'],
//           dataKey: doc['dataKey'],
//         );
//       }).toList();
//     });
//   }

//   // User Stream
//   Stream<List<User>> get usersStream {
//     return userCollection.snapshots().map((snapshot) {
//       return snapshot.docs.map((doc) {
//         return User.fromDocument(doc);
//       }).toList();
//     });
//   }

//   Future<void> createFireStoreProject(String projectName) async {
//     try {
//       await projectCollection.doc(projectName).set({});
//     } catch (e) {
//       debugPrint('Error creating project: $e');
//     }
//   }

//   Future<void> deleteFireStoreProject(
//       String projectName, BuildContext context) async {
//     try {
//       final projectDoc = await projectCollection.doc(projectName).get();

//       if (!projectDoc.exists) {
//         throw Exception("Project does not exist.");
//       }

//       final projectData = projectDoc.data();
//       final members = projectData?['members'] ?? {}; // Get project members

//       // Start a batch operation to delete references efficiently
//       final batch = FirebaseFirestore.instance.batch();

//       // Remove project reference from each user's "projects" field
//       for (String userId in members.keys) {
//         final userDocRef =
//             FirebaseFirestore.instance.collection('users').doc(userId);
//         batch.update(userDocRef, {
//           'projects.$projectName': FieldValue.delete(),
//         });
//       }

//       // Delete the project document
//       batch.delete(projectCollection.doc(projectName));

//       // Commit batch operation
//       await batch.commit();
//     } catch (e) {
//       _showErrorDialog(context, e.toString());
//     }
//   }

//   Future<void> updateFluxData(String projectName, String dataKey,
//       Map<String, dynamic> updatedFields) async {
//     try {
//       await projectCollection
//           .doc(projectName)
//           .collection('data')
//           .doc(dataKey)
//           .update(updatedFields);
//     } catch (e) {
//       debugPrint('Error updating FluxData: $e');
//     }
//   }

//   void _showErrorDialog(BuildContext context, String errorMessage) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Error'),
//         content: Text(errorMessage),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// final projectManagementProvider = Provider<ProjectManagement>((ref) {
//   return ProjectManagement();
// });


// final remoteProjectStreamProvider =
//     StreamProvider.autoDispose<List<Project>>((ref) {
//   final projectManagement = ref.watch(projectManagementProvider);
//   return projectManagement.projectsStream;
// });
// final remoteProjectsCardStreamProvider2 =
//     StreamProvider.autoDispose<List<RemoteProjectCard>>((ref) {
//   final projectManagement = ref.watch(projectManagementProvider);
//   final userAsync = ref.watch(currentUserStateProvider);

//   return userAsync.when(
//     data: (user) {
//       if (user == null) return Stream.value([]);

//       // Filter projects where the user is a member
//       return projectManagement.getUserProjects(user.uid).map((projects) {
//         debugPrint('User: ${user.uid}');

//         return projects.map((project) {
//           final userMembership = project.members?[user.uid];

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
//     loading: () => Stream.value([]),
//     error: (error, stack) {
//       debugPrint('Error fetching user data: $error');
//       return Stream.value([]);
//     },
//   );
// });

