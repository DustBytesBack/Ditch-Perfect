import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/wavy_progress_indicator.dart';
import '../utils/ranking_utils.dart';

class EditUsernameDialog extends StatefulWidget {
  const EditUsernameDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const EditUsernameDialog(),
    );
  }

  @override
  State<EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<EditUsernameDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final savedUsername =
        DatabaseService.settingsBox.get("username") as String?;
    if (savedUsername != null) {
      _controller.text = savedUsername;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = _controller.text.trim();
    if (username.isEmpty) {
      setState(() => _error = "Username cannot be empty");
      return;
    }

    if (username.length < 3) {
      setState(() => _error = "Username must be at least 3 characters");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUid = RankingUtils.getOrCreateUid();

      // Check if username is already in leaderboard (by another user)
      final leaderboardQuery = await FirebaseFirestore.instance
          .collection("leaderboard")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (leaderboardQuery.docs.isNotEmpty) {
        final existingDoc = leaderboardQuery.docs.first;
        final existingUid = existingDoc.data()['uid'] as String?;
        if (existingUid != currentUid) {
          setState(() => _error = "Username is already taken");
          return;
        }
      }

      // Check if username is in rankings (by another user)
      final rankingsQuery = await FirebaseFirestore.instance
          .collection("rankings")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (rankingsQuery.docs.isNotEmpty) {
        final existingDoc = rankingsQuery.docs.first;
        final existingUid = existingDoc.data()['uid'] as String?;
        if (existingUid != currentUid) {
          setState(() => _error = "Username is already taken");
          return;
        }
      }

      // Save locally
      await DatabaseService.settingsBox.put("username", username);
      await DatabaseService.settingsBox.put("isUsernameSet", true);

      // Trigger a sync record upload if we have connectivity
      // (This will overwrite the old record with the new username)
      await RankingUtils.uploadRankingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username updated and synced!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = "Failed to verify username: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final isDynamic = themeProvider.isDynamicMode;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text("Edit Username"),
      backgroundColor: isAbsolute ? scheme.surfaceContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                labelText: "Username",
                hintText: "Cook up a username.",
                errorText: _error,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: .5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: (isDynamic || isAbsolute)
                      ? BorderSide(color: scheme.outlineVariant)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: (isDynamic || isAbsolute)
                      ? BorderSide(color: scheme.outlineVariant)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: scheme.primary,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onChanged: (val) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _isLoading ? null : _saveUsername(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: WavyCircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : FilledButton(
                onPressed: _saveUsername,
                child: const Text("Save"),
              ),
      ],
    );
  }
}
