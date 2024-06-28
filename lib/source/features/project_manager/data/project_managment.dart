import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terra_trace/source/features/authentication/authentication_managment.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';

import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/features/project_manager/domain/project.dart';
import 'package:terra_trace/source/features/project_manager/domain/project_data.dart';
import 'package:terra_trace/source/features/project_manager/presentation/remote_project_card.dart';

import '../../user/domain/user_managment.dart';

//This class manages all the remote project (projects that are stored on firebase) related methods
class ProjectManagement {
  // <<<<< ---- +++ Section for Hive ProjectManagment +++ --- >>>>>>>>
  // Every Firbase Project will be converted into a Hive Project
  // that contains the settings of the specific device used

  // <<<<< ---- +++ Section for Firebase ProjectManagment +++ --- >>>>>>>>

  var projectCollection = FirebaseFirestore.instance.collection('projects');

  Future<void> deleteFireStoreProject(String projectName, context) async {
    try {
      await projectCollection.doc(projectName).delete();
    } catch (e) {
      await Alert(title: e.message, context: context, buttons: [
        DialogButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('ok'),
        )
      ]).show();
    }
  }

  final _projectListStreamController =
      StreamController<List<Project>>.broadcast();

  Stream<List<Project>> get projectListStream =>
      _projectListStreamController.stream;

  final _fluxDataListStreamController =
      StreamController<List<FluxData>>.broadcast();

  Stream<List<FluxData>> get fluxDataListStream =>
      _fluxDataListStreamController.stream;

  void startStreamingRemoteData(String project, Box<FluxData> box) async {
    projectCollection
        .doc(project)
        .collection('data')
        .snapshots()
        .listen((snapshot) {
      final documents = snapshot.docs;
      final allData = documents.map((document) {
        return FluxData(
          dataSite: document['dataSite'],
          dataLong: document['dataLong'],
          dataLat: document['dataLat'],
          dataPress: document['dataPress'],
          dataTemp: document['dataTemp'],
          dataDate: document['dataDate'],
          dataNote: document['dataNote'] ?? 'none',
          dataInstrument: document['dataInstrument'],
          dataCflux: document['dataCflux'],
          dataSoilTemp: document['dataSoilTemp'] ?? 'none',
          dataCfluxGram: document['dataCfluxGram'],
          dataOrigin: document['dataOrigin'],
          dataKey: document['dataKey'],
        );
      }).toList();

      // Add data to stream controller
      _fluxDataListStreamController.add(allData);

      // Store data locally in Hive
      for (final data in allData) {
        box.put(data.dataKey, data);
      }
    });
  }

  Future<void> updateFluxData(String projectName, String dataKey,
      Map<String, dynamic> updatedFields, Box<FluxData> box) async {
    try {
      // Update Firebase
      await projectCollection
          .doc(projectName)
          .collection('data')
          .doc(dataKey)
          .update(updatedFields);

      // Update Hive
      final fluxData = box.get(dataKey);
      if (fluxData != null) {
        updatedFields.forEach((key, value) {
          switch (key) {
            case 'dataSite':
              fluxData.dataSite = value;
              break;
            case 'dataLong':
              fluxData.dataLong = value;
              break;
            case 'dataLat':
              fluxData.dataLat = value;
              break;
            case 'dataPress':
              fluxData.dataPress = value;
              break;
            case 'dataTemp':
              fluxData.dataTemp = value;
              break;
            case 'dataDate':
              fluxData.dataDate = value;
              break;
            case 'dataNote':
              fluxData.dataNote = value;
              break;
            case 'dataInstrument':
              fluxData.dataInstrument = value;
              break;
            case 'dataCflux':
              fluxData.dataCflux = value;
              break;
            case 'dataSoilTemp':
              fluxData.dataSoilTemp = value;
              break;
            case 'dataCfluxGram':
              fluxData.dataCfluxGram = value;
              break;
            case 'dataOrigin':
              fluxData.dataOrigin = value;
              break;
          }
        });
        box.put(dataKey, fluxData);
      }
    } catch (e) {
      // Handle errors
      print('Error updating FluxData: $e');
    }
  }

  var userCollection = FirebaseFirestore.instance.collection('users');

  final StreamController<List<User>> _firebaseUserStreamController =
      StreamController<List<User>>.broadcast();

  Stream<List<User>> get usersStream => _firebaseUserStreamController.stream;

  void startStreamingFirebaseUsers() {
    userCollection.snapshots().listen((snapshot) {
      final documents = snapshot.docs;
      final users = documents.map((doc) {
        return User.fromDocument(doc);
      }).toList();

      _firebaseUserStreamController.add(users);
    });
  }

//Stream Controller for remote Projects
  final StreamController<List<Project>> _remoteProjectStreamController =
      StreamController<List<Project>>();

