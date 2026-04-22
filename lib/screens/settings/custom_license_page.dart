import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class CustomLicensePage extends StatefulWidget {
  const CustomLicensePage({super.key});

  @override
  State<CustomLicensePage> createState() => _CustomLicensePageState();
}

class _CustomLicensePageState extends State<CustomLicensePage> {
  final List<LicenseEntry> _licenses = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    await for (final license in LicenseRegistry.licenses) {
      if (mounted) {
        setState(() {
          _licenses.add(license);
        });
      }
    }
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;

    final topGradientColor = isAbsolute ? scheme.surface : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;
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
                /// HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Back Button
                      Container(
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
                              : null,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
                              : null,
                        ),
                        child: Text(
                          "Licenses",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// MAIN PANEL
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                        bottom: Radius.circular(32),
                      ),
                      boxShadow: isAbsolute
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: !_loaded && _licenses.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _licenses.length,
                            itemBuilder: (context, index) {
                              final license = _licenses[index];
                              final packages = license.packages.join(", ");
                              final paragraphs = license.paragraphs;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isAbsolute
                                      ? scheme.surfaceContainerHigh
                                      : scheme.secondaryContainer.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ExpansionTile(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(24)),
                                  ),
                                  collapsedShape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(24)),
                                  ),
                                  title: Text(
                                    packages,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSecondaryContainer,
                                        ),
                                  ),
                                  iconColor: scheme.primary,
                                  collapsedIconColor: scheme.onSurfaceVariant,
                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.surface.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: paragraphs.map((p) {
                                          if (p.indent == LicenseParagraph.centeredIndent) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Center(
                                                child: Text(
                                                  p.text,
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ),
                                            );
                                          } else {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 8,
                                                left: p.indent * 8.0,
                                              ),
                                              child: Text(
                                                p.text,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            );
                                          }
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
