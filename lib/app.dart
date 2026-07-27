import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/player/providers/player_provider.dart';
import 'features/auth/providers/auth_provider.dart';

/// Root application widget.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Restore Google Sign-In session silently on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleAuthServiceProvider).signInSilently();
    });

    // Listen to current track changes to update recently played history
    ref.listen(currentTrackProvider, (previous, next) {
      final track = next.value;
      if (track != null) {
        ref.read(recentlyPlayedProvider.notifier).addTrack(track);
      }
    });

    final router = createAppRouter(ref);

    return MaterialApp.router(
      title: 'DOLCE',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Router
      routerConfig: router,
    );
  }
}
