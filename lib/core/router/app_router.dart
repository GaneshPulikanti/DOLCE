import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/library/presentation/synced_playlist_screen.dart';
import '../../features/library/presentation/local_playlist_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/youtube/presentation/artist_screen.dart';
import '../../features/youtube/presentation/album_screen.dart';
import '../../features/youtube/presentation/playlist_screen.dart';
import '../widgets/scenic_background.dart';
import '../theme/color_schemes.dart';
import 'route_names.dart';

import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/providers/personalization_provider.dart';
import '../../features/auth/data/models/user_preference_profile.dart';

class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterTransitionNotifier(this._ref) {
    _ref.listen<UserPreferenceProfile?>(userPreferenceProfileProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerTransitionNotifierProvider = Provider<RouterTransitionNotifier>((ref) {
  return RouterTransitionNotifier(ref);
});

/// App-wide router configuration.
GoRouter createAppRouter(WidgetRef ref) {
  final notifier = ref.watch(routerTransitionNotifierProvider);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final profile = ref.read(userPreferenceProfileProvider);
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (profile == null && !isOnboarding) {
        return '/onboarding';
      }
      if (profile != null && isOnboarding) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => const NoTransitionPage(child: OnboardingScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            pageBuilder:
                (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            name: RouteNames.search,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/library',
            name: RouteNames.library,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: LibraryScreen()),
          ),
          GoRoute(
            path: '/local-playlist/:id',
            name: 'localPlaylist',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return MaterialPage(
                key: ValueKey('local_playlist_${id}_${DateTime.now().microsecondsSinceEpoch}'),
                child: LocalPlaylistScreen(playlistId: id),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: RouteNames.settings,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/artist/:id',
            name: RouteNames.artist,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return MaterialPage(
                key: ValueKey('artist_${id}_${DateTime.now().microsecondsSinceEpoch}'),
                child: ArtistScreen(artistId: id),
              );
            },
          ),
          GoRoute(
            path: '/album/:id',
            name: RouteNames.album,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return MaterialPage(
                key: ValueKey('album_${id}_${DateTime.now().microsecondsSinceEpoch}'),
                child: AlbumScreen(albumId: id),
              );
            },
          ),
          GoRoute(
            path: '/playlist/:id',
            name: RouteNames.playlist,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return MaterialPage(
                key: ValueKey('playlist_${id}_${DateTime.now().microsecondsSinceEpoch}'),
                child: PlaylistScreen(playlistId: id),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: RouteNames.fullPlayer,
        pageBuilder: (context, state) => const MaterialPage(
          child: PlayerScreen(),
          fullscreenDialog: true,
        ),
      ),
      GoRoute(
        path: '/synced-playlist',
        name: 'syncedPlaylist',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          final playlistId = args['playlistId'] as String;
          final playlistTitle = args['playlistTitle'] as String;
          final artworkUrl = args['artworkUrl'] as String?;
          return MaterialPage(
            child: SyncedPlaylistScreen(
              playlistId: playlistId,
              playlistTitle: playlistTitle,
              artworkUrl: artworkUrl,
            ),
            fullscreenDialog: true,
          );
        },
      ),
    ],
  );
}

