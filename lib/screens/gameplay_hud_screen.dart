import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/battle_audio.dart';
import '../game/dogfight_engine.dart';
import '../game/dogfight_painter.dart';
import '../game/dogfight_sprites.dart';
import '../models/game_models.dart';
import '../navigation/app_routes.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/hud_widgets.dart';

/// Screen 2: Playable real-time auto-fighting & manual 2.5D aerial dogfight arena
/// with continuous in-screen Easy -> Hard level progression.
class GameplayHudScreen extends StatefulWidget {
  const GameplayHudScreen({
    super.key,
    required this.controller,
    required this.stageNumber,
  });

  final GameController controller;
  final int stageNumber;

  @override
  State<GameplayHudScreen> createState() => _GameplayHudScreenState();
}

class _GameplayHudScreenState extends State<GameplayHudScreen>
    with SingleTickerProviderStateMixin {
  late DogfightEngine _engine;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Timer? _toastTimer;

  Offset _yokeOffset = Offset.zero;
  bool _showingDefeatDialog = false;
  StageClearReport? _toastStageReport;
  MissionSummary? _lastClearedSummary;
  final Set<int> _sessionClearedStages = {};

  @override
  void initState() {
    super.initState();
    for (final rec in widget.controller.history) {
      _sessionClearedStages.add(rec.stageNumber);
    }
    _initEngine();
    DogfightSpriteAtlas.instance.ensureCustomJetLoaded(widget.controller.selectedJet);
    BattleAudio.instance.setMuted(widget.controller.soundMuted);
    BattleAudio.instance.startBattleAmbience();
    _ticker = createTicker(_onTick)..start();
  }

  void _initEngine() {
    final jet = widget.controller.selectedJet;
    _engine = DogfightEngine(
      jet: jet,
      upgrades: widget.controller.upgradesFor(jet.id),
      stageNumber: widget.stageNumber,
      autoFire: true,
    )..addListener(_onEngineStateChanged);
  }

  void _onTick(Duration elapsed) {
    final dt = (_lastElapsed == Duration.zero)
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _engine.update(dt);
    BattleAudio.instance.updateBattleAmbience(
      paused: _engine.paused || _engine.defeatTriggered,
      overdrive: _engine.overdriveActive,
    );
  }

  void _onEngineStateChanged() {
    final clearReport = _engine.takePendingStageClear();
    if (clearReport != null) {
      _recordStageClearInBackground(clearReport);
    }
    if (_engine.defeatTriggered && !_showingDefeatDialog) {
      _showingDefeatDialog = true;
      _engine.paused = true;
      BattleAudio.instance.updateBattleAmbience(paused: true, overdrive: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDefeatModal();
      });
    }
  }

  @override
  void dispose() {
    BattleAudio.instance.stopBattleAmbience();
    _toastTimer?.cancel();
    _ticker.dispose();
    _engine.removeListener(_onEngineStateChanged);
    _engine.dispose();
    super.dispose();
  }

  Future<void> _recordStageClearInBackground(StageClearReport report) async {
    _toastTimer?.cancel();
    setState(() {
      _sessionClearedStages.add(report.stageNumber);
      _toastStageReport = report;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _toastStageReport = null);
      }
    });

    final summary = await widget.controller.completeMission(
      stageNumber: report.stageNumber,
      score: math.max(12500, report.stageScore),
      enemiesShotDown: report.stageEnemiesShotDown,
      bossDestroyed: true,
      creditsEarned: report.levelSpec.creditsReward,
      scrapEarned: report.levelSpec.scrapReward,
      xpEarned: report.levelSpec.xpReward,
      accuracy: report.stageAccuracyPercent,
      elapsedSeconds: math.max(8.5, report.stageElapsedSeconds),
    );
    if (!mounted) return;
    setState(() {
      _lastClearedSummary = summary;
    });
  }

  void _advanceToStageInPlace(int targetStage, {bool resetFullState = false}) {
    _toastTimer?.cancel();
    setState(() {
      _showingDefeatDialog = false;
      _toastStageReport = null;
      _yokeOffset = Offset.zero;
    });
    _engine.advanceToStage(targetStage, resetFullState: resetFullState);
  }

  Future<void> _openFullDebrief() async {
    final summary = _lastClearedSummary;
    if (summary == null || !mounted) return;
    await Navigator.of(context).pushReplacementNamed(
      AppRoutes.victory,
      arguments: VictoryRouteArgs(summary: summary),
    );
  }

  Future<void> _showDefeatModal() async {
    final spec = _engine.levelSpec;
    final stageStr = spec.stageNumber.toString().padLeft(2, '0');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: HudBracketCard(
              accentColor: AvionicsColors.crimson,
            backgroundColor: AvionicsColors.surfaceContainer.withValues(alpha: 0.96),
            padding: const EdgeInsets.all(16),
            bracketSize: 10,
            blurSigma: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AvionicsColors.crimson.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AvionicsColors.crimson.withValues(alpha: 0.7),
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: AvionicsColors.crimson,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MAYDAY // SHOT DOWN',
                            style: AvionicsText.headline(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AvionicsColors.crimson,
                            ),
                          ),
                          Text(
                            'STAGE $stageStr (${spec.shortLabel}) • AIRFRAME LOST',
                            style: AvionicsText.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AvionicsColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AvionicsColors.surfaceLow,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AvionicsColors.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ModalStatLine(
                        label: 'HULL INTEGRITY',
                        value: '0% CRITICAL',
                        valueColor: AvionicsColors.crimson,
                      ),
                      const Divider(height: 10),
                      _ModalStatLine(
                        label: 'ENEMY HITS TAKEN',
                        value: '${_engine.enemyHitsTaken} IMPACTS',
                        valueColor: AvionicsColors.orange,
                      ),
                      const Divider(height: 10),
                      _ModalStatLine(
                        label: 'CAMPAIGN SCORE',
                        value: '${formatTelemetryInt(_engine.score)} PTS',
                        valueColor: AvionicsColors.cyan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ModalActionButton(
                  key: const Key('defeat_retry_button'),
                  icon: Icons.replay_rounded,
                  label: 'RETRY STAGE $stageStr',
                  accent: AvionicsColors.orange,
                  filled: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _advanceToStageInPlace(spec.stageNumber, resetFullState: true);
                  },
                ),
                const SizedBox(height: 8),
                _ModalActionButton(
                  key: const Key('defeat_return_home_button'),
                  icon: Icons.home_rounded,
                  label: 'RETURN TO HOME',
                  accent: AvionicsColors.cyan,
                  filled: false,
                  onTap: () {
                    BattleAudio.instance.stopBattleAmbience();
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
                if (spec.stageNumber > 1) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _advanceToStageInPlace(1, resetFullState: true);
                    },
                    child: Text(
                      'DROP TO STAGE 01 (EASY)',
                      style: AvionicsText.mono(
                        fontSize: 9.5,
                        color: AvionicsColors.emeraldBright,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }

  Future<void> _openPauseDialog() async {
    _engine.paused = true;
    BattleAudio.instance.updateBattleAmbience(
      paused: true,
      overdrive: _engine.overdriveActive,
    );
    final spec = _engine.levelSpec;
    final stageStr = spec.stageNumber.toString().padLeft(2, '0');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: HudBracketCard(
            accentColor: AvionicsColors.cyan,
            backgroundColor: AvionicsColors.surfaceContainer.withValues(alpha: 0.96),
            padding: const EdgeInsets.all(16),
            bracketSize: 10,
            blurSigma: 8,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (_, _) {
                final muted = widget.controller.soundMuted;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AvionicsColors.cyan.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AvionicsColors.cyan.withValues(alpha: 0.7),
                            ),
                          ),
                          child: const Icon(
                            Icons.pause_rounded,
                            size: 20,
                            color: AvionicsColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GAME PAUSED',
                                style: AvionicsText.headline(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AvionicsColors.cyan,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'STAGE $stageStr (${spec.shortLabel}) • ${widget.controller.selectedJet.callsign}',
                                style: AvionicsText.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AvionicsColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AvionicsColors.surfaceLow,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AvionicsColors.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          _ModalStatLine(
                            label: 'CURRENT SCORE',
                            value: formatTelemetryInt(_engine.score),
                            valueColor: AvionicsColors.gold,
                          ),
                          const Divider(height: 10),
                          _ModalStatLine(
                            label: 'HULL / SHIELD',
                            value: '${_engine.hullPercent}% / ${_engine.shieldPercent}%',
                            valueColor: _engine.hullPercent < 35
                                ? AvionicsColors.crimson
                                : AvionicsColors.emeraldBright,
                          ),
                          const Divider(height: 10),
                          _ModalStatLine(
                            label: 'DESTROY BASE',
                            value: '${_engine.baseDestroyPercent}%',
                            valueColor: AvionicsColors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ModalActionButton(
                      key: const Key('pause_sound_toggle_button'),
                      icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      label: muted ? 'SOUND: MUTED • UNMUTE' : 'SOUND: ON • MUTE',
                      accent: muted ? AvionicsColors.gold : AvionicsColors.emeraldBright,
                      filled: false,
                      onTap: () => widget.controller.toggleSoundMuted(),
                    ),
                    const SizedBox(height: 10),
                    _ModalActionButton(
                      key: const Key('pause_resume_button'),
                      icon: Icons.play_arrow_rounded,
                      label: 'RESUME',
                      accent: AvionicsColors.cyan,
                      filled: true,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _engine.paused = false;
                        BattleAudio.instance.updateBattleAmbience(
                          paused: false,
                          overdrive: _engine.overdriveActive,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _ModalActionButton(
                      key: const Key('pause_return_home_button'),
                      icon: Icons.home_rounded,
                      label: 'RETURN TO HOME',
                      accent: AvionicsColors.crimson,
                      filled: false,
                      onTap: () {
                        BattleAudio.instance.stopBattleAmbience();
                        Navigator.of(ctx).pop();
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          key: const Key('pause_restart_button'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _advanceToStageInPlace(spec.stageNumber, resetFullState: true);
                            BattleAudio.instance.updateBattleAmbience(
                              paused: false,
                              overdrive: false,
                            );
                          },
                      icon: const Icon(
                        Icons.replay_rounded,
                        size: 14,
                        color: AvionicsColors.gold,
                      ),
                      label: Text(
                        'RESTART',
                        style: AvionicsText.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AvionicsColors.gold,
                        ),
                      ),
                    ),
                    if (_lastClearedSummary != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openFullDebrief();
                        },
                        child: Text(
                          'MISSION DEBRIEF',
                          style: AvionicsText.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AvionicsColors.emeraldBright,
                          ),
                        ),
                      ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AvionicsViewportFrame(
        child: Scaffold(
        backgroundColor: AvionicsColors.surfaceLowest,
        body: AnimatedBuilder(
          animation: _engine,
          builder: (context, _) {
            final spec = _engine.levelSpec;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Full-screen interactive 60fps aerial combat arena + touch-drag steering
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      key: const Key('dogfight_sky_arena'),
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
                          _engine.nudgeJetByNormalizedDelta(
                            details.delta.dx / constraints.maxWidth,
                            details.delta.dy / constraints.maxHeight,
                          );
                        }
                      },
                      child: CustomPaint(
                        painter: DogfightPainter(engine: _engine),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),

                // Shield barrier edge glow when energy deflector is active
                if (_engine.shieldActive)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AvionicsColors.cyan.withValues(alpha: 0.55),
                          width: 3,
                        ),
                      ),
                    ),
                  ),

                // Hull impact flash perimeter
                if (_engine.player.hitFlashTimer > 0)
                  IgnorePointer(
                    child: ColoredBox(
                      color: AvionicsColors.crimson.withValues(alpha: 0.16),
                    ),
                  ),

                // Cockpit HUD Perimeter Overlay
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                        child: _TopCombatHudRow(
                          score: _engine.score,
                          combo: _engine.combo,
                          levelSpec: spec,
                          wave: _engine.currentWave,
                          totalWaves: _engine.totalWaves,
                          basePercent: _engine.baseDestroyPercent,
                          hullPercent: _engine.hullPercent,
                          shieldPercent: _engine.shieldPercent,
                          onPause: _openPauseDialog,
                        ),
                      ),
                      _DifficultyLevelLadderStrip(
                        currentStage: _engine.stageNumber,
                        clearedStages: _sessionClearedStages,
                        onSelectStage: (stage) => _advanceToStageInPlace(
                          stage,
                          resetFullState: false,
                        ),
                      ),
                      Expanded(
                        child: IgnorePointer(
                          child: Stack(
                            children: [
                              Positioned(
                                left: 10,
                                bottom: 6,
                                child: _LeftFlightInstrumentColumn(
                                  gLoadText: '${_engine.gLoad.toStringAsFixed(1)} G',
                                  pitchOffset: _engine.player.vy * 14,
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 6,
                                child: _RightRadarInstrumentColumn(
                                  altitudeFeet: _engine.baroAltitudeFeet,
                                  engine: _engine,
                                ),
                              ),
                              if (_toastStageReport != null)
                                Positioned(
                                  top: 6,
                                  left: 48,
                                  right: 48,
                                  child: _StageClearToastBanner(
                                    report: _toastStageReport!,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _BottomWeaponsControlDeck(
                        autoFire: _engine.autoFire,
                        cannonAmmo: _engine.cannonAmmo,
                        missileSalvo: _engine.missileSalvo,
                        overdriveCharge: _engine.overdriveCharge.round(),
                        overdriveActive: _engine.overdriveActive,
                        shieldActive: _engine.shieldActive,
                        yokeOffset: _yokeOffset,
                        onToggleAutoFire: () {
                          _engine.setAutoFire(!_engine.autoFire);
                        },
                        onYokeChanged: (offset) {
                          setState(() => _yokeOffset = offset);
                          _engine.setFlightInput(offset.dx, offset.dy);
                        },
                        onOverdrive: _engine.activateOverdrive,
                        onCannonTap: _engine.triggerCannonBurst,
                        onCannonHoldChanged: (held) => _engine.triggerHeld = held,
                        onToggleShield: _engine.activateShield,
                        onFireMissile: _engine.fireFox2Salvo,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}

class _TopCombatHudRow extends StatelessWidget {
  const _TopCombatHudRow({
    required this.score,
    required this.combo,
    required this.levelSpec,
    required this.wave,
    required this.totalWaves,
    required this.basePercent,
    required this.hullPercent,
    required this.shieldPercent,
    required this.onPause,
  });

  final int score;
  final int combo;
  final LevelDifficultySpec levelSpec;
  final int wave;
  final int totalWaves;
  final int basePercent;
  final int hullPercent;
  final int shieldPercent;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final diffColor = levelSpec.difficulty.accentColor;
    final stageStr = levelSpec.stageNumber.toString().padLeft(2, '0');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 9,
          child: HudBracketCard(
            accentColor: AvionicsColors.cyan,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            bracketSize: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SCORE',
                      style: AvionicsText.mono(
                        fontSize: 7.2,
                        color: AvionicsColors.cyanDim,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: AvionicsColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: AvionicsColors.gold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        'x$combo',
                        style: AvionicsText.mono(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          color: AvionicsColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  formatTelemetryInt(score),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvionicsText.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AvionicsColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 12,
          child: HudBracketCard(
            accentColor: diffColor,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            bracketSize: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'LVL $stageStr • ${levelSpec.shortLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AvionicsText.mono(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          color: diffColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'W0$wave/0$totalWaves',
                      style: AvionicsText.mono(
                        fontSize: 7.2,
                        color: AvionicsColors.cyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'DESTROY BASE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AvionicsText.headline(
                          fontSize: 9.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$basePercent%',
                      key: const Key('destroy_base_percent'),
                      style: AvionicsText.mono(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        color: AvionicsColors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: basePercent / 100.0,
                    minHeight: 4,
                    backgroundColor: AvionicsColors.surfaceLowest,
                    valueColor: const AlwaysStoppedAnimation(AvionicsColors.orange),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 8,
          child: Column(
            children: [
              HudBracketCard(
                accentColor: AvionicsColors.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                bracketSize: 5,
                child: Column(
                  children: [
                    _MiniHealthRow(
                      label: 'HULL',
                      percent: hullPercent,
                      color: hullPercent < 35
                          ? AvionicsColors.crimson
                          : AvionicsColors.emerald,
                    ),
                    const SizedBox(height: 2),
                    _MiniHealthRow(
                      label: 'SHLD',
                      percent: shieldPercent,
                      color: AvionicsColors.cyan,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              InkWell(
                key: const Key('pause_tac_button'),
                onTap: onPause,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AvionicsColors.surfaceContainer.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AvionicsColors.cyan.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pause_rounded,
                        size: 12,
                        color: AvionicsColors.cyan,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PAUSE',
                        style: AvionicsText.mono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AvionicsColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniHealthRow extends StatelessWidget {
  const _MiniHealthRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AvionicsText.mono(fontSize: 7.5, color: color),
            ),
            Text(
              '$percent%',
              style: AvionicsText.mono(
                fontSize: 7.5,
                color: AvionicsColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent / 100.0,
            minHeight: 3.5,
            backgroundColor: AvionicsColors.surfaceLowest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _DifficultyLevelLadderStrip extends StatelessWidget {
  const _DifficultyLevelLadderStrip({
    required this.currentStage,
    required this.clearedStages,
    required this.onSelectStage,
  });

  final int currentStage;
  final Set<int> clearedStages;
  final ValueChanged<int> onSelectStage;

  @override
  Widget build(BuildContext context) {
    final stages = [1, 2, 3, 4, if (currentStage > 5) currentStage else 5];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 1, 8, 2),
      child: Row(
        children: stages.map((stage) {
          final spec = GameSeedData.levelSpecForStage(stage);
          final color = spec.difficulty.accentColor;
          final active = stage == currentStage;
          final cleared = clearedStages.contains(stage);
          final chipLabel = stage > 5
              ? '$stage ACE+'
              : '$stage ${spec.difficulty.chipLabel}';

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: stage == stages.last ? 0 : 4),
              child: InkWell(
                key: Key('level_chip_$stage'),
                onTap: () => onSelectStage(stage),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2.2, horizontal: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withValues(alpha: 0.24)
                        : AvionicsColors.surfaceLowest.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: active
                          ? color
                          : (cleared
                              ? color.withValues(alpha: 0.45)
                              : AvionicsColors.outlineVariant.withValues(alpha: 0.35)),
                      width: active ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cleared) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 9,
                          color: active ? color : AvionicsColors.emeraldBright,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          chipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AvionicsText.mono(
                            fontSize: 7.8,
                            fontWeight: FontWeight.w800,
                            color: active ? color : AvionicsColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LeftFlightInstrumentColumn extends StatelessWidget {
  const _LeftFlightInstrumentColumn({
    required this.gLoadText,
    required this.pitchOffset,
  });

  final String gLoadText;
  final double pitchOffset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: Offset(0, pitchOffset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ['+10°', ' 00°', '-10°']
                .map(
                  (deg) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: deg == ' 00°' ? 16 : 10,
                          height: deg == ' 00°' ? 2 : 1,
                          color: AvionicsColors.cyan.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deg,
                          style: AvionicsText.mono(
                            fontSize: 7.5,
                            color: AvionicsColors.cyanFixed,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        _TelemetryReadoutBox(
          title: 'G-LOAD',
          value: gLoadText,
          subtitle: 'NOMINAL',
        ),
      ],
    );
  }
}

class _RightRadarInstrumentColumn extends StatelessWidget {
  const _RightRadarInstrumentColumn({
    required this.altitudeFeet,
    required this.engine,
  });

  final int altitudeFeet;
  final DogfightEngine engine;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: CustomPaint(
            painter: _LiveRadarScopePainter(engine: engine),
          ),
        ),
        const SizedBox(height: 6),
        _TelemetryReadoutBox(
          title: 'BARO ALT',
          value: formatTelemetryInt(altitudeFeet),
          subtitle: 'FT ASL',
          alignRight: true,
        ),
      ],
    );
  }
}

class _TelemetryReadoutBox extends StatelessWidget {
  const _TelemetryReadoutBox({
    required this.title,
    required this.value,
    required this.subtitle,
    this.alignRight = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AvionicsColors.surfaceLowest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AvionicsColors.cyan.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AvionicsText.mono(fontSize: 7.5, color: AvionicsColors.cyanDim),
          ),
          Text(
            value,
            style: AvionicsText.mono(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AvionicsColors.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: AvionicsText.mono(
              fontSize: 7.5,
              color: AvionicsColors.emeraldBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveRadarScopePainter extends CustomPainter {
  _LiveRadarScopePainter({required this.engine}) : super(repaint: engine);

  final DogfightEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AvionicsColors.surfaceLowest.withValues(alpha: 0.8),
    );

    final ringPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.62, ringPaint);
    canvas.drawCircle(center, radius * 0.25, ringPaint);

    // Sweeping beam
    canvas.drawLine(
      center,
      center +
          Offset(math.cos(engine.radarAngle), math.sin(engine.radarAngle)) *
              radius,
      Paint()
        ..color = AvionicsColors.emeraldBright
        ..strokeWidth = 1.6,
    );

    // Real-time Skyfortress boss blip relative to player jet
    final px = engine.player.x;
    final py = engine.player.y;
    if (engine.boss.hp > 0) {
      final relX = ((engine.boss.x - px) * radius * 1.4).clamp(-radius + 4, radius - 4);
      final relY = ((engine.boss.y - py) * radius * 1.4).clamp(-radius + 4, radius - 4);
      canvas.drawRect(
        Rect.fromCenter(center: center + Offset(relX, relY), width: 6, height: 6),
        Paint()..color = AvionicsColors.gold,
      );
    }

    // Live enemy bogie blips
    final bogiePaint = Paint()..color = AvionicsColors.orange;
    for (final e in engine.enemies) {
      final relX = ((e.x - px) * radius * 1.5).clamp(-radius + 4, radius - 4);
      final relY = ((e.y - py) * radius * 1.5).clamp(-radius + 4, radius - 4);
      canvas.drawCircle(center + Offset(relX, relY), 2.6, bogiePaint);
    }

    // Center friendly player dot
    canvas.drawCircle(center, 2.5, Paint()..color = AvionicsColors.cyan);
  }

  @override
  bool shouldRepaint(covariant _LiveRadarScopePainter oldDelegate) => true;
}

class _BottomWeaponsControlDeck extends StatelessWidget {
  const _BottomWeaponsControlDeck({
    required this.autoFire,
    required this.cannonAmmo,
    required this.missileSalvo,
    required this.overdriveCharge,
    required this.overdriveActive,
    required this.shieldActive,
    required this.yokeOffset,
    required this.onToggleAutoFire,
    required this.onYokeChanged,
    required this.onOverdrive,
    required this.onCannonTap,
    required this.onCannonHoldChanged,
    required this.onToggleShield,
    required this.onFireMissile,
  });

  final bool autoFire;
  final int cannonAmmo;
  final int missileSalvo;
  final int overdriveCharge;
  final bool overdriveActive;
  final bool shieldActive;
  final Offset yokeOffset;
  final VoidCallback onToggleAutoFire;
  final ValueChanged<Offset> onYokeChanged;
  final VoidCallback onOverdrive;
  final VoidCallback onCannonTap;
  final ValueChanged<bool> onCannonHoldChanged;
  final VoidCallback onToggleShield;
  final VoidCallback onFireMissile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AvionicsColors.surfaceLowest.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  key: const Key('auto_fire_toggle'),
                  onTap: onToggleAutoFire,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (autoFire
                              ? AvionicsColors.emerald
                              : AvionicsColors.surfaceContainer)
                          .withValues(alpha: autoFire ? 0.22 : 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: autoFire
                            ? AvionicsColors.emeraldBright
                            : AvionicsColors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          autoFire ? Icons.bolt_rounded : Icons.touch_app_rounded,
                          size: 11,
                          color: autoFire
                              ? AvionicsColors.emeraldBright
                              : AvionicsColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          autoFire ? 'AUTO BULLETS: ON' : 'AUTO BULLETS: OFF',
                          style: AvionicsText.mono(
                            fontSize: 8.5,
                            color: autoFire
                                ? AvionicsColors.emeraldBright
                                : AvionicsColors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '20MM: $cannonAmmo // FOX-2: $missileSalvo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvionicsText.mono(
                      fontSize: 8.5,
                      color: AvionicsColors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _FlightYokePad(
                offset: yokeOffset,
                onChanged: onYokeChanged,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    GlowingCapsuleButton(
                      key: const Key('overdrive_button'),
                      label: overdriveActive ? 'AFTERBURN' : 'OVERDRIVE',
                      height: 40,
                      horizontalPadding: 10,
                      fontSize: 11.5,
                      onPressed: onOverdrive,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BOOST $overdriveCharge%',
                      style: AvionicsText.mono(
                        fontSize: 8.5,
                        color: AvionicsColors.orangePeach,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        key: const Key('fire_cannon_button'),
                        onTap: onCannonTap,
                        onLongPressStart: (_) => onCannonHoldChanged(true),
                        onLongPressEnd: (_) => onCannonHoldChanged(false),
                        onLongPressCancel: () => onCannonHoldChanged(false),
                        child: _WeaponSmallVisual(
                          title: '20MM',
                          subtitle: '$cannonAmmo',
                          accentColor: AvionicsColors.gold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const Key('toggle_shield_button'),
                        onTap: onToggleShield,
                        child: _WeaponSmallVisual(
                          title: 'SHIELD',
                          subtitle: shieldActive ? 'ACTIVE' : 'READY',
                          accentColor: AvionicsColors.cyan,
                          active: shieldActive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 136,
                    child: GlowingCapsuleButton(
                      key: const Key('fire_missile_button'),
                      label: 'FOX 2 x$missileSalvo',
                      icon: Icons.rocket_launch_rounded,
                      height: 42,
                      horizontalPadding: 8,
                      fontSize: 11,
                      onPressed: missileSalvo > 0 ? onFireMissile : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlightYokePad extends StatelessWidget {
  const _FlightYokePad({required this.offset, required this.onChanged});

  final Offset offset;
  final ValueChanged<Offset> onChanged;

  static const double _radius = 44;

  void _updateFromLocal(Offset localPos) {
    final center = const Offset(_radius, _radius);
    final delta = localPos - center;
    final dist = delta.distance;
    const maxTravel = 24.0;
    final clamped = dist > maxTravel ? (delta / dist) * maxTravel : delta;
    onChanged(Offset(clamped.dx / maxTravel, clamped.dy / maxTravel));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          key: const Key('flight_yoke_pad'),
          onPanStart: (details) => _updateFromLocal(details.localPosition),
          onPanUpdate: (details) => _updateFromLocal(details.localPosition),
          onPanEnd: (_) => onChanged(Offset.zero),
          child: Container(
            width: _radius * 2,
            height: _radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AvionicsColors.surfaceContainer.withValues(alpha: 0.65),
              border: Border.all(
                color: AvionicsColors.cyan.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AvionicsColors.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(offset.dx * 22, offset.dy * 22),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AvionicsColors.cyan.withValues(alpha: 0.28),
                      border: Border.all(color: AvionicsColors.cyan, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AvionicsColors.cyan.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'FLIGHT YOKE',
          style: AvionicsText.mono(fontSize: 8, color: AvionicsColors.outline),
        ),
      ],
    );
  }
}

class _WeaponSmallVisual extends StatelessWidget {
  const _WeaponSmallVisual({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? accentColor.withValues(alpha: 0.25)
            : AvionicsColors.surfaceContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accentColor.withValues(alpha: active ? 0.95 : 0.55),
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AvionicsText.headline(
              fontSize: 10,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            style: AvionicsText.mono(
              fontSize: 8,
              color: AvionicsColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageClearToastBanner extends StatelessWidget {
  const _StageClearToastBanner({required this.report});

  final StageClearReport report;

  @override
  Widget build(BuildContext context) {
    final clearedStr = report.stageNumber.toString().padLeft(2, '0');
    final nextSpec = GameSeedData.levelSpecForStage(report.stageNumber + 1);
    final nextStr = nextSpec.stageNumber.toString().padLeft(2, '0');
    final nextColor = nextSpec.difficulty.accentColor;

    return Center(
      child: Container(
        key: const Key('stage_clear_toast_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AvionicsColors.surfaceLowest.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AvionicsColors.goldLight.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: AvionicsColors.gold.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 16,
              color: AvionicsColors.goldLight,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LVL $clearedStr (${report.levelSpec.shortLabel}) CLEAR  •  +${report.levelSpec.creditsReward} CR  +${report.levelSpec.scrapReward} SCRAP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvionicsText.mono(
                      fontSize: 8.8,
                      fontWeight: FontWeight.w800,
                      color: AvionicsColors.goldLight,
                    ),
                  ),
                  Text(
                    'ENGAGING LVL $nextStr // ${nextSpec.shortLabel} (${nextSpec.operationTitle})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvionicsText.mono(
                      fontSize: 8.0,
                      fontWeight: FontWeight.w800,
                      color: nextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalStatLine extends StatelessWidget {
  const _ModalStatLine({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AvionicsText.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AvionicsColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AvionicsText.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ModalActionButton extends StatelessWidget {
  const _ModalActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.78)],
                )
              : null,
          color: filled ? null : accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withValues(alpha: filled ? 1.0 : 0.75),
            width: 1.4,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? AvionicsColors.surfaceLowest : accent,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AvionicsText.headline(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: filled ? AvionicsColors.surfaceLowest : accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
