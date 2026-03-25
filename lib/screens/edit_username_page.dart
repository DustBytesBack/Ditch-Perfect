import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/wavy_progress_indicator.dart';

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
    final isLocked =
        DatabaseService.settingsBox.get("isUsernameSet", defaultValue: false)
            as bool;
    if (isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }

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
      // 1. Check if username is already in leaderboard (fastest check)
      final leaderboardDoc = await FirebaseFirestore.instance
          .collection("leaderboard")
          .doc(username)
          .get();

      if (leaderboardDoc.exists) {
        setState(() => _error = "Username is already taken");
        return;
      }

      // 2. Check if username is in rankings (pending calculation)
      final rankingsQuery = await FirebaseFirestore.instance
          .collection("rankings")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (rankingsQuery.docs.isNotEmpty) {
        setState(() => _error = "Username is already taken");
        return;
      }

      // 3. First Confirmation
      if (mounted) {
        final confirm1 = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Set Username?"),
            content: const Text(
              "Are you sure? You will have to pay if you want to change it later.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Continue"),
              ),
            ],
          ),
        );
        if (confirm1 != true) return;
      }

      // 4. Second Confirmation
      if (mounted) {
        final confirm2 = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Final Check!"),
            content: const Text(
              "Just Kidding !. Your username is permanent, just like your name irl. Confirm to save?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Go Back"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirm & Save"),
              ),
            ],
          ),
        );
        if (confirm2 != true) return;
      }

      // If it doesn't exist in either and user confirmed twice, it's unique and final
      await DatabaseService.settingsBox.put("username", username);
      await DatabaseService.settingsBox.put("isUsernameSet", true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Username locked and saved successfully"),
          ),
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
