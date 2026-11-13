import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../audio/battle_audio.dart';
import '../models/game_models.dart';

/// Active player fighter craft telemetry inside the 2.5D dogfight arena.
class PlayerJetState {
  PlayerJetState({
    required this.x,
    required this.y,
    required this.maxHull,
    required this.hull,
    required this.shieldCharge,
  });

  /// Normalized arena X position (`0.08`..`0.92`).
  double x;

  /// Normalized arena Y position (`0.30`..`0.85`).
  double y;

  /// Roll bank angle in radians (`-0.65`..`+0.65`) for 3D wing foreshortening.
  double bankAngle = 0;

  /// Instantaneous horizontal velocity in normalized units/sec.
  double vx = 0;

  /// Instantaneous vertical velocity in normalized units/sec.
  double vy = 0;

  double maxHull;
  double hull;
  double shieldCharge; // 0..100
  double hitFlashTimer = 0;
  final List<(double x, double y)> trail = [];
}

/// Enemy interceptor bogie flying dynamic attack patterns.
class EnemyCraft {
  EnemyCraft({
    required this.id,
    required this.callsign,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.speedY,
    required this.swayFreq,
    required this.swayAmp,
    required this.phase,
    required this.fireCooldown,
  }) : anchorX = x;

  final int id;
  final String callsign;
  double x;
  double y;
  final double anchorX;
  double hp;
  final double maxHp;
  final double speedY;
  final double swayFreq;
  final double swayAmp;
  final double phase;
  double fireCooldown;
  double bankAngle = 0;
  double hitFlash = 0;
}

/// Armored command Skyfortress / Base moving across upper airspace.
class SkyfortressBoss {
  SkyfortressBoss({
    required this.hp,
    required this.maxHp,
  });

  double x = 0.50;
  double y = 0.14;
  double targetY = 0.25;
  double hp;
  final double maxHp;
  double phase = 0;
  double fireCooldown = 1.6;
  double hitFlash = 0;

  double get destroyedFraction => (1.0 - (hp / maxHp)).clamp(0.0, 1.0);
}

/// Active projectile fired by either the player (`20MM`, `FOX 2`) or enemies.
class CombatProjectile {
  CombatProjectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.fromPlayer,
    required this.isMissile,
    this.targetEnemyId,
    this.targetBoss = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double damage;
  final bool fromPlayer;
  final bool isMissile;
  int? targetEnemyId;
  bool targetBoss;
  double life = 4.0;
  final List<(double x, double y)> smokeTrail = [];
}

/// Expanding explosion / spark burst particle.
class ExplosionParticle {
  ExplosionParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.maxLife,
    required this.isCoreFlash,
  }) : life = maxLife;

  double x;
  double y;
  double vx;
  double vy;
  final double radius;
  final double maxLife;
  double life;
  final bool isCoreFlash;

  double get progress => 1.0 - (life / maxLife).clamp(0.0, 1.0);
}

/// Scrolling atmospheric cloud puff for parallax flight sensation.
class CloudPuff {
  CloudPuff({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.opacity,
    required this.layer,
  });

  double x;
  double y;
  final double width;
  final double height;
  final double speed;
  final double opacity;
  final int layer; // 0 = far, 1 = mid
}

/// High-speed wind streak racing past the fighter cockpit.
class SpeedStreak {
  SpeedStreak({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });

  double x;
  double y;
  final double length;
  final double speed;
}

/// Floating damage or kill confirmation tag in world space.
class CombatCallout {
  CombatCallout({
    required this.x,
    required this.y,
    required this.text,
    required this.isCritical,
  });

  double x;
  double y;
  final String text;
  final bool isCritical;
  double life = 0.85;
}

/// Immutable summary emitted when a stage boss falls so the HUD can save
/// rewards to SQLite and display a non-blocking banner without interrupting play.
class StageClearReport {
  const StageClearReport({
    required this.stageNumber,
    required this.levelSpec,
    required this.stageScore,
    required this.stageEnemiesShotDown,
    required this.stageAccuracyPercent,
    required this.stageElapsedSeconds,
  });

  final int stageNumber;
  final LevelDifficultySpec levelSpec;
  final int stageScore;
  final int stageEnemiesShotDown;
  final double stageAccuracyPercent;
  final double stageElapsedSeconds;
}

/// Real-time 60fps aerial combat simulation powering [GameplayHudScreen].
class DogfightEngine extends ChangeNotifier {
  DogfightEngine({
    required this.jet,
    required this.upgrades,
    required int stageNumber,
    this.autoFire = true,
    this.onSoundEvent,
  }) : stageNumber = stageNumber < 1 ? 1 : stageNumber {
    _initBattle();
  }

  final JetConfig jet;
  final Map<SubsystemId, SubsystemUpgrade> upgrades;
  int stageNumber;

