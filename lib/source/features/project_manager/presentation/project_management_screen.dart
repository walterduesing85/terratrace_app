import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/features/authentication/data.dart';
import 'package:terratrace/source/features/project_manager/presentation/remote_projects_tab.dart';

class ProjectManagementScreen extends ConsumerWidget {
  const ProjectManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        title: CustomAppBar(
          title: ref.watch(appBarTitleProvider).when(
                loading: () => 'Loading...', // Show loading message
                error: (error, stackTrace) =>
                    'Error: $error', // Show error message
                data: (title) =>
                    title ??
                    'Default Title', // Use data when available, or default title
              ),
        ),
      ),
      body:
          RemoteProjectsTab(), //TODO Solve Stream already listend error when signing in and out
    );
  }
}

