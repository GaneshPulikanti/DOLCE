import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/player/data/services/audio_player_handler.dart';
import 'features/player/providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('synced_library');
  await Hive.openBox('user_profile');
  await Hive.openBox('offline_audio_data');

  // Initialize the background audio service
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ganesh.musicplayer.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );

  // Configure audio session for music playback (required for Android audio routing)
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Lock to portrait on mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI — dark mono theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF050505),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: App()));
}
