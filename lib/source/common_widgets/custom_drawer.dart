import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rflutter_alert/rflutter_alert.dart';

import 'package:terratrace/source/common_widgets/signin_register_popup.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/authentication/authentication_managment.dart';
import 'package:terratrace/source/features/data/data/data_export.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/routing/app_router.dart';

//This drawer is the main menu that changes appearance when remote = true is selected
class CustomDrawer extends StatelessWidget {
  CustomDrawer();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9,
      child: Drawer(
        child: Container(
          color: Colors.black87,
          child: ListView(
            children: [
              Consumer(builder: (context, ref, _) {
                final projectName = ref.watch(projectNameProvider);
                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/drawer_image_02.png'),
                      fit: BoxFit.cover,
                    ),
                    color: Color.fromRGBO(255, 255, 255, 9),
                  ),
                  accountName: Text(
                    projectName,
                    style: drawerHeader,
                  ),
                  accountEmail: Consumer(builder: (context, ref, _) {
                    final user = ref.watch(userStateProvider);
                    final projectName = ref.watch(projectNameProvider);
                    return GestureDetector(
                        child: Text(
                          user?.email ?? '',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          SigninRegisterPopup(projectName: projectName)
                              .openPopup(context);
                        });
                  }),
                );
              }),
              ListTile(
                  title: Text(
                    'All Projects',
                    style: kDrawerTextStyle,
                  ),
                  trailing: Icon(
                    Icons.ballot_outlined,
                    color: kGreenFluxColor,
                  ),
                  onTap: () {
                    context.pushNamed(AppRoute.projectmanager.name);
                  }),
              ListTile(
                  title: Text(
                    'New project',
                    style: kDrawerTextStyle,
                  ),
                  trailing: Icon(
                    Icons.add_box_outlined,
                    color: kGreenFluxColor,
                  ),
                  onTap: () {
                    context.pushNamed(AppRoute.createNewProjectScreen.name);
                  }),
              // ListTile(
              //   title: Text(
              //     'Project Members',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing: Icon(
              //     Icons.card_membership_sharp,
              //     color: kGreenFluxColor,
              //   ),
              //   onTap: () {
              //     context.pushNamed(AppRoute.projectMemberSettingScreen.name);
              //   },
              // ),
              Consumer(builder: (context, ref, _) {
                return ListTile(
                  title: Text(
                    'Map view',
                    style: kDrawerTextStyle,
                  ),
                  trailing: Icon(
                    Icons.map,
                    color: kGreenFluxColor,
                  ),
                  onTap: () {
                    // if (listLength > 10) {
                    context.pushNamed(AppRoute.mapScreen.name);
                    // } else
                    //  Alert(title: 'minimum 10 data points', context: context)
                    //    .show();
                  },
                );
              }),
              ListTile(
                  title: Text(
                    'List View',
                    style: kDrawerTextStyle,
                  ),
                  trailing: Icon(
                    Icons.list,
                    color: kGreenFluxColor,
                  ),
                  onTap: () {
                    context.pushNamed(AppRoute.dataListScreen.name);
                  }),

              Consumer(builder: (context, WidgetRef ref, _) {
                return ListTile(
                  title: Text(
                    'Save data points',
                    style: kDrawerTextStyle,
                  ),
                  trailing: Icon(
                    Icons.save,
                    color: kGreenFluxColor,
                    size: 28,
                  ),
                  onTap: () async {
                    DataExport fluxStorage =
                        DataExport(ref.read(projectNameProvider));

                    await fluxStorage.getPermission();
                    fluxStorage
                        .saveData(ref.read(fluxDataListProvider).asData!.value);
                    Alert(
                        context: context,
                        title: 'data saved on local storage',
                        buttons: [
                          DialogButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('ok'),
                          )
                        ]).show();
                  },
                );
              }),
              // ListTile(
              //   title: Text(
              //     'Show histogram',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing:
              //       Icon(Icons.insert_chart, color: kGreenFluxColor, size: 28),
              //   onTap: () {
              //     Navigator.push(context, MaterialPageRoute(builder: (context) {
              //       return HistogramScreen(
              //         box: widget.box,
              //         dataSelect: widget.dataSelect,
              //       );
              //     }));
              //   },
              // ),
              // ListTile(
              //   title: Text(
              //     'Update Data Points',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing: Icon(Icons.update, color: kGreenFluxColor, size: 28),
              //   onTap: () async {
              //     print(globals.remote);
              //     print(globals.browseFiles);
              //     await FluxBrain(box: widget.box).getPermission();
              //     if (globals.browseFiles == true) {
              //       await FluxBrain(box: widget.box).makeTheData();
              //     }
              //     if (globals.remote == true) {
              //       await FluxBrain(box: widget.box).pullFireStoreData();
              //       await FluxBrain(box: widget.box).pushFireStoreData();
              //     }
              //     Navigator.pushReplacement(context,
              //         MaterialPageRoute(builder: (context) {
              //       return DataCardScreen(
              //         box: widget.box,
              //       );
              //     }));
              //   },
              // ),
              // ListTile(
              //   title: Text(
              //     'Sign out',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing: Icon(Icons.follow_the_signs_outlined,
              //       color: kGreenFluxColor, size: 28),
              //   onTap: () async {
              //     await _auth.signOut();
              //     Navigator.pushReplacement(context,
              //         MaterialPageRoute(builder: (context) {
              //       return DataCardScreen(
              //           box: widget.box, dataSelect: widget.dataSelect);
              //     }));
              //   },
              // ),
              // ListTile(
              //   title: Text(
              //     'Settings',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing:
              //       Icon(Icons.settings, color: kGreenFluxColor, size: 28),
              //   onTap: () {
              //     Navigator.pushReplacement(context,
              //         MaterialPageRoute(builder: (context) {
              //       return SettingScreen(
              //         box: widget.box,
              //         dataSelect: widget.dataSelect,
              //       );
              //     }));
              //   },
              // ),
              // ListTile(
              //   title: Text(
              //     'Close project',
              //     style: kDrawerTextStyle,
              //   ),
              //   trailing: Icon(Icons.close, color: kGreenFluxColor, size: 28),
              //   onTap: () async {
              //     widget.box.close();
              //     /*Box projectBox = await Hive.openBox<ProjectData>('projects');
              //     ProjectData projectData = projectBox.get(projectName);
              //     projectData = ProjectData(
              //         projectName: projectName,
              //         isRemote: globals.remote,
              //         browseFiles: globals.browseFiles,
              //         chamberVolume: globals.chamberVolume,
              //         surfaceArea: globals.chamberArea,
              //         defaultPressure: double.parse(globals.defaultPressure),
              //         defaultTemperature:
              //             double.parse(globals.defaultTemperature));
              //     await projectBox.put(projectName, projectData);
              //     globals.remote = false;*/
              //     globals.browseFiles = false;
              //     Box projectBox = Hive.box<ProjectData>('projects');
              //     projectBox.close();

              //     Navigator.push(context, MaterialPageRoute(builder: (context) {
              //       return FirstScreen();
              //     }));
              //   },
              // ),
              // DrawerRemote(dataSelect: widget.dataSelect, box: widget.box),
            ],
          ),
        ),
      ),
    );
  }
}
