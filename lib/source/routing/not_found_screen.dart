import 'package:flutter/material.dart';

import 'package:terra_trace/source/common_widgets/empty_placeholder_widgets.dart';

/// Simple not found screen used for 404 errors (page not found on web)
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyPlaceholderWidget(
        message: '404 - Page not found!',
      ),
    );
  }
}
