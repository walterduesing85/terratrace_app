
import 'package:go_router/go_router.dart';

import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/features/data/prensentation/data_list_screen.dart';
import 'package:terra_trace/source/features/data/prensentation/edit_data_screen.dart';

import 'package:terra_trace/source/features/home/home_screen.dart';
import 'package:terra_trace/source/features/map/presentation/map_screen_selector.dart';
import 'package:terra_trace/source/features/project_manager/presentation/create_new_project_screen.dart';
import 'package:terra_trace/source/features/project_manager/presentation/project_management_screen.dart';
import 'package:terra_trace/source/routing/not_found_screen.dart';

enum AppRoute {
  home,
  projectmanager,
  dataListScreen,
  createNewProjectScreen,
  mapScreen,
  histogramScreen,
  editDataScreen,
}

final goRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home.name,
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'createNewProjectScreen',
          name: AppRoute.createNewProjectScreen.name,
          builder: (context, state) => const CreateNewProjectScreen(),
        ),
        GoRoute(
          path: 'projectmanager',
          name: AppRoute.projectmanager.name,
          builder: (context, state) => const ProjectManagementScreen(),
          routes: [
            GoRoute(
              path: 'dataListScreen',
              name: AppRoute.dataListScreen.name,
              builder: (context, state) => const DataListScreen(),
            ),
            GoRoute(
              path: 'mapScreen',
              name: AppRoute.mapScreen.name,
              builder: (context, state) => MapScreenSelector(),
              routes: [
                GoRoute(
                  name: AppRoute.editDataScreen.name,
                  path: 'edit-data-screen/:projectName',
                  builder: (context, state) {
                    final projectName = state.params['projectName'];
                    final fluxData = state.extra as FluxData;

                    return EditDataScreen(
                      projectName: projectName,
                      fluxData: fluxData,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const NotFoundScreen(),
);
