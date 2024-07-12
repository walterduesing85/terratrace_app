import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/domain/flux_data.dart';

import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';

class EditDataScreen extends ConsumerStatefulWidget {
  final String projectName;
  final FluxData fluxData;

  EditDataScreen({required this.projectName, required this.fluxData});

  @override
  _EditFluxDataScreenState createState() => _EditFluxDataScreenState();
}

class _EditFluxDataScreenState extends ConsumerState<EditDataScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _updatedFields = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Flux Data'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: widget.fluxData.dataSite,
                decoration: InputDecoration(labelText: 'Data Site'),
                onChanged: (value) {
                  _updatedFields['dataSite'] = value;
                },
              ),
              // Add other fields similarly...
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final projectManagement =
                        ref.read(projectManagementProvider);

                    await projectManagement.updateFluxData(widget.projectName,
                        widget.fluxData.dataKey!, _updatedFields); //TODO Error updatig data
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
