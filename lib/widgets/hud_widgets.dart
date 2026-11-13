import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';

/// Formats an integer with comma thousands separators (e.g. `14850` -> `14,850`).
String formatTelemetryInt(int value) {
  final str = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    final posFromRight = str.length - i;
    if (i > 0 && posFromRight % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

/// Frames the UI cleanly in a 9:16 portrait smartphone shell on wide displays,
/// while expanding edge-to-edge on actual mobile screens.
class AvionicsViewportFrame extends StatelessWidget {
  const AvionicsViewportFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 480) {
          return ColoredBox(
            color: AvionicsColors.surface,
            child: child,
          );
        }
        final frameWidth = constraints.maxWidth.clamp(360.0, 420.0);
        final frameHeight = constraints.maxHeight.clamp(680.0, 860.0);
        return ColoredBox(
          color: const Color(0xFF04070E),
          child: Center(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                color: AvionicsColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AvionicsColors.cyan.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AvionicsColors.cyan.withValues(alpha: 0.14),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Blueprint / radar coordinate grid backdrop matching Apex Avionics HUD screens.
class CrtGridBackground extends StatelessWidget {
  const CrtGridBackground({
    super.key,
    this.minorSpacing = 18,
    this.majorSpacing = 72,
    this.gridOpacity = 0.055,
    this.backgroundColor = AvionicsColors.surface,
  });

  final double minorSpacing;
  final double majorSpacing;
  final double gridOpacity;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CrtGridPainter(
        minorSpacing: minorSpacing,
        majorSpacing: majorSpacing,
        gridOpacity: gridOpacity,
        backgroundColor: backgroundColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CrtGridPainter extends CustomPainter {
  const _CrtGridPainter({
    required this.minorSpacing,
    required this.majorSpacing,
    required this.gridOpacity,
    required this.backgroundColor,
  });

  final double minorSpacing;
  final double majorSpacing;
  final double gridOpacity;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    final minorPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: gridOpacity * 0.55)
      ..strokeWidth = 0.7;

    final majorPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: gridOpacity * 1.35)
      ..strokeWidth = 1.0;

    for (double x = 0; x <= size.width; x += minorSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }
    for (double y = 0; y <= size.height; y += minorSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    for (double x = 0; x <= size.width; x += majorSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }
    for (double y = 0; y <= size.height; y += majorSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrtGridPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.gridOpacity != gridOpacity;
}

/// Military sci-fi container with L-bracket corner wireframes and optional glass blur.
class HudBracketCard extends StatelessWidget {
  const HudBracketCard({
    super.key,
    required this.child,
    this.accentColor = AvionicsColors.cyan,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(12),
    this.bracketSize = 10,
    this.bracketStroke = 1.6,
    this.borderRadius = 4,
    this.blurSigma = 0,
  });

  final Widget child;
  final Color accentColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double bracketSize;
  final double bracketStroke;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AvionicsColors.surfaceContainer.withValues(alpha: 0.90);
    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: child,
    );

    if (blurSigma > 0) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: inner,
        ),
      );
    }

    return CustomPaint(
      foregroundPainter: _CornerBracketPainter(
        color: accentColor,
        bracketSize: bracketSize,
        strokeWidth: bracketStroke,
      ),
      child: inner,
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({
    required this.color,
    required this.bracketSize,
    required this.strokeWidth,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final l = bracketSize;
    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, l),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - l)
        ..lineTo(0, size.height)
        ..lineTo(l, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 10-segment tactical gauge bar used on telemetry cards (Speed, Armor, Firepower).
class SegmentedStatBar extends StatelessWidget {
  const SegmentedStatBar({
    super.key,
    required this.value,
    this.maxValue = 100,
    this.segments = 10,
    this.activeColor = AvionicsColors.cyan,
    this.height = 6,
  });

  final int value;
  final int maxValue;
  final int segments;
  final Color activeColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final filledCount = ((value / maxValue) * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (index) {
        final active = index < filledCount;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: index == segments - 1 ? 0 : 3),
            decoration: BoxDecoration(
              color: active
                  ? activeColor
                  : AvionicsColors.surfaceHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.45),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Compact pill badge showing currency/resource balance with optional `+` action.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.valueText,
    this.onTapAdd,
    this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String valueText;
  final VoidCallback? onTapAdd;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AvionicsColors.surfaceLow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (borderColor ?? iconColor).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              valueText,
              style: AvionicsText.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AvionicsColors.onSurface,
                letterSpacing: 0.4,
              ),
            ),
            if (onTapAdd != null) ...[
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, size: 10, color: iconColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared top application header bar (`AVIONICS // TAC-01` + `LIVE` badge).
class AvionicsTopAppBar extends StatelessWidget {
  const AvionicsTopAppBar({
    super.key,
    this.title = 'AVIONICS // TAC-01',
    this.showBack = false,
    this.onBack,
    this.trailing,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AvionicsColors.surfaceLowest.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: AvionicsColors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AvionicsColors.cyan.withValues(alpha: 0.45),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AvionicsColors.cyan,
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.radar_rounded,
                size: 17,
                color: AvionicsColors.cyan,
              ),
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AvionicsText.headline(
                fontSize: 13,
                letterSpacing: 1.5,
                color: AvionicsColors.cyan,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AvionicsColors.emeraldDeep.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AvionicsColors.emerald.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AvionicsColors.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: AvionicsText.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AvionicsColors.emeraldBright,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Luminous capsule / pill CTA button with tactile military glow.
class GlowingCapsuleButton extends StatefulWidget {
  const GlowingCapsuleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradientColors = const [AvionicsColors.orange, AvionicsColors.orangeDark],
    this.textColor = AvionicsColors.surfaceLowest,
    this.glowColor = AvionicsColors.orange,
    this.icon,
    this.trailingIcon,
    this.height = 46,
    this.horizontalPadding = 22,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final Color textColor;
  final Color glowColor;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final double horizontalPadding;
  final double fontSize;

  @override
  State<GlowingCapsuleButton> createState() => _GlowingCapsuleButtonState();
}

class _GlowingCapsuleButtonState extends State<GlowingCapsuleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled
                  ? widget.gradientColors
                  : [AvionicsColors.surfaceHigh, AvionicsColors.surfaceContainer],
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.35)
                  : AvionicsColors.outlineVariant,
              width: 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.50),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: enabled ? widget.textColor : AvionicsColors.outline,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvionicsText.headline(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: enabled ? widget.textColor : AvionicsColors.outline,
                    ),
                  ),
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  widget.trailingIcon,
                  size: 18,
                  color: enabled ? widget.textColor : AvionicsColors.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds a symmetric 45-degree chamfered octagonal armor silhouette path.
Path buildChamferedRectPath(Size size, {double chamfer = 10}) {
  final c = chamfer.clamp(0.0, (size.shortestSide * 0.45));
  return Path()
    ..moveTo(c, 0)
    ..lineTo(size.width - c, 0)
    ..lineTo(size.width, c)
    ..lineTo(size.width, size.height - c)
    ..lineTo(size.width - c, size.height)
    ..lineTo(c, size.height)
    ..lineTo(0, size.height - c)
    ..lineTo(0, c)
    ..close();
}

class _ChamferedRectClipper extends CustomClipper<Path> {
  const _ChamferedRectClipper({this.chamfer = 10});

  final double chamfer;

  @override
  Path getClip(Size size) => buildChamferedRectPath(size, chamfer: chamfer);

  @override
  bool shouldReclip(_ChamferedRectClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}

/// Sculpted 3D mobile-game sortie launch dock housing a heavy chamfered
/// `TO BATTLE!` mechanical trigger with hazard chevron wings and jet emblem.
class BattleSortieDock extends StatefulWidget {
  const BattleSortieDock({
    super.key,
    required this.buttonKey,
    required this.jetCallsign,
    required this.energyCost,
    required this.onPressed,
    this.label = 'TO BATTLE!',
  });

  final Key buttonKey;
  final String jetCallsign;
  final int energyCost;
  final VoidCallback onPressed;
  final String label;

  @override
  State<BattleSortieDock> createState() => _BattleSortieDockState();
}

class _BattleSortieDockState extends State<BattleSortieDock> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final depthOffset = _pressed ? 3.5 : 0.0;
    return CustomPaint(
      painter: _LaunchDockFramePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        child: GestureDetector(
          key: widget.buttonKey,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: SizedBox(
            height: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 3D extruded dark burnt-bronze lower housing lip
                Positioned(
                  left: 0,
                  right: 0,
                  top: 5,
                  bottom: 0,
                  child: ClipPath(
                    clipper: const _ChamferedRectClipper(chamfer: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF561802),
                        boxShadow: [
                          BoxShadow(
                            color: AvionicsColors.orange.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tactile spring-loaded fiery armor plate
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 70),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  top: depthOffset,
                  bottom: 5.0 - depthOffset,
                  child: ClipPath(
                    clipper: const _ChamferedRectClipper(chamfer: 12),
                    child: CustomPaint(
                      painter: _BattlePlateSurfacePainter(pressed: _pressed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            // Left fighter squadron launch emblem socket
                            ClipPath(
                              clipper: const _ChamferedRectClipper(chamfer: 6),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A0D07),
                                  border: Border.all(
                                    color: AvionicsColors.goldLight.withValues(alpha: 0.55),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.airplanemode_active_rounded,
                                  size: 21,
                                  color: AvionicsColors.goldLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Center embossed hero action title + sortie telemetry badge
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      style: AvionicsText.headline(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                        color: const Color(0xFF190903),
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            offset: const Offset(0, 1),
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC190A04),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '${widget.jetCallsign} READY • -${widget.energyCost}⚡',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AvionicsText.mono(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: AvionicsColors.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right kinetic triple-chevron launch cluster
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x45180702),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.double_arrow_rounded,
                                    size: 19,
                                    color: Color(0xFFFFF0B8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchDockFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Stepped armored bulkhead housing behind TO BATTLE!
    final hull = Path()
      ..moveTo(0, 8)
      ..lineTo(18, 8)
      ..lineTo(28, 0)
      ..lineTo(size.width - 28, 0)
      ..lineTo(size.width - 18, 8)
      ..lineTo(size.width, 8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      hull,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141E2E), Color(0xFF0A111B)],
        ).createShader(Offset.zero & size),
    );

    // Top steel trim line with glowing center amber beacon accents
    final topBorder = Path()
      ..moveTo(0, 8)
      ..lineTo(18, 8)
      ..lineTo(28, 0)
      ..lineTo(size.width - 28, 0)
      ..lineTo(size.width - 18, 8)
      ..lineTo(size.width, 8);
    canvas.drawPath(
      topBorder,
      Paint()
        ..color = AvionicsColors.orange.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Subtle yellow-black caution hatch marks on left and right bulkhead shoulders
    final hazardPaint = Paint()
      ..color = AvionicsColors.gold.withValues(alpha: 0.25)
      ..strokeWidth = 3.0;
    for (var i = 0; i < 3; i++) {
      final lx = 8.0 + i * 7.0;
      canvas.drawLine(Offset(lx, 12), Offset(lx - 4, 20), hazardPaint);
      final rx = size.width - 8.0 - i * 7.0;
      canvas.drawLine(Offset(rx, 12), Offset(rx + 4, 20), hazardPaint);
    }
  }

  @override
  bool shouldRepaint(_LaunchDockFramePainter oldDelegate) => false;
}

class _BattlePlateSurfacePainter extends CustomPainter {
  const _BattlePlateSurfacePainter({required this.pressed});

  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Radiant blazing jet-plasma core gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pressed
              ? const [
                  Color(0xFFF5A31A),
                  Color(0xFFE05504),
                  Color(0xFFB32F02),
                ]
              : const [
                  Color(0xFFFFD15C),
                  Color(0xFFFF7A08),
                  Color(0xFFD63B02),
                ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    // Diagonal tactical specular gleam across upper armor face
    final gleam = Path()
      ..moveTo(size.width * 0.14, 0)
      ..lineTo(size.width * 0.46, 0)
      ..lineTo(size.width * 0.32, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      gleam,
      Paint()..color = Colors.white.withValues(alpha: pressed ? 0.08 : 0.14),
    );

    // Subtle military diagonal micro-tread texture on flanks
    final stripePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 3.5;
    for (double x = -size.height; x < size.width + size.height; x += 14) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.55, 0),
        stripePaint,
      );
    }

    // Crisp illuminated chamfer bevel rim + corner white-gold sheen
    final rimPath = buildChamferedRectPath(size, chamfer: 12);
    canvas.drawPath(
      rimPath,
      Paint()
        ..color = const Color(0xFFFFF2C2).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_BattlePlateSurfacePainter oldDelegate) =>
      oldDelegate.pressed != pressed;
}

/// Top-level bottom navigation tabs matching the 4-tab design system.
enum NavTab { home, upgrades, alliance, shop }

/// Mobile-game armored command dock (`HOME`, `UPGRADES`, `ALLIANCE`, `SHOP`)
/// styled as illuminated chamfered hardware keycaps on an aircraft deck console.
class AvionicsBottomNavBar extends StatelessWidget {
  const AvionicsBottomNavBar({
    super.key,
    required this.activeTab,
    required this.onSelectTab,
    this.showUpgradeAlert = true,
  });

  final NavTab activeTab;
  final ValueChanged<NavTab> onSelectTab;
  final bool showUpgradeAlert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: CustomPaint(
        painter: _CommandDockDeckPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.flight_rounded,
                label: 'HOME',
                accentColor: AvionicsColors.cyan,
                active: activeTab == NavTab.home,
                onTap: () => onSelectTab(NavTab.home),
              ),
              const SizedBox(width: 6),
              _NavItem(
                icon: Icons.precision_manufacturing_rounded,
                label: 'UPGRADES',
                accentColor: AvionicsColors.emeraldBright,
                active: activeTab == NavTab.upgrades,
                showBadgeDot: showUpgradeAlert,
                onTap: () => onSelectTab(NavTab.upgrades),
              ),
              const SizedBox(width: 6),
              _NavItem(
                icon: Icons.shield_rounded,
                label: 'ALLIANCE',
                accentColor: AvionicsColors.gold,
                active: activeTab == NavTab.alliance,
                onTap: () => onSelectTab(NavTab.alliance),
              ),
              const SizedBox(width: 6),
              _NavItem(
                icon: Icons.military_tech_rounded,
                label: 'SHOP',
                accentColor: AvionicsColors.orange,
                active: activeTab == NavTab.shop,
                onTap: () => onSelectTab(NavTab.shop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandDockDeckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1320), Color(0xFF040810)],
        ).createShader(Offset.zero & size),
    );

    // Top console ridge highlight & rivet accents
    canvas.drawLine(
      const Offset(0, 0.8),
      Offset(size.width, 0.8),
      Paint()
        ..color = AvionicsColors.cyan.withValues(alpha: 0.34)
        ..strokeWidth = 1.4,
    );
    final rivetPaint = Paint()..color = AvionicsColors.outlineVariant;
    for (final frac in [0.03, 0.25, 0.50, 0.75, 0.97]) {
      canvas.drawCircle(Offset(size.width * frac, 4.5), 1.3, rivetPaint);
    }
  }

  @override
  bool shouldRepaint(_CommandDockDeckPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.active,
    required this.onTap,
    this.showBadgeDot = false,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final bool active;
  final VoidCallback onTap;
  final bool showBadgeDot;

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor;
    final fgColor = active ? Colors.white : const Color(0xFF93A5BC);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: Matrix4.translationValues(0, active ? -2.0 : 0.0, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 3D sunken mechanical keycap bottom lip
              Positioned.fill(
                top: 3,
                child: ClipPath(
                  clipper: const _ChamferedRectClipper(chamfer: 7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? activeColor.withValues(alpha: 0.42)
                          : const Color(0xFF03060B),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.35),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              // Main chamfered console cap face
              Positioned.fill(
                bottom: 2.5,
                child: ClipPath(
                  clipper: const _ChamferedRectClipper(chamfer: 7),
                  child: CustomPaint(
                    painter: _NavKeycapPainter(
                      active: active,
                      accentColor: activeColor,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Emblem plate behind game icon
                        ClipPath(
                          clipper: const _ChamferedRectClipper(chamfer: 4),
                          child: Container(
                            width: 30,
                            height: 23,
                            decoration: BoxDecoration(
                              color: active
                                  ? activeColor.withValues(alpha: 0.22)
                                  : const Color(0xFF142133),
                              border: Border.all(
                                color: active
                                    ? activeColor.withValues(alpha: 0.65)
                                    : activeColor.withValues(alpha: 0.20),
                                width: 0.9,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 16,
                              color: active ? activeColor : fgColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              label,
                              maxLines: 1,
                              style: AvionicsText.mono(
                                fontSize: 9,
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w700,
                                color: active ? Colors.white : fgColor,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Active top luminous laser strip
              if (active)
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.85),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              // Game-style angled diamond alert badge on Upgrades keycap
              if (showBadgeDot)
                Positioned(
                  right: 6,
                  top: 2,
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AvionicsColors.emeraldBright,
                        borderRadius: BorderRadius.circular(1.5),
                        border: Border.all(
                          color: const Color(0xFF041A0D),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AvionicsColors.emerald.withValues(alpha: 0.85),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavKeycapPainter extends CustomPainter {
  const _NavKeycapPainter({required this.active, required this.accentColor});

  final bool active;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [
                  Color.lerp(const Color(0xFF16324A), accentColor, 0.22)!,
                  const Color(0xFF0B1A2B),
                ]
              : const [
                  Color(0xFF132032),
                  Color(0xFF0B131E),
                ],
        ).createShader(rect),
    );

    canvas.drawPath(
      buildChamferedRectPath(size, chamfer: 7),
      Paint()
        ..color = active
            ? accentColor.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.4 : 0.9,
    );
  }

  @override
  bool shouldRepaint(_NavKeycapPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.accentColor != accentColor;
}

/// Interactive Squadron Alliance & SQLite Sortie Log sheet.
Future<void> showAllianceModal(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AvionicsColors.surfaceLow,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: controller,
        builder: (ctx, _) {
          final history = controller.history;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_moon_outlined,
                          color: AvionicsColors.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SQUADRON ALLIANCE // TASK FORCE APEX',
                          style: AvionicsText.headline(
                            fontSize: 13.5,
                            color: AvionicsColors.cyan,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HudBracketCard(
                      accentColor: AvionicsColors.emerald,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ALLIANCE BUFF: +12% CREDIT BOUNTY',
                                  style: AvionicsText.mono(
                                    fontSize: 10.5,
                                    color: AvionicsColors.emeraldBright,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MISSIONS LOGGED: ${controller.profile.missionsCompleted}  •  HIGH SCORE: ${formatTelemetryInt(controller.profile.highScore)}',
                                  style: AvionicsText.mono(
                                    fontSize: 10,
                                    color: AvionicsColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AvionicsColors.emerald,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'RECENT SORTIE LOG (SQLITE PERSISTED)',
                      style: AvionicsText.mono(
                        fontSize: 10,
                        color: AvionicsColors.outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (history.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AvionicsColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AvionicsColors.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'NO SORTIES LOGGED YET • LAUNCH MISSION TO RECORD COMBAT DATA',
                          textAlign: TextAlign.center,
                          style: AvionicsText.mono(
                            fontSize: 9.5,
                            color: AvionicsColors.outline,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, index) {
                          final item = history[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AvionicsColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AvionicsColors.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AvionicsColors.cyan.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'S0${item.stageNumber}',
                                    style: AvionicsText.mono(
                                      fontSize: 10,
                                      color: AvionicsColors.cyan,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.operationName,
                                        style: AvionicsText.headline(
                                          fontSize: 11.5,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Text(
                                        '${item.jetId.toUpperCase()} • ${item.enemiesShotDown} KILLS • ${item.accuracy.toStringAsFixed(1)}% ACC',
                                        style: AvionicsText.mono(
                                          fontSize: 9.5,
                                          color: AvionicsColors.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatTelemetryInt(item.score),
                                  style: AvionicsText.mono(
                                    fontSize: 11,
                                    color: AvionicsColors.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Interactive Tactical Supply & Armory Shop sheet backed by SQLite transactions.
Future<void> showShopModal(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AvionicsColors.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: controller,
        builder: (ctx, _) {
          final p = controller.profile;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AvionicsColors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TACTICAL ARMORY // SUPPLY DROP',
                        style: AvionicsText.headline(
                          fontSize: 13.5,
                          color: AvionicsColors.gold,
                        ),
                      ),
                      const Spacer(),
                      CurrencyPill(
                        icon: Icons.diamond_rounded,
                        iconColor: AvionicsColors.cyan,
                        valueText: formatTelemetryInt(p.gems),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ShopOfferTile(
                    title: 'JP-8 FUEL CELL (+30 ENERGY)',
                    subtitle: 'RECHARGE HANGAR SORTIE CAPACITY',
                    costLabel: '20 GEMS',
                    accentColor: AvionicsColors.emerald,
                    onTap: () => controller.rechargeEnergy(amount: 30, gemCost: 20),
                  ),
                  const SizedBox(height: 8),
                  _ShopOfferTile(
                    title: 'WAR CHEST (+2,500 CREDITS)',
                    subtitle: 'EXCHANGE PREMIUM GEMS FOR ENGINEERING FUNDS',
                    costLabel: '40 GEMS',
                    accentColor: AvionicsColors.gold,
                    onTap: () => controller.buyCreditsPack(
                      creditsAdded: 2500,
                      gemCost: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ShopOfferTile(
                    title: 'RESET CAMPAIGN TELEMETRY',
                    subtitle: 'RESTORE DEFAULT SQLITE SAVE STATE',
                    costLabel: 'RESET',
                    accentColor: AvionicsColors.crimson,
                    onTap: () async {
                      await controller.resetAllProgress();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ShopOfferTile extends StatelessWidget {
  const _ShopOfferTile({
    required this.title,
    required this.subtitle,
    required this.costLabel,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String costLabel;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudBracketCard(
      accentColor: accentColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AvionicsText.headline(
                    fontSize: 12.5,
                    color: AvionicsColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AvionicsText.mono(
                    fontSize: 9.5,
                    color: AvionicsColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: AvionicsColors.surfaceLowest,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: AvionicsText.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(costLabel),
          ),
        ],
      ),
    );
  }
}
