import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/common_widgets/custom_appbar.dart';
import 'package:terra_trace/source/features/authentication/data.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';
import 'package:terra_trace/source/features/project_manager/domain/project_data.dart';
import 'package:terra_trace/source/features/project_manager/presentation/project_card.dart';

import 'package:terra_trace/source/features/project_manager/presentation/remote_projects_tab.dart';

class ProjectManagementScreen extends ConsumerWidget {
  const ProjectManagementScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectBox = ref.watch(projectBoxProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            indicatorWeight: 20,
            tabs: [Text('local'), Text('remote')],
          ),
        ),
        body: TabBarView(
          children: [
            projectBox == null
                ? CircularProgressIndicator()
                : ListView.builder(
                    itemCount: projectBox.values.length,
                    itemBuilder: (context, index) {
                      final ProjectData project =
                          projectBox.values.toList()[index];
                      return ProjectCard(project: project);
                    },
                  ),
            RemoteProjectsTab()
          ],
        ),
      ),
    );
  }
}