  /// Automatically fires primary 20MM bullets while player steers manually with the joystick.
  bool autoFire;

  /// Optional test hook overriding default [BattleAudio] sound playback.
  final void Function(BattleSfx sfx)? onSoundEvent;

  void _emitSound(BattleSfx sfx) {
    (onSoundEvent ?? BattleAudio.instance.playSfx)(sfx);
  }

  final math.Random _rng = math.Random(42);

  late PlayerJetState player;
  late SkyfortressBoss boss;

  final List<EnemyCraft> enemies = [];
  final List<CombatProjectile> projectiles = [];
  final List<ExplosionParticle> particles = [];
  final List<CloudPuff> clouds = [];
  final List<SpeedStreak> streaks = [];
  final List<CombatCallout> callouts = [];

  // Steering & controls (100% pilot controlled via Flight Yoke or touch drag)
  double inputX = 0;
  double inputY = 0;
  bool triggerHeld = false;

  // Tactical weapons & gauges
  int cannonAmmo = 850;
  int maxMissileSalvo = 4;
  int missileSalvo = 4;
  double _missileRechargeTimer = 0;
  double _cannonCooldown = 0;
  int _queuedBurstShots = 0;

  bool shieldActive = false;
  double _shieldTimer = 0;
  double _shieldRegenDelay = 0;
  int enemyHitsTaken = 0;

  bool overdriveActive = false;
  double _overdriveTimer = 0;
  double overdriveCharge = 92;

  // Telemetry & scoring (cumulative campaign + per-stage metrics)
  int score = 0;
  int stageScore = 0;
  int combo = 1;
  double _comboDecayTimer = 0;
  int enemiesShotDown = 0;
  int stageEnemiesShotDown = 0;
  int shotsFired = 0;
  int stageShotsFired = 0;
  int shotsHit = 0;
  int stageShotsHit = 0;
  double elapsedSeconds = 0;
  double stageElapsedSeconds = 0;
  double battlefieldScroll = 0;
  double radarAngle = 0;
  double screenShake = 0;
  double bannerTimer = 2.4;

  int currentWave = 1;
  final int totalWaves = 3;
  int _nextEnemyId = 1;
  double _spawnTimer = 0.25;
  double _trailTimer = 0;

  bool victoryTriggered = false;
  bool defeatTriggered = false;
  bool paused = false;
  double _stageTransitionTimer = 0;
  StageClearReport? _pendingStageClear;

  /// True during the brief explosion cascade right before the next level starts.
  bool get isStageTransitioning => _stageTransitionTimer > 0;

  /// Returns and clears the latest completed-stage report once consumed by UI.
  StageClearReport? takePendingStageClear() {
    final report = _pendingStageClear;
    _pendingStageClear = null;
    return report;
  }

  LevelDifficultySpec get levelSpec => GameSeedData.levelSpecForStage(stageNumber);

  double get _cannonDamage =>
      8.5 +
      (jet.firepower - 75) * 0.16 +
      ((upgrades[SubsystemId.cannon]?.level ?? 1) * 0.95);

  double get _missileDamage =>
      55.0 +
      (jet.firepower - 75) * 0.45 +
      ((upgrades[SubsystemId.missiles]?.level ?? 1) * 5.0);

  double get _playerSpeedScale =>
      0.56 +
      (jet.speed - 75) * 0.006 +
      ((upgrades[SubsystemId.engine]?.level ?? 1) * 0.018);

  int get baseDestroyPercent =>
      victoryTriggered ? 100 : (boss.destroyedFraction * 100).round().clamp(0, 100);

  int get hullPercent =>
      player.maxHull <= 0 ? 0 : ((player.hull / player.maxHull) * 100).round().clamp(0, 100);

  int get shieldPercent => player.shieldCharge.round().clamp(0, 100);

  double get machSpeed {
    final baseMach = 1.95 + (jet.speed - 80) * 0.015;
    final turnBonus = (player.vx.abs() + player.vy.abs()) * 0.25;
    return baseMach + turnBonus + (overdriveActive ? 0.55 : 0.0);
  }

  double get gLoad {
    final maneuver = math.sqrt(player.vx * player.vx + player.vy * player.vy);
    return (1.8 + maneuver * 7.5 + (overdriveActive ? 1.4 : 0)).clamp(1.0, 9.5);
  }

  int get baroAltitudeFeet => (24400 + (0.75 - player.y) * 1600).round();

  int get vviClimbFpm => (-player.vy * 950).round();

  double get accuracyPercent {
    if (shotsFired == 0) return 94.6;
    return ((shotsHit / shotsFired) * 100).clamp(55.0, 99.4);
  }

  double get stageAccuracyPercent {
    if (stageShotsFired == 0) return 94.6;
    return ((stageShotsHit / stageShotsFired) * 100).clamp(55.0, 99.4);
  }

