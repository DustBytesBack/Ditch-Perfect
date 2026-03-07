import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {

  final String version;
  final String url;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: const Text("Update Available"),
      content: Text("A new version ($version) is available."),
      actions: [

        TextButton(
          child: const Text("Later"),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        FilledButton(
          child: const Text("Update"),
          onPressed: () async {

            final uri = Uri.parse(url);

            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );

          },
        ),
      ],
    );
  }
}