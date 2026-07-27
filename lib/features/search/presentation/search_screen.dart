import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/theme/color_schemes.dart';

import '../../youtube/data/models/youtube_track.dart';
import '../../youtube/providers/youtube_providers.dart';
import '../../player/providers/player_provider.dart';
import '../../library/presentation/local_playlist_dialogs.dart';
import '../../library/providers/local_library_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;
    final resultsAsync = ref.watch(searchResultsProvider);

    // Sync Text Controller from provider query
    if (_searchController.text != query) {
      _searchController.text = query;
    }

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
              'Search',
              style: context.textStyles.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            toolbarHeight: 72,
          ),

          // Glass search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UIConstants.spaceLG,
              ),
              child: _buildSearchBar(context, isSearching),
            ),
          ),

          // Content area
          SliverPadding(
            padding: const EdgeInsets.all(UIConstants.spaceLG),
            sliver:
                isSearching
                    ? _buildSearchResults(context, resultsAsync)
                    : _buildBrowseCategories(context),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: UIConstants.spaceXXXL),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isSearching) {
    return GlassContainer(
      borderRadius: UIConstants.radiusXL,
      blurSigma: 14,
      fillColor: Colors.white.withValues(alpha: 0.06),
      borderColor: Colors.white.withValues(alpha: 0.12),
      showHighlight: false,
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
          style: context.textStyles.bodyLarge?.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search for any song or artist',
            hintStyle: context.textStyles.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            suffixIcon:
                isSearching
                    ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                        _focusNode.unfocus();
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: UIConstants.spaceMD,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSearchResults(
    BuildContext context,
    AsyncValue<List<YoutubeTrack>> resultsAsync,
  ) {
    return resultsAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  'No results found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _SearchResultTrackItem(track: tracks[index]),
            childCount: tracks.length,
          ),
        );
      },
      loading:
          () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      error:
          (e, _) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  'Error: $e',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildBrowseCategories(BuildContext context) {
    const categories = [
      ('Telugu', 0xFF1E1E1E),
      ('Hindi', 0xFF1A1A1A),
      ('Tamil', 0xFF222222),
      ('Pop', 0xFF181818),
      ('Electronic', 0xFF1C1C1C),
      ('Classical', 0xFF202020),
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: UIConstants.spaceLG),
          Text(
            'Browse All',
            style: context.textStyles.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: UIConstants.spaceLG),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.isWideScreen ? 3 : 2,
              crossAxisSpacing: UIConstants.spaceMD,
              mainAxisSpacing: UIConstants.spaceMD,
              childAspectRatio: 1.8,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final (name, colorHex) = categories[index];
              return _GlassCategoryCard(
                name: name,
                surfaceColor: Color(colorHex),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassCategoryCard extends ConsumerWidget {
  final String name;
  final Color surfaceColor;

  const _GlassCategoryCard({
    required this.name,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(searchQueryProvider.notifier).state = name;
      },
      child: GlassContainer(
        borderRadius: UIConstants.radiusLG,
        fillColor: surfaceColor.withValues(alpha: 0.3),
        borderColor: Colors.white.withValues(alpha: 0.1),
        blurSigma: 12,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(UIConstants.spaceMD),
              child: Text(
                name,
                style: context.textStyles.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTrackItem extends ConsumerWidget {
  final YoutubeTrack track;

  const _SearchResultTrackItem({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final isCurrent = currentTrack?.id == track.id;

    return GestureDetector(
      onTap: () {
        final handler = ref.read(playerHandlerProvider);
        if (isCurrent) {
          if (isPlaying) {
            handler.pause();
          } else {
            handler.play();
          }
        } else {
          handler.playTrack(track);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isCurrent
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                )
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: track.artworkUrl != null
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        placeholder: (context, url) => Container(
                          color: AppColorSchemes.surface2,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white30,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColorSchemes.surface2,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white24,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColorSchemes.surface2,
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white24,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(
                      color: isCurrent ? Colors.white : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(
                      color: isCurrent ? Colors.white.withValues(alpha: 0.8) : Colors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrent)
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final handler = ref.read(playerHandlerProvider);
                      if (isPlaying) {
                        handler.pause();
                      } else {
                        handler.play();
                      }
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                  color: AppColorSchemes.bgMid,
                  onSelected: (value) async {
                    if (value == 'favorite') {
                      ref.read(localLibraryProvider.notifier).toggleFavorite(track);
                    } else if (value == 'playlist') {
                      showAddToPlaylistSheet(context, ref, track);
                    } else if (value == 'download') {
                      final notifier = ref.read(localLibraryProvider.notifier);
                      final isDownloaded = notifier.isDownloaded(track.id);
                      if (isDownloaded) {
                        await notifier.removeDownload(track.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Song removed from downloads')),
                        );
                      } else {
                        await notifier.addDownload(track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Song downloaded successfully!')),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) {
                    final isFav = ref.read(localLibraryProvider.notifier).isFavorite(track.id);
                    final isDown = ref.read(localLibraryProvider.notifier).isDownloaded(track.id);
                    return [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.redAccent : Colors.white70),
                            const SizedBox(width: 12),
                            Text(isFav ? 'Remove Favorite' : 'Add to Favorites', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'playlist',
                        child: Row(
                          children: const [
                            Icon(Icons.playlist_add_rounded, color: Colors.white70),
                            const SizedBox(width: 12),
                            Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(isDown ? Icons.download_done_rounded : Icons.download_rounded, color: isDown ? Colors.green : Colors.white70),
                            const SizedBox(width: 12),
                            Text(isDown ? 'Remove Download' : 'Download Song', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