  /// Target currently highlighted by the HUD orange lock reticle.
  ({double x, double y, String label, int rangeMeters})? get lockedTarget {
    if (enemies.isNotEmpty) {
      EnemyCraft nearest = enemies.first;
      double bestDist = _distSq(player.x, player.y, nearest.x, nearest.y);
      for (final e in enemies.skip(1)) {
        final d = _distSq(player.x, player.y, e.x, e.y);
        if (d < bestDist) {
          bestDist = d;
          nearest = e;
        }
      }
      final meters = (math.sqrt(bestDist) * 780).round().clamp(90, 950);
      return (
        x: nearest.x,
        y: nearest.y,
        label: 'LOCK // ${nearest.callsign}',
        rangeMeters: meters,
      );
    }

    if (!boss.hp.isNaN && boss.hp > 0) {
      final d = math.sqrt(_distSq(player.x, player.y, boss.x, boss.y));
      return (
        x: boss.x,
        y: boss.y,
        label: 'LOCK // SKYFORTRESS BASE',
        rangeMeters: (d * 820).round().clamp(120, 980),
      );
    }
    return null;
  }

  void _initBattle() {
    final armorBoost = (upgrades[SubsystemId.shield]?.level ?? 1) * 8.0;
    final hullMax = 100.0 + (jet.armor - 70) * 1.1 + armorBoost;
    player = PlayerJetState(
      x: 0.50,
      y: 0.76,
      maxHull: hullMax,
      hull: hullMax,
      shieldCharge: 100,
    );

    maxMissileSalvo = 4 + ((upgrades[SubsystemId.missiles]?.level ?? 1) >= 6 ? 1 : 0);

    // Seed volumetric multi-layer clouds & airflow streaks once across stage transitions
    for (var i = 0; i < 16; i++) {
      clouds.add(
        CloudPuff(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          width: 0.22 + _rng.nextDouble() * 0.28,
          height: 0.08 + _rng.nextDouble() * 0.11,
          speed: i.isEven ? (0.14 + _rng.nextDouble() * 0.08) : (0.28 + _rng.nextDouble() * 0.14),
          opacity: i.isEven ? 0.20 : 0.34,
          layer: i.isEven ? 0 : 1,
        ),
      );
    }

    for (var i = 0; i < 24; i++) {
      streaks.add(
        SpeedStreak(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          length: 0.04 + _rng.nextDouble() * 0.08,
          speed: 0.75 + _rng.nextDouble() * 0.85,
        ),
      );
    }

    _configureStageEntities(resetFullState: true);
  }

  void _configureStageEntities({required bool resetFullState}) {
    final spec = levelSpec;
    boss = SkyfortressBoss(hp: spec.bossMaxHp, maxHp: spec.bossMaxHp);
    enemies.clear();
    projectiles.clear();
    callouts.clear();

    missileSalvo = maxMissileSalvo;
    _missileRechargeTimer = 0;
    _spawnTimer = 2.6;
    currentWave = 1;
    bannerTimer = 2.4;
    victoryTriggered = false;
    defeatTriggered = false;
    paused = false;
    _stageTransitionTimer = 0;
    _shieldRegenDelay = 0;

    stageScore = 0;
    stageEnemiesShotDown = 0;
    stageShotsFired = 0;
    stageShotsHit = 0;
    stageElapsedSeconds = 0;

    if (resetFullState) {
      _pendingStageClear = null;
      enemyHitsTaken = 0;
      player.hull = player.maxHull;
      player.shieldCharge = 100;
      overdriveCharge = 92;
      score = 0;
      combo = 1;
      enemiesShotDown = 0;
      shotsFired = 0;
      shotsHit = 0;
      elapsedSeconds = 0;
    } else {
      // Carry campaign momentum forward while repairing +35% airframe hull between stages
      player.hull = math.min(player.maxHull, player.hull + player.maxHull * 0.35);
      player.shieldCharge = 100;
      overdriveCharge = math.min(100, overdriveCharge + 35);
    }

    _spawnEnemyWave(count: spec.enemyMaxActive);
  }

  /// Toggles continuous automatic 20MM cannon bullet fire on/off.
  void setAutoFire(bool enabled) {
    autoFire = enabled;
    notifyListeners();
  }

  /// Transitions seamlessly in the same combat arena to [nextStage] (Easy -> Hard -> Ace).
  void advanceToStage(int nextStage, {bool resetFullState = false}) {
    stageNumber = nextStage < 1 ? 1 : nextStage;
    _configureStageEntities(resetFullState: resetFullState);
    notifyListeners();
  }

