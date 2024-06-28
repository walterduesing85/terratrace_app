import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import '../../data/prensentation/circle_icon_button.dart';
import 'package:terra_trace/source/constants/constants.dart';

class TextFieldTab extends ConsumerWidget {
  final TextEditingController controller;

  const TextFieldTab({
    Key key,
    @required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchValueNotifier = ref.watch(searchValueTabProvider.notifier);

    return TextField(
      controller: controller,
      decoration: kInputTextField.copyWith(
        suffixIcon: CircleIconButton(
          onPressed: () {
            controller.clear();
            searchValueNotifier.clearSearchValue();
            FocusScope.of(context).unfocus();
          },
        ),
        hintText: 'Search Site',
      ),
      style: const TextStyle(
        fontSize: 12, // Adjust font size as needed
        color: Colors.white70,
      ),
      onChanged: (value) {
        searchValueNotifier.setSearchValue(value);
        FocusScope.of(context).requestFocus();
      },
    );
  }
}
