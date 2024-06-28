import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/constants/constants.dart';
import 'circle_icon_button.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';

class SearchTextField extends ConsumerStatefulWidget {
  const SearchTextField({Key key}) : super(key: key);

  @override
  _SearchTextFieldState createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends ConsumerState<SearchTextField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        style: const TextStyle(
          fontSize: 25,
          color: Colors.white70,
        ),
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (value) {
          ref.read(searchValueTabProvider.notifier).setSearchValue(value);
        },
        decoration: kInputTextField.copyWith(
          suffixIcon: CircleIconButton(
            onPressed: () {
              _controller.clear();
              ref.read(searchValueTabProvider.notifier).clearSearchValue();
              FocusScopeNode currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                currentFocus.focusedChild.unfocus();
              }
            },
          ),
          hintText: '    Search Site',
          hintStyle: const TextStyle(
            fontSize: 20,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
