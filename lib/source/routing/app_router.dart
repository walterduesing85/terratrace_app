import 'package:go_router/go_router.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

import 'package:terratrace/source/features/data/presentation/edit_data_screen.dart';
import 'package:terratrace/source/features/home/home_screen.dart';
import 'package:terratrace/source/features/map/presentation/heat_map_screen.dart';
import 'package:terratrace/source/features/mbu_control/data_acquistion_screen.dart';
import 'package:terratrace/source/features/project_manager/presentation/create_new_project_screen.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_management_screen.dart';
import 'package:terratrace/source/routing/not_found_screen.dart';
import 'package:terratrace/source/features/project_manager/presentation/data_table_screen.dart';
import 'package:terratrace/source/features/mbu_control/reselect_bound.dart';

enum AppRoute {
  home,
  projectmanager,

  createNewProjectScreen,
  mapScreen,
  editDataScreen,
  chamberConnect,
  chamberAcquisition,
  reselectScreen,
  dataTableScreen
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
                path: 'dataTableScreen/:project',
                name: AppRoute.dataTableScreen.name,
                builder: (context, state) {
                  return DataTableScreen(
                    project: state.pathParameters['project'],
                  );
                },
                routes: [
                  GoRoute(
                    path: 'reselectScreen/:samplingPoint',
                    name: AppRoute.reselectScreen.name,
                    builder: (context, state) {
                      return ReselectScreen(
                        project: state.pathParameters['project'],
                        samplingPoint: state.pathParameters['samplingPoint'],
                      );
                    },
                  ),
                ]),
            GoRoute(
              path: 'mapScreen',
              name: AppRoute.mapScreen.name,
              builder: (context, state) => HeatMapScreen(),
              routes: [
                GoRoute(
                  path: 'edit-data-screen/:projectName',
                  name: AppRoute.editDataScreen.name,
                  builder: (context, state) {
                    final projectName = state.pathParameters['projectName'];
                    final fluxData = state.extra as FluxData;

                    return EditDataScreen(
                      projectName: projectName!,
                      fluxData: fluxData,
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'chamberAcquisition',
              name: AppRoute.chamberAcquisition.name,
              builder: (context, state) => DataAcquisitionScreenScreen(
                  // type: state.uri.queryParameters['type'],
                  ),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const NotFoundScreen(),
);
