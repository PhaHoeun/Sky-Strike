import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/hud_widgets.dart';

/// Screen 4: Hangar Upgrade & Engineering Screen with interactive CAD schematic.
class HangarUpgradeScreen extends StatefulWidget {
  const HangarUpgradeScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HangarUpgradeScreen> createState() => _HangarUpgradeScreenState();
}

class _HangarUpgradeScreenState extends State<HangarUpgradeScreen> {
  SubsystemId _selectedSubsystem = SubsystemId.engine;
  String? _feedbackToast;

  Future<void> _handleUpgrade() async {
    final result = await widget.controller.upgradeSubsystem(_selectedSubsystem);
    if (!mounted) return;
    setState(() {
      _feedbackToast = result.success
          ? '${_selectedSubsystem.shortLabel} UPGRADED!'
          : result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;
        final jet = widget.controller.selectedJet;
        final upgrades = widget.controller.upgradesFor(jet.id);
        final activeUpgrade = upgrades[_selectedSubsystem] ??
            SubsystemUpgrade(
              jetId: jet.id,
              subsystem: _selectedSubsystem,
              level: 1,
            );
        final delta = _selectedSubsystem.deltaPerLevel;

        return AvionicsViewportFrame(
          child: Scaffold(
            backgroundColor: AvionicsColors.surfaceLowest,
            body: Stack(
              children: [
                const CrtGridBackground(
                  backgroundColor: AvionicsColors.surfaceLowest,
                  minorSpacing: 16,
                  majorSpacing: 64,
                  gridOpacity: 0.08,
                ),
                SafeArea(
                  child: Column(
                    children: [
                      AvionicsTopAppBar(
                        title: 'ENGINEERING // ${jet.codeTag}',
                        showBack: true,
                        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrencyPill(
                              icon: Icons.monetization_on_rounded,
                              iconColor: AvionicsColors.gold,
                              valueText: formatTelemetryInt(profile.credits),
                              onTapAdd: () => showShopModal(context, widget.controller),
                            ),
                            const SizedBox(width: 6),
                            CurrencyPill(
                              icon: Icons.settings_suggest_rounded,
                              iconColor: AvionicsColors.cyanFixed,
                              valueText: formatTelemetryInt(profile.scrapMetal),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BlueprintWireframeStage(
                                jet: jet,
                                upgrades: upgrades,
                                selectedSubsystem: _selectedSubsystem,
                                onSelectSubsystem: (sub) => setState(() {
                                  _selectedSubsystem = sub;
                                  _feedbackToast = null;
                                }),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatDeltaCard(
                                      label: 'SPEED',
                                      currentValue: jet.speed,
                                      delta: math.min(
                                        100 - jet.speed,
                                        delta.speed,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatDeltaCard(
                                      label: 'ARMOR',
                                      currentValue: jet.armor,
                                      delta: math.min(
                                        100 - jet.armor,
                                        delta.armor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatDeltaCard(
                                      label: 'FIREPOWER',
                                      currentValue: jet.firepower,
                                      delta: math.min(
                                        100 - jet.firepower,
                                        delta.firepower,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _UpgradeActionCard(
                                upgrade: activeUpgrade,
                                creditsAvailable: profile.credits,
                                statusNote: _feedbackToast,
                                onUpgrade: _handleUpgrade,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AvionicsBottomNavBar(
                        activeTab: NavTab.upgrades,
                        showUpgradeAlert: false,
                        onSelectTab: (tab) {
                          switch (tab) {
                            case NavTab.home:
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            case NavTab.upgrades:
                              break;
                            case NavTab.alliance:
                              showAllianceModal(context, widget.controller);
                            case NavTab.shop:
                              showShopModal(context, widget.controller);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlueprintWireframeStage extends StatelessWidget {
  const _BlueprintWireframeStage({
    required this.jet,
    required this.upgrades,
    required this.selectedSubsystem,
    required this.onSelectSubsystem,
  });

  final JetConfig jet;
  final Map<SubsystemId, SubsystemUpgrade> upgrades;
  final SubsystemId selectedSubsystem;
  final ValueChanged<SubsystemId> onSelectSubsystem;

  @override
  Widget build(BuildContext context) {
    return HudBracketCard(
      accentColor: AvionicsColors.cyan,
      backgroundColor: AvionicsColors.surfaceLowest.withValues(alpha: 0.78),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 318,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                // Top-down wireframe CAD jet + concentric rings + neon leader lines
                CustomPaint(
                  size: Size(w, h),
                  painter: _FighterBlueprintPainter(
                    selectedSubsystem: selectedSubsystem,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  child: Text(
                    'CAD // SPEC: ${jet.codeTag}A_REV4',
                    style: AvionicsText.mono(
                      fontSize: 9,
                      color: AvionicsColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 10,
                  child: Text(
                    'DIAGNOSTIC: OPTIMAL',
                    style: AvionicsText.mono(
                      fontSize: 9,
                      color: AvionicsColors.emeraldBright,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 4 non-overlapping quadrant subsystem node chips
                for (final sub in SubsystemId.values)
                  _PositionedNodeButton(
                    stageSize: Size(w, h),
                    subsystem: sub,
                    level: upgrades[sub]?.level ?? 1,
                    selected: sub == selectedSubsystem,
                    onTap: () => onSelectSubsystem(sub),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PositionedNodeButton extends StatelessWidget {
  const _PositionedNodeButton({
    required this.stageSize,
    required this.subsystem,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final Size stageSize;
  final SubsystemId subsystem;
  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final anchor = subsystem.nodeAnchor;
    const nodeWidth = 108.0;
    const nodeHeight = 46.0;
    final left = (anchor.dx * stageSize.width - nodeWidth / 2)
        .clamp(8.0, stageSize.width - nodeWidth - 8.0);
    final top = (anchor.dy * stageSize.height - nodeHeight / 2)
        .clamp(28.0, stageSize.height - nodeHeight - 8.0);
    final accent = selected ? AvionicsColors.emerald : AvionicsColors.cyan;

    return Positioned(
      left: left,
      top: top,
      width: nodeWidth,
      height: nodeHeight,
      child: GestureDetector(
        key: Key('node_${subsystem.dbKey}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AvionicsColors.emeraldDeep.withValues(alpha: 0.9)
                : AvionicsColors.surfaceContainer.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.95 : 0.45),
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AvionicsColors.emerald.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(subsystem.icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subsystem.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AvionicsText.mono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AvionicsColors.onSurface,
                      ),
                    ),
                    Text(
                      'LVL $level',
                      style: AvionicsText.mono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering concentric blueprint calibration rings, a top-down F-22
/// stealth fighter CAD wireframe, and glowing leader lines to the 4 subsystem nodes.
class _FighterBlueprintPainter extends CustomPainter {
  const _FighterBlueprintPainter({required this.selectedSubsystem});

  final SubsystemId selectedSubsystem;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);

    // Concentric radar / blueprint calibration rings
    final ringPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final r in [46.0, 88.0, 130.0]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // Center axis crosshair
    final axisPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx, 26),
      Offset(center.dx, size.height - 16),
      axisPaint,
    );
    canvas.drawLine(
      Offset(18, center.dy),
      Offset(size.width - 18, center.dy),
      axisPaint,
    );

    // Fighter silhouette dimensions
    final s = math.min(size.width, size.height) * 0.84;
    final topY = center.dy - s * 0.40;
    final leftX = center.dx;

    // Outer stealth fighter outline (F-22 inspired swept wing + canted twin tail)
    final airframe = Path()
      ..moveTo(leftX, topY) // Nose cone
      ..lineTo(leftX + s * 0.06, topY + s * 0.18) // Forward fuselage / strake
      ..lineTo(leftX + s * 0.11, topY + s * 0.25) // Intake
      ..lineTo(leftX + s * 0.34, topY + s * 0.46) // Right main wingtip
      ..lineTo(leftX + s * 0.31, topY + s * 0.54) // Right wing trailing edge
      ..lineTo(leftX + s * 0.13, topY + s * 0.56) // Fuselage junction
      ..lineTo(leftX + s * 0.23, topY + s * 0.72) // Right stabilator tip
      ..lineTo(leftX + s * 0.17, topY + s * 0.79) // Right stabilator trailing
      ..lineTo(leftX + s * 0.08, topY + s * 0.74) // Engine fairing
      ..lineTo(leftX + s * 0.06, topY + s * 0.78) // Right exhaust nozzle
      ..lineTo(leftX + s * 0.02, topY + s * 0.78)
      ..lineTo(leftX, topY + s * 0.74) // Tail sting
      ..lineTo(leftX - s * 0.02, topY + s * 0.78)
      ..lineTo(leftX - s * 0.06, topY + s * 0.78) // Left exhaust nozzle
      ..lineTo(leftX - s * 0.08, topY + s * 0.74)
      ..lineTo(leftX - s * 0.17, topY + s * 0.79)
      ..lineTo(leftX - s * 0.23, topY + s * 0.72)
      ..lineTo(leftX - s * 0.13, topY + s * 0.56)
      ..lineTo(leftX - s * 0.31, topY + s * 0.54)
      ..lineTo(leftX - s * 0.34, topY + s * 0.46)
      ..lineTo(leftX - s * 0.11, topY + s * 0.25)
      ..lineTo(leftX - s * 0.06, topY + s * 0.18)
      ..close();

    // Subtle holographic cyan fill + glowing wireframe stroke
    canvas.drawPath(
      airframe,
      Paint()
        ..color = AvionicsColors.cyan.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      airframe,
      Paint()
        ..color = AvionicsColors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Cockpit canopy diamond + structural ribs
    final canopy = Path()
      ..moveTo(leftX, topY + s * 0.11)
      ..lineTo(leftX + s * 0.036, topY + s * 0.20)
      ..lineTo(leftX, topY + s * 0.29)
      ..lineTo(leftX - s * 0.036, topY + s * 0.20)
      ..close();
    canvas.drawPath(
      canopy,
      Paint()
        ..color = AvionicsColors.cyanFixed.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // Internal fuselage ribs & twin vertical tail fins
    final ribPaint = Paint()
      ..color = AvionicsColors.cyan.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset(leftX - s * 0.18, topY + s * 0.49),
      Offset(leftX + s * 0.18, topY + s * 0.49),
      ribPaint,
    );
    canvas.drawLine(
      Offset(leftX - s * 0.08, topY + s * 0.57),
      Offset(leftX - s * 0.11, topY + s * 0.73),
      ribPaint,
    );
    canvas.drawLine(
      Offset(leftX + s * 0.08, topY + s * 0.57),
      Offset(leftX + s * 0.11, topY + s * 0.73),
      ribPaint,
    );

    // Neon leader lines connecting internal anchors to the 4 node cards
    for (final sub in SubsystemId.values) {
      final active = sub == selectedSubsystem;
      final lineColor = active
          ? AvionicsColors.emeraldBright
          : AvionicsColors.cyan.withValues(alpha: 0.55);

      final start = Offset(
        sub.aircraftAnchor.dx * size.width,
        sub.aircraftAnchor.dy * size.height,
      );
      final end = Offset(
        sub.nodeAnchor.dx * size.width,
        sub.nodeAnchor.dy * size.height,
      );
      final elbow = Offset(
        (start.dx + end.dx) * 0.52,
        start.dy,
      );

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(end.dx, end.dy),
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.8 : 1.1,
      );

      // Anchor pulse dot on the aircraft fuselage
      canvas.drawCircle(
        start,
        active ? 5.0 : 3.2,
        Paint()..color = lineColor,
      );
      if (active) {
        canvas.drawCircle(
          start,
          9.0,
          Paint()
            ..color = AvionicsColors.emerald.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FighterBlueprintPainter oldDelegate) =>
      oldDelegate.selectedSubsystem != selectedSubsystem;
}

class _StatDeltaCard extends StatelessWidget {
  const _StatDeltaCard({
    required this.label,
    required this.currentValue,
    required this.delta,
  });

  final String label;
  final int currentValue;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final nextValue = currentValue + delta;
    return HudBracketCard(
      accentColor: delta > 0 ? AvionicsColors.emerald : AvionicsColors.cyan,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      bracketSize: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AvionicsText.mono(
              fontSize: 8.5,
              color: AvionicsColors.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentValue',
                style: AvionicsText.headline(
                  fontSize: 18,
                  color: AvionicsColors.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '→ $nextValue',
                style: AvionicsText.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AvionicsColors.emeraldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AvionicsColors.emeraldDeep.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '+$delta SPEC',
              style: AvionicsText.mono(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: AvionicsColors.emeraldBright,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeActionCard extends StatelessWidget {
  const _UpgradeActionCard({
    required this.upgrade,
    required this.creditsAvailable,
    required this.onUpgrade,
    this.statusNote,
  });

  final SubsystemUpgrade upgrade;
  final int creditsAvailable;
  final VoidCallback onUpgrade;
  final String? statusNote;

  @override
  Widget build(BuildContext context) {
    final canAfford = !upgrade.isMaxed && creditsAvailable >= upgrade.nextCost;
    return HudBracketCard(
      accentColor: AvionicsColors.emerald,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '// SUBSYSTEM FOCUS',
                style: AvionicsText.mono(
                  fontSize: 9.5,
                  color: AvionicsColors.emeraldBright,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'MAX LVL ${upgrade.subsystem.maxLevel}',
                style: AvionicsText.mono(
                  fontSize: 9,
                  color: AvionicsColors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${upgrade.subsystem.engineeringTitle} ${upgrade.mkTransition}',
            style: AvionicsText.headline(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (statusNote != null) ...[
            const SizedBox(height: 4),
            Text(
              statusNote!,
              style: AvionicsText.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AvionicsColors.cyan,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              // Credit cost badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AvionicsColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AvionicsColors.gold.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 16,
                      color: AvionicsColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      upgrade.isMaxed
                          ? 'MAX SPEC'
                          : formatTelemetryInt(upgrade.nextCost),
                      style: AvionicsText.mono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: canAfford ? AvionicsColors.gold : AvionicsColors.crimson,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlowingCapsuleButton(
                  key: const Key('upgrade_action_button'),
                  label: upgrade.isMaxed ? 'MAXED' : 'UPGRADE',
                  icon: Icons.upgrade_rounded,
                  gradientColors: const [
                    AvionicsColors.emeraldBright,
                    AvionicsColors.emerald,
                  ],
                  glowColor: AvionicsColors.emerald,
                  textColor: AvionicsColors.emeraldDeep,
                  onPressed: canAfford ? onUpgrade : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

