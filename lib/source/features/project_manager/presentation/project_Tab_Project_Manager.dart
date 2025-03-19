import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/common_widgets/async_value_widget.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_card_drawer.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_card_project_manager.dart';

import 'package:terratrace/source/features/project_manager/presentation/remote_project_card.dart';
import 'sign_in_form.dart'; // Import the SignInForm widget

class ProjectTabProjectManager extends ConsumerWidget {
  const ProjectTabProjectManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentUserStateProvider);
//TODO add search functionality and maybe think about how to sort the projects (show projects first that you are collaborator or owner of)
    return authState.when(
      data: (user) {
        if (user == null) {
          return SignInForm(); // Show the SignInForm when not signed in
        } else {
          return AsyncValueWidget<List<ProjectCardProjectManager>>(
            value: ref.watch(projectCardStreamProvider),
            data: (projectCards) => ListView.builder(
              itemCount: projectCards.length,
              itemBuilder: (context, index) {
                return projectCards[index];
              },
            ),
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
