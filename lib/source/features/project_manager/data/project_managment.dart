import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

import 'package:terratrace/source/features/project_manager/domain/project.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_card_drawer.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_card_project_manager.dart';
import 'package:terratrace/source/features/project_manager/presentation/remote_project_card.dart';
import 'package:terratrace/source/features/user/domain/user_managment.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

class ProjectState {
  final String projectName;
  final List<FluxData> fluxDataList;

  ProjectState({required this.projectName, required this.fluxDataList});

  ProjectState copyWith({String? projectName, List<FluxData>? fluxDataList}) {
    return ProjectState(
      projectName: projectName ?? this.projectName,
      fluxDataList: fluxDataList ?? this.fluxDataList,
    );
  }

  ProjectState clear() {
    return ProjectState(projectName: "", fluxDataList: []);
  }
}

class ProjectManagementNotifier extends StateNotifier<ProjectState> {
  ProjectManagementNotifier(this.ref)
      : super(ProjectState(projectName: "", fluxDataList: []));

  final Ref ref;
  final projectCollection = FirebaseFirestore.instance.collection('projects');
  final userCollection = FirebaseFirestore.instance.collection('users');

  Timer? _simulationTimer;
  List<FluxData> _sortedFluxData = [];
  int _currentIndex = 0;

  setProjectName(String value) {
    state = state.copyWith(
        projectName:
            value); // ✅ Correct: Update `projectName` within `ProjectState`
  }

  void clearProjectName() {
    state = state.copyWith(
        projectName: ""); // ✅ Correct: Clear project name within `ProjectState`
  }

  /// **📂 Load project data from Firestore**
  Future<void> loadProject(String projectName) async {
    print("📂 Loading project: $projectName");

    final snapshot =
        await projectCollection.doc(projectName).collection('data').get();

    final newFluxData = snapshot.docs.map((doc) {
      return FluxData(
        dataMbus: doc['dataMbus'],
        dataSite: doc['dataSite'],
        dataLong: doc['dataLong'],
        dataLat: doc['dataLat'],
        dataPress: doc['dataPress'],
        dataTemp: doc['dataTemp'],
        dataDate: doc['dataDate'],
        dataNote: doc['dataNote'] ?? 'none',
        dataInstrument: doc['dataInstrument'],
        dataCflux: doc['dataCflux'],
        dataVocfluxGram: doc['dataVocfluxGram'],
        dataCh4fluxGram: doc['dataCh4fluxGram'],
        dataH2ofluxGram: doc['dataH2ofluxGram'],
        dataSoilTemp: doc['dataSoilTemp'] ?? 'none',
        dataCfluxGram: doc['dataCfluxGram'],
        dataKey: doc['dataKey'],
      );
    }).toList();

    // ✅ Update state with loaded data
    state = state.copyWith(fluxDataList: newFluxData);

    print(
        "✅ Project loaded: ${state.projectName} with ${newFluxData.length} data points.");
  }

  /// **▶️ Start Flux Data Simulation**
  void startFluxSimulation() async {
    if (state.projectName.isEmpty) {
      print("🚨 ERROR: Cannot start simulation without a project name!");
      return;
    }

    await loadAndSortFluxData();
    print("▶️ Starting simulation for ${state.projectName}...");

    _simulationTimer?.cancel(); // Cancel any existing simulation

    print("✅ Flux data loaded and sorted: ${_sortedFluxData.length} points.");

    _simulationTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentIndex < _sortedFluxData.length) {
        await addFluxDataToFirebase(
            state.projectName, _sortedFluxData[_currentIndex]);
        _currentIndex++;
      } else {
        timer.cancel(); // Stop when all data has been uploaded
      }
    });
  }

