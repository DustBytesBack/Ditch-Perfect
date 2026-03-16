import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../services/database_service.dart';

/// Silent check — used on app launch. Shows dialog only if update exists.
Future<void> checkForUpdate(BuildContext context) async {
  try {
    final update = await UpdateService.checkForUpdate();
    if (update == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) =>
          _UpdateResultDialog(version: update["version"], url: update["url"]),
    );
  } catch (_) {
    // Silent — don't bother the user on launch failures.
  }
}

/// Post-update check — shows release notes if the app was just updated.
/// Compares the running version against `lastSeenVersion` in Hive.
/// Should be called once on app launch (after checkForUpdate).
Future<void> checkForPostUpdateNotes(BuildContext context) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final settings = DatabaseService.settingsBox;
    final lastSeen = settings.get("lastSeenVersion") as String?;

    // First-ever launch: just store the version, don't show notes.
    if (lastSeen == null) {
      await settings.put("lastSeenVersion", currentVersion);
      return;
    }

    // Same or older version — nothing to show.
    if (!UpdateService.isVersionNewer(currentVersion, lastSeen)) {
      return;
    }

    // User updated! Save immediately so we don't show again on next launch.
    await settings.put("lastSeenVersion", currentVersion);

    // Fetch release notes from GitHub.
    final notes = await UpdateService.fetchReleaseNotes(currentVersion);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) =>
          _ReleaseNotesDialog(version: currentVersion, notes: notes),
    );
  } catch (_) {
    // Silent — don't block the user if fetching notes fails.
  }
}

/// Manual check — used from Settings. Shows a dialog with loading → result.
void checkForUpdateManual(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ManualUpdateCheckDialog(),
  );
}

// ── Manual check dialog (loading → result → error) ──────────────

class _ManualUpdateCheckDialog extends StatefulWidget {
  const _ManualUpdateCheckDialog();

  @override
  State<_ManualUpdateCheckDialog> createState() =>
      _ManualUpdateCheckDialogState();
}

class _ManualUpdateCheckDialogState extends State<_ManualUpdateCheckDialog> {
  bool _loading = true;
  String? _error;
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
        _loading = false;
        _update = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text("Update Check Failed"),
        content: Text(
          "Could not check for updates. Please try again later.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      );
    }

    if (_update != null) {
      return _UpdateResultDialog(
        version: _update!["version"],
        url: _update!["url"],
      );
    }

    // Up to date.
    return AlertDialog(
      title: const Text("You're Up to Date"),
      content: Text(
        "You're running the latest version.",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    );
  }
}

// ── Update available dialog ─────────────────────────────────────

class _UpdateResultDialog extends StatelessWidget {
  final String version;
  final String url;

  const _UpdateResultDialog({required this.version, required this.url});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Update Available"),
      content: Text("A new version ($version) is available."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Later"),
        ),

        FilledButton(
          onPressed: () async {
            final uri = Uri.parse(url);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: const Text("View Release"),
        ),
      ],
    );
  }
}

// ── Release notes dialog (shown after update) ───────────────────

class _ReleaseNotesDialog extends StatelessWidget {
  final String version;
  final String? notes;

  const _ReleaseNotesDialog({required this.version, this.notes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.celebration_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "What's New in v$version",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
        child: notes != null
            ? Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: notes!,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(
                          Uri.parse(href),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium,
                          h1: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: Theme.of(context).textTheme.bodyMedium,
                        ),
                  ),
                ),
              )
            : Text(
                "You've successfully updated to version $version!",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Got it"),
        ),
      ],
    );
  }
}
