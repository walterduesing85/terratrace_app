import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';
import 'package:terra_trace/source/routing/app_router.dart';

import '../domain/project_data.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    Key key,
    @required this.project,
  });

  final ProjectData project;

  @override
  Widget build(BuildContext context) {
    final projectName = project.projectName;
    return Align(
      alignment: FractionalOffset.bottomCenter,
      child: Opacity(
        opacity: 0.85,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 20.0,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10.0),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
                color: const Color.fromRGBO(64, 75, 96, 1),
                borderRadius: BorderRadius.circular(15)),
            child: Consumer(builder: (context, ref, _) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 10.0),
                leading: Container(
                  decoration: const BoxDecoration(
                      border: Border(
                    right: BorderSide(width: 1.0, color: Colors.white24),
                  )),
                  padding: const EdgeInsets.only(right: 10.0),
                  child: MaterialButton(
                    child: const Icon(
                      Icons.delete,
                      color: Color.fromRGBO(182, 139, 113, 6),
                      size: 30,
                    ),
                    onPressed: () async {
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Confirm Deletion'),
                            content: Text(
                                'Are you sure you want to delete the project "$projectName"?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(
                                      false); // Return false to indicate cancellation
                                },
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(
                                      true); // Return true to indicate confirmation
                                },
                                child: Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmDelete == true) {
                        await ref
                            .read(projectBoxProvider.notifier)
                            .deleteProject(projectName);
                      }
                    },
                  ),
                ),
                title: Text(
                  projectName,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                // subtitle: Text("Intermediate", style: TextStyle(color: Colors.white)),

                trailing: Container(
                  decoration: const BoxDecoration(
                      border: Border(
                    left: BorderSide(width: 1.0, color: Colors.white24),
                  )),
                  child: const Icon(Icons.arrow_forward,
                      color: Color.fromRGBO(180, 211, 175, 9), size: 30.0),
                ),
                onTap: () async {
                  context.pushNamed(AppRoute.dataListScreen.name);
                  await ref
                      .read(projectNameProvider.notifier)
                      .setProjectName(projectName);
                  ref.read(isRemoteProvider.notifier).state = project.browseFiles;
                  await ref.read(dataManagementProvider).createNewProject(
                      projectName,
                      ref.read(isRemoteProvider),
                      ref.read(browseFilesProvider));
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}
