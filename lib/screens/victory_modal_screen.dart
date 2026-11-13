import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../navigation/app_routes.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/hud_widgets.dart';

/// Screen 3: Mission Accomplished / Victory Modal overlaid on blurred aerial combat.
class VictoryModalScreen extends StatelessWidget {
  const VictoryModalScreen({
    super.key,
    required this.controller,
    required this.summary,
  });

  final GameController controller;
  final MissionSummary summary;

  String _formatDuration(double seconds) {
    final totalMs = (seconds * 100).round();
    final mins = totalMs ~/ 6000;
    final remCs = totalMs % 6000;
    final secs = remCs ~/ 100;
    final cs = remCs % 100;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  void _nextMission(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameplay,
      arguments: GameplayRouteArgs(stageNumber: summary.stageNumber + 1),
    );
  }

  void _replayMission(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameplay,
      arguments: GameplayRouteArgs(stageNumber: summary.stageNumber),
    );
  }

  void _returnToHangar(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final stageStr = summary.stageNumber.toString().padLeft(2, '0');
    return AvionicsViewportFrame(
      child: Scaffold(
        backgroundColor: AvionicsColors.surfaceLowest,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Softly blurred aerial combat backdrop
            Image.asset(
              'assets/images/dogfight_sky.jpg',
              fit: BoxFit.cover,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: ColoredBox(
                color: AvionicsColors.surfaceLowest.withValues(alpha: 0.72),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  AvionicsTopAppBar(
                    title: 'AVIONICS // TAC-01',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AvionicsColors.cyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AvionicsColors.cyan.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        'SEC-CLR: S${summary.stageNumber}',
                        style: AvionicsText.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AvionicsColors.cyan,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Three gleaming gold achievement stars
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _AchievementStar(size: 30, offsetY: 6),
                                SizedBox(width: 8),
                                _AchievementStar(size: 40, offsetY: 0),
                                SizedBox(width: 8),
                                _AchievementStar(size: 30, offsetY: 6),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Centered metallic-beveled popup window
                            HudBracketCard(
                              accentColor: AvionicsColors.cyan,
                              backgroundColor: AvionicsColors.surfaceContainer
                                  .withValues(alpha: 0.94),
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              bracketSize: 12,
                              blurSigma: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Gold banner reading MISSION ACCOMPLISHED!
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE09600),
                                          AvionicsColors.goldLight,
                                          AvionicsColors.gold,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AvionicsColors.gold
                                              .withValues(alpha: 0.45),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'MISSION ACCOMPLISHED!',
                                      textAlign: TextAlign.center,
                                      style: AvionicsText.headline(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: AvionicsColors.surfaceLowest,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${summary.operationName} // STAGE $stageStr CLEAR',
                                    textAlign: TextAlign.center,
                                    style: AvionicsText.mono(
                                      fontSize: 10,
                                      color: AvionicsColors.cyanFixed,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Score & timing box
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AvionicsColors.surfaceLowest
                                          .withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AvionicsColors.cyan
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'COMBAT SCORE',
                                                  style: AvionicsText.mono(
                                                    fontSize: 8.5,
                                                    color: AvionicsColors.outline,
                                                  ),
                                                ),
                                                Text(
                                                  '${formatTelemetryInt(summary.score)} PTS',
                                                  style: AvionicsText.headline(
                                                    fontSize: 17,
                                                    color: AvionicsColors.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AvionicsColors.emeraldDeep,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AvionicsColors.emerald,
                                                ),
                                              ),
                                              child: Text(
                                                summary.rankGrade,
                                                style: AvionicsText.mono(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AvionicsColors.emeraldBright,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'TIME ${_formatDuration(summary.elapsedSeconds)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AvionicsText.mono(
                                                  fontSize: 9,
                                                  color: AvionicsColors.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'ACC ${summary.accuracy.toStringAsFixed(1)}%',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AvionicsText.mono(
                                                  fontSize: 9,
                                                  color: AvionicsColors.cyan,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Stats box with the 4 required combat/reward rows
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AvionicsColors.surfaceLow
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AvionicsColors.outlineVariant
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _VictoryStatRow(
                                          icon: Icons.dangerous_outlined,
                                          iconColor: AvionicsColors.orange,
                                          label: 'Boss Destroyed',
                                          value: summary.bossDestroyed
                                              ? '1 / 1 CONFIRMED'
                                              : '0 / 1',
                                          valueColor: AvionicsColors.emeraldBright,
                                        ),
                                        const Divider(height: 12),
                                        _VictoryStatRow(
                                          icon: Icons.gps_fixed_rounded,
                                          iconColor: AvionicsColors.cyan,
                                          label: 'Enemies Shot Down',
                                          value: '${summary.enemiesShotDown} TARGETS',
                                          valueColor: AvionicsColors.onSurface,
                                        ),
                                        const Divider(height: 12),
                                        _VictoryStatRow(
                                          icon: Icons.monetization_on_rounded,
                                          iconColor: AvionicsColors.gold,
                                          label: '+${summary.creditsEarned} Credits',
                                          value: 'CREDITED',
                                          valueColor: AvionicsColors.gold,
                                        ),
                                        const Divider(height: 12),
                                        _VictoryStatRow(
                                          icon: Icons.settings_suggest_rounded,
                                          iconColor: AvionicsColors.cyanFixed,
                                          label: '+${summary.scrapEarned} Scrap Metal',
                                          value: 'SALVAGED',
                                          valueColor: AvionicsColors.cyanFixed,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Pilot XP progress bar
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          summary.newLevel > summary.previousLevel
                                              ? 'PILOT LVL ${summary.previousLevel} → LVL ${summary.newLevel}'
                                              : 'PILOT LVL ${summary.newLevel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AvionicsText.mono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AvionicsColors.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+${formatTelemetryInt(summary.xpEarned)} XP',
                                        style: AvionicsText.mono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AvionicsColors.emeraldBright,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: summary.xpProgress,
                                      minHeight: 6,
                                      backgroundColor: AvionicsColors.surfaceLowest,
                                      valueColor: const AlwaysStoppedAnimation(
                                        AvionicsColors.cyan,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Action row: Replay icon button + cyan Next Mission capsule
                                  Row(
                                    children: [
                                      InkWell(
                                        key: const Key('replay_mission_button'),
                                        onTap: () => _replayMission(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: AvionicsColors.surfaceHigh,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AvionicsColors.cyan
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.refresh_rounded,
                                            color: AvionicsColors.cyan,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GlowingCapsuleButton(
                                          key: const Key('next_mission_button'),
                                          label: 'Next Mission',
                                          trailingIcon: Icons.double_arrow_rounded,
                                          gradientColors: const [
                                            AvionicsColors.cyan,
                                            AvionicsColors.cyanDim,
                                          ],
                                          glowColor: AvionicsColors.cyan,
                                          onPressed: () => _nextMission(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: TextButton(
                                      key: const Key('return_to_hangar_button'),
                                      onPressed: () => _returnToHangar(context),
                                      child: Text(
                                        '« RETURN TO HANGAR',
                                        style: AvionicsText.mono(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AvionicsColors.onSurfaceVariant,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AvionicsBottomNavBar(
                    activeTab: NavTab.home,
                    onSelectTab: (tab) {
                      switch (tab) {
                        case NavTab.home:
                          _returnToHangar(context);
                        case NavTab.upgrades:
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.upgrades,
                            (r) => r.isFirst,
                          );
                        case NavTab.alliance:
                          showAllianceModal(context, controller);
                        case NavTab.shop:
                          showShopModal(context, controller);
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
  }
}

class _AchievementStar extends StatelessWidget {
  const _AchievementStar({required this.size, required this.offsetY});

  final double size;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: AvionicsColors.gold,
        shadows: [
          Shadow(
            color: AvionicsColors.gold.withValues(alpha: 0.75),
            blurRadius: 14,
          ),
        ],
      ),
    );
  }
}

class _VictoryStatRow extends StatelessWidget {
  const _VictoryStatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AvionicsText.headline(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AvionicsColors.onSurface,
              letterSpacing: 0.4,
            ),
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

