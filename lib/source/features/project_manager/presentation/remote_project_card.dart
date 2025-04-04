import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/mbu_control/save_csv.dart';
import 'package:terratrace/source/routing/app_router.dart';
import 'package:terratrace/source/features/mbu_control/utils.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class RemoteProjectCard extends StatelessWidget {
  const RemoteProjectCard({
    required this.project,
    required this.membershipStatus,
  });

  final String project;
  final Icon membershipStatus;

  // Future<void> showCustomDialog({
  //   required BuildContext context,
  //   required String title,
  //   required String content,
  //   required String confirmButtonText,
  //   required VoidCallback onConfirm,
  //   String cancelButtonText = 'Cancel',
  // }) async {
  //   return showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text(title),
  //         content: Text(content),
  //         actions: [
  //           ElevatedButton(
  //             onPressed: () async {
  //               onConfirm();
  //               Navigator.of(context)
  //                   .pop(); // Close the dialog after confirming
  //             },
  //             child: Text(confirmButtonText),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context)
  //                   .pop(); // Close the dialog without confirming
  //             },
  //             child: Text(cancelButtonText),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      return Align(
        alignment: FractionalOffset.bottomCenter,
        child: Opacity(
          opacity: 0.85,
          child: Card(
            borderOnForeground: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 20.0,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10.0),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                  // color: const Color.fromRGBO(64, 75, 96, 1),
                  color: Color.fromARGB(255, 95, 98, 106),
                  borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),

                // Minimize leading width
                leading: IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete Button
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            // color: Colors.blueGrey,
                            size: 24),
                        onSelected: (String value) async {
                          if (value == 'delete') {
                            // Show confirmation dialog
                            final bool? confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  // backgroundColor:
                                  //     const Color.fromRGBO(64, 75, 96, 1),
                                  title: Text(
                                    'Delete Project',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete the project "$project"? This action cannot be undone.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(false);
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                            255, 113, 15, 15),
                                      ),
                                      child: Text('Delete',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmDelete == true) {
                              await ref
                                  .watch(projectManagementProvider)
                                  .deleteFireStoreProject(project, context);
                              showDownloadMessage(
                                  context, "The project is deleted!");
                            }
                          } else if (value == 'reselect') {
                            context.pushNamed(AppRoute.dataTableScreen.name,
                                pathParameters: {
                                  'project': project,
                                });
                          } else if (value == 'zip_files') {
                            final filepath =
                                await zipFilesContainingProjectName(project);
                            showDownloadMessage(
                                context, 'Zip file has been downloaded!');
                            bool hasConnection = await InternetConnectionChecker
                                .instance.hasConnection;
                            if (hasConnection) {
                              await showCustomDialog(
                                context: context,
                                title: 'Share Project Zip File',
                                content: 'Do you want to share the file?',
                                confirmButtonText: 'Share',
                                onConfirm: () async {
                                  await shareFile(filepath);
                                },
                              );
                            }
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'reselect',
                            child: Text('Reselect Boundaries'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'zip_files',
                            child: Text('Zip and download all samplings'),
                          ),
                        ],
                      ),

                      // Download CSV Button with Tooltip
                      Tooltip(
                        message: "Download summary table (CSV)",
                        child: IconButton(
                          icon: Image.asset(
                            'images/csv.png', // Path to your custom icon
                            width: 24, // Adjust size as needed
                            height: 24,
                          ),
                          onPressed: () async {
                            try {
                              // Perform the download/export action
                              String filepath =
                                  await exportFirestoreToCSV(project);

                              // Notify the user that the file has been downloaded
                              showDownloadMessage(
                                  context, 'File has been downloaded!');
                              bool hasConnection =
                                  await InternetConnectionChecker
                                      .instance.hasConnection;
                              if (hasConnection) {
                                await showCustomDialog(
                                  context: context,
                                  title: 'Share Summary Table',
                                  content: 'Do you want to share the CSV file?',
                                  confirmButtonText: 'Share CSV',
                                  onConfirm: () async {
                                    await shareFile(filepath);
                                  },
                                );
                              }
                            } catch (e) {
                              print(e);
                              // Handle error (if necessary)
                              final errorSnackBar = SnackBar(
                                content: Text(
                                    'Failed to download the file. Please try again!'),
                                duration: Duration(seconds: 2),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(errorSnackBar);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Title takes up remaining space
                title: Center(
                  child: Text(
                    project,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    overflow:
                        TextOverflow.ellipsis, // Ensure text doesn't overflow
                  ),
                ),

                trailing: Container(
                  height: 70,
                  width: 80,
                  padding: const EdgeInsets.only(left: 20.0),
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(width: 1.0, color: Colors.white24)),
                  ),
                  child: membershipStatus,
                ),

                onTap: () async {
                  if (membershipStatus.icon == Icons.how_to_reg ||
                      membershipStatus.icon == Icons.card_membership) {
                    await ref
                        .read(projectNameProvider.notifier)
                        .setProjectName(project);
                    context.pushNamed(AppRoute.mapScreen.name);
                  }
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}
