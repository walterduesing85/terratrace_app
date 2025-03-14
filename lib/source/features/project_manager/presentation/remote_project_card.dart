import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/mbu_control/save_csv.dart';
import 'package:terratrace/source/routing/app_router.dart';
import 'package:terratrace/source/features/mbu_control/utils.dart';

class RemoteProjectCard extends StatelessWidget {
  const RemoteProjectCard({
    required this.project,
    required this.membershipStatus,
  });

  final String project;
  final Icon membershipStatus;

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
                  color: const Color.fromRGBO(64, 75, 96, 1),
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
                            color: Colors.blueGrey, size: 24),
                        onSelected: (String value) async {
                          if (value == 'delete') {
                            await ref
                                .watch(projectManagementProvider)
                                .deleteFireStoreProject(project, context);
                          } else if (value == 'reselect') {
                            context.pushNamed(AppRoute.dataTableScreen.name,
                                pathParameters: {
                                  'project': project,
                                });
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //       builder: (context) => ReselectScreen(
                            //             project: project,
                            //             samplingPoint: "1",
                            //           )),
                            // );
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
                              showDownloadMessage(context);
                              return showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Share Summary Table'),
                                    content: Text(
                                        'Do you want to share the CSV file?'),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          await shareCSVFile(filepath);
                                          Navigator.of(context)
                                              .pop(); // close the dialog after sharing
                                        },
                                        child: Text('Share CSV'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .pop(); // close the dialog without sharing
                                        },
                                        child: Text('Cancel'),
                                      ),
                                    ],
                                  );
                                },
                              );
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
