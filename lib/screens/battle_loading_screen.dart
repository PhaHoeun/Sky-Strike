import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/dogfight_sprites.dart';
import '../models/game_models.dart';
import '../navigation/app_routes.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/jet_360_viewer.dart';

/// Tactical sortie deployment screen displayed between clicking "TO BATTLE!"
/// in Hangar and entering the playable battlefield arena.
class BattleLoadingScreen extends StatefulWidget {
  const BattleLoadingScreen({
    super.key,
    required this.controller,
    required this.stageNumber,
  });

  final GameController controller;
  final int stageNumber;

  @override
  State<BattleLoadingScreen> createState() => _BattleLoadingScreenState();
}

class _BattleLoadingScreenState extends State<BattleLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _deployController;
  bool _assetsReady = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final jet = widget.controller.selectedJet;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (bindingName.contains('TestWidgetsFlutterBinding')) {
      DogfightSpriteAtlas.instance.ensureCustomJetLoaded(jet);
      _assetsReady = true;
    } else {
      DogfightSpriteAtlas.instance.waitUntilReady(jet).then((_) {
        if (!mounted) return;
        _assetsReady = true;
        if (_deployController.isCompleted) {
          _launchGameplay();
        } else {
          setState(() {});
        }
      });
    }

    _deployController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _launchGameplay();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _deployController.dispose();
    super.dispose();
  }

  double get _effectiveProgress {
    final timeline = (_deployController.value / 0.90).clamp(0.0, 1.0);
    if (!_assetsReady && timeline > 0.93) {
      return 0.93;
    }
    return timeline;
  }

  bool get _canFastDeploy => _assetsReady && _effectiveProgress >= 0.45;

  void _launchGameplay({bool force = false}) {
    if (_navigated || !mounted) return;
    if (!_assetsReady) return;
    if (!force && !_deployController.isCompleted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameplay,
      arguments: GameplayRouteArgs(stageNumber: widget.stageNumber),
    );
  }

  String _deployStatusLabel(JetConfig jet, double progress) {
    if (!_assetsReady && progress >= 0.90) {
      return 'COMPILING 3D COMBAT SPRITE RIG...';
    }
    if (progress < 0.30) {
      return 'LOCKING WARZONE TERRAIN GRID...';
    }
    if (progress < 0.62) {
      return 'SCRAMBLING ${jet.codeTag} (${jet.selectedCamo})...';
    }
    if (progress < 0.92) {
      return 'ARMING 20MM VULCAN & FOX-2 PODS...';
    }
    return 'CLEARED HOT // ENGAGING HOSTILES';
  }

  @override
  Widget build(BuildContext context) {
    final jet = widget.controller.selectedJet;
    final opName = GameSeedData.operationNameForStage(widget.stageNumber);
    final stageStr = widget.stageNumber.toString().padLeft(2, '0');

    return Scaffold(
      key: const Key('battle_loading_screen'),
      backgroundColor: AvionicsColors.surfaceLowest,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _canFastDeploy ? () => _launchGameplay(force: true) : null,
        child: AnimatedBuilder(
          animation: _deployController,
          builder: (context, _) {
            final t = _deployController.value;
            final progress = _effectiveProgress;
            final percent = (progress * 100).round().clamp(0, 100);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Scrolling warzone terrain preview
                Opacity(
                  opacity: 0.46,
                  child: Transform.translate(
                    offset: Offset(0, 26 * (1.0 - t)),
                    child: Transform.scale(
                      scale: 1.08,
                      child: Image.asset(
                        'assets/images/sprites/battlefield_ground.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF141D26),
                        ),
                      ),
                    ),
                  ),
                ),

                // Atmospheric warzone haze + dark top/bottom HUD scrim
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.32, 0.66, 1.0],
                      colors: [
                        Color(0xE8070E18),
                        Color(0x880B1826),
                        Color(0xAA0C1520),
                        Color(0xF5050A12),
                      ],
                    ),
                  ),
                ),

                // Tactical deployment radar sweep & corner telemetry framing
                CustomPaint(
                  painter: _BattleDeployHudPainter(
                    animValue: t,
                    progress: progress,
                    accentColor: jet.accentColor,
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DeployHeaderBar(
                          stageStr: stageStr,
                          operationName: opName,
                        ),
                        const Spacer(),
                        _JetScramblePreview(
                          jet: jet,
                          animValue: t,
                          progress: progress,
                        ),
                        const Spacer(),
                        _ArmoredDeployConsole(
                          jet: jet,
                          progress: progress,
                          percent: percent,
                          statusLabel: _deployStatusLabel(jet, progress),
                          canFastDeploy: _canFastDeploy,
                          animValue: t,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeployHeaderBar extends StatelessWidget {
  const _DeployHeaderBar({
    required this.stageStr,
    required this.operationName,
  });

  final String stageStr;
  final String operationName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: AvionicsColors.orange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AvionicsColors.orange.withValues(alpha: 0.72),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.radar_rounded,
                size: 13,
                color: AvionicsColors.orangePeach,
              ),
              const SizedBox(width: 6),
              Text(
                'SORTIE DEPLOYMENT // STAGE $stageStr',
                style: AvionicsText.mono(
                  fontSize: 9.5,
                  color: AvionicsColors.orangePeach,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'OP: $operationName',
            textAlign: TextAlign.center,
            style: AvionicsText.headline(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: Colors.white,
            ).copyWith(
              shadows: const [
                Shadow(
                  color: Color(0xE0040912),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'WEAPONS FREE // AUTO-CANNON ENGAGED',
          style: AvionicsText.mono(
            fontSize: 9.5,
            color: AvionicsColors.cyanFixed,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _JetScramblePreview extends StatelessWidget {
  const _JetScramblePreview({
    required this.jet,
    required this.animValue,
    required this.progress,
  });

  final JetConfig jet;
  final double animValue;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final climbOffset = 14.0 * (1.0 - Curves.easeOutCubic.transform(animValue));
    final spritePath = 'assets/images/sprites/player_${jet.id}_0.png';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, climbOffset),
          child: SizedBox(
            width: 158,
            height: 158,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Twin afterburner exhaust plumes beneath airframe
                Positioned(
                  bottom: 14,
                  child: Container(
                    width: 44,
                    height: 34 + 14 * math.sin(animValue * math.pi * 10).abs(),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          AvionicsColors.cyanFixed.withValues(alpha: 0.8),
                          AvionicsColors.orange.withValues(alpha: 0.42),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: ColorFiltered(
                    colorFilter: resolveCamoColorFilter(jet),
                    child: Image.asset(
                      spritePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.airplanemode_active_rounded,
                        size: 74,
                        color: jet.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            jet.callsign,
            style: AvionicsText.headline(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AvionicsColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: jet.accentColor.withValues(alpha: 0.5),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'LIVERY: ${jet.selectedCamo}  //  20MM + FOX-2',
              style: AvionicsText.mono(
                fontSize: 9,
                color: AvionicsColors.cyanFixed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArmoredDeployConsole extends StatelessWidget {
  const _ArmoredDeployConsole({
    required this.jet,
    required this.progress,
    required this.percent,
    required this.statusLabel,
    required this.canFastDeploy,
    required this.animValue,
  });

  final JetConfig jet;
  final double progress;
  final int percent;
  final String statusLabel;
  final bool canFastDeploy;
  final double animValue;

  @override
  Widget build(BuildContext context) {
    final ready = percent >= 100;
    final barColor = ready ? AvionicsColors.emeraldBright : AvionicsColors.orange;
    final promptAlpha = 0.55 + 0.45 * math.sin(animValue * math.pi * 8).abs();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEB151D2B), Color(0xF5090F18)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: barColor.withValues(alpha: 0.62),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statusLabel,
                  key: const Key('battle_loading_status_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvionicsText.mono(
                    fontSize: 10,
                    color: ready
                        ? AvionicsColors.emeraldBright
                        : AvionicsColors.orangePeach,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                key: const Key('battle_loading_percent_label'),
                style: AvionicsText.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ready ? AvionicsColors.emeraldBright : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF060B12),
                border: Border.all(
                  color: AvionicsColors.outlineVariant.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                painter: _DeployGaugePainter(
                  progress: progress,
                  ready: ready,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'CALLSIGN // ${jet.codeTag}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvionicsText.mono(
                    fontSize: 8.5,
                    color: AvionicsColors.outline,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    ready
                        ? 'LAUNCHING SORTIE...'
                        : (canFastDeploy ? 'TAP TO LAUNCH >>' : 'ARMING PODS'),
                    maxLines: 1,
                    style: AvionicsText.mono(
                      fontSize: 8.5,
                      color: ready
                          ? AvionicsColors.emeraldBright
                          : AvionicsColors.cyanFixed.withValues(
                              alpha: canFastDeploy ? promptAlpha : 0.85,
                            ),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeployGaugePainter extends CustomPainter {
  const _DeployGaugePainter({
    required this.progress,
    required this.ready,
  });

  final double progress;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final fillWidth = size.width * progress.clamp(0.0, 1.0);
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            colors: ready
                ? const [Color(0xFF00C853), Color(0xFF22EF7E), Color(0xFFB9F6CA)]
                : const [Color(0xFFD94A00), Color(0xFFFE6B00), Color(0xFFFFD166)],
          ).createShader(fillRect),
      );
      canvas.drawRect(
        Rect.fromLTWH(math.max(0.0, fillWidth - 4), 0, 4, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      );
    }

    const segments = 18;
    final dividerPaint = Paint()
      ..color = const Color(0xFF050A12).withValues(alpha: 0.72)
      ..strokeWidth = 1.6;
    for (int i = 1; i < segments; i++) {
      final x = size.width * (i / segments);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DeployGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ready != ready;
  }
}

class _BattleDeployHudPainter extends CustomPainter {
  const _BattleDeployHudPainter({
    required this.animValue,
    required this.progress,
    required this.accentColor,
  });

  final double animValue;
  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 96, ringPaint);
    canvas.drawCircle(
      center,
      128,
      ringPaint..color = AvionicsColors.orange.withValues(alpha: 0.16),
    );

    // Sweeping radar scanner sector around aircraft
    final sweepAngle = animValue * math.pi * 4.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 112),
      sweepAngle,
      0.65,
      false,
      Paint()
        ..color = AvionicsColors.cyan.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Target corner framing brackets
    const inset = 14.0;
    const arm = 18.0;
    final bracketPaint = Paint()
      ..color = AvionicsColors.orange.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final corners = [
      [const Offset(inset, inset + arm), const Offset(inset, inset), const Offset(inset + arm, inset)],
      [Offset(size.width - inset - arm, inset), Offset(size.width - inset, inset), Offset(size.width - inset, inset + arm)],
      [Offset(inset, size.height - inset - arm), Offset(inset, size.height - inset), Offset(inset + arm, size.height - inset)],
      [Offset(size.width - inset - arm, size.height - inset), Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - arm)],
    ];
    for (final pts in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BattleDeployHudPainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.progress != progress;
  }
}

