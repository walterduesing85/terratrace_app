import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/common_widgets/async_value_widget.dart';
import 'package:terra_trace/source/features/authentication/authentication_managment.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';

import 'package:terra_trace/source/features/project_manager/presentation/remote_project_card.dart';
import 'sign_in_form.dart'; // Import the SignInForm widget

class RemoteProjectsTab extends ConsumerWidget {
  const RemoteProjectsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthStreamProvider);
//TODO add search functionality and maybe think about how to sort the projects (show projects first that you are collaborator or owner of)
    return authState.when(
      data: (user) {
        if (user == null) {
          return SignInForm(); // Show the SignInForm when not signed in
        } else {
          return AsyncValueWidget<List<RemoteProjectCard>>(
            value: ref.watch(remoteProjectsCardStreamProvider2),
            data: (remoteProjectCards) => ListView.builder(
              itemCount: remoteProjectCards.length,
              itemBuilder: (context, index) {
                return remoteProjectCards[index];
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
