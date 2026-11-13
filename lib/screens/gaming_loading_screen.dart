import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';

/// Full-screen cinematic gaming boot & tactical preflight loading screen
/// shown on launch before entering the Hangar home screen.
class GamingLoadingScreen extends StatefulWidget {
  const GamingLoadingScreen({
    super.key,
    required this.controller,
  });

  final GameController controller;

  @override
  State<GamingLoadingScreen> createState() => _GamingLoadingScreenState();
}

class _GamingLoadingScreenState extends State<GamingLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tacticalTips = <String>[
    'STEER THE FLIGHT YOKE TO DODGE CROSSFIRE WHILE AUTO-CANNONS TRACK HOSTILES.',
    'DEPLOY AEGIS SHIELD BEFORE HEAVY CRUISER MISSILE VOLLEYS IMPACT.',
    'UPGRADE AFTERBURNERS & 20MM VULCAN IN ENGINEERING TO UNLOCK ACE JETS.',
    'INSPECT EVERY AIRFRAME IN 360° HANGAR MODE AND EQUIP STEALTH LIVERIES.',
  ];

  late final AnimationController _bootController;
  late final int _tipIndex;
  bool _precached = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _tipIndex = DateTime.now().millisecond % _tacticalTips.length;
    widget.controller.addListener(_onControllerChanged);

    _bootController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _tryProceedToHangar();
        }
      })
      ..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingName.contains('TestWidgetsFlutterBinding')) {
      precacheImage(const AssetImage('assets/images/dogfight_sky.jpg'), context)
          .catchError((_) {});
      precacheImage(
        const AssetImage('assets/images/sprites/battlefield_ground.png'),
        context,
      ).catchError((_) {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _bootController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_bootController.isCompleted && !widget.controller.isLoading) {
      _tryProceedToHangar();
    } else {
      setState(() {});
    }
  }

  double get _effectiveProgress {
    final timeline = (_bootController.value / 0.90).clamp(0.0, 1.0);
    if (widget.controller.isLoading && timeline > 0.94) {
      return 0.94;
    }
    return timeline;
  }

  bool get _canFastEnter =>
      !widget.controller.isLoading && _effectiveProgress >= 0.45;

  void _tryProceedToHangar({bool force = false}) {
    if (_navigated || !mounted) return;
    if (widget.controller.isLoading) return;
    if (!force && !_bootController.isCompleted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.hangar);
  }

  String _bootStatusLabel(double progress) {
    if (widget.controller.isLoading) {
      return 'SYNCING SQLITE SQUADRON LOGS...';
    }
    if (progress < 0.28) {
      return 'INITIALIZING AVIONICS & FLIGHT TELEMETRY...';
    }
    if (progress < 0.58) {
      return 'CALIBRATING 360° HANGAR DECK RIG...';
    }
    if (progress < 0.86) {
      return 'ARMING 20MM VULCAN & FOX-2 PODS...';
    }
    if (progress < 1.0) {
      return 'STREAMING BATTLEFIELD TERRAIN & AUDIO...';
    }
    return 'ALL SYSTEMS GREEN // ENTERING HANGAR';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('gaming_loading_screen'),
      backgroundColor: AvionicsColors.surfaceLowest,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _canFastEnter ? () => _tryProceedToHangar(force: true) : null,
        child: AnimatedBuilder(
          animation: _bootController,
          builder: (context, _) {
            final t = _bootController.value;
            final progress = _effectiveProgress;
            final percent = (progress * 100).round().clamp(0, 100);
            final zoom = 1.06 - (t * 0.06);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Key-art dogfight hero backdrop with smooth camera push-in
                Transform.scale(
                  scale: zoom,
                  child: Image.asset(
                    'assets/images/dogfight_sky.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.15),
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF0A1626),
                    ),
                  ),
                ),

                // Cinematic depth gradient preserving fighter jet artwork in center
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.26, 0.54, 0.78, 1.0],
                      colors: [
                        Color(0xD9050B14),
                        Color(0x52060F1C),
                        Color(0x18060F1C),
                        Color(0xCC060C16),
                        Color(0xF5050911),
                      ],
                    ),
                  ),
                ),

                // Live animated avionics HUD reticle, scanline & radar sweep
                CustomPaint(
                  painter: _LoadingHudOverlayPainter(
                    animValue: t,
                    progress: progress,
                  ),
                ),

                // Safe-area foreground game branding + armored loading console
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopTelemetryHeader(ready: percent >= 100),
                        const SizedBox(height: 18),
                        _GameEmblemHeader(animValue: t),
                        const Spacer(),
                        _TacticalTipBanner(tip: _tacticalTips[_tipIndex]), 
                        const SizedBox(height: 12),
                        _ArmoredLoadingConsole(
                          progress: progress,
                          percent: percent,
                          statusLabel: _bootStatusLabel(progress),
                          canFastEnter: _canFastEnter,
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

class _TopTelemetryHeader extends StatelessWidget {
  const _TopTelemetryHeader({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AvionicsColors.surfaceLowest.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AvionicsColors.cyan.withValues(alpha: 0.45),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ready
                          ? AvionicsColors.emeraldBright
                          : AvionicsColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AVIONICS // v4.2',
                    style: AvionicsText.mono(
                      fontSize: 9.5,
                      color: AvionicsColors.cyanFixed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AvionicsColors.surfaceLowest.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AvionicsColors.orange.withValues(alpha: 0.5),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'TAC-01 // PACIFIC',
                style: AvionicsText.mono(
                  fontSize: 9,
                  color: AvionicsColors.orangePeach,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameEmblemHeader extends StatelessWidget {
  const _GameEmblemHeader({required this.animValue});

  final double animValue;

  @override
  Widget build(BuildContext context) {
    final glowAlpha = 0.24 + 0.16 * math.sin(animValue * math.pi * 6).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Winged squadron insignia pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AvionicsColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AvionicsColors.cyan.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                size: 13,
                color: AvionicsColors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                'ACE COMBAT SQUADRON',
                style: AvionicsText.mono(
                  fontSize: 9.5,
                  color: AvionicsColors.cyan,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SKY STRIKE',
          textAlign: TextAlign.center,
          style: AvionicsText.headline(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            color: Colors.white,
          ).copyWith(
            shadows: [
              Shadow(
                color: AvionicsColors.cyan.withValues(alpha: glowAlpha + 0.35),
                blurRadius: 18,
              ),
              const Shadow(
                color: Color(0xE6040912),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 2,
              color: AvionicsColors.cyan.withValues(alpha: 0.85),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'AIR SUPERIORITY PROTOCOL',
                    style: AvionicsText.mono(
                      fontSize: 10,
                      color: AvionicsColors.goldLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ).copyWith(
                      shadows: const [
                        Shadow(
                          color: Color(0xD9040912),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 28,
              height: 2,
              color: AvionicsColors.orange.withValues(alpha: 0.9),
            ),
          ],
        ),
      ],
    );
  }
}

class _TacticalTipBanner extends StatelessWidget {
  const _TacticalTipBanner({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC0D1827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AvionicsColors.cyan.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AvionicsColors.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AvionicsColors.orange.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              'TIP',
              style: AvionicsText.mono(
                fontSize: 8.5,
                color: AvionicsColors.orangePeach,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              tip,
              style: AvionicsText.mono(
                fontSize: 9.5,
                color: AvionicsColors.onSurface,
                letterSpacing: 0.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArmoredLoadingConsole extends StatelessWidget {
  const _ArmoredLoadingConsole({
    required this.progress,
    required this.percent,
    required this.statusLabel,
    required this.canFastEnter,
    required this.animValue,
  });

  final double progress;
  final int percent;
  final String statusLabel;
  final bool canFastEnter;
  final double animValue;

  @override
  Widget build(BuildContext context) {
    final ready = percent >= 100;
    final barColor = ready ? AvionicsColors.emeraldBright : AvionicsColors.cyan;
    final promptAlpha = 0.55 + 0.45 * math.sin(animValue * math.pi * 8).abs();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEB101B2B), Color(0xF508101A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (ready ? AvionicsColors.emerald : AvionicsColors.cyan)
              .withValues(alpha: 0.55),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.18),
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
                  key: const Key('loading_status_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvionicsText.mono(
                    fontSize: 10,
                    color: ready
                        ? AvionicsColors.emeraldBright
                        : AvionicsColors.cyanFixed,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                key: const Key('loading_percent_label'),
                style: AvionicsText.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ready ? AvionicsColors.emeraldBright : Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Beveled segmented armored progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF060B13),
                border: Border.all(
                  color: AvionicsColors.outlineVariant.withValues(alpha: 0.65),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                painter: _SegmentedGaugePainter(
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
                  'HANGAR BAY // DECK-04',
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
                        ? 'LAUNCHING HANGAR...'
                        : (canFastEnter ? 'TAP TO ENTER >>' : 'PREFLIGHT CHECK'),
                    maxLines: 1,
                    style: AvionicsText.mono(
                      fontSize: 8.5,
                      color: ready
                          ? AvionicsColors.emeraldBright
                          : AvionicsColors.orangePeach.withValues(
                              alpha: canFastEnter ? promptAlpha : 0.85,
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

class _SegmentedGaugePainter extends CustomPainter {
  const _SegmentedGaugePainter({
    required this.progress,
    required this.ready,
  });

  final double progress;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final fillWidth = (size.width * progress.clamp(0.0, 1.0));
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            colors: ready
                ? const [Color(0xFF00C853), Color(0xFF22EF7E), Color(0xFFB9F6CA)]
                : const [Color(0xFF0077B6), Color(0xFF00E5FF), Color(0xFFFF9E40)],
          ).createShader(fillRect),
      );

      // Leading edge hot laser tip
      canvas.drawRect(
        Rect.fromLTWH(math.max(0.0, fillWidth - 4), 0, 4, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // Precision armored gauge segment ticks
    const segments = 20;
    final dividerPaint = Paint()
      ..color = const Color(0xFF050A12).withValues(alpha: 0.72)
      ..strokeWidth = 1.6;
    for (int i = 1; i < segments; i++) {
      final x = size.width * (i / segments);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ready != ready;
  }
}

class _LoadingHudOverlayPainter extends CustomPainter {
  const _LoadingHudOverlayPainter({
    required this.animValue,
    required this.progress,
  });

  final double animValue;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Subtle tactical viewport corner brackets
    const inset = 12.0;
    const arm = 20.0;
    final corners = [
      // Top-left
      [const Offset(inset, inset + arm), const Offset(inset, inset), const Offset(inset + arm, inset)],
      // Top-right
      [Offset(size.width - inset - arm, inset), Offset(size.width - inset, inset), Offset(size.width - inset, inset + arm)],
      // Bottom-left
      [Offset(inset, size.height - inset - arm), Offset(inset, size.height - inset), Offset(inset + arm, size.height - inset)],
      // Bottom-right
      [Offset(size.width - inset - arm, size.height - inset), Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - arm)],
    ];
    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, framePaint);
    }

    // Sweeping horizontal avionics radar scanline
    final scanY = size.height * (0.12 + 0.72 * animValue);
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AvionicsColors.cyan.withValues(alpha: 0.36),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, scanY - 2, size.width, 4))
        ..strokeWidth = 1.8,
    );

    // Subtle rotating target lock ring over upper sky battle horizon
    final lockCenter = Offset(size.width * 0.5, size.height * 0.45);
    final lockRadius = 38.0 + (1.0 - progress) * 14.0;
    final rot = animValue * math.pi * 2.5;
    final lockPaint = Paint()
      ..color = (progress >= 0.98 ? AvionicsColors.emerald : AvionicsColors.cyan)
          .withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      final start = rot + i * (math.pi / 2) + 0.18;
      canvas.drawArc(
        Rect.fromCircle(center: lockCenter, radius: lockRadius),
        start,
        0.55,
        false,
        lockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingHudOverlayPainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.progress != progress;
  }
}

