import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../services/database_service.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/wavy_progress_indicator.dart';

/// Silent check — used on app launch. Shows dialog only if update exists.
Future<void> checkForUpdate(BuildContext context) async {
  try {
    final update = await UpdateService.checkForUpdate();
    if (update == null) return;
    if (!context.mounted) return;

    context.read<SettingsProvider>().setUpdateInfo(update);

    showDialog(
      context: context,
      builder: (_) => _UpdateResultDialog(
        version: update["version"],
        url: update["url"],
        notes: update["notes"],
      ),
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

/// Shows the update result dialog with the provided [update] info.
void showUpdateDialog(BuildContext context, Map<String, dynamic> update) {
  showDialog(
    context: context,
    builder: (_) => _UpdateResultDialog(
      version: update["version"],
      url: update["url"],
      notes: update["notes"],
    ),
  );
}

/// Manual check — used from Settings. Shows a dialog with loading → result.
void checkForUpdateManual(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ManualUpdateCheckDialog(),
  );
}

/// Shows the release notes dialog manually.
void showReleaseNotesDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ReleaseNotesDialog(
      version: packageInfo.version,
      notes: null, // It will load from history automatically
    ),
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
      final result = await Future.wait([
        UpdateService.checkForUpdate(),
        Future.delayed(const Duration(seconds: 3)),
      ]).then((values) => values[0] as Map<String, dynamic>?);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _update = result;
      });

      if (mounted && result != null) {
        context.read<SettingsProvider>().setUpdateInfo(result);
      }
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const WavyCircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Please wait...",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
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
        notes: _update!["notes"],
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
  final String? notes;

  const _UpdateResultDialog({
    required this.version,
    required this.url,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text("Update Available")),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "A new version ($version) is available.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (notes != null && notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "What's New:",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: Scrollbar(
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
                          listBullet: Theme.of(context).textTheme.bodyMedium,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
          child: const Text("Update Now"),
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
      content: _SequentialReleaseNotesView(
        initialVersion: version,
        initialNotes: notes,
        maxHeight: 400,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}

class _SequentialReleaseNotesView extends StatefulWidget {
  final String initialVersion;
  final String? initialNotes;
  final double maxHeight;

  const _SequentialReleaseNotesView({
    required this.initialVersion,
    this.initialNotes,
    this.maxHeight = 250,
  });

  @override
  State<_SequentialReleaseNotesView> createState() =>
      _SequentialReleaseNotesViewState();
}

class _SequentialReleaseNotesViewState
    extends State<_SequentialReleaseNotesView> {
  List<Map<String, dynamic>> _releases = [];
  int _currentIndex = -1;
  bool _loading = false;
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        UpdateService.fetchAllReleases(),
        PackageInfo.fromPlatform(),
      ]);

      final releases = results[0] as List<Map<String, dynamic>>;
      final packageInfo = results[1] as PackageInfo;

      if (!mounted) return;

      int initialIndex = releases.indexWhere(
        (r) => (r["version"] as String).contains(widget.initialVersion),
      );

      setState(() {
        _releases = releases;
        _installedVersion = packageInfo.version;
        _currentIndex = initialIndex != -1 ? initialIndex : 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Fallback to initial notes if error occurs
      });
    }
  }

  void _next() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _previous() {
    if (_currentIndex < _releases.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading && _releases.isEmpty) {
      return SizedBox(
        height: widget.maxHeight,
        child: const Center(child: WavyCircularProgressIndicator()),
      );
    }

    final String currentDisplayVersion;
    final String currentNotes;

    if (_currentIndex != -1 && _releases.isNotEmpty) {
      currentDisplayVersion = _releases[_currentIndex]["version"] as String;
      currentNotes = _releases[_currentIndex]["body"] as String? ?? "";
    } else {
      currentDisplayVersion = widget.initialVersion;
      currentNotes = widget.initialNotes ?? "";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              "Version $currentDisplayVersion",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),

            // BADGES
            if (_installedVersion != null &&
                currentDisplayVersion.contains(_installedVersion!))
              _buildBadge("CURRENT", scheme.secondaryContainer,
                  scheme.onSecondaryContainer),

            if (_releases.isNotEmpty &&
                currentDisplayVersion == _releases.first["version"]) ...[
              const SizedBox(width: 4),
              _buildBadge(
                  "LATEST", scheme.primaryContainer, scheme.onPrimaryContainer),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight,
            maxWidth: 400,
          ),
          child: currentNotes.trim().isNotEmpty
              ? Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: ValueKey(currentDisplayVersion),
                    child: MarkdownBody(
                      data: currentNotes,
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
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "No release notes provided for this version.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
        if (_releases.length > 1) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    _currentIndex < _releases.length - 1 ? _previous : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text("Older"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_currentIndex + 1} / ${_releases.length}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: 20,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: _currentIndex > 0 ? _next : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text("Newer"),
                iconAlignment: IconAlignment.end,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String label, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
