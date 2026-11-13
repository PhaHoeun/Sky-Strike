import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/avionics_theme.dart';
import '../widgets/jet_360_viewer.dart';
import 'dogfight_engine.dart';
import 'dogfight_sprites.dart';

/// Renders the live 60fps aerial combat arena: scrolling war battlefield terrain,
/// artillery flashes, AAA flak, battle smoke, speed streaks, 3D-rendered
/// Skyfortress boss, banking stealth player jet, enemy bogies, homing missiles, tracers, and explosions.
class DogfightPainter extends CustomPainter {
  DogfightPainter({required this.engine})
      : super(
          repaint: Listenable.merge([engine, DogfightSpriteAtlas.instance]),
        ) {
    DogfightSpriteAtlas.instance.ensureCustomJetLoaded(engine.jet);
  }

  final DogfightEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    if (engine.screenShake > 0) {
      final mag = engine.screenShake * 6.0;
      final sx = math.sin(engine.elapsedSeconds * 55) * mag;
      final sy = math.cos(engine.elapsedSeconds * 48) * mag;
      canvas.translate(sx, sy);
    }

    _drawWarBattlefieldBackdrop(canvas, size);
    _drawBattlefieldGroundEvents(canvas, w, h);
    _drawCloudsAndStreaks(canvas, w, h);
    _drawSkyfortressBoss(canvas, w, h);
    _drawEnemyJets(canvas, w, h);
    _drawProjectiles(canvas, w, h);
    _drawPlayerJet(canvas, w, h);
    _drawExplosionsAndCallouts(canvas, w, h);
    _drawLockedTargetBox(canvas, w, h);
    _drawLevelBanner(canvas, w, h);
    _drawDamageWarningOverlay(canvas, w, h);

