import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_models.dart';
import 'navigation/app_routes.dart';
import 'screens/battle_loading_screen.dart';
import 'screens/gaming_loading_screen.dart';
import 'screens/gameplay_hud_screen.dart';
import 'screens/hangar_screen.dart';
import 'screens/hangar_upgrade_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/victory_modal_screen.dart';
import 'state/game_controller.dart';
import 'theme/avionics_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final controller = GameController();
  unawaited(controller.initialize());
  runApp(SkyStrikeApp(controller: controller));
}

/// Root Sky Strike application coordinating SQLite state and 4-screen avionics flow.
class SkyStrikeApp extends StatefulWidget {
  const SkyStrikeApp({
    super.key,
    this.controller,
    this.skipLoading = false,
  });

  final GameController? controller;
  final bool skipLoading;

  @override
  State<SkyStrikeApp> createState() => _SkyStrikeAppState();
}

class _SkyStrikeAppState extends State<SkyStrikeApp> {
  late final GameController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? (GameController()..initialize());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.battleLoading:
        final args = settings.arguments as GameplayRouteArgs?;
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          pageBuilder: (_, _, _) => BattleLoadingScreen(
            controller: _controller,
            stageNumber: args?.stageNumber ?? _controller.profile.currentStage,
          ),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      case AppRoutes.gameplay:
        final args = settings.arguments as GameplayRouteArgs?;
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => GameplayHudScreen(
            controller: _controller,
            stageNumber: args?.stageNumber ?? _controller.profile.currentStage,
          ),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      case AppRoutes.victory:
        final args = settings.arguments as VictoryRouteArgs?;
        final summary = args?.summary ??
            MissionSummary(
              stageNumber: _controller.profile.currentStage,
              operationName:
                  GameSeedData.operationNameForStage(_controller.profile.currentStage),
              score: _controller.profile.highScore,
              elapsedSeconds: 164.18,
              accuracy: 94.6,
              bossDestroyed: true,
              enemiesShotDown: 14,
              creditsEarned: 450,
              scrapEarned: 50,
              xpEarned: 1250,
              previousLevel: _controller.profile.rankLevel,
              newLevel: _controller.profile.rankLevel + 1,
              xpProgress: 0.85,
              rankGrade: 'S-RANK ACE',
            );
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => VictoryModalScreen(
            controller: _controller,
            summary: summary,
          ),
        );
      case AppRoutes.upgrades:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => HangarUpgradeScreen(controller: _controller),
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SettingsScreen(controller: _controller),
        );
      case AppRoutes.loading:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => GamingLoadingScreen(controller: _controller),
        );
      case AppRoutes.hangar:
      default:
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => HangarScreen(controller: _controller),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const envStart = String.fromEnvironment('START_ROUTE');
    final startRoute = envStart.isNotEmpty
        ? envStart
        : (widget.skipLoading ? AppRoutes.hangar : AppRoutes.loading);
    return MaterialApp(
      title: 'Sky Strike // Avionics HUD',
      debugShowCheckedModeBanner: false,
      theme: AvionicsTheme.darkTheme,
      initialRoute: startRoute,
      onGenerateInitialRoutes: (String initialRouteName) => <Route<dynamic>>[
        _onGenerateRoute(RouteSettings(name: initialRouteName)),
      ],
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
