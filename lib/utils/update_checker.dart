import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

Future<void> checkForUpdate(BuildContext context) async {

  final update = await UpdateService.checkForUpdate();

  if (update == null) return;

  showDialog(
    context: context,
    builder: (_) => UpdateDialog(
      version: update["version"],
      url: update["url"],
    ),
  );
}