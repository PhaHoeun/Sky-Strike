import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Real-time battle and tactical UI sound effects triggered by [DogfightEngine]
/// and avionics screens via [BattleAudio].
enum BattleSfx {
  cannon('cannon'),
  missile('missile'),
  explosionSmall('explosion_small'),
  explosionBig('explosion_big'),
  playerHit('player_hit'),
  shieldHit('shield_hit'),
  overdrive('overdrive'),
  shield('shield'),
  stageClear('stage_clear'),
  defeat('defeat'),
  uiClick('ui_click');

  const BattleSfx(this.channelKey);

  final String channelKey;
}

/// Low-latency battle sound controller bridged to native Apple `AVAudioEngine`
/// synthesis (`com.fightingjet/battle_audio`) with safe headless test fallbacks.
class BattleAudio {
  BattleAudio._();

  static final BattleAudio instance = BattleAudio._();

  static const MethodChannel _channel =
      MethodChannel('com.fightingjet/battle_audio');

  static const Map<BattleSfx, int> _minIntervalMs = {
    BattleSfx.cannon: 82,
    BattleSfx.explosionSmall: 55,
    BattleSfx.explosionBig: 110,
    BattleSfx.playerHit: 95,
    BattleSfx.shieldHit: 90,
  };

  bool _muted = false;
  bool _ambienceActive = false;
  bool _ambiencePaused = false;
  bool _overdrive = false;
  final Map<BattleSfx, int> _lastPlayedMs = {};

  /// Unmuted event counter exposed for automated diagnostics and tests.
  int debugPlayedCount = 0;
  BattleSfx? debugLastSfx;

  bool get isMuted => _muted;

  static bool get _supportsNativeAudio {
    if (kIsWeb) return false;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApple) return false;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return !bindingName.contains('TestWidgetsFlutterBinding');
  }

  /// Applies persisted mute state immediately to active mixer & looping ambience.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (_supportsNativeAudio) {
      try {
        await _channel.invokeMethod<void>('setMuted', {'muted': muted});
      } catch (_) {}
    }
  }

  /// Triggers a single polyphonic combat or UI sound effect if unmuted.
  void playSfx(BattleSfx sfx) {
    if (_muted) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final minGap = _minIntervalMs[sfx] ?? 0;
    final prevMs = _lastPlayedMs[sfx] ?? 0;
    if (minGap > 0 && nowMs - prevMs < minGap) {
      return;
    }
    _lastPlayedMs[sfx] = nowMs;

    debugPlayedCount += 1;
    debugLastSfx = sfx;

    if (!_supportsNativeAudio) return;
    _channel
        .invokeMethod<void>('playSfx', {'name': sfx.channelKey})
        .catchError((_) {});
  }

  /// Starts continuous looping jet turbine & battlefield rumble inside battle.
  void startBattleAmbience({bool overdrive = false}) {
    _ambienceActive = true;
    _ambiencePaused = false;
    _overdrive = overdrive;
    if (!_supportsNativeAudio) return;
    _channel
        .invokeMethod<void>('startBattleLoop', {'overdrive': overdrive})
        .catchError((_) {});
  }

  /// Syncs looping jet ambience with combat pause or supersonic overdrive state.
  void updateBattleAmbience({required bool paused, required bool overdrive}) {
    if (!_ambienceActive) return;
    if (_ambiencePaused == paused && _overdrive == overdrive) return;
    _ambiencePaused = paused;
    _overdrive = overdrive;
    if (!_supportsNativeAudio) return;
    _channel.invokeMethod<void>('updateBattleLoop', {
      'paused': paused,
      'overdrive': overdrive,
    }).catchError((_) {});
  }

  /// Stops combat ambience cleanly when leaving the dogfight arena.
  void stopBattleAmbience() {
    _ambienceActive = false;
    _ambiencePaused = false;
    _overdrive = false;
    if (!_supportsNativeAudio) return;
    _channel.invokeMethod<void>('stopBattleLoop').catchError((_) {});
  }
}

