import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:terra_trace/source/common_widgets/primary_button.dart';
import 'package:terra_trace/source/constants/app_sizes.dart';
import 'package:terra_trace/source/routing/app_router.dart';

/// Placeholder widget showing a message and CTA to go back to the home screen.
class EmptyPlaceholderWidget extends StatelessWidget {
  const EmptyPlaceholderWidget({@required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Sizes.p16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            gapH32,
            PrimaryButton(
              onPressed: () => context.goNamed('home'),
              text: 'Go Home',
            )
          ],
        ),
      ),
    );
  }
}
