import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/game_models.dart';
import '../widgets/jet_360_viewer.dart';
import 'dogfight_engine.dart';

/// Asynchronously decodes and caches 3D-rendered aircraft sprites used by
/// [DogfightPainter] so combat aircraft match the selected Hangar 3D jet across
/// silhouette, lighting, camo livery, canopy tint, and nozzle glow at 60+ fps.
class DogfightSpriteAtlas extends ChangeNotifier {
  DogfightSpriteAtlas._();

  static final DogfightSpriteAtlas instance = DogfightSpriteAtlas._();

  static const _channel = MethodChannel('com.fightingjet/battle_sprites');
  static const _playerJets = ['f22', 'f35', 'su57', 'x02'];
  static const _playerPoses = ['m2', 'm1', '0', 'p1', 'p2'];
  static const _enemyTypes = ['flanker', 'ace'];
  static const _enemyPoses = ['m1', '0', 'p1'];

  final Map<String, ui.Image> _sprites = {};
  final Map<String, Map<String, ui.Image>> _customLiverySprites = {};
  final Map<String, Future<void>> _inFlightLiveryFutures = {};
  Future<void>? _loadingFuture;

  static String _poseKeyForBank(double bankAngle) => switch (bankAngle) {
    < -0.40 => 'm2',
    < -0.14 => 'm1',
    <= 0.14 => '0',
    <= 0.40 => 'p1',
    _ => 'p2',
  };

  static String _liveryCacheKey(JetConfig jet) =>
      '${jet.id}|${jet.selectedCamo}|${jet.unlocked}';

  static bool get _supportsNative3dSprites {
    if (kIsWeb) return false;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApple) return false;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return !bindingName.contains('TestWidgetsFlutterBinding');
  }

  /// Begins decoding all battle sprites once; notifies listeners when ready.
  void ensureLoaded() {
    _loadingFuture ??= _loadAll();
  }

  /// Renders runtime Metal 3D sprites matching [jet]'s exact Hangar `.scn` livery
  /// and camo preset on iOS/macOS so custom camos match Hangar frame-for-frame.
  void ensureCustomJetLoaded(JetConfig jet) {
    ensureLoaded();
    if (!_supportsNative3dSprites) return;

    final key = _liveryCacheKey(jet);
    if (_customLiverySprites.containsKey(key) ||
        _inFlightLiveryFutures.containsKey(key)) {
      return;
    }
    _inFlightLiveryFutures[key] = _renderCustomLivery(jet, key);
  }

  /// Resolves once core battlefield sprites and any in-flight Metal jet sprites
  /// for [jet] have finished decoding.
  Future<void> waitUntilReady(JetConfig jet) async {
    ensureCustomJetLoaded(jet);
    if (_loadingFuture != null) {
      await _loadingFuture;
    }
    final pendingCustom = _inFlightLiveryFutures[_liveryCacheKey(jet)];
    if (pendingCustom != null) {
      await pendingCustom;
    }
  }

  Future<void> _renderCustomLivery(JetConfig jet, String key) async {
    try {
      final camoStyle = resolveJetCamoStyle(jet.selectedCamo, jet.accentColor);
      final rawMap = await _channel.invokeMapMethod<String, dynamic>(
        'renderPlayerSprites',
        <String, dynamic>{
          'jetId': jet.id,
          'camo': jet.selectedCamo,
          'unlocked': jet.unlocked,
          'trimArgb': camoStyle.trim.toARGB32(),
          'canopyArgb': camoStyle.canopyTop.toARGB32(),
          'afterburnerArgb': camoStyle.afterburnerOuter.toARGB32(),
        },
      );
      if (rawMap == null) return;

      final decoded = <String, ui.Image>{};
      await Future.wait(
        rawMap.entries.map((entry) async {
          final bytes = entry.value;
          if (bytes is Uint8List && bytes.isNotEmpty) {
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            decoded[entry.key] = frame.image;
          }
        }),
      );
      if (decoded.isNotEmpty) {
        _customLiverySprites[key] = decoded;
        notifyListeners();
      }
    } catch (_) {
      // Falls back cleanly to Hangar-matched bundled 3D PNG assets + camo filter.
    } finally {
      _inFlightLiveryFutures.remove(key);
    }
  }

  Future<void> _loadAll() async {
    final keys = <String>[
      for (final jetId in _playerJets)
        for (final pose in _playerPoses)
          'assets/images/sprites/player_${jetId}_$pose.png',
      for (final enemyType in _enemyTypes)
        for (final pose in _enemyPoses)
          'assets/images/sprites/enemy_${enemyType}_$pose.png',
      'assets/images/sprites/boss_skyfortress.png',
      'assets/images/sprites/battlefield_ground.png',
    ];

    await Future.wait(keys.map(_decodeIntoCache));
    notifyListeners();
  }

  Future<void> _decodeIntoCache(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sprites[assetPath] = frame.image;
    } catch (_) {
      // Headless unit tests or missing optional assets fall back cleanly to vector hulls.
    }
  }

  /// Resolves the closest 3D roll pose (`-34°`..`+34°`) for [jetId] at [bankAngle].
  ui.Image? playerSprite(String jetId, double bankAngle) {
    final pose = _poseKeyForBank(bankAngle);
    return _sprites['assets/images/sprites/player_${jetId}_$pose.png'] ??
        _sprites['assets/images/sprites/player_f22_$pose.png'];
  }

  /// Resolves the best 3D chase sprite for [jet] (live Metal camo render if ready,
  /// otherwise the matching bundled 3D sprite). [hasBakedCustomLivery] indicates
  /// the sprite already carries non-native Hangar PBR camo and needs no color matrix.
  ({ui.Image? image, bool hasBakedCustomLivery}) resolvePlayerSprite(
    JetConfig jet,
    double bankAngle,
  ) {
    final pose = _poseKeyForBank(bankAngle);
    final custom = _customLiverySprites[_liveryCacheKey(jet)]?[pose];
    if (custom != null) {
      return (image: custom, hasBakedCustomLivery: true);
    }
    return (image: playerSprite(jet.id, bankAngle), hasBakedCustomLivery: false);
  }

  /// Returns the 3D Aggressor sprite matching [enemy] archetype and bank angle.
  ui.Image? enemySprite(EnemyCraft enemy) {
    final variant = (enemy.id % 3 == 0) ? 'ace' : 'flanker';
    final pose = switch (enemy.bankAngle) {
      < -0.16 => 'm1',
      > 0.16 => 'p1',
      _ => '0',
    };
    return _sprites['assets/images/sprites/enemy_${variant}_$pose.png'];
  }

  /// Returns the 3D heavy flying-wing boss sprite once decoded.
  ui.Image? get bossSprite =>
      _sprites['assets/images/sprites/boss_skyfortress.png'];

  /// Returns the seamless top-down aerial warzone terrain tile once decoded.
  ui.Image? get battlefieldTile =>
      _sprites['assets/images/sprites/battlefield_ground.png'];
}
