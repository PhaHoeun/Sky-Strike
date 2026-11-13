import 'package:flutter/material.dart';

import '../audio/battle_audio.dart';
import '../state/game_controller.dart';
import '../theme/avionics_theme.dart';
import '../widgets/hud_widgets.dart';

/// Dedicated tactical Settings screen allowing players to mute or unmute battle
/// audio (persisted cleanly in SQLite) and review local campaign telemetry.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _audioNotice;

  void _previewBattleAudio() {
    if (widget.controller.soundMuted) {
      setState(() {
        _audioNotice = 'SOUND IS MUTED — TAP UNMUTE TO PREVIEW AUDIO';
      });
      return;
    }
    BattleAudio.instance.playSfx(BattleSfx.explosionBig);
    setState(() {
      _audioNotice = 'TEST AUDIO DISPATCHED // BATTLE SFX ACTIVE';
    });
  }

  Future<void> _toggleSound() async {
    final willMute = !widget.controller.soundMuted;
    await widget.controller.setSoundMuted(willMute);
    if (!mounted) return;
    setState(() {
      _audioNotice = willMute
          ? 'ALL BATTLE SOUND EFFECTS MUTED'
          : 'BATTLE SOUND EFFECTS UNMUTED';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;
        final muted = widget.controller.soundMuted;
        final statusColor = muted ? AvionicsColors.gold : AvionicsColors.emeraldBright;

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
                        title: 'AVIONICS // SETTINGS',
                        showBack: true,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HudBracketCard(
                                accentColor: statusColor,
                                backgroundColor: AvionicsColors.surfaceContainer
                                    .withValues(alpha: 0.94),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: statusColor.withValues(alpha: 0.55),
                                            ),
                                          ),
                                          child: Icon(
                                            muted
                                                ? Icons.volume_off_rounded
                                                : Icons.volume_up_rounded,
                                            size: 22,
                                            color: statusColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'BATTLE AUDIO CONTROL',
                                                style: AvionicsText.headline(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: AvionicsColors.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                muted
                                                    ? 'STATUS: MUTED // SILENT SORTIE'
                                                    : 'STATUS: ACTIVE // COMBAT SFX + ENGINE',
                                                style: AvionicsText.mono(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          key: const Key('sound_mute_switch'),
                                          value: !muted,
                                          activeThumbColor: AvionicsColors.emeraldBright,
                                          activeTrackColor:
                                              AvionicsColors.emeraldDeep,
                                          inactiveThumbColor: AvionicsColors.gold,
                                          inactiveTrackColor:
                                              AvionicsColors.surfaceHigh,
                                          onChanged: (enabled) =>
                                              widget.controller.setSoundMuted(!enabled),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AvionicsColors.surfaceLow,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: AvionicsColors.outlineVariant
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _AudioChannelRow(
                                            label: '20MM CANNON & FOX-2 SALVO',
                                            enabled: !muted,
                                          ),
                                          const Divider(height: 10),
                                          _AudioChannelRow(
                                            label: 'EXPLOSIONS & HULL IMPACTS',
                                            enabled: !muted,
                                          ),
                                          const Divider(height: 10),
                                          _AudioChannelRow(
                                            label: 'JET TURBINE & OVERDRIVE RUMBLE',
                                            enabled: !muted,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GlowingCapsuleButton(
                                            key: const Key('sound_mute_toggle_button'),
                                            height: 44,
                                            fontSize: 12,
                                            horizontalPadding: 12,
                                            icon: muted
                                                ? Icons.volume_up_rounded
                                                : Icons.volume_off_rounded,
                                            label: muted ? 'UNMUTE SOUND' : 'MUTE SOUND',
                                            gradientColors: muted
                                                ? const [
                                                    AvionicsColors.emeraldBright,
                                                    Color(0xFF0A8F4A),
                                                  ]
                                                : const [
                                                    AvionicsColors.gold,
                                                    AvionicsColors.orangeDark,
                                                  ],
                                            glowColor: muted
                                                ? AvionicsColors.emerald
                                                : AvionicsColors.gold,
                                            onPressed: _toggleSound,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          key: const Key('settings_test_sfx_button'),
                                          onTap: _previewBattleAudio,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            height: 44,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AvionicsColors.surfaceHigh,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AvionicsColors.cyan
                                                    .withValues(alpha: 0.65),
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.graphic_eq_rounded,
                                                  size: 16,
                                                  color: AvionicsColors.cyan,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'TEST SFX',
                                                  style: AvionicsText.mono(
                                                    fontSize: 10,
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
                                    if (_audioNotice != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: statusColor.withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: Text(
                                          _audioNotice!,
                                          textAlign: TextAlign.center,
                                          style: AvionicsText.mono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              HudBracketCard(
                                accentColor: AvionicsColors.cyan,
                                backgroundColor: AvionicsColors.surfaceContainer
                                    .withValues(alpha: 0.90),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AVIONICS SYSTEM TELEMETRY',
                                      style: AvionicsText.headline(
                                        fontSize: 13.5,
                                        color: AvionicsColors.cyan,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _TelemetryInfoRow(
                                      label: 'STORAGE',
                                      value: 'LOCAL SQLITE ACTIVE',
                                      valueColor: AvionicsColors.emeraldBright,
                                    ),
                                    const Divider(height: 12),
                                    _TelemetryInfoRow(
                                      label: 'STAGE UNLOCKED',
                                      value:
                                          'STAGE ${profile.currentStage.toString().padLeft(2, '0')}',
                                      valueColor: AvionicsColors.cyanFixed,
                                    ),
                                    const Divider(height: 12),
                                    _TelemetryInfoRow(
                                      label: 'MISSIONS CLEARED',
                                      value: '${profile.missionsCompleted}',
                                      valueColor: AvionicsColors.onSurface,
                                    ),
                                    const Divider(height: 12),
                                    _TelemetryInfoRow(
                                      label: 'HIGH SCORE',
                                      value: '${formatTelemetryInt(profile.highScore)} PTS',
                                      valueColor: AvionicsColors.gold,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        decoration: BoxDecoration(
                          color: AvionicsColors.surfaceLowest.withValues(alpha: 0.9),
                          border: Border(
                            top: BorderSide(
                              color: AvionicsColors.cyan.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: GlowingCapsuleButton(
                            key: const Key('settings_back_home_button'),
                            label: 'RETURN TO HANGAR',
                            icon: Icons.arrow_back_rounded,
                            gradientColors: const [
                              AvionicsColors.cyan,
                              Color(0xFF0091B5),
                            ],
                            glowColor: AvionicsColors.cyan,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
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

class _AudioChannelRow extends StatelessWidget {
  const _AudioChannelRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AvionicsColors.emeraldBright : AvionicsColors.outline;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AvionicsText.mono(
              fontSize: 9.5,
              color: AvionicsColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          enabled ? 'ONLINE' : 'MUTED',
          style: AvionicsText.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TelemetryInfoRow extends StatelessWidget {
  const _TelemetryInfoRow({
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
            fontSize: 10,
            color: AvionicsColors.outline,
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

