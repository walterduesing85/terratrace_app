import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/common_widgets/signin_register_popup.dart';

import 'package:terra_trace/source/constants/constants.dart';

import '../features/data/data/data_management.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({@required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Consumer(builder: (context, ref, _) {
          final projectName = ref.watch(projectNameProvider);
          return GestureDetector(
            onTap: () {
              SigninRegisterPopup(projectName: projectName).openPopup(context);
            },
            child: Text(
              title,
              style: const TextStyle(color: kGreenFluxColor, fontSize: 18),
            ),
          );
        }),
        const Expanded(child: SizedBox(width: 100)),
        Image.asset(
          'images/TT_Logo.png',
          width: 100,
        ),
        const SizedBox(width: 10),
        const SizedBox(
          width: 10,
        )
      ],
    );
  }
}
