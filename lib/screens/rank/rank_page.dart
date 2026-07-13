import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/ranking_utils.dart';
import '../../services/database_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/wavy_progress_indicator.dart';
import '../../widgets/edit_username_dialog.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  String? _username;
  String? _uid;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _uid = RankingUtils.getOrCreateUid();
    _loadUsername();
    // Listen for changes (e.g. data reset from settings)
    DatabaseService.settingsBox.listenable().addListener(_loadUsername);
  }

  void _loadUsername() {
    if (!mounted) return;
    setState(() {
      _username = DatabaseService.settingsBox.get("username") as String?;
    });
  }

  Future<void> _refreshLeaderboard() async {
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

  void _showRankingInfoDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("How Ranking Works"),
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Our algorithm calculates your ranking score based on several factors to encourage consistent attendance.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                context,
                Icons.gps_fixed_rounded,
                "The 75% Target",
                "Ranking is optimized around the 75% attendance mark. Being above this target is your primary goal.",
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                context,
                Icons.trending_up_rounded,
                "The Safety Buffer",
                "As your attendance gets closer to 75%, your score increases exponentially. The closer you are to 100%, the more 'secure' your rank becomes.",
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                context,
                Icons.warning_amber_rounded,
                "Low Attendance Penalty",
                "Dropping below 75% incurs a significant penalty. Each class missed weighs your score down more heavily when you're in the 'danger zone'.",
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                context,
                Icons.balance_rounded,
                "Weighted Average",
                "Your final score is a weighted average across all your subjects. Every class in every subject counts toward your global standing.",
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understood"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading data: $e')));
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

    final topGradientColor = isAbsolute
        ? scheme.surface
        : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute
        ? scheme.surfaceContainer
        : scheme.surface;
    final panelColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;

    return Scaffold(
      backgroundColor: isAbsolute ? scheme.surface : scheme.primaryContainer,
      body: Stack(
        children: [
          /// GRADIENT BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topGradientColor, bottomGradientColor],
                ),
              ),
            ),
          ),

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
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
                              : null,
                        ),
                        child: Text(
                          "Rankings (BETA)",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                )
                              : null,
                        ),
                        child: _isUploading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: WavyCircularProgressIndicator(
                                    size: 28,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : IconButton(
                                iconSize: 28,
                                padding: const EdgeInsets.all(14),
                                icon: Icon(
                                  Icons.cloud_upload_outlined,
                                  color: scheme.onSurface,
                                ),
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await _submitRankingData();
                                },
                                tooltip: "Sync Ranking Data",
                              ),
                      ),

                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSubmissionForm(context, isAbsolute, scheme),
                          const SizedBox(height: 12),
                          _buildRankingHeader(context, scheme),
                          const SizedBox(height: 12),
                          _buildTabBar(context, scheme),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildLeaderboardTab(
                                  context,
                                  isAbsolute,
                                  scheme,
                                ),
                                _buildWeeklyLeaderboardTab(
                                  context,
                                  isAbsolute,
                                  scheme,
                                ),
                              ],
                            ),
                          ),
                        ],
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
    BuildContext context,
    bool isAbsolute,
    ColorScheme scheme,
  ) {
    final hasUsername = _username != null && _username!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAbsolute
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
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
                        child: WavyCircularProgressIndicator(
                          size: 24,
                          strokeWidth: 3,
                        ),
                      )
                    : IconButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await EditUsernameDialog.show(context);
                          _loadUsername();
                        },
                        icon: Icon(
                          Icons.edit_rounded,
                          color: scheme.tertiary,
                        ),
                        tooltip: "Edit Username",
                      ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: scheme.onPrimary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: "Leaderboard"),
                Tab(text: "Weekly"),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _refreshLeaderboard,
          icon: Icon(Icons.refresh, color: scheme.primary),
          tooltip: 'Reload Leaderboard',
        ),
      ],
    );
  }

  Widget _buildRankingHeader(BuildContext context, ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaderboard')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        Timestamp? updatedAt;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final firstDoc =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          updatedAt = firstDoc['updatedAt'] as Timestamp?;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              if (updatedAt != null) ...[
                Icon(
                  Icons.history,
                  size: 14,
                  color: scheme.onSurfaceVariant.withValues(alpha: .5),
                ),
                const SizedBox(width: 6),
                Text(
                  "Updated ${_formatRelativeTime(updatedAt)}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: .7),
                  ),
                ),
              ],
              const Spacer(),
              Material(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showRankingInfoDialog(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Ranking Info",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab(
    BuildContext context,
    bool isAbsolute,
    ColorScheme scheme,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('rank')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No leaderboard data found')),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshLeaderboard,
          displacement: 20,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == docs.length) return const SizedBox(height: 120);

              final data = docs[index].data() as Map<String, dynamic>;
              final username = data['username'] as String? ?? 'Anonymous';
              final userUid = data['uid'] as String?;
              final attendance =
                  (data['attendancePercent'] as num?)?.toDouble() ?? 0.0;
              final score = (data['rankingScore'] as num?)?.toDouble() ?? 0.0;
              final rank = data['rank'] as int? ?? (index + 1);
              final isCurrentUser = userUid == _uid;

              final isRank1 = rank == 1;
              final isRank2 = rank == 2;
              final isRank3 = rank == 3;

              Color? shimmerColor;
              if (isRank1) {
                shimmerColor = Colors.amber;
              } else if (isRank2) {
                shimmerColor = const Color(0xFFC0C0C0); // Silver
              }

              Widget rankIcon;
              if (isRank1) {
                rankIcon = const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 24,
                );
              } else if (isRank2) {
                rankIcon = const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFC0C0C0),
                  size: 24,
                );
              } else if (isRank3) {
                rankIcon = const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFCD7F32),
                  size: 24,
                ); // Bronze
              } else {
                rankIcon = Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                );
              }

              final pill = Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? scheme.primaryContainer.withValues(alpha: 0.3)
                      : isAbsolute
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: isCurrentUser
                      ? Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: rank <= 3
                              ? (rank == 1
                                  ? Colors.amber.withValues(alpha: 0.1)
                                  : rank == 2
                                      ? Colors.grey.withValues(alpha: 0.1)
                                      : Colors.brown.withValues(alpha: 0.1))
                              : scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: rankIcon),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                fontWeight: isCurrentUser
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 16,
                                color: isCurrentUser
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${attendance.toStringAsFixed(1)}% Attendance",
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            score.toStringAsFixed(0),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: scheme.primary,
                            ),
                          ),
                          Text(
                            "points",
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (shimmerColor != null) {
                return ShimmeringRankPill(
                  shimmerColor: shimmerColor,
                  duration: Duration(
                    milliseconds: isRank1 ? 3000 : 6000,
                  ),
                  child: pill,
                );
              }
              return pill;
            },
          ),
        );
      },
    );
  }

  Widget _buildWeeklyLeaderboardTab(
    BuildContext context,
    bool isAbsolute,
    ColorScheme scheme,
  ) {
    final currentWeekId = RankingUtils.getCurrentWeekId();
    // Calculate previous week ID
    final now = DateTime.now();
    final previousWeekDate = now.subtract(const Duration(days: 7));
    final previousWeekId = RankingUtils.getWeekId(previousWeekDate);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('weekly_leaderboards')
          .doc(previousWeekId)
          .snapshots(),
      builder: (context, officialSnapshot) {
        final officialDoc = officialSnapshot.data?.data() as Map<String, dynamic>?;
        final officialLeaderboard = (officialDoc?['leaderboard'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("weekly_rankings")
              .where("weekId", isEqualTo: currentWeekId)
              .snapshots(),
          builder: (context, previewSnapshot) {
            final liveRanks = <String, int>{};
            
            if (previewSnapshot.hasData) {
              final users = previewSnapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final subjects = (data['subjects'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                return {
                  'uid': data['uid'],
                  'score': RankingUtils.calculateRankingScore(subjects),
                };
              }).toList();

              users.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
              
              for (int i = 0; i < users.length; i++) {
                final uid = users[i]['uid'] as String?;
                if (uid != null) liveRanks[uid] = i + 1;
              }
            }

            return RefreshIndicator(
              onRefresh: _refreshLeaderboard,
              displacement: 20,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeeklyStatusHeader(scheme, previousWeekId, currentWeekId, officialLeaderboard.isNotEmpty),
                    
                    if (officialLeaderboard.isEmpty)
                      _buildNoDataState(scheme, previousWeekId)
                    else
                      _buildFixedLeaderboard(
                        context,
                        isAbsolute,
                        scheme,
                        leaderboard: officialLeaderboard,
                        liveRanks: liveRanks,
                      ),
                    
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyStatusHeader(ColorScheme scheme, String prevId, String currId, bool hasOfficial) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasOfficial ? scheme.secondaryContainer.withValues(alpha: 0.15) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (hasOfficial ? scheme.secondary : scheme.outline).withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(hasOfficial ? Icons.verified_user_rounded : Icons.history_toggle_off_rounded, 
                 color: hasOfficial ? scheme.secondary : scheme.onSurfaceVariant, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasOfficial ? "Week ${prevId.split('-W').last} Official Standings" : "No Past Rankings",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (hasOfficial)
                    Text(
                      "Arrows indicate predicted change for Next Week using live data.",
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(ColorScheme scheme, String weekId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              "No past ranking data found.",
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              "Standings finalize every Monday morning.",
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedLeaderboard(
    BuildContext context,
    bool isAbsolute,
    ColorScheme scheme, {
    required List<Map<String, dynamic>> leaderboard,
    required Map<String, int> liveRanks,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) {
        final data = leaderboard[index];
        final userUid = data['uid'] as String?;
        final username = data['username'] as String? ?? 'Anonymous';
        final score = (data['rankingScore'] as num?)?.toDouble() ?? 0.0;
        final attendance = (data['attendancePercent'] as num?)?.toDouble() ?? 0.0;
        final officialRank = data['rank'] as int? ?? (index + 1);
        final isCurrentUser = userUid == _uid;

        int? trend;
        if (userUid != null) {
          final liveRank = liveRanks[userUid];
          if (liveRank != null) {
            if (liveRank < officialRank) {
              trend = 1;
            } else if (liveRank > officialRank) trend = -1;
            else trend = 0;
          }
        }

        return _buildRankTile(
          context,
          isAbsolute,
          scheme,
          rank: officialRank,
          username: username,
          attendance: attendance,
          score: score,
          isCurrentUser: isCurrentUser,
          trend: trend,
        );
      },
    );
  }

  Widget _buildRankTile(
    BuildContext context,
    bool isAbsolute,
    ColorScheme scheme, {
    required int rank,
    required String username,
    required double attendance,
    required double score,
    required bool isCurrentUser,
    int? trend,
    bool isNew = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? scheme.primaryContainer.withValues(alpha: 0.3)
            : isAbsolute
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: isCurrentUser
            ? Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? (rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown[300])
                    : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isCurrentUser ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "NEW",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${attendance.toStringAsFixed(1)}% Attendance",
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (trend != null) ...[
                      Icon(
                        trend == 1
                            ? Icons.arrow_upward_rounded
                            : trend == -1
                                ? Icons.arrow_downward_rounded
                                : Icons.remove_rounded,
                        size: 14,
                        color: trend == 1 ? Colors.green : (trend == -1 ? Colors.red : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  "points",
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
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
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
