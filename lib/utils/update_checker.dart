import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

/// Silent check used on app launch — only shows dialog if update is available.
Future<void> checkForUpdate(BuildContext context) async {
  final update = await UpdateService.checkForUpdate();

  if (update == null) return;

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (_) =>
        UpdateDialog(version: update["version"], url: update["url"]),
  );
}

/// Manual check triggered from Settings — shows a dialog with loading state,
/// then either "up to date" or "update available" with a link to the release page.
void checkForUpdateManual(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateCheckDialog(),
  );
}

class _UpdateCheckDialog extends StatefulWidget {
  const _UpdateCheckDialog();

  @override
  State<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<_UpdateCheckDialog> {
  bool _loading = true;
  bool _error = false;
  Map<String, dynamic>? _update;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final result = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _update = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: const Text("Checking for Updates"),
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                "Please wait...",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error) {
      return AlertDialog(
        title: const Text("Update Check Failed"),
        content: const Text(
          "Could not check for updates. Please check your internet connection and try again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      );
    }

    if (_update == null) {
      // Up to date
      return AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text("You're up to date!"),
        content: const Text("No new updates available."),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      );
    }

    // Update available
    final version = _update!["version"];
    final releaseUrl =
        "https://github.com/${UpdateService.repoOwner}/${UpdateService.repoName}/releases/tag/$version";

    return AlertDialog(
      icon: Icon(
        Icons.system_update,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text("Update Available"),
      content: Text("A new version ($version) is available."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Later"),
        ),
        FilledButton(
          onPressed: () async {
            final uri = Uri.parse(releaseUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: const Text("View Release"),
        ),
      ],
    );
  }
}
