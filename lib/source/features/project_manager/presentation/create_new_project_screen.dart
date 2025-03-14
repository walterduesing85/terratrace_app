import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';

import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/project_manager/domain/create_new_project.dart';
import 'package:terratrace/source/routing/app_router.dart';

import 'sign_in_form.dart';

final currentQuestionProvider = StateProvider<int>((ref) => 0);

class CreateNewProjectScreen extends ConsumerWidget {
  const CreateNewProjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentUserStateProvider);
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
          title: CustomAppBar(
            title: ref.watch(projectNameProvider).isEmpty
                ? 'Create Project'
                : ref.watch(projectNameProvider),
          ),
        ),
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1),
        body: authState.when(
          data: (user) {
            if (user == null) {
              return SignInForm(); // Show the SignInForm when not signed in
            } else {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ProjectSummary(),
                      ProjectQuestions(
                        user: user,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ));
  }
}

class ProjectQuestions extends ConsumerWidget {
  final User user;
  const ProjectQuestions({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentQuestion = ref.watch(currentQuestionProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (currentQuestion == 0) ProjectNameQuestion(),
          if (currentQuestion == 1)
            ElevatedButton(
              onPressed: () async {
                final projectName = ref.read(projectNameProvider);

                await ref
                    .watch(createNewRemoteProjectProvider)
                    .createNewEmptyProject(
                      projectName,
                      context,
                      user,
                    );
                ref
                    .watch(projectManagementProvider)
                    .getFluxDataStream(projectName);
                // ✅ Prevents using context if the widget is unmounted
                if (!context.mounted) return;
                context.pushNamed(AppRoute.mapScreen.name);
                ref.read(currentQuestionProvider.notifier).state = 0;
              },
              child: const Text('Create Project'),
            ),
        ],
      ),
    );
  }
}

class ProjectNameQuestion extends ConsumerWidget {
  const ProjectNameQuestion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (value) {
        ref.read(projectNameProvider.notifier).setProjectName(value);
      },
      onSubmitted: (value) {
        ref.read(currentQuestionProvider.notifier).state++;
      },
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        color: Color.fromRGBO(180, 211, 175, 0.93),
      ),
      decoration: kInputTextFieldEditData.copyWith(
        hintText: 'Enter project name',
        hintStyle: const TextStyle(
          fontSize: 20,
          color: Color.fromRGBO(180, 211, 175, 0.93),
        ),
      ),
    );
  }
}

class ProjectSummary extends ConsumerWidget {
  const ProjectSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(projectNameProvider);

    // Display the summary only if the project name is not empty
    if (ref.watch(currentQuestionProvider) != 1) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Project name: $projectName',
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            Text(
              'Chamber Volume [m\u00B3]: $chamberVolume', //TODO add chamberVolume to user
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            Text(
              'Chamber Area [m\u00B2]: $chamberArea', //TODO add chamberArea to user
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class ContextNotifier extends StateNotifier<BuildContext?> {
  ContextNotifier() : super(null);

  void setContext(BuildContext context) {
    state = context;
  }
}

final contextProvider = StateNotifierProvider<ContextNotifier, BuildContext?>(
  (ref) => ContextNotifier(),
);
