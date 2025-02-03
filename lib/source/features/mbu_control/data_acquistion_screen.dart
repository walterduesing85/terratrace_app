import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/features/mbu_control/chart_menu.dart';
import 'package:terratrace/source/features/project_manager/presentation/sign_in_form.dart';

class DataAcquisitionScreenScreen extends ConsumerWidget {
  final String? type;
  const DataAcquisitionScreenScreen({Key? key, this.type}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentUserStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
              backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
              appBar: AppBar(
                backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
                title: CustomAppBar(
                  title: type == "mbu1"
                      ? 'MBU1: Select Device'
                      : "MBU2: Select Device", // Use data when available, or default title
                ),
              ),
              body: SignInForm()); // Show the SignInForm when not signed in
        } else {
          return BLEScreen(
            type: type,
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
