import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/local_library_provider.dart';
import 'local_playlist_dialogs.dart';

final _libraryTabProvider = StateProvider<String>((ref) => 'local');

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final googleUser = googleUserAsync.value;
    final libraryState = ref.watch(syncedLibraryProvider);
    final localLibrary = ref.watch(localLibraryProvider);
    final activeTab = ref.watch(_libraryTabProvider);

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
              'Your Library',
              style: context.textStyles.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            toolbarHeight: 72,
            actions: [
              if (googleUser != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: googleUser.photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: googleUser.photoUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                                ),
                                errorWidget: (_, __, ___) => const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                                ),
                              )
                            : const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                              ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
            ],
          ),

          // Tab Switcher removed

          if (activeTab == 'local') ...[
            // Welcome Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: const Text(
                  'My Music Library',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ).animate().fadeIn(duration: 350.ms),
            ),

            // Favorites Tile
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildLocalFavoritesTile(context, localLibrary.favorites.length),
              ),
            ),

            // Downloads Tile
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildLocalDownloadsTile(context, localLibrary.downloads.length),
              ),
            ),

            // Playlists Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playlists',
                      style: context.textStyles.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: () {
                        showCreatePlaylistDialog(context, ref, null);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Playlists List
            if (localLibrary.playlists.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.playlist_add_rounded, color: Colors.white24, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No local playlists yet.',
                          style: TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => showCreatePlaylistDialog(context, ref, null),
                          child: const Text('Create a Playlist', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlistsList = localLibrary.playlists.values.toList();
                      final playlist = playlistsList[index];
                      final artworkUrl = playlist.tracks.isNotEmpty ? playlist.tracks.first.artworkUrl : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            context.push('/local-playlist/${playlist.id}');
                          },
                          child: GlassContainer(
                            borderRadius: UIConstants.radiusXL,
                            blurSigma: 10,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            borderColor: Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: artworkUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: artworkUrl,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                                            errorWidget: (_, __, ___) => Container(
                                              color: AppColorSchemes.surface2,
                                              child: const Icon(Icons.playlist_play_rounded, color: Colors.white30),
                                            ),
                                          )
                                        : Container(
                                            color: AppColorSchemes.surface2,
                                            child: const Icon(Icons.playlist_play_rounded, color: Colors.white30),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.name,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${playlist.tracks.length} tracks',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.25),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 250.ms, delay: (index * 45).ms);
                    },
                    childCount: localLibrary.playlists.length,
                  ),
                ),
              ),
          ] else ...[
            // Synced YT Music Section
            if (googleUser == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassContainer(
                          borderRadius: UIConstants.radiusXXL,
                          blurSigma: 16,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          borderColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Sync YouTube Music',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Connect your Google Account to import all your personal playlists and liked songs from YouTube Music.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Colors.white54,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              GoogleSignInButton(
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  try {
                                    await ref.read(googleAuthServiceProvider).signIn();
                                  } catch (e) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Sign-In failed: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Welcome Header Greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        googleUser.displayName ?? 'Google User',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.05, duration: 350.ms),
              ),

              // Liked Songs Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildLikedSongsTile(context, libraryState.likedSongs.length),
                ),
              ),

              // Playlists Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Playlists',
                        style: context.textStyles.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (libraryState.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                    ],
                  ),
                ),
              ),

              // Playlist Grid/List
              if (libraryState.playlists.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.playlist_play_rounded, color: Colors.white24, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'No playlists synchronized yet.',
                            style: TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.push('/settings'),
                            child: const Text('Go to Settings to Sync', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = libraryState.playlists[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              context.push(
                                '/synced-playlist',
                                extra: {
                                  'playlistId': playlist.id,
                                  'playlistTitle': playlist.title,
                                  'artworkUrl': playlist.artworkUrl,
                                },
                              );
                            },
                            child: GlassContainer(
                              borderRadius: UIConstants.radiusXL,
                              blurSigma: 10,
                              fillColor: Colors.white.withValues(alpha: 0.04),
                              borderColor: Colors.white.withValues(alpha: 0.08),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: playlist.artworkUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: playlist.artworkUrl!,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                                              errorWidget: (_, __, ___) => Container(
                                                color: AppColorSchemes.surface2,
                                                child: const Icon(Icons.playlist_play_rounded, color: Colors.white30),
                                              ),
                                            )
                                          : Container(
                                              color: AppColorSchemes.surface2,
                                              child: const Icon(Icons.playlist_play_rounded, color: Colors.white30),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.title,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${playlist.trackCount ?? 0} tracks',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: libraryState.playlists.length,
                    ),
                  ),
                ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }



  Widget _buildLocalFavoritesTile(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        context.push('/local-playlist/favorites');
      },
      child: GlassContainer(
        borderRadius: UIConstants.radiusXXL,
        blurSigma: 12,
        fillColor: Colors.white.withValues(alpha: 0.05),
        borderColor: Colors.white.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local Favorites',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count songs saved',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildLocalDownloadsTile(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        context.push('/local-playlist/downloads');
      },
      child: GlassContainer(
        borderRadius: UIConstants.radiusXXL,
        blurSigma: 12,
        fillColor: Colors.white.withValues(alpha: 0.05),
        borderColor: Colors.white.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Downloads',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count songs downloaded',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildLikedSongsTile(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/synced-playlist',
          extra: {
            'playlistId': 'LL',
            'playlistTitle': 'Liked Songs',
          },
        );
      },
      child: GlassContainer(
        borderRadius: UIConstants.radiusXXL,
        blurSigma: 12,
        fillColor: Colors.white.withValues(alpha: 0.05),
        borderColor: Colors.white.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liked Songs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count songs synced',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}
