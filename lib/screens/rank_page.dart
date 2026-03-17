import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/database_service.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import '../providers/theme_provider.dart';

import '../utils/attendance_utils.dart';
import 'edit_username_page.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  String? _username;
  bool _isUsernameSet = false;
  bool _isUploading = false;
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    // Listen for changes (e.g. data reset from settings)
    DatabaseService.settingsBox.listenable().addListener(_loadUsername);
  }

  void _loadUsername() {
    if (!mounted) return;
    setState(() {
      _username = DatabaseService.settingsBox.get("username") as String?;
      _isUsernameSet = DatabaseService.settingsBox.get("isUsernameSet", defaultValue: false) as bool;
    });
  }

  Future<void> _refreshLeaderboard() async {
    setState(() {
      _refreshCounter++;
    });
    // Small delay to show the indicator for a moment
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    DatabaseService.settingsBox.listenable().removeListener(_loadUsername);
    super.dispose();
  }

  Future<void> _submitRankingData() async {
    if (_username == null || _username!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a username first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final subjectsBox = DatabaseService.subjectsBox;
      final attendanceBox = DatabaseService.attendanceBox;

      final subjects = subjectsBox.values.cast<Subject>().toList();
      final allAttendance = attendanceBox.values.cast<Attendance>().toList();

      final subjectsSummary = subjects.map((subject) {
        final stats = calculateStats(subject.id, allAttendance);
        return {
          'subjectName': subject.name,
          'totalClasses': stats.total,
          'attendedClasses': stats.attended,
        };
      }).toList();

      final dataMap = {
        'username': _username,
        'timestamp': FieldValue.serverTimestamp(),
        'subjects': subjectsSummary,
      };

      await FirebaseFirestore.instance.collection("rankings").add(dataMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ranking data uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
                        ),
                        child: Text(
                          "Rankings",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const Spacer(),
                      if (!_isUsernameSet) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: isAbsolute
                                ? Border.all(color: scheme.outlineVariant)
                                : null,
                          ),
                          child: IconButton(
                            iconSize: 28,
                            padding: const EdgeInsets.all(14),
                            icon: Icon(Icons.edit, color: scheme.onSurface),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const EditUsernamePage()),
                              );
                              _loadUsername();
                            },
                            tooltip: "Set Username",
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isAbsolute
                          ? scheme.surfaceContainer
                          : scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: RefreshIndicator(
                      onRefresh: _refreshLeaderboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSubmissionForm(context, isAbsolute, scheme),
                            const SizedBox(height: 32),
                            _buildLeaderboard(context, isAbsolute, scheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          /// NAV BAR COLOR FIX
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 12,
              color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm(
      BuildContext context, bool isAbsolute, ColorScheme scheme) {
    final hasUsername = _username != null && _username!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Share your progress",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Submit your attendance snapshot to the global leaderboard.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Display Name",
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      hasUsername ? _username! : "Not set",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isUploading || !hasUsername ? null : _submitRankingData,
          icon: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isUploading ? "Uploading..." : "Submit Ranking Data"),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboard(
      BuildContext context, bool isAbsolute, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Global Leaderboard",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              onPressed: _refreshLeaderboard,
              icon: Icon(Icons.refresh, color: scheme.primary),
              tooltip: 'Reload Leaderboard',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Users closest to 75% attendance rank higher.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          key: ValueKey('leaderboard_stream_$_refreshCounter'),
          stream: FirebaseFirestore.instance
              .collection('leaderboard')
              .orderBy('rank')
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 48, color: scheme.outline),
                      const SizedBox(height: 12),
                      Text("No rankings yet",
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final username = data['username'] ?? 'Unknown';
                final attendance = (data['attendancePercent'] ?? 0.0).toDouble();
                final score = (data['rankingScore'] ?? 0.0).toDouble();
                final rank = data['rank'] ?? (index + 1);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isAbsolute
                        ? scheme.surfaceContainerHigh
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: isAbsolute
                        ? Border.all(color: scheme.outlineVariant)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: index < 3
                              ? scheme.primaryContainer
                              : scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$rank",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index < 3
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${attendance.toStringAsFixed(1)}% Attendance",
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            score.toStringAsFixed(1),
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "Score",
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
