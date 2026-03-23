import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/ranking_utils.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/wavy_progress_indicator.dart';

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

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());
    final minutes = difference.inMinutes;
    final hours = difference.inHours;

    if (hours >= 1) {
      return "${hours}hr ago";
    } else {
      return "$minutes min ago";
    }
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

    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      await RankingUtils.uploadRankingData();

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
                              ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                              : null,
                        ),
                        child: Text(
                          "Rankings (BETA)",
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
                              ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: isAbsolute
                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                : Border.all(color: scheme.outlineVariant),
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
              const SizedBox(width: 8),
              if (hasUsername)
                _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: WavyCircularProgressIndicator(size: 24, strokeWidth: 3),
                      )
                    : IconButton(
                        onPressed: () => _submitRankingData(),
                        icon: Icon(Icons.cloud_upload_outlined,
                            color: scheme.primary),
                        tooltip: "Sync Now",
                      ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboard(
      BuildContext context, bool isAbsolute, ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('leaderboard_stream_$_refreshCounter'),
      stream: FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('rank')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        Timestamp? updatedAt;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final firstDoc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          updatedAt = firstDoc['updatedAt'] as Timestamp?;
        }

        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Leaderboard",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (updatedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeTime(updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: .7),
                        ),
                  ),
                ],
                const Spacer(),
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
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Error: ${snapshot.error}'),
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: WavyCircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              Center(
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
              )
            else
              ListView.separated(
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
                  final isCurrentUser = _username != null && username == _username;
                  final isRank1 = rank == 1;
                  final isRank2 = rank == 2;
                  final isRank3 = rank == 3;

                  Color? rankColor;
                  IconData? rankIcon;
                  Color? shimmerColor;

                  if (isRank1) {
                    rankColor = const Color(0xFFFFD700); // Pure Gold
                    rankIcon = Icons.workspace_premium_rounded;
                    shimmerColor = const Color(0xFFFFE082); // Brighter Gold Shimmer
                  } else if (isRank2) {
                    rankColor = Colors.blueGrey.shade400;
                    rankIcon = Icons.emoji_events_rounded;
                    shimmerColor = Colors.grey.shade300;
                  } else if (isRank3) {
                    rankColor = Colors.brown.shade300;
                    rankIcon = Icons.emoji_events_rounded;
                    shimmerColor = null; // Removed shine for bronze
                  }

                  Widget pill = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isAbsolute
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: rankColor != null
                          ? Border.all(color: rankColor, width: 2.5)
                          : (isCurrentUser
                              ? Border.all(color: scheme.primary, width: 2.5)
                              : (isAbsolute
                                  ? Border.all(
                                      color: scheme.primary.withValues(alpha: 0.10))
                                  : null)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: rankColor?.withValues(alpha: 0.15) ??
                                (index < 3
                                    ? scheme.primaryContainer
                                    : scheme.surface),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: rankIcon != null
                              ? Icon(
                                  rankIcon,
                                  color: rankColor,
                                  size: 24,
                                )
                              : Text(
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: scheme.onSurface,
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

                  if (shimmerColor != null) {
                    return ShimmeringRankPill(
                      shimmerColor: shimmerColor,
                      duration: Duration(milliseconds: isRank1 ? 3000 : 6000),
                      child: pill,
                    );
                  }
                  return pill;
                },
              ),
            const SizedBox(height: 120),
          ],
        );
      },
    );
  }
}

class ShimmeringRankPill extends StatefulWidget {
  final Widget child;
  final Color shimmerColor;
  final Duration duration;
  const ShimmeringRankPill({
    super.key,
    required this.child,
    required this.shimmerColor,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<ShimmeringRankPill> createState() => _ShimmeringRankPillState();
}

class _ShimmeringRankPillState extends State<ShimmeringRankPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double offset = _controller.value;

        // Maintain consistent speed (3s travel) while allowing variable frequency
        const travelDurationMs = 3000.0;
        final totalDurationMs = widget.duration.inMilliseconds.toDouble();

        if (totalDurationMs > travelDurationMs) {
          final ratio = travelDurationMs / totalDurationMs;
          if (offset < ratio) {
            offset = offset / ratio;
          } else {
            offset = 1.1; // Stay just outside the right edge
          }
        }

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.shimmerColor.withValues(alpha: 0),
                widget.shimmerColor.withValues(alpha: 0.5),
                widget.shimmerColor.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(offset: offset),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double offset;
  const _SlidingGradientTransform({required this.offset});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (offset * 3 - 1.5), 0, 0);
  }
}
