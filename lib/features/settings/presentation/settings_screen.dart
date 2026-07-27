import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/providers/auth_provider.dart';

/// Settings screen — monochromatic glassmorphism.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final googleUser = googleUserAsync.value;
    final libraryState = ref.watch(syncedLibraryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
            title: Text(
              'Settings',
              style: context.textStyles.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            toolbarHeight: 72,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(UIConstants.spaceLG),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (googleUser != null)
                  _GlassSection(
                    title: 'ACCOUNT',
                    delay: 0,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(UIConstants.spaceLG),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with a glowing ring
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: googleUser.photoUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: googleUser.photoUrl!,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 52,
                                              height: 52,
                                              color: AppColorSchemes.surface2,
                                              child: const Icon(Icons.person_rounded, color: Colors.white30),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: 52,
                                              height: 52,
                                              color: AppColorSchemes.surface2,
                                              child: const Icon(Icons.person_rounded, color: Colors.white30),
                                            ),
                                          )
                                        : Container(
                                            width: 52,
                                            height: 52,
                                            color: AppColorSchemes.surface2,
                                            child: const Icon(Icons.person_rounded, color: Colors.white30),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        googleUser.displayName ?? 'Google Account',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        googleUser.email,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.4),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Connected badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Connected',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Stats Summary
                            Container(
                              padding: const EdgeInsets.all(UIConstants.spaceMD),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(UIConstants.radiusLG),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.playlist_play_rounded,
                                    count: libraryState.playlists.length,
                                    label: 'Playlists',
                                  ),
                                  Container(
                                    height: 24,
                                    width: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  _buildStatItem(
                                    icon: Icons.favorite_border_rounded,
                                    count: libraryState.likedSongs.length,
                                    label: 'Liked Songs',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Action buttons (Sync and Sign Out)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: libraryState.isLoading
                                        ? null
                                        : () async {
                                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                                            try {
                                              await ref.read(syncedLibraryProvider.notifier).syncAll();
                                              scaffoldMessenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text('YouTube Music library synced!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Sync failed: $e'),
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                              );
                                            }
                                          },
                                    icon: libraryState.isLoading
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white70,
                                            ),
                                          )
                                        : const Icon(Icons.sync_rounded, size: 16),
                                    label: Text(
                                      libraryState.isLoading ? 'Syncing...' : 'Sync Now',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    // Confirm Sign Out dialog
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: AppColorSchemes.bgMid,
                                        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                                        content: const Text(
                                          'Are you sure you want to sign out? This will disconnect your Google account and clear cached tracks.',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(googleAuthServiceProvider).signOut();
                                      ref.read(syncedLibraryProvider.notifier).clearCache();
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: BorderSide(
                                      color: Colors.redAccent.withValues(alpha: 0.25),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: UIConstants.spaceLG),

                _GlassSection(
                  title: 'PLAYBACK',
                  delay: 1,
                  children: [
                    _SettingsTile(
                      icon: Icons.high_quality_rounded,
                      title: 'Audio Quality',
                      subtitle: 'High',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConstants.spaceLG),

                _GlassSection(
                  title: 'ABOUT',
                  delay: 2,
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Version',
                      subtitle: '0.1.0',
                    ),
                    _SectionDivider(),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: 'Open Source Licenses',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConstants.spaceXXXL),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

/// Glass-wrapped section container.
class _GlassSection extends StatelessWidget {
  final String title;
  final int delay;
  final List<Widget> children;

  const _GlassSection({
    required this.title,
    required this.delay,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
        GlassContainer(
          borderRadius: UIConstants.radiusXXL,
          blurSigma: 14,
          fillColor: Colors.white.withValues(alpha: 0.05),
          borderColor: Colors.white.withValues(alpha: 0.08),
          showHighlight: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ],
    ).animate().fadeIn(duration: 320.ms, delay: (delay * 90).ms);
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spaceLG,
        vertical: 13,
      ),
      child: Row(
        children: [
          // Icon badge — dark charcoal rounded square
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColorSchemes.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: Colors.white),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