  void _spawnEnemyWave({required int count}) {
    final spec = levelSpec;
    for (var i = 0; i < count; i++) {
      final slotX = 0.20 + (i / math.max(1, count - 1)) * 0.60;
      enemies.add(
        EnemyCraft(
          id: _nextEnemyId,
          callsign: 'SU-57 BOGIE-0$_nextEnemyId',
          x: slotX.clamp(0.16, 0.84),
          y: 0.14 - i * 0.03,
          hp: spec.enemyHp,
          maxHp: spec.enemyHp,
          speedY: spec.enemySpeedY + _rng.nextDouble() * 0.035,
          swayFreq: 1.3 + _rng.nextDouble() * 0.9,
          swayAmp: 0.10 + _rng.nextDouble() * 0.08,
          phase: _rng.nextDouble() * math.pi * 2,
          fireCooldown: spec.enemyFireCooldown * (0.65 + _rng.nextDouble() * 0.55),
        ),
      );
      _nextEnemyId++;
    }
  }

  /// Applies Flight Yoke / joystick steering normalized into `[-1, 1]`.
  void setFlightInput(double dx, double dy) {
    inputX = dx.clamp(-1.0, 1.0);
    inputY = dy.clamp(-1.0, 1.0);
  }

  /// Directly steers the fighter toward a normalized drag delta on the sky viewport.
  void nudgeJetByNormalizedDelta(double dx, double dy) {
    player.x = (player.x + dx).clamp(0.08, 0.92);
    player.y = (player.y + dy).clamp(0.32, 0.86);
    player.bankAngle = (dx * 16).clamp(-0.65, 0.65);
  }

  /// Fires a crisp 20MM vulcan burst (or holds rapid fire while pressed).
  void triggerCannonBurst() {
    if (paused || victoryTriggered || defeatTriggered) return;
    _queuedBurstShots = math.max(_queuedBurstShots, 4);
    _fireCannonSalvo();
  }

  void _fireCannonSalvo() {
    final cannonLvl = upgrades[SubsystemId.cannon]?.level ?? 1;
    final hasSpread = cannonLvl >= 5 || overdriveActive;
    final shotCount = hasSpread ? 3 : 2;
    if (cannonAmmo <= shotCount) {
      cannonAmmo = 850; // Tactical infinite belt reload
    }
    cannonAmmo = math.max(0, cannonAmmo - shotCount);
    shotsFired += shotCount;
    stageShotsFired += shotCount;

    const vy = -1.42;
    for (final offset in [(-0.030, -0.025), (0.030, 0.025)]) {
      projectiles.add(
        CombatProjectile(
          x: player.x + offset.$1,
          y: player.y - 0.04,
          vx: offset.$2,
          vy: vy,
          damage: _cannonDamage,
          fromPlayer: true,
          isMissile: false,
        ),
      );
    }
    if (hasSpread) {
      projectiles.add(
        CombatProjectile(
          x: player.x,
          y: player.y - 0.055,
          vx: 0,
          vy: vy * 1.06,
          damage: _cannonDamage * 0.9,
          fromPlayer: true,
          isMissile: false,
        ),
      );
    }
    _emitSound(BattleSfx.cannon);
  }

  /// Launches twin heat-seeking FOX-2 AMRAAM missiles locked onto active threats.
  void fireFox2Salvo() {
    if (paused || victoryTriggered || defeatTriggered) return;
    if (missileSalvo <= 0) return;

    missileSalvo -= 1;
    shotsFired += 2;
    stageShotsFired += 2;

    final int? targetId = enemies.isNotEmpty ? enemies.first.id : null;
    final bool lockBoss = enemies.isEmpty;

    for (final side in [-1.0, 1.0]) {
      projectiles.add(
        CombatProjectile(
          x: player.x + side * 0.045,
          y: player.y - 0.03,
          vx: side * 0.22,
          vy: -0.68,
          damage: _missileDamage,
          fromPlayer: true,
          isMissile: true,
          targetEnemyId: targetId,
          targetBoss: lockBoss,
        ),
      );
    }
    _emitSound(BattleSfx.missile);
  }

  /// Activates energy deflector dome around the player's jet.
  void activateShield() {
    if (paused || victoryTriggered || defeatTriggered) return;
    if (shieldActive) {
      shieldActive = false;
      _emitSound(BattleSfx.uiClick);
      notifyListeners();
      return;
    }
    if (player.shieldCharge >= 20) {
      shieldActive = true;
      _shieldTimer = 3.6 + (upgrades[SubsystemId.shield]?.level ?? 1) * 0.3;
      _emitSound(BattleSfx.shield);
      notifyListeners();
    }
  }

  /// Engages supersonic Overdrive afterburners, boosting agility and fire rate.
  void activateOverdrive() {
    if (paused || victoryTriggered || defeatTriggered) return;
    overdriveActive = true;
    _overdriveTimer = 3.2;
    overdriveCharge = 100;
    _queuedBurstShots = math.max(_queuedBurstShots, 6);
    _emitSound(BattleSfx.overdrive);
    fireFox2Salvo();
    notifyListeners();
  }

