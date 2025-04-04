import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';
import 'package:terratrace/source/features/map/presentation/heat_map_screen.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/routing/app_router.dart';

class ProjectCardDrawer extends StatelessWidget {
  const ProjectCardDrawer(
      {required this.project,
      required this.membershipStatus,
      this.isInProject});

  final String project;
  final Icon membershipStatus;
  final bool? isInProject;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      return Align(
        alignment: FractionalOffset.bottomCenter,
        child: Opacity(
            opacity: 0.85,
            child: Card(
              color: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Colors.white, width: 0.8), // **Thin white border**
              ),
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              elevation: 4, // **Slight elevation for a "floating" effect**
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Row(
                  children: [
                    MaterialButton(
                      child: const Icon(
                        Icons.delete,
                        color: Colors.blueGrey,
                        size: 30,
                      ),
                      onPressed: () async {
                        ref
                            .watch(projectManagementProvider.notifier)
                            .deleteFireStoreProject(project, context);
                      },
                    ),

                    /// **📛 User Info**
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              if (membershipStatus.icon == Icons.how_to_reg ||
                                  membershipStatus.icon ==
                                      Icons.card_membership) {
                                await ref
                                    .read(projectManagementProvider.notifier)
                                    .setProjectName(project);
                              }
                            },
                            child: Text(
                              project,
                              style: kUserCardHeadeTextStyle.copyWith(
                                fontSize: 14,
                                color: Colors
                                    .white, // **Ensures visibility on dark background**
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// **➕ Add User Button**

                    membershipStatus,
                  ],
                ),
              ),
            )),
      );
    });
  }
}
