import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveButtonNotifier extends StateNotifier<String> {
  ActiveButtonNotifier() : super('none');

  void setActiveButton(String button) {
    state = (state == button) ? 'none' : button;
  }
}

final activeButtonProvider =
    StateNotifierProvider<ActiveButtonNotifier, String>(
  (ref) => ActiveButtonNotifier(),
);
