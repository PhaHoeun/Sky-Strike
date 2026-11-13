import '../models/game_models.dart';

/// Centralized route names for the Sky Strike avionics flow.
abstract final class AppRoutes {
  static const String loading = '/loading';
  static const String battleLoading = '/battle-loading';
  static const String hangar = '/';
  static const String gameplay = '/gameplay';
  static const String victory = '/victory';
  static const String upgrades = '/upgrades';
  static const String settings = '/settings';
}

/// Arguments passed when launching [GameplayHudScreen].
class GameplayRouteArgs {
  const GameplayRouteArgs({required this.stageNumber});

  final int stageNumber;
}

/// Arguments passed when displaying [VictoryModalScreen].
class VictoryRouteArgs {
  const VictoryRouteArgs({required this.summary});

  final MissionSummary summary;
}

