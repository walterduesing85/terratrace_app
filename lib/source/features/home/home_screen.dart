import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/common_widgets/rounded_button.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/routing/app_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScrenState();
}

class _HomeScrenState extends State<HomeScreen> {
  Future<String> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // Ensure it returns a String
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color.fromRGBO(58, 66, 86, 1),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(child: Image.asset('images/TT_Logo.png')),
                const SizedBox(height: 60.0),
                Flexible(
                  child: Consumer(builder: (context, ref, _) {
                    return RoundedButton(
                      // buttonColor: const Color.fromRGBO(64, 75, 96, 1),
                      buttonColor: Color.fromARGB(255, 95, 98, 106),
                      buttonText: 'Create new project',
                      goTo: () {
                        ref
                              .read(projectManagementProvider.notifier)
                            .setProjectName('');
                        context.pushNamed(AppRoute.createNewProjectScreen.name);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 30.0),
                Flexible(
                  child: RoundedButton(
                    buttonColor: Color.fromARGB(255, 95, 98, 106),
                    buttonText: 'Project Manager',
                    goTo: () {
                      context.pushNamed(AppRoute.projectmanager.name);
                    },
                  ),
                ),
                const SizedBox(height: 30.0),
                Flexible(
                  child: RoundedButton(
                    buttonColor: Color.fromARGB(255, 95, 98, 106),
                    buttonText: 'Acquire Data',
                    goTo: () {
                      context.pushNamed(AppRoute.chamberAcquisition.name);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom-Right Version Text
          Positioned(
            bottom: 10,
            right: 10,
            child: FutureBuilder<String>(
              future: _getAppVersion(), // Fetch the version
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading...",
                      style: TextStyle(fontSize: 12, color: Colors.grey));
                }
                if (snapshot.hasError) {
                  return const Text("Error",
                      style: TextStyle(fontSize: 12, color: Colors.red));
                }
                return Text(
                  "App Version: v${snapshot.data}",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