    canvas.restore();
  }

  void _drawWarBattlefieldBackdrop(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final diff = engine.levelSpec.difficulty;
    final panX = -(engine.player.x - 0.5) * (w * 0.055);
    final terrain = DogfightSpriteAtlas.instance.battlefieldTile;

    if (terrain != null) {
      final drawW = w * 1.12;
      final tileH = drawW * (terrain.height / terrain.width);
      final scrollPx = (engine.battlefieldScroll * h * 1.35) % tileH;
      final baseLeft = (w - drawW) * 0.5 + panX;
      final src = Rect.fromLTWH(0, 0, terrain.width.toDouble(), terrain.height.toDouble());
      final terrainPaint = Paint()..filterQuality = FilterQuality.medium;

      for (double top = scrollPx - tileH; top < h; top += tileH) {
        final dst = Rect.fromLTWH(baseLeft, top, drawW, tileH + 1.0);
        canvas.drawImageRect(terrain, src, dst, terrainPaint);
      }
    } else {
      _drawProceduralWarzoneFallback(canvas, w, h, panX);
    }

    // Atmosphere & time-of-day grading matched to campaign tier so foreground
    // 3D aircraft & combat ordnance stay crisp and unmistakable over ground detail.
    final (Color atmosColor, double atmosAlpha, Color glowColor) = switch (diff) {
      CombatDifficulty.easy => (const Color(0xFF0A141E), 0.22, const Color(0x30FF9B42)),
      CombatDifficulty.medium => (const Color(0xFF171210), 0.28, const Color(0x36FF8533)),
      CombatDifficulty.hard => (const Color(0xFF211411), 0.34, const Color(0x3CFF6E28)),
      CombatDifficulty.veryHard => (const Color(0xFF1C0C13), 0.40, const Color(0x42FF4E2A)),
      CombatDifficulty.extreme => (const Color(0xFF14070D), 0.48, const Color(0x4CFF3624)),
    };
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = atmosColor.withValues(alpha: atmosAlpha),
    );

    // Subtle shifting horizon artillery glow & combat edge vignette for depth
    final pulse = 0.78 + 0.22 * math.sin(engine.elapsedSeconds * 3.1);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.18, -0.35),
          radius: 1.05,
          colors: [
            glowColor.withValues(alpha: (glowColor.a * pulse).clamp(0.0, 1.0)),
            Colors.transparent,
            const Color(0x9405080D),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Faint tactical recon sector grid moving smoothly with overflight
    final gridPaint = Paint()
      ..color = diff.accentColor.withValues(alpha: 0.045)
      ..strokeWidth = 0.7;
    final gridScroll = (engine.battlefieldScroll * h * 1.35) % 64.0;
    for (double y = gridScroll; y < h; y += 64.0) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  void _drawProceduralWarzoneFallback(
    Canvas canvas,
    double w,
    double h,
    double panX,
  ) {
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B1F19),
          Color(0xFF24231D),
          Color(0xFF1A1B18),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), groundPaint);

    final scrollPx = (engine.battlefieldScroll * h * 1.35) % h;
    for (final offsetY in [scrollPx - h, scrollPx]) {
      final river = Path()
        ..moveTo(w * 0.58 + panX, offsetY)
        ..cubicTo(
          w * 0.70 + panX,
          offsetY + h * 0.33,
          w * 0.45 + panX,
          offsetY + h * 0.66,
          w * 0.58 + panX,
          offsetY + h,
        );
      canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xFF13222A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.09
          ..strokeCap = StrokeCap.round,
      );

      final craterPaint = Paint()..color = const Color(0x66100E0C);
      for (var i = 0; i < 8; i++) {
        final cx = ((i * 0.37 + 0.13) % 0.85 + 0.07) * w + panX;
        final cy = offsetY + ((i * 0.23 + 0.08) % 0.9) * h;
        canvas.drawCircle(Offset(cx, cy), w * (0.025 + (i % 3) * 0.01), craterPaint);
      }
    }
  }

  void _drawBattlefieldGroundEvents(Canvas canvas, double w, double h) {
    final t = engine.elapsedSeconds;
    final panX = -(engine.player.x - 0.5) * (w * 0.055);
    final groundOffset = engine.battlefieldScroll * 1.35;

    // 1. Live artillery bombardment flashes & smoke rings anchored to ground scroll
    const shellSites = [
      (u: 0.22, v: 0.18, period: 3.4, phase: 0.2),
      (u: 0.78, v: 0.32, period: 4.1, phase: 1.5),
      (u: 0.42, v: 0.54, period: 2.9, phase: 2.1),
      (u: 0.83, v: 0.76, period: 3.7, phase: 0.9),
    ];
    for (final site in shellSites) {
      final rawCycle = ((t + site.phase) % site.period) / site.period;
      // Active explosion takes first 55% of each site's artillery cycle
      if (rawCycle > 0.55) continue;
      final p = rawCycle / 0.55;
      final sx = site.u * w + panX;
      final sy = ((site.v + groundOffset) % 1.0) * h;

      // Ground smoke ring expanding as blast fades
      final ringRadius = w * (0.015 + p * 0.055);
      canvas.drawCircle(
        Offset(sx, sy),
        ringRadius,
        Paint()
          ..color = const Color(0xFF181512).withValues(alpha: (1.0 - p) * 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );

      // Fiery artillery flash during initial detonation
      if (p < 0.42) {
        final fp = 1.0 - (p / 0.42);
        canvas.drawCircle(
          Offset(sx, sy),
          w * (0.014 + fp * 0.016),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFF6A1A),
              const Color(0xFFFFE69A),
              fp * fp,
            )!
                .withValues(alpha: fp * 0.78)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

    // 2. Distant anti-aircraft (AAA) flak bursts & low-contrast upward tracers
    //    deliberately subtle & low-alpha below aircraft altitude so enemy combat bullets stay unmistakable.
    const flakBatteries = [
      (u: 0.14, v: 0.44, period: 2.6, phase: 0.4, dirX: 0.14),
      (u: 0.87, v: 0.24, period: 3.1, phase: 1.7, dirX: -0.16),
      (u: 0.26, v: 0.84, period: 2.8, phase: 2.2, dirX: 0.11),
      (u: 0.72, v: 0.64, period: 3.5, phase: 0.9, dirX: -0.12),
    ];
    for (final bat in flakBatteries) {
      final cycle = ((t + bat.phase) % bat.period) / bat.period;
      final originX = bat.u * w + panX;
      final originY = ((bat.v + groundOffset) % 1.0) * h;

      if (cycle < 0.48) {
        // Ascending AAA tracer streak from ground battery toward upper-mid sky
        final p = cycle / 0.48;
        final tipX = originX + bat.dirX * w * p;
        final tipY = originY - h * 0.22 * p;
        final tailX = originX + bat.dirX * w * math.max(0.0, p - 0.16);
        final tailY = originY - h * 0.22 * math.max(0.0, p - 0.16);
        canvas.drawLine(
          Offset(tailX, tailY),
          Offset(tipX, tipY),
          Paint()
            ..color = const Color(0xFFFFA149).withValues(alpha: (1.0 - p * 0.5) * 0.34)
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // Dark flak airburst smoke puff + quick orange center spark
        final fp = (cycle - 0.48) / 0.52;
        final burstX = originX + bat.dirX * w;
        final burstY = originY - h * 0.22;
        final puffR = 7.0 + fp * 13.0;
        canvas.drawCircle(
          Offset(burstX, burstY),
          puffR,
          Paint()
            ..color = const Color(0xFF1F2126).withValues(alpha: (1.0 - fp) * 0.36)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        if (fp < 0.25) {
          final spark = 1.0 - (fp / 0.25);
          canvas.drawCircle(
            Offset(burstX, burstY),
            3.5 * spark,
            Paint()..color = const Color(0xFFFFC978).withValues(alpha: spark * 0.52),
          );
        }
      }
    }
  }

  void _drawCloudsAndStreaks(Canvas canvas, double w, double h) {
    final isBurningNight =
        engine.levelSpec.difficulty == CombatDifficulty.veryHard ||
        engine.levelSpec.difficulty == CombatDifficulty.extreme;

    // Drifting dark battlefield smoke plumes (layer 0) & hazy war cloud wisps (layer 1)
    for (final c in engine.clouds) {
      final rect = Rect.fromCenter(
        center: Offset(c.x * w, c.y * h),
        width: c.width * w,
        height: c.height * h,
      );
      final baseColor = c.layer == 0
          ? (isBurningNight ? const Color(0xFF23191D) : const Color(0xFF1B1E23))
          : (isBurningNight ? const Color(0xFF47373D) : const Color(0xFF606B78));
      final effectiveOpacity = c.layer == 0 ? c.opacity * 0.92 : c.opacity * 0.44;
      final paint = Paint()
        ..color = baseColor.withValues(alpha: effectiveOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(rect, paint);
    }

    // Supersonic airflow & overdrive slipstream streaks
    final streakColor = engine.overdriveActive
        ? AvionicsColors.cyan.withValues(alpha: 0.44)
        : Colors.white.withValues(alpha: 0.16);
    final streakPaint = Paint()
      ..color = streakColor
      ..strokeWidth = engine.overdriveActive ? 2.0 : 1.1
      ..strokeCap = StrokeCap.round;

    for (final s in engine.streaks) {
      final x = s.x * w;
      final y = s.y * h;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y - s.length * h * (engine.overdriveActive ? 1.7 : 1.0)),
        streakPaint,
      );
    }
  }

  void _drawAircraftSpriteWithShadow(
    Canvas canvas, {
    required ui.Image image,
    required Rect dstRect,
    required Offset shadowOffset,
    double shadowScale = 0.86,
    ColorFilter? colorFilter,
  }) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final shadowRect = Rect.fromCenter(
      center: dstRect.center + shadowOffset,
      width: dstRect.width * shadowScale,
      height: dstRect.height * shadowScale,
    );
    canvas.drawImageRect(
      image,
      src,
      shadowRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.mode(Color(0x52000000), BlendMode.srcIn),
    );
    canvas.drawImageRect(
      image,
      src,
      dstRect,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = colorFilter,
    );
  }

  void _drawSkyfortressBoss(Canvas canvas, double w, double h) {
    final b = engine.boss;
    if (b.hp <= 0) return;

    final cx = b.x * w;
    final cy = b.y * h;
    final bw = w * 0.44;
    final bh = bw * 0.36;
    final bossSprite = DogfightSpriteAtlas.instance.bossSprite;

    if (bossSprite != null) {
      final dstW = bw * 1.48;
      final dstH = dstW * (bossSprite.height / bossSprite.width);
      final pulse = 0.65 + 0.35 * math.sin(engine.elapsedSeconds * 9.0);

      // 6 trailing upper turbine exhaust jets above the serrated flying-wing edge
      for (final side in [-1.0, 1.0]) {
        for (final frac in [0.16, 0.24, 0.31]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx + side * dstW * frac, cy - dstH * 0.24),
              width: dstW * 0.032,
              height: dstH * (0.14 + pulse * 0.04),
            ),
            Paint()
              ..color = AvionicsColors.orange.withValues(alpha: 0.72)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }

      _drawAircraftSpriteWithShadow(
        canvas,
        image: bossSprite,
        dstRect: Rect.fromCenter(center: Offset(cx, cy), width: dstW, height: dstH),
        shadowOffset: const Offset(18, 28),
        colorFilter: b.hitFlash > 0
            ? ColorFilter.mode(AvionicsColors.orange.withValues(alpha: 0.62), BlendMode.srcATop)
            : null,
      );

      // Pulsing fusion reactor core glow atop dorsal center
      canvas.drawCircle(
        Offset(cx, cy - dstH * 0.01),
        dstW * 0.045,
        Paint()
          ..color = AvionicsColors.orange.withValues(alpha: 0.55 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    } else {
      // Vector fallback before image decode completes
      final hull = Path()
        ..moveTo(cx, cy - bh * 0.55)
        ..lineTo(cx + bw * 0.48, cy - bh * 0.05)
        ..lineTo(cx + bw * 0.54, cy + bh * 0.34)
        ..lineTo(cx + bw * 0.24, cy + bh * 0.46)
        ..lineTo(cx + bw * 0.14, cy + bh * 0.62)
        ..lineTo(cx - bw * 0.14, cy + bh * 0.62)
        ..lineTo(cx - bw * 0.24, cy + bh * 0.46)
        ..lineTo(cx - bw * 0.54, cy + bh * 0.34)
        ..lineTo(cx - bw * 0.48, cy - bh * 0.05)
        ..close();

      canvas.drawPath(
        hull,
        Paint()
          ..color = b.hitFlash > 0
              ? const Color(0xFFFFC19E)
              : const Color(0xFF1F2937),
      );
      canvas.drawPath(
        hull,
        Paint()
          ..color = AvionicsColors.orange.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      final pulse = 0.7 + 0.3 * math.sin(engine.elapsedSeconds * 7);
      canvas.drawCircle(
        Offset(cx, cy + bh * 0.08),
        bw * 0.09,
        Paint()..color = AvionicsColors.orange.withValues(alpha: pulse),
      );
      canvas.drawCircle(
        Offset(cx - bw * 0.25, cy + bh * 0.18),
        bw * 0.035,
        Paint()..color = AvionicsColors.gold,
      );
      canvas.drawCircle(
        Offset(cx + bw * 0.25, cy + bh * 0.18),
        bw * 0.035,
        Paint()..color = AvionicsColors.gold,
      );
    }

    // Boss HP integrity bar cleanly hovering above carrier
    final barW = bw * 0.85;
    final barRect = Rect.fromLTWH(cx - barW / 2, cy - bh * 0.92, barW, 4);
    canvas.drawRect(
      barRect,
      Paint()..color = AvionicsColors.surfaceLowest.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        barRect.left,
        barRect.top,
        barW * (b.hp / b.maxHp).clamp(0.0, 1.0),
        4,
      ),
      Paint()..color = AvionicsColors.orange,
    );
  }

  void _drawEnemyJets(Canvas canvas, double w, double h) {
    final atlas = DogfightSpriteAtlas.instance;
    for (final e in engine.enemies) {
      final cx = e.x * w;
      final cy = e.y * h;
      final scale = 25.0 * (1.0 - e.bankAngle.abs() * 0.16);
      final enemySprite = atlas.enemySprite(e);

      if (enemySprite != null) {
        final spriteSize = scale * 2.75;
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(e.bankAngle * 0.24);

        // Enemy twin afterburner flames protruding behind upper nozzles
        final flamePulse = 0.80 + 0.20 * math.sin(engine.elapsedSeconds * 36 + e.id);
        for (final side in [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(side * spriteSize * 0.075, -spriteSize * 0.44),
              width: scale * 0.20,
              height: scale * 0.54 * flamePulse,
            ),
            Paint()
              ..color = AvionicsColors.orange.withValues(alpha: 0.88)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(side * spriteSize * 0.075, -spriteSize * 0.41),
              width: scale * 0.09,
              height: scale * 0.28 * flamePulse,
            ),
            Paint()..color = const Color(0xFFFFF2CF),
          );
        }

        _drawAircraftSpriteWithShadow(
          canvas,
          image: enemySprite,
          dstRect: Rect.fromCenter(center: Offset.zero, width: spriteSize, height: spriteSize),
          shadowOffset: const Offset(12, 18),
          colorFilter: e.hitFlash > 0
              ? ColorFilter.mode(Colors.white.withValues(alpha: 0.72), BlendMode.srcATop)
              : null,
        );
        canvas.restore();
      } else {
        // Fallback vector enemy silhouette
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - scale * 0.18, cy - scale * 0.95),
            width: scale * 0.16,
            height: scale * 0.5,
          ),
          Paint()..color = AvionicsColors.orange.withValues(alpha: 0.85),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + scale * 0.18, cy - scale * 0.95),
            width: scale * 0.16,
            height: scale * 0.5,
          ),
          Paint()..color = AvionicsColors.orange.withValues(alpha: 0.85),
        );

        final jetPath = Path()
          ..moveTo(cx, cy + scale * 1.1)
          ..lineTo(cx + scale * 0.24, cy + scale * 0.35)
          ..lineTo(cx + scale * 0.95, cy - scale * 0.25)
          ..lineTo(cx + scale * 0.86, cy - scale * 0.50)
          ..lineTo(cx + scale * 0.28, cy - scale * 0.45)
          ..lineTo(cx + scale * 0.54, cy - scale * 0.88)
          ..lineTo(cx + scale * 0.22, cy - scale * 0.88)
          ..lineTo(cx, cy - scale * 0.70)
          ..lineTo(cx - scale * 0.22, cy - scale * 0.88)
          ..lineTo(cx - scale * 0.54, cy - scale * 0.88)
          ..lineTo(cx - scale * 0.28, cy - scale * 0.45)
          ..lineTo(cx - scale * 0.86, cy - scale * 0.50)
          ..lineTo(cx - scale * 0.95, cy - scale * 0.25)
          ..lineTo(cx - scale * 0.24, cy + scale * 0.35)
          ..close();

        canvas.drawPath(
          jetPath,
          Paint()
            ..color = e.hitFlash > 0
                ? Colors.white
                : const Color(0xFF333D4B),
        );
        canvas.drawPath(
          jetPath,
          Paint()
            ..color = AvionicsColors.crimson.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }

      // Compact enemy HP bar
      final hpPct = (e.hp / e.maxHp).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(cx - 16, cy - scale * 1.42, 32, 3),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(cx - 16, cy - scale * 1.42, 32 * hpPct, 3),
        Paint()..color = AvionicsColors.crimson,
      );
    }
  }

  void _drawPlayerJet(Canvas canvas, double w, double h) {
    final p = engine.player;
    final cx = p.x * w;
    final cy = p.y * h;
    final wingCompress = 1.0 - p.bankAngle.abs() * 0.32;
    const s = 36.0;
    final resolved = DogfightSpriteAtlas.instance.resolvePlayerSprite(
      engine.jet,
      p.bankAngle,
    );
    final playerSprite = resolved.image;

    // Wingtip contrail ribbons matched to swept vs forward-swept wingtips
    final wingtipY = playerSprite != null
        ? (engine.jet.id == 'x02' ? -s * 0.14 : s * 0.34)
        : s * 0.24;
    final wingtipSpan = playerSprite != null ? s * 1.18 : s * 0.92;
    if (p.trail.length > 1) {
      for (final side in [-1.0, 1.0]) {
        final ribbon = Path();
        for (var i = 0; i < p.trail.length; i++) {
          final pt = p.trail[i];
          final px = pt.$1 * w + side * wingtipSpan * wingCompress;
          final py = pt.$2 * h + wingtipY;
          if (i == 0) {
            ribbon.moveTo(px, py);
          } else {
            ribbon.lineTo(px, py);
          }
        }
        canvas.drawPath(
          ribbon,
          Paint()
            ..color = (engine.overdriveActive
                    ? AvionicsColors.cyan
                    : Colors.white)
                .withValues(alpha: 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(p.bankAngle * (playerSprite != null ? 0.24 : 0.35));

    final camoStyle = resolveJetCamoStyle(
      engine.jet.selectedCamo,
      engine.jet.accentColor,
    );

    // Thrust plumes matched to jet nozzle configuration & 3D chase perspective
    final flameLen = (engine.overdriveActive ? 1.45 : 0.78) +
        math.sin(engine.elapsedSeconds * 42) * 0.14;
    final nozzleOffsets = switch (engine.jet.id) {
      'f35' => const [0.0],
      'su57' => [-s * 0.22 * wingCompress, s * 0.22 * wingCompress],
      _ => [-s * 0.12 * wingCompress, s * 0.12 * wingCompress],
    };
    final flameBaseY = playerSprite != null ? s * 0.98 : s * 0.72;
    final flameBaseColor = engine.overdriveActive
        ? AvionicsColors.cyan
        : camoStyle.afterburnerOuter;
    for (final nozX in nozzleOffsets) {
      final outerFlame = Paint()
        ..color = flameBaseColor.withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(nozX, flameBaseY + s * flameLen * 0.34),
          width: s * (engine.jet.id == 'f35' ? 0.24 : 0.18),
          height: s * flameLen,
        ),
        outerFlame,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(nozX, flameBaseY + s * flameLen * 0.20),
          width: s * 0.09,
          height: s * flameLen * 0.55,
        ),
        Paint()..color = camoStyle.afterburnerCore,
      );
    }

    if (playerSprite != null) {
      const spriteSize = s * 2.85;
      final filter = p.hitFlashTimer > 0
          ? ColorFilter.mode(
              AvionicsColors.orange.withValues(alpha: 0.60),
              BlendMode.srcATop,
            )
          : (resolved.hasBakedCustomLivery
                ? null
                : resolveCamoColorFilter(engine.jet));
      _drawAircraftSpriteWithShadow(
        canvas,
        image: playerSprite,
        dstRect: Rect.fromCenter(
          center: Offset.zero,
          width: spriteSize,
          height: spriteSize,
        ),
        shadowOffset: const Offset(16, 24),
        colorFilter: filter,
      );
    } else {
      // Vector fallback before image decode completes
      final wx = s * wingCompress;
      final body = _playerJetSilhouettePath(engine.jet.id, s, wx);

      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: p.hitFlashTimer > 0
                ? [AvionicsColors.crimson, AvionicsColors.orange]
                : [camoStyle.lower, camoStyle.upper, camoStyle.lower],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 1.1)),
      );
      canvas.drawPath(
        body,
        Paint()
          ..color = engine.jet.accentColor.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      final ribPaint = Paint()
        ..color = AvionicsColors.cyanFixed.withValues(alpha: 0.45)
        ..strokeWidth = 1.3;
      canvas.drawLine(
        Offset(-wx * 0.28, s * 0.45),
        Offset(-wx * 0.36, s * 0.85),
        ribPaint,
      );
      canvas.drawLine(
        Offset(wx * 0.28, s * 0.45),
        Offset(wx * 0.36, s * 0.85),
        ribPaint,
      );
      final (navX, navY) = switch (engine.jet.id) {
        'f35' => (wx * 0.88, s * 0.32),
        'su57' => (wx * 1.04, s * 0.34),
        'x02' => (wx * 1.02, -s * 0.04),
        _ => (wx * 1.01, s * 0.26),
      };
      canvas.drawCircle(
        Offset(-navX, navY),
        2.3,
        Paint()..color = AvionicsColors.crimson,
      );
      canvas.drawCircle(
        Offset(navX, navY),
        2.3,
        Paint()..color = AvionicsColors.emeraldBright,
      );

      final canopy = Path()
        ..moveTo(0, -s * 0.78)
        ..lineTo(wx * 0.10, -s * 0.46)
        ..lineTo(0, -s * 0.18)
        ..lineTo(-wx * 0.10, -s * 0.46)
        ..close();
      canvas.drawPath(
        canopy,
        Paint()..color = camoStyle.canopyBottom.withValues(alpha: 0.82),
      );
    }

    // Energy shield dome when SHIELD active
    if (engine.shieldActive) {
      canvas.drawCircle(
        Offset.zero,
        s * 1.38,
        Paint()
          ..color = AvionicsColors.cyan.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset.zero,
        s * 1.38,
        Paint()
          ..color = AvionicsColors.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    canvas.restore();

    // Compact tactical hull integrity bar right beneath player fighter
    final hullFrac = p.maxHull <= 0 ? 0.0 : (p.hull / p.maxHull).clamp(0.0, 1.0);
    final hullBarW = s * 1.3;
    final hullRect = Rect.fromLTWH(cx - hullBarW / 2, cy + s * 1.24, hullBarW, 4);
    canvas.drawRect(
      hullRect,
      Paint()..color = AvionicsColors.surfaceLowest.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromLTWH(hullRect.left, hullRect.top, hullBarW * hullFrac, 4),
      Paint()
        ..color = hullFrac <= 0.30
            ? AvionicsColors.crimson
            : (hullFrac <= 0.60 ? AvionicsColors.gold : AvionicsColors.emeraldBright),
    );
  }

  void _drawProjectiles(Canvas canvas, double w, double h) {
    for (final proj in engine.projectiles) {
      final px = proj.x * w;
      final py = proj.y * h;

      if (proj.isMissile) {
        // Curved homing missile smoke trail
        if (proj.smokeTrail.length > 1) {
          final smoke = Path();
          for (var i = 0; i < proj.smokeTrail.length; i++) {
            final pt = proj.smokeTrail[i];
            if (i == 0) {
              smoke.moveTo(pt.$1 * w, pt.$2 * h);
            } else {
              smoke.lineTo(pt.$1 * w, pt.$2 * h);
            }
          }
          canvas.drawPath(
            smoke,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4,
          );
        }

        // Missile warhead glow
        canvas.drawCircle(
          Offset(px, py),
          4.2,
          Paint()..color = AvionicsColors.orange,
        );
        canvas.drawCircle(
          Offset(px, py),
          2.0,
          Paint()..color = Colors.white,
        );
      } else if (proj.fromPlayer) {
        // 20MM glowing supersonic vulcan tracer
        final tracerColor = engine.overdriveActive
            ? AvionicsColors.cyan
            : AvionicsColors.goldLight;
        canvas.drawLine(
          Offset(px, py),
          Offset(px - proj.vx * 18, py - proj.vy * 14),
          Paint()
            ..color = tracerColor
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // Enemy plasma orb with outer glow halo for tactical fan dodging
        canvas.drawCircle(
          Offset(px, py),
          7.6,
          Paint()..color = AvionicsColors.crimson.withValues(alpha: 0.28),
        );
        canvas.drawCircle(
          Offset(px, py),
          4.3,
          Paint()..color = AvionicsColors.crimson,
        );
        canvas.drawCircle(
          Offset(px, py),
          2.0,
          Paint()..color = const Color(0xFFFFE5C2),
        );
      }
    }
  }

  void _drawExplosionsAndCallouts(Canvas canvas, double w, double h) {
    for (final pt in engine.particles) {
      final alpha = (1.0 - pt.progress).clamp(0.0, 1.0);
      final pos = Offset(pt.x * w, pt.y * h);
      if (pt.isCoreFlash) {
        canvas.drawCircle(
          pos,
          pt.radius * (0.8 + pt.progress * 2.2),
          Paint()
            ..color = AvionicsColors.orange.withValues(alpha: alpha * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
      canvas.drawCircle(
        pos,
        pt.radius * (1.0 - pt.progress * 0.55),
        Paint()
          ..color = (pt.isCoreFlash ? Colors.white : AvionicsColors.gold)
              .withValues(alpha: alpha),
      );
    }

    for (final c in engine.callouts) {
      final alpha = (c.life / 0.85).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: c.text,
          style: AvionicsText.mono(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: (c.isCritical ? AvionicsColors.gold : AvionicsColors.cyan)
                .withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.x * w - tp.width / 2, c.y * h));
    }
  }

  void _drawLockedTargetBox(Canvas canvas, double w, double h) {
    final target = engine.lockedTarget;
    if (target == null) return;

    final center = Offset(target.x * w, target.y * h);
    const boxHalf = 22.0;
    const corner = 7.0;
    final paint = Paint()
      ..color = AvionicsColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // 4 orange targeting brackets tracking the live bogie / base
    final rect = Rect.fromCenter(center: center, width: boxHalf * 2, height: boxHalf * 2);
    for (final path in [
      Path()
        ..moveTo(rect.left, rect.top + corner)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + corner, rect.top),
      Path()
        ..moveTo(rect.right - corner, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + corner),
      Path()
        ..moveTo(rect.left, rect.bottom - corner)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left + corner, rect.bottom),
      Path()
        ..moveTo(rect.right - corner, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.bottom - corner),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  void _drawLevelBanner(Canvas canvas, double w, double h) {
    if (engine.bannerTimer <= 0 ||
        engine.victoryTriggered ||
        engine.isStageTransitioning) {
      return;
    }
    final alpha = math.min(1.0, engine.bannerTimer * 1.4).clamp(0.0, 1.0);
    final spec = engine.levelSpec;
    final accent = spec.difficulty.accentColor;

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'LEVEL ${spec.stageNumber.toString().padLeft(2, '0')} // ${spec.shortLabel}',
        style: AvionicsText.headline(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: accent.withValues(alpha: alpha),
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final subPainter = TextPainter(
      text: TextSpan(
        text: spec.operationTitle,
        style: AvionicsText.mono(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: alpha * 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxW = math.max(titlePainter.width, subPainter.width) + 28;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: boxW, height: 48),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      boxRect,
      Paint()..color = AvionicsColors.surfaceLowest.withValues(alpha: alpha * 0.72),
    );
    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = accent.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    titlePainter.paint(
      canvas,
      Offset(w * 0.5 - titlePainter.width / 2, h * 0.42 - 17),
    );
    subPainter.paint(
      canvas,
      Offset(w * 0.5 - subPainter.width / 2, h * 0.42 + 4),
    );
  }

  void _drawDamageWarningOverlay(Canvas canvas, double w, double h) {
    final hitAlpha = (engine.player.hitFlashTimer * 1.4).clamp(0.0, 0.34);
    final lowHullAlpha = engine.hullPercent <= 35
        ? (0.14 + math.sin(engine.elapsedSeconds * 10).abs() * 0.16)
        : 0.0;
    final alpha = math.max(hitAlpha, lowHullAlpha);
    if (alpha <= 0.01) return;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = AvionicsColors.crimson.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
  }

  @override
  bool shouldRepaint(covariant DogfightPainter oldDelegate) => true;
}

Path _buildSymmetricJetPath(List<Offset> starboardHalf) {
  final path = Path()..moveTo(starboardHalf.first.dx, starboardHalf.first.dy);
  for (var i = 1; i < starboardHalf.length; i++) {
    path.lineTo(starboardHalf[i].dx, starboardHalf[i].dy);
  }
  for (var i = starboardHalf.length - 2; i >= 1; i--) {
    final pt = starboardHalf[i];
    if (pt.dx.abs() > 1e-4) {
      path.lineTo(-pt.dx, pt.dy);
    }
  }
  return path..close();
}

Path _playerJetSilhouettePath(String jetId, double s, double wx) {
  return switch (jetId) {
    // F-35 Valkyrie: compact muscular body, broader wings, single center nozzle
    'f35' => _buildSymmetricJetPath([
      Offset(0, -s * 1.05),
      Offset(wx * 0.20, -s * 0.50),
      Offset(wx * 0.30, -s * 0.24),
      Offset(wx * 0.90, s * 0.20),
      Offset(wx * 0.84, s * 0.44),
      Offset(wx * 0.28, s * 0.42),
      Offset(wx * 0.54, s * 0.78),
      Offset(wx * 0.34, s * 0.90),
      Offset(wx * 0.14, s * 0.72),
      Offset(wx * 0.11, s * 0.84),
      Offset(0, s * 0.84),
    ]),
    // SU-57 Phantom: wide LERX strakes, swept lambda wings, wide nacelles & center sting
    'su57' => _buildSymmetricJetPath([
      Offset(0, -s * 1.18),
      Offset(wx * 0.17, -s * 0.62),
      Offset(wx * 0.38, -s * 0.36),
      Offset(wx * 1.08, s * 0.24),
      Offset(wx * 0.98, s * 0.46),
      Offset(wx * 0.34, s * 0.44),
      Offset(wx * 0.66, s * 0.80),
      Offset(wx * 0.42, s * 0.96),
      Offset(wx * 0.26, s * 0.84),
      Offset(wx * 0.12, s * 0.84),
      Offset(0, s * 1.04),
    ]),
    // X-02 Wyvern: needle nose, forward canards, forward-swept switchblade wings
    'x02' => _buildSymmetricJetPath([
      Offset(0, -s * 1.24),
      Offset(wx * 0.15, -s * 0.68),
      Offset(wx * 0.48, -s * 0.44),
      Offset(wx * 0.42, -s * 0.30),
      Offset(wx * 0.24, -s * 0.24),
      Offset(wx * 0.46, s * 0.14),
      Offset(wx * 1.06, -s * 0.12),
      Offset(wx * 0.98, s * 0.10),
      Offset(wx * 0.48, s * 0.44),
      Offset(wx * 0.22, s * 0.42),
      Offset(wx * 0.62, s * 0.82),
      Offset(wx * 0.38, s * 0.96),
      Offset(wx * 0.16, s * 0.72),
      Offset(wx * 0.14, s * 0.86),
      Offset(wx * 0.04, s * 0.86),
      Offset(0, s * 0.74),
    ]),
    // F-22 Apex Raptor: clipped diamond-delta twin-tail stealth fighter
    _ => _buildSymmetricJetPath([
      Offset(0, -s * 1.15),
      Offset(wx * 0.18, -s * 0.55),
      Offset(wx * 0.32, -s * 0.32),
      Offset(wx * 1.05, s * 0.22),
      Offset(wx * 0.96, s * 0.45),
      Offset(wx * 0.36, s * 0.42),
      Offset(wx * 0.64, s * 0.82),
      Offset(wx * 0.38, s * 0.94),
      Offset(wx * 0.20, s * 0.72),
      Offset(wx * 0.16, s * 0.82),
      Offset(wx * 0.04, s * 0.82),
      Offset(0, s * 0.70),
    ]),
  };
}
