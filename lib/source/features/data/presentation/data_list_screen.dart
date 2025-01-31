import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/async_value_widget.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'data_card.dart';
import 'circle_icon_button.dart';

class DataListScreen extends StatefulWidget {
  const DataListScreen({Key? key}) : super(key: key);

  @override
  _DataListScreenState createState() => _DataListScreenState();
}

class _DataListScreenState extends State<DataListScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/flux_Tec_logo_schwarz.png'),
          fit: BoxFit.fitWidth,
        ),
      ),
      child: Scaffold(
        drawer: CustomDrawer(),
        backgroundColor: const Color.fromRGBO(58, 66, 86, 0.93),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
          title: const CustomAppBar(
            title: 'Data Points',
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final boxAsyncValue = ref.watch(fluxDataListProvider);
                  return AsyncValueWidget<List<FluxData>>(
                    value: boxAsyncValue,
                    data: (dataList) {
                      return ListView.builder(
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        itemCount: dataList.length,
                        itemBuilder: (context, index) {
                          FluxData fluxData = dataList[index];
                          return DataCard(
                            date: fluxData.dataDate!,
                            site: fluxData.dataSite!,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Consumer(
                builder: (context, ref, child) => TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontSize: 25,
                    // color: Colors.white70,
                  ),
                  onChanged: (value) {
                    ref
                        .read(searchValueProvider.notifier)
                        .setSearchValue(value);
                    print(value);
                  },
                  decoration: kInputTextField.copyWith(
                    suffixIcon: CircleIconButton(
                      onPressed: () {
                        ref
                            .read(searchValueProvider.notifier)
                            .clearSearchValue();
                        FocusScope.of(context).unfocus();
                        _controller.clear();
                      },
                    ),
                    hintText: '    Search Site',
                    hintStyle: const TextStyle(
                      fontSize: 20,
                      // color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
