import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terra_trace/source/common_widgets/rounded_button.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/routing/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScrenState();
}

class _HomeScrenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(58, 66, 86, 1),
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(child: Image.asset('images/TT_Logo.png')),
                const SizedBox(
                  height: 60.0,
                ),
                Flexible(
                  child: Consumer(builder: (context, ref, _) {
                    return RoundedButton(
                        buttonColor: const Color.fromRGBO(64, 75, 96, 1),
                        buttonText: 'Create new project',
                        goTo: () {
                          ref.read(isRemoteProvider.notifier).state = false;
                          ref.read(isRemoteProvider.notifier).state = false;
                          ref
                              .read(projectNameProvider.notifier)
                              .setProjectName('');

                          context
                              .pushNamed(AppRoute.createNewProjectScreen.name);
                        });
                  }),
                ),
                const SizedBox(
                  height: 40.0,
                ),
                Flexible(
                  child: RoundedButton(
                      buttonColor: const Color.fromRGBO(64, 75, 96, 1),
                      buttonText: 'Project Manager',
                      goTo: () {
                        context.pushNamed(AppRoute.projectmanager.name);
                      }),
                ),
              ])),
    );
  }
}