  /// Advances combat simulation by [rawDt] seconds (capped for frame-drop safety).
  void update(double rawDt) {
    if (paused || defeatTriggered) return;
    final dt = rawDt.clamp(0.0, 0.05);
    elapsedSeconds += dt;
    radarAngle = (radarAngle + dt * 2.4) % (math.pi * 2);
    screenShake = math.max(0, screenShake - dt * 3.5);
    bannerTimer = math.max(0, bannerTimer - dt);
    player.hitFlashTimer = math.max(0, player.hitFlashTimer - dt);

    if (victoryTriggered) {
      _updateEnvironment(dt);
      _updateVictoryCruise(dt);
      _updateParticlesAndCallouts(dt);
      notifyListeners();
      return;
    }

    stageElapsedSeconds += dt;

    _updateTimers(dt);
    _updateEnvironment(dt);
    _updatePlayerFlight(dt);
    _updateBoss(dt);
    _updateEnemies(dt);
    _updateProjectiles(dt);
    _updateParticlesAndCallouts(dt);

    if (_stageTransitionTimer > 0) {
      _stageTransitionTimer -= dt;
      if (_stageTransitionTimer <= 0) {
        _stageTransitionTimer = 0;
        advanceToStage(stageNumber + 1);
        return;
      }
    }

    notifyListeners();
  }

  void _updateVictoryCruise(double dt) {
    final cruiseX = 0.50 + math.sin(elapsedSeconds * 1.4) * 0.14;
    final dx = cruiseX - player.x;
    player.vx = dx * 2.5;
    player.vy = (0.72 - player.y) * 2.0;
    player.x = (player.x + player.vx * dt).clamp(0.12, 0.88);
    player.y = (player.y + player.vy * dt).clamp(0.35, 0.82);
    player.bankAngle += ((player.vx * 0.9) - player.bankAngle) * math.min(1.0, dt * 6);
    _trailTimer += dt;
    if (_trailTimer >= 0.03) {
      _trailTimer = 0;
      player.trail.insert(0, (player.x, player.y + 0.04));
      if (player.trail.length > 16) player.trail.removeLast();
    }
    for (var i = 0; i < player.trail.length; i++) {
      final pt = player.trail[i];
      player.trail[i] = (pt.$1, pt.$2 + dt * 0.35);
    }
  }

  void _updateTimers(double dt) {
    if (_comboDecayTimer > 0) {
      _comboDecayTimer -= dt;
      if (_comboDecayTimer <= 0) {
        combo = 1;
      }
    }

    if (shieldActive) {
      _shieldTimer -= dt;
      player.shieldCharge = (player.shieldCharge - dt * 16).clamp(0, 100);
      if (_shieldTimer <= 0 || player.shieldCharge <= 0) {
        shieldActive = false;
      }
    } else if (_shieldRegenDelay > 0) {
      _shieldRegenDelay = math.max(0, _shieldRegenDelay - dt);
    } else {
      player.shieldCharge = (player.shieldCharge + dt * 5.0).clamp(0, 100);
    }

    if (overdriveActive) {
      _overdriveTimer -= dt;
      overdriveCharge = (overdriveCharge - dt * 28).clamp(0, 100);
      if (_overdriveTimer <= 0) {
        overdriveActive = false;
      }
    } else {
      overdriveCharge = (overdriveCharge + dt * 9).clamp(0, 100);
    }

    if (missileSalvo < maxMissileSalvo) {
      _missileRechargeTimer += dt;
      if (_missileRechargeTimer >= 2.0) {
        _missileRechargeTimer = 0;
        missileSalvo += 1;
      }
    }

    _cannonCooldown -= dt;
    final fireInterval = overdriveActive ? 0.09 : 0.15;
    if ((autoFire || triggerHeld || _queuedBurstShots > 0) &&
        _cannonCooldown <= 0) {
      _cannonCooldown = fireInterval;
      if (_queuedBurstShots > 0) _queuedBurstShots--;
      _fireCannonSalvo();
    }
  }

  void _updateEnvironment(double dt) {
    final speedBoost = overdriveActive ? 1.85 : 1.0;
    battlefieldScroll += 0.115 * speedBoost * dt;
    for (final c in clouds) {
      c.y += c.speed * speedBoost * dt;
      if (c.y - c.height > 1.15) {
        c.y = -c.height - _rng.nextDouble() * 0.25;
        c.x = _rng.nextDouble();
      }
    }
    for (final s in streaks) {
      s.y += s.speed * speedBoost * dt;
      if (s.y - s.length > 1.05) {
        s.y = -s.length - _rng.nextDouble() * 0.2;
        s.x = _rng.nextDouble();
      }
    }
  }