//getter method for the stream
  Stream<List<Project>> get projectsStream =>
      _remoteProjectStreamController.stream;

  void startStreamingRemoteProjects() {
    projectCollection.snapshots().listen((snapshot) {
      final documents = snapshot.docs;
      final projects = documents.map((doc) {
        return Project(
          name: doc['name'],
          members: doc['members'],
          // Other properties...
        );
      }).toList();

      _remoteProjectStreamController.add(projects);
    });
  }
}

final remoteStreamingProvider = FutureProvider<void>((ref) async {
  final projectManagement = ref.read(projectManagementProvider);
  final currentUser = await ref.watch(currentUserStateProvider.future);
  final isRemote = ref.watch(isRemoteProvider);
  final project = ref.watch(projectNameProvider);
  final boxAsyncValue = ref.watch(hiveDataBoxProvider);

  await boxAsyncValue.when(
    data: (box) async {
      if (project.isNotEmpty && isRemote && currentUser != null) {
        await projectManagement.startStreamingRemoteData(project, box);
        await projectManagement.startStreamingRemoteProjects();
        await projectManagement.startStreamingFirebaseUsers();
      } else {
        await projectManagement.startStreamingRemoteProjects();
        await projectManagement.startStreamingFirebaseUsers();
        print('Project is empty or not remote, or current user is null');
      }
    },
    loading: () {
      CircularProgressIndicator();
      // Handle loading state if necessary
      print('Loading Hive box...');
    },
    error: (error, stack) {
      // Handle error state if necessary
      print('Error loading Hive box: $error');
    },
  );
});

final projectManagementProvider = Provider<ProjectManagement>((ref) {
  return ProjectManagement();
});

final userCollectionProvider =
    Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return ref.watch(projectManagementProvider).userCollection;
});

final projectCollectionProvider =
    Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return ref.watch(projectManagementProvider).projectCollection;
});

final remoteProjectStreamProvider = StreamProvider<List<Project>>((ref) {
  final projectMangement = ref.watch(projectManagementProvider);

  return projectMangement._remoteProjectStreamController.stream;
});

class ProjectBoxStateNotifier extends StateNotifier<Box<ProjectData>> {
  final DataManagement dataManagement;

  ProjectBoxStateNotifier(this.dataManagement) : super(null) {
    _init();
  }

  Future<void> _init() async {
    await dataManagement.openProjectBox();
    state = Hive.box<ProjectData>('projects');
  }

  Future<void> deleteProject(String projectName) async {
    await dataManagement.deleteProject(projectName);
    state = Hive.box<ProjectData>('projects');
  }
}

final projectBoxProvider =
    StateNotifierProvider<ProjectBoxStateNotifier, Box<ProjectData>>((ref) {
  final dataManager = ref.watch(dataManagementProvider);
  return ProjectBoxStateNotifier(dataManager);
});

final remoteProjectsCardStreamProvider2 =
    StreamProvider.autoDispose<List<RemoteProjectCard>>((ref) {
  final projectStream = ref.watch(projectManagementProvider);
  final userAsync = ref.watch(currentUserStateProvider);

  return userAsync.when(
    data: (user) {
      return projectStream.projectsStream.map((projects) {
        return projects.map((project) {
          // Handle null user or membership directly in the stream
          var userMembership = user == null ? null : project.members[user.uid];

          Icon membershipStatus;
          if (userMembership == 'owner') {
            membershipStatus =
                const Icon(Icons.card_membership, color: Colors.green);
          } else if (userMembership == 'collaborator') {
            membershipStatus = const Icon(Icons.how_to_reg, color: Colors.blue);
          } else {
            membershipStatus = const Icon(Icons.person, color: Colors.grey);
          }

          return RemoteProjectCard(
            project: project.name,
            membershipStatus: membershipStatus,
          );
        }).toList();
      }).handleError((error) {
        print('Error in projectsStream: $error');
        return [];
      });
    },
    loading: () {
      print('User data is loading');
      // Continue streaming projects even if user data is loading

      return projectStream.projectsStream.map((projects) {
        return projects.map((project) {
          // Return default icon when user data is still loading
          return RemoteProjectCard(
            project: project.name,
            membershipStatus: const Icon(Icons.person, color: Colors.grey),
          );
        }).toList();
      });
    },
    error: (error, stack) {
      print('Error in userAsync: $error');
      // Continue streaming projects even if user data has an error

      return projectStream.projectsStream.map((projects) {
        return projects.map((project) {
          // Return default icon when there is an error in user data
          return RemoteProjectCard(
            project: project.name,
            membershipStatus: const Icon(Icons.person, color: Colors.grey),
          );
        }).toList();
      });
    },
  );
});
