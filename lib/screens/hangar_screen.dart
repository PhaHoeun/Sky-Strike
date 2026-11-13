import 'package:flutter/material.dart';

import '../game/dogfight_sprites.dart';
import '../models/game_models.dart';
import '../navigation/app_routes.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/hud_widgets.dart';
import '../widgets/jet_360_viewer.dart';

/// Screen 1: Hangar / Jet Select Screen matching the Apex Avionics HUD layout.
class HangarScreen extends StatefulWidget {
  const HangarScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen> {
  bool _inspect360 = false;
  String? _previewJetId;
  int _headingDeg = 37;
  int _pitchDeg = 14;

  static const List<String> _camoPresets = [
    'STEALTH SLATE',
    'ARCTIC GHOST',
    'APEX ORANGE',
    'NIGHTHAWK',
  ];

  static String _nativeCamoForJet(String jetId) => switch (jetId) {
    'f35' => 'OBSIDIAN NAVY',
    'su57' => 'DIGITAL FLANKER',
    'x02' => 'EXPERIMENTAL TITANIUM',
    _ => 'STEALTH SLATE',
  };

  void _toggleInspect() {
    setState(() {
      _inspect360 = !_inspect360;
    });
  }

  void _handleOrientationChanged(int headingDeg, int pitchDeg) {
    if (_headingDeg == headingDeg && _pitchDeg == pitchDeg) return;
    if (!mounted) return;
    setState(() {
      _headingDeg = headingDeg;
      _pitchDeg = pitchDeg;
    });
  }

  Future<void> _cycleCamo(JetConfig jet) async {
    final native = _nativeCamoForJet(jet.id);
    final options = <String>[
      native,
      for (final c in _camoPresets)
        if (c != native) c,
    ];
    final currentIdx = options.indexOf(jet.selectedCamo);
    final nextCamo = options[(currentIdx + 1) % options.length];
    await widget.controller.selectCamo(jet.id, nextCamo);
  }

  Future<void> _onJetTapped(JetConfig jet) async {
    if (jet.unlocked) {
      if (_previewJetId != null) {
        setState(() => _previewJetId = null);
      }
      await widget.controller.selectJet(jet.id);
      return;
    }

    // First tap on a locked jet displays it on the 360° Hangar stage;
    // tapping again opens the requisition dialog.
    if (_previewJetId != jet.id) {
      setState(() => _previewJetId = jet.id);
      return;
    }
    await _showUnlockDialog(jet);
  }

  Future<void> _showUnlockDialog(JetConfig jet) async {
    if (!mounted) return;
    final canAfford = widget.controller.profile.credits >= jet.unlockCost;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AvionicsColors.surfaceContainer,
        title: Text(
          '${jet.callsign} LOCKED',
          style: AvionicsText.headline(
            fontSize: 15,
            color: AvionicsColors.gold,
          ),
        ),
        content: Text(
          'Unlocks automatically at Pilot Level ${jet.unlockLevel}, or requisition early for ${formatTelemetryInt(jet.unlockCost)} Credits.',
          style: AvionicsText.mono(
            fontSize: 11,
            color: AvionicsColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CLOSE',
              style: AvionicsText.mono(color: AvionicsColors.outline),
            ),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () async {
                    Navigator.of(ctx).pop();
                    await widget.controller.unlockJet(jet.id);
                    if (mounted) {
                      setState(() => _previewJetId = null);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AvionicsColors.cyan,
              foregroundColor: AvionicsColors.surfaceLowest,
            ),
            child: Text(
              'UNLOCK (${formatTelemetryInt(jet.unlockCost)})',
              style: AvionicsText.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AvionicsColors.surfaceLowest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchBattle() async {
    DogfightSpriteAtlas.instance.ensureCustomJetLoaded(
      widget.controller.selectedJet,
    );
    await widget.controller.beginSortie();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.battleLoading,
      // Always start sortie gauntlet from Level 1 (Easy) and progress upward in-screen
      arguments: const GameplayRouteArgs(stageNumber: 1),
    );
  }

  void _openUpgrades() {
    Navigator.of(context).pushNamed(AppRoutes.upgrades);
  }

  void _openSettings() {
    Navigator.of(context).pushNamed(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;
        final activeJet = widget.controller.selectedJet;
        final jets = widget.controller.jets;
        final displayJet = _previewJetId == null
            ? activeJet
            : jets.firstWhere(
                (j) => j.id == _previewJetId,
                orElse: () => activeJet,
              );

        return AvionicsViewportFrame(
          child: Scaffold(
            backgroundColor: AvionicsColors.surface,
            body: Stack(
              children: [
                const CrtGridBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      AvionicsTopAppBar(
                        title: 'AVIONICS // TAC-01',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LiveBadge(),
                            const SizedBox(width: 8),
                            InkWell(
                              key: const Key('open_settings_button'),
                              onTap: _openSettings,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AvionicsColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: widget.controller.soundMuted
                                        ? AvionicsColors.gold.withValues(alpha: 0.7)
                                        : AvionicsColors.cyan.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.controller.soundMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      size: 13,
                                      color: widget.controller.soundMuted
                                          ? AvionicsColors.gold
                                          : AvionicsColors.emeraldBright,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.settings_rounded,
                                      size: 15,
                                      color: AvionicsColors.onSurface,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PlayerStatusStrip(
                        profile: profile,
                        onTapAddCredits: () => showShopModal(context, widget.controller),
                        onTapAddGems: () => showShopModal(context, widget.controller),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HeroHangarStage(
                                jet: displayJet,
                                inspect360: _inspect360,
                                headingDeg: _headingDeg,
                                pitchDeg: _pitchDeg,
                                onToggleInspect: _toggleInspect,
                                onOrientationChanged: _handleOrientationChanged,
                                onCycleCamo: () => _cycleCamo(displayJet),
                                onRequestUnlock: () => _showUnlockDialog(displayJet),
                              ),
                              const SizedBox(height: 10),
                              _TelemetryStatsCard(
                                jet: displayJet,
                                onUpgradeStats: displayJet.unlocked
                                    ? _openUpgrades
                                    : () => _showUnlockDialog(displayJet),
                              ),
                              const SizedBox(height: 10),
                              _SquadronCarouselSection(
                                jets: jets,
                                selectedJetId: displayJet.id,
                                onSelectJet: _onJetTapped,
                              ),
                            ],
                          ),
                        ),
                      ),
                      BattleSortieDock(
                        buttonKey: const Key('to_battle_button'),
                        label: 'TO BATTLE!',
                        jetCallsign: activeJet.codeTag,
                        energyCost: 10,
                        onPressed: _launchBattle,
                      ),
                      AvionicsBottomNavBar(
                        activeTab: NavTab.home,
                        onSelectTab: (tab) {
                          switch (tab) {
                            case NavTab.home:
                              break;
                            case NavTab.upgrades:
                              _openUpgrades();
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

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AvionicsColors.emeraldDeep.withValues(alpha: 0.85),
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
          const SizedBox(width: 4),
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
    );
  }
}

class _PlayerStatusStrip extends StatelessWidget {
  const _PlayerStatusStrip({
    required this.profile,
    required this.onTapAddCredits,
    required this.onTapAddGems,
  });

  final PlayerProfile profile;
  final VoidCallback onTapAddCredits;
  final VoidCallback onTapAddGems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: AvionicsColors.surfaceLow.withValues(alpha: 0.92),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AvionicsColors.surfaceContainer,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AvionicsColors.cyan.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AvionicsColors.cyan.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: AvionicsColors.cyan),
                  ),
                  child: Text(
                    '${profile.rankLevel}',
                    style: AvionicsText.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AvionicsColors.cyan,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LVL ${profile.rankLevel}',
                      style: AvionicsText.headline(
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      profile.rankTitle,
                      style: AvionicsText.mono(
                        fontSize: 7.5,
                        color: AvionicsColors.cyan,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AvionicsColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AvionicsColors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: AvionicsColors.gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${profile.energy}/${profile.maxEnergy}',
                          style: AvionicsText.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AvionicsColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: profile.energyFraction,
                      minHeight: 4,
                      backgroundColor: AvionicsColors.surfaceLowest,
                      valueColor: const AlwaysStoppedAnimation(
                        AvionicsColors.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          CurrencyPill(
            icon: Icons.monetization_on_rounded,
            iconColor: AvionicsColors.gold,
            valueText: formatTelemetryInt(profile.credits),
            onTapAdd: onTapAddCredits,
          ),
          const SizedBox(width: 4),
          CurrencyPill(
            icon: Icons.diamond_rounded,
            iconColor: AvionicsColors.cyan,
            valueText: formatTelemetryInt(profile.gems),
            onTapAdd: onTapAddGems,
          ),
        ],
      ),
    );
  }
}

class _HeroHangarStage extends StatelessWidget {
  const _HeroHangarStage({
    required this.jet,
    required this.inspect360,
    required this.headingDeg,
    required this.pitchDeg,
    required this.onToggleInspect,
    required this.onOrientationChanged,
    required this.onCycleCamo,
    required this.onRequestUnlock,
  });

  final JetConfig jet;
  final bool inspect360;
  final int headingDeg;
  final int pitchDeg;
  final VoidCallback onToggleInspect;
  final void Function(int headingDeg, int pitchDeg) onOrientationChanged;
  final VoidCallback onCycleCamo;
  final VoidCallback onRequestUnlock;

  @override
  Widget build(BuildContext context) {
    final stageAccent = jet.unlocked ? jet.accentColor : AvionicsColors.gold;
    final hdgText = headingDeg.toString().padLeft(3, '0');
    final pitchText = pitchDeg >= 0 ? '+$pitchDeg' : '$pitchDeg';

    return HudBracketCard(
      accentColor: stageAccent,
      padding: EdgeInsets.zero,
      borderRadius: 6,
      child: SizedBox(
        height: 214,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Jet360Viewer(
                key: const Key('hero_jet_360_viewer'),
                jet: jet,
                autoSpin: inspect360,
                onOrientationChanged: onOrientationChanged,
              ),
            ),
            // Light corner-edge framing scrim preserves bright Hangar jet visibility while keeping HUD crisp.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AvionicsColors.surfaceLowest.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.transparent,
                      AvionicsColors.surfaceLowest.withValues(alpha: 0.24),
                    ],
                    stops: const [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOC: SEC-04 // DECK-HEX',
                      style: AvionicsText.mono(
                        fontSize: 9.5,
                        color: stageAccent,
                        fontWeight: FontWeight.w700,
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0xCC060C12),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'HDG $hdgText° // PITCH $pitchText° // DRAG 360°',
                      key: const Key('hero_jet_orientation_label'),
                      style: AvionicsText.mono(
                        fontSize: 8.5,
                        color: AvionicsColors.onSurface,
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0xCC060C12),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: jet.unlocked ? null : onRequestUnlock,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AvionicsColors.surfaceLowest.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: (jet.unlocked
                                  ? AvionicsColors.emerald
                                  : AvionicsColors.gold)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        jet.unlocked
                            ? 'RADAR: ACTIVE'
                            : 'PREVIEW // LOCKED LVL ${jet.unlockLevel}',
                        style: AvionicsText.mono(
                          fontSize: 8.5,
                          color: jet.unlocked
                              ? AvionicsColors.emeraldBright
                              : AvionicsColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IgnorePointer(
                    child: Text(
                      'LOCK // ${jet.codeTag}',
                      key: const Key('hero_jet_code_tag'),
                      style: AvionicsText.mono(
                        fontSize: 9.5,
                        color: stageAccent,
                        fontWeight: FontWeight.w700,
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0xCC060C12),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _StageChipButton(
                      key: const Key('inspect_360_button'),
                      icon: Icons.threesixty_rounded,
                      label: inspect360 ? '360° ACTIVE' : 'INSPECT 360°',
                      active: inspect360,
                      onTap: onToggleInspect,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _StageChipButton(
                      key: const Key('cycle_camo_button'),
                      icon: Icons.palette_outlined,
                      label: 'CAMO: ${jet.selectedCamo}',
                      active: false,
                      onTap: onCycleCamo,
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

class _StageChipButton extends StatelessWidget {
  const _StageChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AvionicsColors.cyan.withValues(alpha: 0.25)
              : AvionicsColors.surfaceLowest.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AvionicsColors.cyan
                : AvionicsColors.cyan.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AvionicsColors.cyan),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvionicsText.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AvionicsColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryStatsCard extends StatelessWidget {
  const _TelemetryStatsCard({
    required this.jet,
    required this.onUpgradeStats,
  });

  final JetConfig jet;
  final VoidCallback onUpgradeStats;

  @override
  Widget build(BuildContext context) {
    return HudBracketCard(
      accentColor: AvionicsColors.cyan,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jet.callsign,
                      style: AvionicsText.headline(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jet.subtitle,
                      style: AvionicsText.mono(
                        fontSize: 9.5,
                        color: AvionicsColors.cyanDim,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AvionicsColors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AvionicsColors.cyan.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '${jet.tierLabel} ${jet.roleLabel}',
                  style: AvionicsText.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AvionicsColors.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatBarRow(
            label: 'SPEED // MACH 2.25',
            value: jet.speed,
            accentColor: AvionicsColors.cyan,
            badgeText: '+${jet.boostDelta} BOOST',
          ),
          const SizedBox(height: 8),
          _StatBarRow(
            label: 'ARMOR // NANO-TITANIUM',
            value: jet.armor,
            accentColor: AvionicsColors.emerald,
          ),
          const SizedBox(height: 8),
          _StatBarRow(
            label: 'FIREPOWER // AMRAAM x6',
            value: jet.firepower,
            accentColor: AvionicsColors.orange,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.memory_rounded,
                size: 13,
                color: AvionicsColors.emeraldBright,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'AVIONICS FIRMWARE 4.2: SYNCED',
                  style: AvionicsText.mono(
                    fontSize: 9,
                    color: AvionicsColors.outline,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('upgrade_stats_button'),
                onPressed: onUpgradeStats,
                icon: Icon(
                  jet.unlocked ? Icons.upgrade_rounded : Icons.lock_open_rounded,
                  size: 14,
                ),
                label: Text(
                  jet.unlocked
                      ? 'UPGRADE STATS'
                      : 'UNLOCK (${formatTelemetryInt(jet.unlockCost)})',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      jet.unlocked ? AvionicsColors.cyan : AvionicsColors.gold,
                  side: BorderSide(
                    color: (jet.unlocked
                            ? AvionicsColors.cyan
                            : AvionicsColors.gold)
                        .withValues(alpha: 0.65),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AvionicsText.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _StatBarRow extends StatelessWidget {
  const _StatBarRow({
    required this.label,
    required this.value,
    required this.accentColor,
    this.badgeText,
  });

  final String label;
  final int value;
  final Color accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AvionicsText.mono(
                  fontSize: 10,
                  color: AvionicsColors.onSurfaceVariant,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AvionicsColors.emeraldDeep.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  badgeText!,
                  style: AvionicsText.mono(
                    fontSize: 8.5,
                    color: AvionicsColors.emeraldBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Text(
              '$value/100',
              style: AvionicsText.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AvionicsColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SegmentedStatBar(value: value, activeColor: accentColor),
      ],
    );
  }
}

class _SquadronCarouselSection extends StatelessWidget {
  const _SquadronCarouselSection({
    required this.jets,
    required this.selectedJetId,
    required this.onSelectJet,
  });

  final List<JetConfig> jets;
  final String selectedJetId;
  final ValueChanged<JetConfig> onSelectJet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '// SQUADRON JET FLEET',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvionicsText.mono(
                  fontSize: 9.5,
                  color: AvionicsColors.cyan,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${jets.length} ACTIVE HANGARS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvionicsText.mono(
                  fontSize: 9,
                  color: AvionicsColors.outline,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: jets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final jet = jets[index];
              final isSelected = jet.id == selectedJetId;
              return _JetCarouselCard(
                key: Key('jet_card_${jet.id}'),
                jet: jet,
                selected: isSelected,
                onTap: () => onSelectJet(jet),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JetCarouselCard extends StatelessWidget {
  const _JetCarouselCard({
    super.key,
    required this.jet,
    required this.selected,
    required this.onTap,
  });

  final JetConfig jet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = jet.unlocked ? AvionicsColors.cyan : AvionicsColors.gold;
    final borderColor = selected
        ? activeColor
        : (jet.unlocked
              ? AvionicsColors.outlineVariant.withValues(alpha: 0.6)
              : AvionicsColors.outlineVariant.withValues(alpha: 0.35));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 126,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? AvionicsColors.surfaceHigh
              : AvionicsColors.surfaceContainer.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  jet.tierLabel,
                  style: AvionicsText.mono(
                    fontSize: 8.5,
                    color: selected ? activeColor : AvionicsColors.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  jet.unlocked ? Icons.airplanemode_active_rounded : Icons.lock_outline_rounded,
                  size: 14,
                  color: jet.unlocked
                      ? (selected ? AvionicsColors.cyan : AvionicsColors.onSurfaceVariant)
                      : AvionicsColors.gold,
                ),
              ],
            ),
            Text(
              jet.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AvionicsText.headline(
                fontSize: 11.5,
                color: (jet.unlocked || selected)
                    ? AvionicsColors.onSurface
                    : AvionicsColors.outline,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              jet.unlocked
                  ? 'PWR ${jet.powerRating.toStringAsFixed(1)}'
                  : (selected
                        ? 'PREVIEW // LVL ${jet.unlockLevel}'
                        : 'UNLOCK AT LVL ${jet.unlockLevel}'),
              style: AvionicsText.mono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: jet.unlocked ? AvionicsColors.emeraldBright : AvionicsColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