  void _updatePlayerFlight(double dt) {
    final speedFactor = _playerSpeedScale * (overdriveActive ? 1.45 : 1.0);
    final targetVx = inputX * speedFactor;
    final targetVy = inputY * speedFactor * 0.85;

    player.vx += (targetVx - player.vx) * math.min(1.0, dt * 11.0);
    player.vy += (targetVy - player.vy) * math.min(1.0, dt * 11.0);

    player.x = (player.x + player.vx * dt).clamp(0.08, 0.92);
    player.y = (player.y + player.vy * dt).clamp(0.32, 0.85);

    final targetBank = (player.vx * 1.1).clamp(-0.65, 0.65);
    player.bankAngle += (targetBank - player.bankAngle) * math.min(1.0, dt * 10.0);

    _trailTimer += dt;
    if (_trailTimer >= 0.03) {
      _trailTimer = 0;
      player.trail.insert(0, (player.x, player.y + 0.04));
      if (player.trail.length > 16) {
        player.trail.removeLast();
      }
    }
    for (var i = 0; i < player.trail.length; i++) {
      final pt = player.trail[i];
      player.trail[i] = (pt.$1, pt.$2 + dt * (overdriveActive ? 0.45 : 0.28));
    }
  }

  void _updateBoss(double dt) {
    boss.hitFlash = math.max(0, boss.hitFlash - dt);
    if (isStageTransitioning || boss.hp <= 0) {
      return;
    }

    final spec = levelSpec;
    if (boss.destroyedFraction >= 0.65) {
      currentWave = 3;
    } else if (boss.destroyedFraction >= 0.30) {
      currentWave = 2;
    }

    boss.phase += dt * (0.65 + (stageNumber - 1) * 0.08);
    if (boss.y < boss.targetY) {
      boss.y += dt * 0.22;
    } else {
      boss.x = 0.50 + math.sin(boss.phase) * 0.20;
    }

    final waveSpread =
        spec.bossSpreadCount + (currentWave >= 3 && stageNumber >= 2 ? 1 : 0);
    final waveCooldown =
        (spec.bossFireCooldown * (currentWave >= 2 ? 0.86 : 1.0))
            .clamp(0.60, 2.2);

    boss.fireCooldown -= dt;
    if (boss.fireCooldown <= 0 && boss.y >= 0.10) {
      boss.fireCooldown = waveCooldown;
      final angleToPlayer = math.atan2(player.y - boss.y, player.x - boss.x);
      final half = (waveSpread - 1) / 2.0;
      for (var s = 0; s < waveSpread; s++) {
        final offset = (s - half) * 0.16;
        final a = angleToPlayer + offset;
        projectiles.add(
          CombatProjectile(
            x: boss.x,
            y: boss.y + 0.05,
            vx: math.cos(a) * spec.enemyShotSpeed,
            vy: math.sin(a) * spec.enemyShotSpeed,
            damage: spec.enemyShotDamage + 1.0,
            fromPlayer: false,
            isMissile: false,
          ),
        );
      }
    }

    // Keep dogfight populated across waves scaled by level difficulty
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && enemies.length < spec.enemyMaxActive) {
      _spawnTimer = math.max(1.6, 2.8 - (stageNumber - 1) * 0.2);
      _spawnEnemyWave(count: math.min(2, spec.enemyMaxActive - enemies.length));
    }
  }

  void _updateEnemies(double dt) {
    final spec = levelSpec;
    for (var i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      e.hitFlash = math.max(0, e.hitFlash - dt);

      final prevX = e.x;
      final hoverY = 0.34 + (i % 3) * 0.075;
      final approachSpeed = e.y < hoverY ? math.max(0.22, e.speedY) : e.speedY;
      e.y += approachSpeed * dt;
      if (e.y > hoverY && e.y < 0.62) {
        // Patrol laterally in open mid-upper dogfight airspace
        e.y = hoverY + math.sin(elapsedSeconds * 1.1 + e.phase) * 0.035;
      }
      e.x = (e.anchorX + math.sin(elapsedSeconds * e.swayFreq + e.phase) * e.swayAmp)
          .clamp(0.16, 0.84);
      e.bankAngle = ((e.x - prevX) / math.max(dt, 0.001) * 1.4).clamp(-0.55, 0.55);

      e.fireCooldown -= dt;
      if (e.fireCooldown <= 0 && e.y > 0.05) {
        e.fireCooldown = spec.enemyFireCooldown * (0.75 + _rng.nextDouble() * 0.55);
        final dx = player.x - e.x;
        final dy = player.y - e.y;
        final angleToPlayer = math.atan2(dy, dx);
        final half = (spec.enemySpreadCount - 1) / 2.0;
        for (var s = 0; s < spec.enemySpreadCount; s++) {
          final a = angleToPlayer + (s - half) * 0.18;
          projectiles.add(
            CombatProjectile(
              x: e.x,
              y: e.y + 0.03,
              vx: math.cos(a) * spec.enemyShotSpeed,
              vy: math.sin(a) * spec.enemyShotSpeed,
              damage: spec.enemyShotDamage,
              fromPlayer: false,
              isMissile: false,
            ),
          );
        }
      }

      if (e.y > 1.08) {
        enemies.removeAt(i);
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (var i = projectiles.length - 1; i >= 0; i--) {
      final p = projectiles[i];
      p.life -= dt;

      if (p.isMissile && p.fromPlayer) {
        final targetPos = _resolveMissileTarget(p);
        if (targetPos != null) {
          final dx = targetPos.$1 - p.x;
          final dy = targetPos.$2 - p.y;
          final dist = math.max(0.001, math.sqrt(dx * dx + dy * dy));
          const speed = 1.12;
          final desiredVx = (dx / dist) * speed;
          final desiredVy = (dy / dist) * speed;
          p.vx += (desiredVx - p.vx) * math.min(1.0, dt * 8.5);
          p.vy += (desiredVy - p.vy) * math.min(1.0, dt * 8.5);
        }
        p.smokeTrail.insert(0, (p.x, p.y));
        if (p.smokeTrail.length > 10) p.smokeTrail.removeLast();
      }

      p.x += p.vx * dt;
      p.y += p.vy * dt;

      if (p.life <= 0 || p.y < -0.15 || p.y > 1.15 || p.x < -0.1 || p.x > 1.1) {
        projectiles.removeAt(i);
        continue;
      }

      if (p.fromPlayer) {
        bool consumed = false;
        // Check enemy jet hits
        for (var j = enemies.length - 1; j >= 0; j--) {
          final e = enemies[j];
          final hitR = p.isMissile ? 0.068 : 0.048;
          if (_distSq(p.x, p.y, e.x, e.y) <= hitR * hitR) {
            shotsHit += 1;
            stageShotsHit += 1;
            e.hp -= p.damage;
            e.hitFlash = 0.14;
            _spawnExplosion(p.x, p.y, small: !p.isMissile);
            if (e.hp <= 0) {
              _onEnemyDestroyed(e);
              enemies.removeAt(j);
            }
            consumed = true;
            break;
          }
        }

        // Check Skyfortress Boss Base hit
        if (!consumed && boss.y >= 0.0) {
          final bossWidth = 0.20;
          final bossHeight = 0.095;
          if ((p.x - boss.x).abs() <= bossWidth &&
              (p.y - boss.y).abs() <= bossHeight) {
            shotsHit += 1;
            stageShotsHit += 1;
            _damageBoss(p.damage, p.x, p.y, critical: p.isMissile);
            consumed = true;
          }
        }

        if (consumed) {
          projectiles.removeAt(i);
        }
      } else {
        // Enemy fire vs Player Jet
        final hitR = shieldActive ? 0.068 : 0.048;
        if (_distSq(p.x, p.y, player.x, player.y) <= hitR * hitR) {
          projectiles.removeAt(i);
          _damagePlayer(p.damage);
        }
      }
    }
  }

  (double, double)? _resolveMissileTarget(CombatProjectile p) {
    if (p.targetEnemyId != null) {
      for (final e in enemies) {
        if (e.id == p.targetEnemyId) return (e.x, e.y);
      }
      if (enemies.isNotEmpty) {
        p.targetEnemyId = enemies.first.id;
        return (enemies.first.x, enemies.first.y);
      }
      p.targetEnemyId = null;
      p.targetBoss = true;
    }
    if (p.targetBoss || enemies.isEmpty) {
      return (boss.x, boss.y);
    }
    return null;
  }

  void _onEnemyDestroyed(EnemyCraft e) {
    enemiesShotDown += 1;
    stageEnemiesShotDown += 1;
    combo = math.min(8, combo + 1);
    _comboDecayTimer = 4.0;
    final pts = 1250 * combo;
    score += pts;
    stageScore += pts;
    _spawnExplosion(e.x, e.y, small: false);
    _emitSound(BattleSfx.explosionBig);
    callouts.add(
      CombatCallout(
        x: e.x,
        y: e.y - 0.02,
        text: '+$pts SPLASH',
        isCritical: true,
      ),
    );
    // Escort kills weaken Skyfortress defense matrix
    _damageBoss(24.0, e.x, e.y, critical: false, silent: true);
  }

  void _damageBoss(
    double dmg,
    double hitX,
    double hitY, {
    required bool critical,
    bool silent = false,
  }) {
    if (victoryTriggered || isStageTransitioning || boss.hp <= 0) return;
    boss.hp = math.max(0, boss.hp - dmg);
    boss.hitFlash = 0.12;
    final dmgPts = (dmg * 35 * combo).round();
    score += dmgPts;
    stageScore += dmgPts;
    _comboDecayTimer = 3.5;

    if (!silent) {
      _spawnExplosion(hitX, hitY, small: !critical);
      _emitSound(critical ? BattleSfx.explosionBig : BattleSfx.explosionSmall);
      if (critical) {
        screenShake = math.max(screenShake, 0.45);
        callouts.add(
          CombatCallout(
            x: hitX,
            y: hitY,
            text: 'DIRECT HIT!',
            isCritical: true,
          ),
        );
      }
    }

    if (boss.hp <= 0 && !isStageTransitioning) {
      final clearBonus = 15000 + stageNumber * 3500;
      score += clearBonus;
      stageScore += clearBonus;
      _spawnExplosion(boss.x, boss.y, small: false);
      _spawnExplosion(boss.x - 0.08, boss.y + 0.02, small: false);
      _spawnExplosion(boss.x + 0.08, boss.y - 0.02, small: false);
      _spawnExplosion(boss.x, boss.y - 0.04, small: false);
      _emitSound(BattleSfx.explosionBig);
      _emitSound(BattleSfx.stageClear);
      screenShake = 1.0;
      callouts.add(
        CombatCallout(
          x: boss.x,
          y: boss.y + 0.02,
          text: 'LVL ${stageNumber.toString().padLeft(2, '0')} CLEAR!',
          isCritical: true,
        ),
      );
      _pendingStageClear = StageClearReport(
        stageNumber: stageNumber,
        levelSpec: levelSpec,
        stageScore: stageScore,
        stageEnemiesShotDown: stageEnemiesShotDown,
        stageAccuracyPercent: stageAccuracyPercent,
        stageElapsedSeconds: stageElapsedSeconds,
      );
      _stageTransitionTimer = 1.0;
    }
  }

  void _damagePlayer(double dmg) {
    if (defeatTriggered || victoryTriggered) return;
    if (shieldActive) {
      player.shieldCharge = math.max(0, player.shieldCharge - 8.0);
      if (player.shieldCharge <= 0) {
        shieldActive = false;
      }
      _spawnExplosion(player.x, player.y - 0.02, small: true);
      _emitSound(BattleSfx.shieldHit);
      return;
    }

    enemyHitsTaken += 1;
    _shieldRegenDelay = 2.2;
    var hitDamage = dmg * 1.45;
    if (overdriveActive) {
      hitDamage *= 0.6;
    }

    // Passive shield mitigates up to 35% while active, leaving real hull damage on every hit
    double hullLoss = hitDamage;
    if (player.shieldCharge > 0) {
      final shieldMitigation = math.min(player.shieldCharge * 0.4, hitDamage * 0.35);
      player.shieldCharge = math.max(0, player.shieldCharge - shieldMitigation * 4.2);
      hullLoss = math.max(1.0, hitDamage - shieldMitigation);
    }

    player.hull = math.max(0, player.hull - hullLoss);
    player.hitFlashTimer = 0.24;
    screenShake = math.max(screenShake, 0.58);
    _spawnExplosion(player.x, player.y, small: true);
    _emitSound(BattleSfx.playerHit);
    callouts.add(
      CombatCallout(
        x: player.x,
        y: player.y - 0.05,
        text: '-${hullLoss.round()} HULL',
        isCritical: true,
      ),
    );

    if (player.hull <= 0) {
      defeatTriggered = true;
      _spawnExplosion(player.x, player.y, small: false);
      _spawnExplosion(player.x - 0.04, player.y + 0.02, small: false);
      _emitSound(BattleSfx.defeat);
      screenShake = 1.0;
    }
  }

  void _spawnExplosion(double x, double y, {required bool small}) {
    final count = small ? 5 : 14;
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final speed = (small ? 0.14 : 0.34) * (0.35 + _rng.nextDouble());
      particles.add(
        ExplosionParticle(
          x: x,
          y: y,
          vx: math.cos(a) * speed,
          vy: math.sin(a) * speed,
          radius: small ? 4.5 : (7.0 + _rng.nextDouble() * 8.0),
          maxLife: small ? 0.22 : (0.38 + _rng.nextDouble() * 0.25),
          isCoreFlash: i == 0,
        ),
      );
    }
  }

  void _updateParticlesAndCallouts(double dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      final pt = particles[i];
      pt.life -= dt;
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      if (pt.life <= 0) {
        particles.removeAt(i);
      }
    }
    for (var i = callouts.length - 1; i >= 0; i--) {
      final c = callouts[i];
      c.life -= dt;
      c.y -= dt * 0.08;
      if (c.life <= 0) {
        callouts.removeAt(i);
      }
    }
  }

  double _distSq(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return dx * dx + dy * dy;
  }
}
