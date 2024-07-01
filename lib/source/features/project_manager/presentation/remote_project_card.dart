import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:terra_trace/source/features/data/data/data_management.dart';

import 'package:terra_trace/source/routing/app_router.dart';

class RemoteProjectCard extends StatelessWidget {
  const RemoteProjectCard({
    @required this.project,
    @required this.membershipStatus,
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
                        color: Colors.blueGrey,
                        size: 30,
                      ),
                      onPressed:
                          () async {}, //TODO implement delete remoteproject
                    ),
                  ),
                  title: Text(
                    project,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  // subtitle: Text("Intermediate", style: TextStyle(color: Colors.white)),

                  trailing: Container(
                      height: 70,
                      width: 80,
                      padding: const EdgeInsets.only(left: 20.0),
                      decoration: const BoxDecoration(
                          border: Border(
                        left: BorderSide(width: 1.0, color: Colors.white24),
                      )),
                      child: membershipStatus),
                  onTap: () async {
                    if (membershipStatus.icon == Icons.how_to_reg ||
                        membershipStatus.icon == Icons.card_membership) {
                      await ref
                          .read(projectNameProvider.notifier)
                          .setProjectName(project);
                      ref.read(isRemoteProvider.notifier).state = true;

                      context.pushNamed(AppRoute.mapScreen.name);
                    }
                  }),
            ),
          ),
        ),
      );
    });
  }
}
