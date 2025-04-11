import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/constants/constants.dart';

import 'package:terratrace/source/features/user/domain/user_managment.dart';

class TabUser extends StatefulWidget {
  const TabUser({super.key});

  @override
  _TabUserState createState() => _TabUserState();
}

class _TabUserState extends State<TabUser> {
  var _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer(builder: (context, WidgetRef ref, _) {
        // Watch the user cards provider for updated data
        final userCardsAsyncValue = ref.watch(userCardsProvider);

        return Column(
          children: [
            // Search Bar
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  style: TextStyle(
                    fontSize: 25,
                    color: Colors.white70,
                  ),
                  controller: _controller,
                  onChanged: (value) {
                    // Update search query in the provider
                    ref.read(userSearchValueProvider.notifier).state = value;
                  },
                  decoration: kInputTextField.copyWith(
                      suffixIcon: CircleIconButton(onPressed: () {
                        setState(() {
                          _controller.clear();
                          ref.read(userSearchValueProvider.notifier).state =
                              ''; // Clear the search query
                          FocusScopeNode currentFocus = FocusScope.of(context);
                          if (!currentFocus.hasPrimaryFocus &&
                              currentFocus.focusedChild != null) {
                            currentFocus.focusedChild?.unfocus();
                          }
                        });
                      }),
                      hintText: 'Search user',
                      hintStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      )),
                ),
              ),
            ),
            // Display user cards
            Expanded(
              child: userCardsAsyncValue.when(
                data: (userCards) {
                  if (userCards.isEmpty) {
                    return Center(child: Text('No collaborators found.'));
                  }
                  return ListView(
                      children: userCards); // Display filtered user cards
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (e, stack) =>
                    Center(child: Text('Error loading users: $e')),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final double size;
  final Function() onPressed;
  final IconData icon;

  CircleIconButton(
      {this.size = 30.0, this.icon = Icons.clear, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onPressed,
        child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment(0.0, 0.0), // all centered
              children: <Widget>[
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.grey[300]),
                ),
                Icon(
                  icon,
                  size: size * 0.6, // 60% width for icon
                )
              ],
            )));
  }
}
