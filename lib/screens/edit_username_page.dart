import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/wavy_progress_indicator.dart';
import '../utils/ranking_utils.dart';

class EditUsernamePage extends StatefulWidget {
  const EditUsernamePage({super.key});

  @override
  State<EditUsernamePage> createState() => _EditUsernamePageState();
}

class _EditUsernamePageState extends State<EditUsernamePage> {
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
        // Allow if the existing entry belongs to the current user
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username saved successfully")),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isAbsolute ? scheme.surface : scheme.primaryContainer,
      appBar: AppBar(
        title: const Text("Edit Username"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "Pick a unique name",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This name will be displayed on the global leaderboard.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: "Username",
                      hintText: "Enter your username",
                      errorText: _error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: (val) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveUsername,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: WavyCircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text("Save Username"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

