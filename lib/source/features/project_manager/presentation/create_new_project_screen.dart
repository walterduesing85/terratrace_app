import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:terra_trace/source/common_widgets/custom_appbar.dart';
import 'package:terra_trace/source/constants/constants.dart';
import 'package:terra_trace/source/features/authentication/authentication_managment.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/data/data_point_watcher.dart';
import 'package:terra_trace/source/features/data/data/sand_box.dart';

import 'package:terra_trace/source/features/project_manager/domain/create_new_project.dart';
import 'package:terra_trace/source/features/project_manager/domain/project_data.dart';
import 'package:terra_trace/source/routing/app_router.dart';

final projectBoxProvider = FutureProvider<Box<ProjectData>>((ref) async {
  return await Hive.openBox<ProjectData>('projects');
});

final currentQuestionProvider = StateProvider<int>((ref) => 0);

class CreateNewProjectScreen extends ConsumerWidget {
  const CreateNewProjectScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ProjectSummary(),
              const ProjectQuestions(),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectQuestions extends ConsumerWidget {
  const ProjectQuestions({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentQuestion = ref.watch(currentQuestionProvider);
    final projectBox = ref.watch(projectBoxProvider).maybeWhen(
          data: (box) => box,
          orElse: () => null,
        );

    if (projectBox == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (currentQuestion == 0) ProjectNameQuestion(),
          if (currentQuestion == 1) IsRemoteQuestion(),
          if (currentQuestion == 2) BrowseFilesQuestion(),
          if (currentQuestion == 3)
            ElevatedButton(
              onPressed: () async {
                final projectName = ref.read(projectNameProvider);
                final isRemote = ref.read(isRemoteProvider);
                final browseFiles = ref.read(browseFilesProvider);
                final boxAsyncValue = ref.read(hiveDataBoxProvider);

                await ref
                    .watch(dataManagementProvider)
                    .createNewProject(projectName, isRemote, browseFiles);

                if (browseFiles) {
                  await boxAsyncValue.when(
                    data: (box) async {
                      await ref
                          .read(sandBoxProvider)
                          .browseAllFiles(isRemote, projectName, box);
                    },
                    loading: () {
                      // Handle loading state if necessary
                      CircularProgressIndicator();
                    },
                    error: (error, stack) {
                      // Handle error state if necessary
                      print('Error loading Hive box: $error');
                    },
                  );
                  context.pushNamed(AppRoute.mapScreen.name);
                }

                // Navigate to the map screen

                // Reset state or navigate to another screen if needed
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

class IsRemoteQuestion extends ConsumerStatefulWidget {
  const IsRemoteQuestion({Key key}) : super(key: key);

  @override
  _IsRemoteQuestionState createState() => _IsRemoteQuestionState();
}

class _IsRemoteQuestionState extends ConsumerState<IsRemoteQuestion> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save the context reference
    ref.read(contextProvider.notifier).setContext(context);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Is the project remote?',
            style: TextStyle(
              fontSize: 20,
              color: Color.fromRGBO(180, 211, 175, 0.93),
            ),
          ),
          Switch(
            value: ref.watch(isRemoteProvider),
            onChanged: (value) {
              ref.read(isRemoteProvider.notifier).state = value;
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Setting your project to remote will enable you to add collaborators to your project.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              ref.read(currentQuestionProvider.notifier).state++;

              final savedContext = ref.read(contextProvider);
              if (ref.read(isRemoteProvider.notifier).state &&
                  savedContext != null) {
                await ref
                    .read(createNewRemoteProjectProvider)
                    .createNewEmptyProject(ref.read(projectNameProvider),
                        savedContext, ref.read(currentUserProvider));
              }
            },
            child: Icon(
              Icons.arrow_forward,
              color: const Color.fromRGBO(180, 211, 175, 0.93),
              size: 100,
            ),
          ),
        ],
      ),
    );
  }
}

class BrowseFilesQuestion extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Browse files?',
            style: TextStyle(
              fontSize: 20,
              color: Color.fromRGBO(180, 211, 175, 0.93),
            ),
          ),
          Switch(
            value: ref.watch(browseFilesProvider),
            onChanged: (value) {
              ref.read(browseFilesProvider.notifier).state = value;
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'If you have TextManager files already saved in the Flux Manager folder that you would like to add to this project, enable this option. Otherwise, TerraTrace will only add new FluxManager files to your project.',
              style: TextStyle(
                fontSize: 15,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(currentQuestionProvider.notifier).state++;
            },
            child: Icon(
              Icons.arrow_forward,
              color: const Color.fromRGBO(180, 211, 175, 0.93),
              size: 100,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectSummary extends ConsumerWidget {
  const ProjectSummary({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(projectNameProvider);
    final isRemote = ref.watch(isRemoteProvider);
    final browseFiles = ref.watch(browseFilesProvider);

    // Display the summary only if the project name is not empty
    if (projectName.isEmpty) {
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
              'Is Remote: ${isRemote ? "Yes" : "No"}',
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            Text(
              'Browse Files: ${browseFiles ? "Yes" : "No"}',
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            Text(
              'Chamber Volume [m\u00B3]: $chamberVolume',
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(180, 211, 175, 0.93),
              ),
            ),
            Text(
              'Chamber Area [m\u00B2]: $chamberArea',
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

class ContextNotifier extends StateNotifier<BuildContext> {
  ContextNotifier() : super(null);

  void setContext(BuildContext context) {
    state = context;
  }
}

final contextProvider = StateNotifierProvider<ContextNotifier, BuildContext>(
  (ref) => ContextNotifier(),
);