//Parse scientific notation

  double parseScientificNotation(String value) {
    try {
      return double.parse(value.replaceAll(",", ".")); // Convert to decimal
    } catch (e) {
      print("🚨 ERROR parsing scientific notation: $value");
      return 0.0; // Default fallback
    }
  }

  /// **Load and parse CSV, then sort data by date**

  Future<void> loadAndSortFluxData() async {
    print("📂 Loading and sorting flux data...");

    try {
      final csvData =
          await rootBundle.loadString("assets/extracted_flux_data.csv");
      print(
          "✅ CSV loaded successfully. First 500 chars:\n${csvData.substring(0, 500)}");

      final List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: "\n",
      ).convert(csvData);

      if (csvTable.isEmpty || csvTable.length == 1) {
        print("🚨 ERROR: CSV file is empty or contains only headers.");
        return;
      }

      print("✅ CSV successfully parsed with ${csvTable.length} rows.");

      // Extract headers
      final headers = csvTable.first;
      csvTable.removeAt(0); // Remove header row

      // Ensure each row has enough columns
      _sortedFluxData = csvTable.map((row) {
        while (row.length < headers.length) {
          row.add("N/A"); // Fill missing columns
        }

        return FluxData(
          dataInstrument: row[0].toString(), // INSTRUMENT S/N
          dataDate: row[1].toString(), // TIME
          dataSite: row[2].toString(), // SITE
          dataPoint: row[3].toString(), // POINT
          dataLong: row[4].toString(), // LONGITUDE
          dataLat: row[5].toString(), // LATITUDE
          dataLocationAccuracy: row[6].toString(), // POSITION_ERROR (m)

          dataTemp: row[9].toString(), // TEMPERATURE (°C)
          dataPress: row[10].toString(), // PRESSURE (HPa)

          dataCflux: row[14].toString(), // FLUX (ppm/sec)
          dataCfluxGram: row[14].toString(), // FLUX (moles/m²/d)
          dataCo2RSquared: row[17].toString(), // R²
          dataCh4fluxGram: row[17].toString(),
          dataVocfluxGram: row[18].toString(),
          dataH2ofluxGram: row[19].toString(),
          dataKey: generateUniqueKey(), // Unique key
        );
      }).toList();

      print(
          "✅ Flux data parsed successfully with ${_sortedFluxData.length} points.");

      // **Sort by date (oldest first)**
      DateFormat dateFormat = DateFormat("dd-MM-yyyy HH:mm:ss");
      _sortedFluxData.sort((a, b) {
        DateTime dateA = dateFormat.parse(a.dataDate!);
        DateTime dateB = dateFormat.parse(b.dataDate!);
        return dateA.compareTo(dateB);
      });

      _currentIndex = 0;
    } catch (e) {
      print("🚨 ERROR loading CSV: $e");
    }
  }

  String generateUniqueKey() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomValue = random.nextInt(100000); // Adds additional randomness
    return '$timestamp-$randomValue';
  }

  /// **⏹ Stop Flux Data Simulation**
  void stopFluxSimulation() {
    _simulationTimer?.cancel();
  }

  /// **Add individual flux data points to Firebase**
  Future<void> addFluxDataToFirebase(String projectName, FluxData data) async {
    try {
      await projectCollection.doc(projectName).collection('data').doc().set({
        'dataSite': data.dataSite,
        'dataLong': data.dataLong,
        'dataLat': data.dataLat,
        'dataTemp': data.dataTemp,
        'dataPress': data.dataPress,
        'dataCflux': data.dataCflux,
        'dataVocfluxGram': data.dataVocfluxGram,
        'dataCh4fluxGram': data.dataCh4fluxGram,
        'dataH2ofluxGram': data.dataH2ofluxGram,
        'dataDate': data.dataDate,
        'dataNote': data.dataNote,
        'dataSoilTemp': "null",
        'dataInstrument': data.dataInstrument,
        'dataCfluxGram': data.dataCfluxGram,
        'dataKey': data.dataKey,
      });
    } catch (e) {
      debugPrint('Error adding flux data: $e');
    }
  }

  /// **🗑 Delete a Project**
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
      final batch = FirebaseFirestore.instance.batch();

      // Remove project reference from each user's "projects" field
      for (String userId in members.keys) {
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(userId);
        batch.update(userDocRef, {
          'projects.$projectName': FieldValue.delete(),
        });
      }

      // Delete the project document
      batch.delete(projectCollection.doc(projectName));

      // Commit batch operation
      await batch.commit();
    } catch (e) {
      _showErrorDialog(context, e.toString());
    }
  }

  /// **🛠 Update Flux Data in Firestore**
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

  /// **📂 Create a new Firestore Project**
  Future<void> createFireStoreProject(String projectName) async {
    try {
      await projectCollection.doc(projectName).set({});
    } catch (e) {
      debugPrint('Error creating project: $e');
    }
  }

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

  Stream<List<Project>> getUserProjects(String userId) {
    return projectCollection
        .where('members.$userId',
            isEqualTo: 'owner') // or just check existence with isNull: false
        .snapshots()
        .map((snapshot) {
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
          dataVocfluxGram: doc['dataVocfluxGram'],
          dataCh4fluxGram: doc['dataCh4fluxGram'],
          dataH2ofluxGram: doc['dataH2ofluxGram'],
          dataSoilTemp: doc['dataSoilTemp'] ?? 'none',
          dataCfluxGram: doc['dataCfluxGram'],
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

/// ✅ **Provider for `ProjectManagementNotifier`**
final projectManagementProvider =
    StateNotifierProvider<ProjectManagementNotifier, ProjectState>((ref) {
  return ProjectManagementNotifier(ref);
});

final projectNameProvider = Provider<String>((ref) {
  final projectManagement = ref.watch(projectManagementProvider);
  return projectManagement.projectName;
});

final projectCardStreamProvider =
    StreamProvider.autoDispose<List<ProjectCardProjectManager>>((ref) {
  final projectManagement = ref.watch(projectManagementProvider.notifier);
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

          return ProjectCardProjectManager(
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

final projectDrawerCardStreamProvider =
    StreamProvider.autoDispose<List<RemoteProjectCard>>((ref) {
  final projectManagement = ref.watch(projectManagementProvider.notifier);
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
