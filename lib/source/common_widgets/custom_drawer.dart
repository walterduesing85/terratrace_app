import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terratrace/source/common_widgets/signin_register_popup.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/user/presentation/tab_user.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/project_manager/presentation/remote_projects_tab.dart';
import 'package:terratrace/source/routing/app_router.dart';

class CustomDrawer extends ConsumerStatefulWidget {
  const CustomDrawer({super.key});

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends ConsumerState<CustomDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.95,
      child: Drawer(
        child: Container(
          color: Colors.black87,
          child: Column(
            children: [
              /// **🧑 User Account Info**
              Consumer(builder: (context, ref, _) {
                final projectName = ref.watch(projectNameProvider);
                final authState = ref.watch(currentUserStateProvider);
                return UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/drawer_image_02.png'),
                        fit: BoxFit.cover,
                      ),
                    color: Colors.white,
                    ),
                    accountName: Text(
                      projectName,
                      style: drawerHeader,
                    ),
                    accountEmail: GestureDetector(
                        child: authState.when(
                      data: (user) => Text(
                              user?.email ?? '',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                          loading: () => Text('Loading...'),
                          error: (error, _) => Text('Error loading email'),
                        ),
                        onTap: () {
                          SigninRegisterPopup.showAuthPopup(context, ref);
                    },
                  ),
                );
              }),

              /// **📌 Elevated Tab Bar**
              Material(
                color: const Color.fromARGB(221, 16, 4, 4),
                elevation: 5,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: kGreenFluxColor,
                  tabs: [
                    Tab(icon: Icon(Icons.settings), text: "Settings"),
                    Tab(icon: Icon(Icons.folder), text: "Projects"),
                    Tab(icon: Icon(Icons.people), text: "Users"),
                  ],
                ),
              ),

              /// **📌 TabBar View - Scrollable Content**
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    /// **⚙️ Settings Tab**
                    ListView(
                      children: [
              ListTile(
                          title: Text('User Profile', style: kDrawerTextStyle),
                          trailing: Icon(Icons.account_circle,
                              color: kGreenFluxColor),
                          onTap: () =>
                              context.pushNamed(AppRoute.mapScreen.name),
                        ),
                        ListTile(
                          title:
                              Text('Connected device', style: kDrawerTextStyle),
                          trailing: Icon(Icons.settings_input_antenna,
                              color: kGreenFluxColor),
                          onTap: () => context.pushNamed(AppRoute.home.name),
                        ),
                        ListTile(
                          title: Text('Close Project', style: kDrawerTextStyle),
                          trailing: Icon(Icons.close, color: kGreenFluxColor),
                          onTap: () => context.pushNamed(AppRoute.home.name),
                        ),
                      ],
                    ),

                    /// **📂 Projects Tab**

                    ProjectTapDrawer(),

                    /// **👥 Users Tab**
                    TabUser(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