/// Root shell: dark mono background, glass drawer, frosted bottom nav.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _tabs = ['/home', '/search', '/library'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _tabs.indexWhere((t) => location.startsWith(t));
    if (index >= 0) {
      _currentIndex = index;
    }

    return ScenicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const _GlassDrawer(),
        body: widget.child,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayerPlaceholder(),
            const SizedBox(height: 14), // Elegant vertical clearance for the rolling active nav bubble
            _FrostedBottomNav(
              currentIndex: _currentIndex,
              onTap: (i) {
                if (i != _currentIndex) context.go(_tabs[i]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted bottom navigation bar — mono glass style
// ─────────────────────────────────────────────────────────────────────────────

class _FrostedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _FrostedBottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_FrostedBottomNav> createState() => _FrostedBottomNavState();
}

class _FrostedBottomNavState extends State<_FrostedBottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(
      begin: _getPercent(_lastIndex),
      end: _getPercent(widget.currentIndex),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.value = 1.0;
  }

  double _getPercent(int index) {
    // 3 tabs: Home (0), Search (1), Library (2)
    return 0.1666667 + index * 0.3333333;
  }

  @override
  void didUpdateWidget(covariant _FrostedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _lastIndex = oldWidget.currentIndex;
      _animation = Tween<double>(
        begin: _getPercent(_lastIndex),
        end: _getPercent(widget.currentIndex),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.library_music_rounded,
    ];

    return Container(
      margin: EdgeInsets.only(bottom: bottomPad + 8, left: 16, right: 16),
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Curved Liquid Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: CurvedNavigationBarPainter(
                    loc: _animation.value,
                    color: const Color(0xFF141416), // Solid deep charcoal/black like the image
                  ),
                );
              },
            ),
          ),

          // ── Sliding Bubble (Circle) ──
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final stackWidth = MediaQuery.of(context).size.width - 32;
              // Compute rotation angle so it rolls perfectly:
              // Phase offset of -0.1666667 makes rotation exactly 0 at index 0.
              // Multiplying by 6 * pi gives exactly 1 full rotation (360 deg) per tab transition.
              final rotationAngle = (_animation.value - 0.1666667) * 6 * 3.141592653589793;

              return Positioned(
                bottom: 26, // Positioned so the top elevates above the bar and fits the U-scoop
                left: (_animation.value * stackWidth) - 26,
                child: Transform.rotate(
                  angle: rotationAngle,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14), // Frosted glass translucency
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), // Elegant white glass highlight edge
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.12), // Premium soft white glow
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Center(
                          child: Icon(
                            icons[widget.currentIndex],
                            color: Colors.white, // Crisp white active icon to match glass theme
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Bottom Icons Row ──
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (index) {
                final isSelected = index == widget.currentIndex;
                return GestureDetector(
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 72,
                    height: 64,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: isSelected ? 0.0 : 0.65, // Hide under sliding active bubble
                        child: Icon(
                          icons[index],
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter for Curved Liquid Convex Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class CurvedNavigationBarPainter extends CustomPainter {
  final double loc; // 0.0 to 1.0 representing horizontal position percentage
  final Color color;

  CurvedNavigationBarPainter({required this.loc, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // The center point of the U-dip
    final cX = loc * width;

    // Dip dimensions matching the reference image's deep scoop
    final dipWidth = 84.0;
    final dipHeight = 28.0;
    final radius = 28.0; // Perfect rounded capsule corner

    // Top-left corner
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    // Move to the start of the dip
    final dipStart = cX - dipWidth / 2;
    final dipEnd = cX + dipWidth / 2;

    path.lineTo(dipStart - 10, 0);

    // Deep smooth Bezier dip curve matching the reference image
    path.cubicTo(
      dipStart - 2, 0,
      dipStart + 6, dipHeight,
      cX, dipHeight,
    );
    path.cubicTo(
      dipEnd - 6, dipHeight,
      dipEnd + 2, 0,
      dipEnd + 10, 0,
    );

    // Top-right corner
    path.lineTo(width - radius, 0);
    path.quadraticBezierTo(width, 0, width, 0);

    // Capsule border curves
    path.lineTo(width, height - radius);
    path.quadraticBezierTo(width, height, width - radius, height);
    path.lineTo(radius, height);
    path.quadraticBezierTo(0, height, 0, height - radius);
    path.close();

    // Draw elegant shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.6), 14, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CurvedNavigationBarPainter oldDelegate) {
    return oldDelegate.loc != loc || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass drawer — mono edition
// ─────────────────────────────────────────────────────────────────────────────

class _GlassDrawer extends StatefulWidget {
  const _GlassDrawer();

  @override
  State<_GlassDrawer> createState() => _GlassDrawerState();
}

class _GlassDrawerState extends State<_GlassDrawer> {
  bool _isLibraryExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.72,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              // Deep charcoal glass panel
              color: AppColorSchemes.bgMid.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(24),
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.8,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Close button row ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                    indent: 20,
                    endIndent: 20,
                  ),
                  const SizedBox(height: 8),

                  // ── Nav items ─────────────────────────────────────────
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/home');
                    },
                    delay: 0,
                  ),
                  _DrawerItem(
                    icon: Icons.library_music_rounded,
                    label: 'Library',
                    onTap: () {
                      setState(() {
                        _isLibraryExpanded = !_isLibraryExpanded;
                      });
                    },
                    delay: 2,
                    isExpandable: true,
                    isExpanded: _isLibraryExpanded,
                  ),
                  if (_isLibraryExpanded) ...[
                    _DrawerSubItem(
                      label: 'Favourites',
                      delay: 3,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/local-playlist/favorites');
                      },
                    ),
                    _DrawerSubItem(
                      label: 'Downloads',
                      delay: 4,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/local-playlist/downloads');
                      },
                    ),
                    _DrawerSubItem(
                      label: 'Playlists',
                      delay: 5,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/library');
                      },
                    ),
                    _DrawerSubItem(
                      label: 'All history',
                      delay: 6,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/library');
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings');
                    },
                    delay: 8,
                  ),

                  const Spacer(),

                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                    indent: 20,
                    endIndent: 20,
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    onTap: () => Navigator.pop(context),
                    delay: 9,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int delay;
  final bool isExpandable;
  final bool isExpanded;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.delay,
    this.isExpandable = false,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (isExpandable)
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms, delay: (delay * 35).ms);
  }
}

class _DrawerSubItem extends StatelessWidget {
  final String label;
  final int delay;
  final bool hasArrow;
  final VoidCallback? onTap;

  const _DrawerSubItem({
    required this.label,
    required this.delay,
    this.hasArrow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 54, right: 20, top: 8, bottom: 8),
        child: Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            if (hasArrow)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 16,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms, delay: (delay * 35).ms);
  }
}
