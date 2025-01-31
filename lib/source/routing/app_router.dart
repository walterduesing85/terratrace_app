import 'package:go_router/go_router.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/data/presentation/data_list_screen.dart';
import 'package:terratrace/source/features/data/presentation/edit_data_screen.dart';
import 'package:terratrace/source/features/home/home_screen.dart';
import 'package:terratrace/source/features/map/presentation/map_screen_selector.dart';
// import 'package:terratrace/source/features/mbu_control/chart_menu.dart';
// import 'package:terratrace/source/features/mbu_control/data_acquistion_screen.dart';
import 'package:terratrace/source/features/project_manager/presentation/create_new_project_screen.dart';
import 'package:terratrace/source/features/project_manager/presentation/project_management_screen.dart';
import 'package:terratrace/source/routing/not_found_screen.dart';

enum AppRoute {
  home,
  projectmanager,
  dataListScreen,
  createNewProjectScreen,
  mapScreen,
  editDataScreen,
  chamberConnect,
  chamberAcquisition
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

            // GoRoute(
            //   path: 'chamberAcquisition',
            //   name: AppRoute.chamberAcquisition.name,
            //   builder: (context, state) => DataAcquisitionScreenScreen(),
            // ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const NotFoundScreen(),
);
