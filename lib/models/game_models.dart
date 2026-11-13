import 'package:flutter/material.dart';

/// Upgradeable tactical aircraft subsystems shown on the Engineering schematic.
enum SubsystemId {
  shield,
  cannon,
  missiles,
  engine,
}

/// Static blueprint layout and stat-scaling metadata for each aircraft subsystem.
extension SubsystemMeta on SubsystemId {
  String get dbKey => name;

  String get shortLabel => switch (this) {
    SubsystemId.shield => 'SHIELD',
    SubsystemId.cannon => 'WING CANNON',
    SubsystemId.missiles => 'MISSILES',
    SubsystemId.engine => 'ENGINE',
  };

  String get engineeringTitle => switch (this) {
    SubsystemId.shield => 'AETHER DEFLECTOR MATRIX',
    SubsystemId.cannon => '20MM VULCAN POD',
    SubsystemId.missiles => 'AMRAAM PAYLOAD BAY',
    SubsystemId.engine => 'VECTOR THRUST ENGINE',
  };

  IconData get icon => switch (this) {
    SubsystemId.shield => Icons.shield_outlined,
    SubsystemId.cannon => Icons.gps_fixed,
    SubsystemId.missiles => Icons.rocket_launch_outlined,
    SubsystemId.engine => Icons.bolt_rounded,
  };

  int get maxLevel => 10;

  /// Normalized anchor point on the top-down fighter schematic (0..1 space).
  Offset get aircraftAnchor => switch (this) {
    SubsystemId.shield => const Offset(0.50, 0.28),
    SubsystemId.cannon => const Offset(0.32, 0.56),
    SubsystemId.missiles => const Offset(0.67, 0.62),
    SubsystemId.engine => const Offset(0.50, 0.78),
  };

  /// Normalized card anchor center in the blueprint stage (non-overlapping quadrants).
  Offset get nodeAnchor => switch (this) {
    SubsystemId.shield => const Offset(0.19, 0.21),
    SubsystemId.cannon => const Offset(0.19, 0.77),
    SubsystemId.missiles => const Offset(0.81, 0.24),
    SubsystemId.engine => const Offset(0.80, 0.80),
  };

  /// Returns speed, armor, and firepower gains granted by the next level.
  ({int speed, int armor, int firepower}) get deltaPerLevel => switch (this) {
    SubsystemId.engine => (speed: 6, armor: 4, firepower: 3),
    SubsystemId.shield => (speed: 1, armor: 6, firepower: 2),
    SubsystemId.cannon => (speed: 1, armor: 2, firepower: 6),
    SubsystemId.missiles => (speed: 2, armor: 1, firepower: 5),
  };

  /// Upgrade cost in credits for upgrading from [currentLevel] to [currentLevel + 1].
  int upgradeCostForLevel(int currentLevel) => (currentLevel * 400) + 400;

  /// Roman numeral MK tier label (e.g. MK-V -> MK-VI).
  static String romanNumeral(int level) {
    const numerals = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    if (level >= 0 && level < numerals.length) return numerals[level];
    return '$level';
  }

  static SubsystemId fromDbKey(String key) {
    return SubsystemId.values.firstWhere(
      (s) => s.dbKey == key,
      orElse: () => SubsystemId.engine,
    );
  }
}

/// Persistent player profile row stored in SQLite (`player_profile`).
@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.rankLevel,
    required this.rankTitle,
    required this.xp,
    required this.xpToNext,
    required this.energy,
    required this.maxEnergy,
    required this.credits,
    required this.gems,
    required this.scrapMetal,
    required this.selectedJetId,
    required this.currentStage,
    required this.highScore,
    required this.missionsCompleted,
  });

  final int rankLevel;
  final String rankTitle;
  final int xp;
  final int xpToNext;
  final int energy;
  final int maxEnergy;
  final int credits;
  final int gems;
  final int scrapMetal;
  final String selectedJetId;
  final int currentStage;
  final int highScore;
  final int missionsCompleted;

  double get energyFraction => maxEnergy == 0 ? 0 : (energy / maxEnergy).clamp(0.0, 1.0);
  double get xpFraction => xpToNext == 0 ? 0 : (xp / xpToNext).clamp(0.0, 1.0);

  factory PlayerProfile.fromMap(Map<String, Object?> map) {
    return PlayerProfile(
      rankLevel: (map['rank_level'] as num).toInt(),
      rankTitle: map['rank_title'] as String,
      xp: (map['xp'] as num).toInt(),
      xpToNext: (map['xp_to_next'] as num).toInt(),
      energy: (map['energy'] as num).toInt(),
      maxEnergy: (map['max_energy'] as num).toInt(),
      credits: (map['credits'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
      scrapMetal: (map['scrap_metal'] as num).toInt(),
      selectedJetId: map['selected_jet_id'] as String,
      currentStage: (map['current_stage'] as num).toInt(),
      highScore: (map['high_score'] as num).toInt(),
      missionsCompleted: (map['missions_completed'] as num).toInt(),
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'rank_level': rankLevel,
    'rank_title': rankTitle,
    'xp': xp,
    'xp_to_next': xpToNext,
    'energy': energy,
    'max_energy': maxEnergy,
    'credits': credits,
    'gems': gems,
    'scrap_metal': scrapMetal,
    'selected_jet_id': selectedJetId,
    'current_stage': currentStage,
    'high_score': highScore,
    'missions_completed': missionsCompleted,
  };
}

/// Aircraft definition + persisted unlock/camo/stat data (`jets` table).
@immutable
class JetConfig {
  const JetConfig({
    required this.id,
    required this.callsign,
    required this.shortName,
    required this.subtitle,
    required this.tierLabel,
    required this.roleLabel,
    required this.codeTag,
    required this.speed,
    required this.armor,
    required this.firepower,
    required this.boostDelta,
    required this.powerRating,
    required this.unlockLevel,
    required this.unlockCost,
    required this.unlocked,
    required this.selectedCamo,
    required this.imageAsset,
    required this.accentColorValue,
  });

  final String id;
  final String callsign;
  final String shortName;
  final String subtitle;
  final String tierLabel;
  final String roleLabel;
  final String codeTag;
  final int speed;
  final int armor;
  final int firepower;
  final int boostDelta;
  final double powerRating;
  final int unlockLevel;
  final int unlockCost;
  final bool unlocked;
  final String selectedCamo;
  final String imageAsset;
  final int accentColorValue;

  Color get accentColor => Color(accentColorValue);

  factory JetConfig.fromMap(Map<String, Object?> map) {
    return JetConfig(
      id: map['id'] as String,
      callsign: map['callsign'] as String,
      shortName: map['short_name'] as String,
      subtitle: map['subtitle'] as String,
      tierLabel: map['tier_label'] as String,
      roleLabel: map['role_label'] as String,
      codeTag: map['code_tag'] as String,
      speed: (map['speed'] as num).toInt(),
      armor: (map['armor'] as num).toInt(),
      firepower: (map['firepower'] as num).toInt(),
      boostDelta: (map['boost_delta'] as num).toInt(),
      powerRating: (map['power_rating'] as num).toDouble(),
      unlockLevel: (map['unlock_level'] as num).toInt(),
      unlockCost: (map['unlock_cost'] as num).toInt(),
      unlocked: ((map['unlocked'] as num).toInt()) == 1,
      selectedCamo: map['selected_camo'] as String,
      imageAsset: map['image_asset'] as String,
      accentColorValue: (map['accent_color'] as num).toInt(),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'callsign': callsign,
    'short_name': shortName,
    'subtitle': subtitle,
    'tier_label': tierLabel,
    'role_label': roleLabel,
    'code_tag': codeTag,
    'speed': speed,
    'armor': armor,
    'firepower': firepower,
    'boost_delta': boostDelta,
    'power_rating': powerRating,
    'unlock_level': unlockLevel,
    'unlock_cost': unlockCost,
    'unlocked': unlocked ? 1 : 0,
    'selected_camo': selectedCamo,
    'image_asset': imageAsset,
    'accent_color': accentColorValue,
  };
}

/// Persisted upgrade level for one subsystem on one jet (`jet_upgrades`).
@immutable
class SubsystemUpgrade {
  const SubsystemUpgrade({
    required this.jetId,
    required this.subsystem,
    required this.level,
  });

  final String jetId;
  final SubsystemId subsystem;
  final int level;

  bool get isMaxed => level >= subsystem.maxLevel;
  int get nextLevel => isMaxed ? level : level + 1;
  int get nextCost => subsystem.upgradeCostForLevel(level);
  String get mkTransition =>
      'MK-${SubsystemMeta.romanNumeral(level)} → MK-${SubsystemMeta.romanNumeral(nextLevel)}';

  factory SubsystemUpgrade.fromMap(Map<String, Object?> map) {
    return SubsystemUpgrade(
      jetId: map['jet_id'] as String,
      subsystem: SubsystemMeta.fromDbKey(map['subsystem'] as String),
      level: (map['level'] as num).toInt(),
    );
  }
}

/// Mission history entry stored in SQLite (`mission_history`).
@immutable
class MissionRecord {
  const MissionRecord({
    this.id,
    required this.stageNumber,
    required this.operationName,
    required this.jetId,
    required this.score,
    required this.enemiesShotDown,
    required this.bossDestroyed,
    required this.creditsEarned,
    required this.scrapEarned,
    required this.accuracy,
    required this.elapsedSeconds,
    required this.completedAtIso,
  });

  final int? id;
  final int stageNumber;
  final String operationName;
  final String jetId;
  final int score;
  final int enemiesShotDown;
  final bool bossDestroyed;
  final int creditsEarned;
  final int scrapEarned;
  final double accuracy;
  final double elapsedSeconds;
  final String completedAtIso;

  factory MissionRecord.fromMap(Map<String, Object?> map) {
    return MissionRecord(
      id: (map['id'] as num?)?.toInt(),
      stageNumber: (map['stage_number'] as num).toInt(),
      operationName: map['operation_name'] as String,
      jetId: map['jet_id'] as String,
      score: (map['score'] as num).toInt(),
      enemiesShotDown: (map['enemies_shot_down'] as num).toInt(),
      bossDestroyed: ((map['boss_destroyed'] as num).toInt()) == 1,
      creditsEarned: (map['credits_earned'] as num).toInt(),
      scrapEarned: (map['scrap_earned'] as num).toInt(),
      accuracy: (map['accuracy'] as num).toDouble(),
      elapsedSeconds: (map['elapsed_seconds'] as num).toDouble(),
      completedAtIso: map['completed_at_iso'] as String,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'stage_number': stageNumber,
    'operation_name': operationName,
    'jet_id': jetId,
    'score': score,
    'enemies_shot_down': enemiesShotDown,
    'boss_destroyed': bossDestroyed ? 1 : 0,
    'credits_earned': creditsEarned,
    'scrap_earned': scrapEarned,
    'accuracy': accuracy,
    'elapsed_seconds': elapsedSeconds,
    'completed_at_iso': completedAtIso,
  };
}

/// Snapshot of a completed sortie displayed on [VictoryModalScreen].
@immutable
class MissionSummary {
  const MissionSummary({
    required this.stageNumber,
    required this.operationName,
    required this.score,
    required this.elapsedSeconds,
    required this.accuracy,
    required this.bossDestroyed,
    required this.enemiesShotDown,
    required this.creditsEarned,
    required this.scrapEarned,
    required this.xpEarned,
    required this.previousLevel,
    required this.newLevel,
    required this.xpProgress,
    required this.rankGrade,
  });

  final int stageNumber;
  final String operationName;
  final int score;
  final double elapsedSeconds;
  final double accuracy;
  final bool bossDestroyed;
  final int enemiesShotDown;
  final int creditsEarned;
  final int scrapEarned;
  final int xpEarned;
  final int previousLevel;
  final int newLevel;
  final double xpProgress;
  final String rankGrade;
}

/// Complete game state loaded from SQLite.
@immutable
class GameSnapshot {
  const GameSnapshot({
    required this.profile,
    required this.jets,
    required this.upgradesByJet,
    required this.history,
    this.soundMuted = false,
  });

  final PlayerProfile profile;
  final List<JetConfig> jets;
  final Map<String, Map<SubsystemId, SubsystemUpgrade>> upgradesByJet;
  final List<MissionRecord> history;
  final bool soundMuted;

  JetConfig get selectedJet => jets.firstWhere(
    (j) => j.id == profile.selectedJetId,
    orElse: () => jets.first,
  );

  Map<SubsystemId, SubsystemUpgrade> upgradesFor(String jetId) {
    return upgradesByJet[jetId] ?? const {};
  }
}

/// Initial clean rookie profile values on fresh first install.
abstract final class GameSeedData {
  static const PlayerProfile initialProfile = PlayerProfile(
    rankLevel: 1,
    rankTitle: 'CADET',
    xp: 0,
    xpToNext: 500,
    energy: 100,
    maxEnergy: 100,
    credits: 0,
    gems: 0,
    scrapMetal: 0,
    selectedJetId: 'f22',
    currentStage: 1,
    highScore: 0,
    missionsCompleted: 0,
  );

  static const List<JetConfig> initialJets = [
    JetConfig(
      id: 'f22',
      callsign: 'F-22 APEX RAPTOR',
      shortName: 'F-22 RAPTOR',
      subtitle: 'TACTICAL AIR DOMINANCE // STARTER FIGHTER',
      tierLabel: 'TIER IV',
      roleLabel: 'AIR SUP',
      codeTag: 'F-22',
      speed: 78,
      armor: 72,
      firepower: 76,
      boostDelta: 2,
      powerRating: 76.5,
      unlockLevel: 1,
      unlockCost: 0,
      unlocked: true,
      selectedCamo: 'STEALTH SLATE',
      imageAsset: 'assets/images/hangar_f22.jpg',
      accentColorValue: 0xFF00E5FF,
    ),
    JetConfig(
      id: 'f35',
      callsign: 'F-35 VALKYRIE',
      shortName: 'F-35 VALKYRIE',
      subtitle: 'MULTIROLE VTOL // PRECISION STRIKE',
      tierLabel: 'TIER III',
      roleLabel: 'STRIKE',
      codeTag: 'F-35',
      speed: 74,
      armor: 76,
      firepower: 75,
      boostDelta: 2,
      powerRating: 75.0,
      unlockLevel: 3,
      unlockCost: 1200,
      unlocked: false,
      selectedCamo: 'OBSIDIAN NAVY',
      imageAsset: 'assets/images/hangar_f22.jpg',
      accentColorValue: 0xFF00DAF3,
    ),
    JetConfig(
      id: 'su57',
      callsign: 'SU-57 PHANTOM',
      shortName: 'SU-57 PHANTOM',
      subtitle: 'SUPERMANEUVERABLE // THRUST VECTOR',
      tierLabel: 'TIER IV',
      roleLabel: 'INTERCEPT',
      codeTag: 'SU-57',
      speed: 82,
      armor: 70,
      firepower: 80,
      boostDelta: 3,
      powerRating: 79.8,
      unlockLevel: 5,
      unlockCost: 2800,
      unlocked: false,
      selectedCamo: 'DIGITAL FLANKER',
      imageAsset: 'assets/images/hangar_f22.jpg',
      accentColorValue: 0xFFFE6B00,
    ),
    JetConfig(
      id: 'x02',
      callsign: 'X-02 WYVERN',
      shortName: 'X-02 WYVERN',
      subtitle: 'EXPERIMENTAL // HYPERSONIC PROTOTYPE',
      tierLabel: 'TIER V',
      roleLabel: 'PROTO',
      codeTag: 'X-02',
      speed: 86,
      armor: 78,
      firepower: 84,
      boostDelta: 4,
      powerRating: 84.5,
      unlockLevel: 10,
      unlockCost: 6500,
      unlocked: false,
      selectedCamo: 'EXPERIMENTAL TITANIUM',
      imageAsset: 'assets/images/hangar_f22.jpg',
      accentColorValue: 0xFFFFB800,
    ),
  ];

  static Map<SubsystemId, int> initialLevelsForJet(String jetId) => const {
    SubsystemId.shield: 1,
    SubsystemId.cannon: 1,
    SubsystemId.missiles: 1,
    SubsystemId.engine: 1,
  };

  static String operationNameForStage(int stage) => switch (stage) {
    1 => 'OPERATION IRON DAWN',
    2 => 'OPERATION CRIMSON HORIZON',
    3 => 'OPERATION APEX INTERCEPT',
    4 => 'OPERATION SKYFIRE',
    5 => 'OPERATION NIGHTFALL VECTOR',
    _ => 'OPERATION VANGUARD S$stage',
  };

  /// Ordered progressive difficulty specs from Level 1 (Easy) to Level 5+ (Extreme).
  static LevelDifficultySpec levelSpecForStage(int stage) {
    final s = stage < 1 ? 1 : stage;
    return switch (s) {
      1 => const LevelDifficultySpec(
        stageNumber: 1,
        difficulty: CombatDifficulty.easy,
        shortLabel: 'EASY',
        operationTitle: 'OPERATION IRON DAWN',
        enemyMaxActive: 3,
        enemyHp: 50,
        enemySpeedY: 0.06,
        enemyFireCooldown: 2.2,
        enemyShotSpeed: 0.30,
        enemyShotDamage: 5,
        enemySpreadCount: 1,
        bossMaxHp: 1100,
        bossFireCooldown: 2.1,
        bossSpreadCount: 2,
        creditsReward: 250,
        scrapReward: 25,
        xpReward: 600,
      ),
      2 => const LevelDifficultySpec(
        stageNumber: 2,
        difficulty: CombatDifficulty.medium,
        shortLabel: 'MEDIUM',
        operationTitle: 'OPERATION CRIMSON HORIZON',
        enemyMaxActive: 4,
        enemyHp: 85,
        enemySpeedY: 0.075,
        enemyFireCooldown: 1.75,
        enemyShotSpeed: 0.38,
        enemyShotDamage: 7,
        enemySpreadCount: 1,
        bossMaxHp: 2100,
        bossFireCooldown: 1.75,
        bossSpreadCount: 3,
        creditsReward: 350,
        scrapReward: 35,
        xpReward: 900,
      ),
      3 => const LevelDifficultySpec(
        stageNumber: 3,
        difficulty: CombatDifficulty.hard,
        shortLabel: 'HARD',
        operationTitle: 'OPERATION APEX INTERCEPT',
        enemyMaxActive: 4,
        enemyHp: 130,
        enemySpeedY: 0.09,
        enemyFireCooldown: 1.45,
        enemyShotSpeed: 0.46,
        enemyShotDamage: 9,
        enemySpreadCount: 2,
        bossMaxHp: 3400,
        bossFireCooldown: 1.45,
        bossSpreadCount: 4,
        creditsReward: 450,
        scrapReward: 50,
        xpReward: 1250,
      ),
      4 => const LevelDifficultySpec(
        stageNumber: 4,
        difficulty: CombatDifficulty.veryHard,
        shortLabel: 'V.HARD',
        operationTitle: 'OPERATION SKYFIRE',
        enemyMaxActive: 5,
        enemyHp: 185,
        enemySpeedY: 0.108,
        enemyFireCooldown: 1.2,
        enemyShotSpeed: 0.54,
        enemyShotDamage: 11,
        enemySpreadCount: 2,
        bossMaxHp: 5000,
        bossFireCooldown: 1.2,
        bossSpreadCount: 5,
        creditsReward: 600,
        scrapReward: 70,
        xpReward: 1600,
      ),
      _ => LevelDifficultySpec(
        stageNumber: s,
        difficulty: CombatDifficulty.extreme,
        shortLabel: s == 5 ? 'ACE' : 'ACE+$s',
        operationTitle: operationNameForStage(s),
        enemyMaxActive: (5 + ((s - 5) ~/ 2)).clamp(5, 7),
        enemyHp: 240.0 + (s - 5) * 45.0,
        enemySpeedY: (0.12 + (s - 5) * 0.008).clamp(0.12, 0.17),
        enemyFireCooldown: (0.98 - (s - 5) * 0.06).clamp(0.62, 0.98),
        enemyShotSpeed: (0.62 + (s - 5) * 0.03).clamp(0.62, 0.84),
        enemyShotDamage: 13.0 + (s - 5) * 1.8,
        enemySpreadCount: 3,
        bossMaxHp: 7000.0 + (s - 5) * 1600.0,
        bossFireCooldown: (0.98 - (s - 5) * 0.05).clamp(0.68, 0.98),
        bossSpreadCount: 6,
        creditsReward: 750 + (s - 5) * 100,
        scrapReward: 90 + (s - 5) * 15,
        xpReward: 2000 + (s - 5) * 250,
      ),
    };
  }
}

/// Difficulty tier categories from Level 1 (Easy) to Level 5+ (Extreme).
enum CombatDifficulty {
  easy,
  medium,
  hard,
  veryHard,
  extreme,
}

extension CombatDifficultyStyle on CombatDifficulty {
  Color get accentColor => switch (this) {
    CombatDifficulty.easy => const Color(0xFF10E89E),
    CombatDifficulty.medium => const Color(0xFF00E5FF),
    CombatDifficulty.hard => const Color(0xFFFFB800),
    CombatDifficulty.veryHard => const Color(0xFFFE6B00),
    CombatDifficulty.extreme => const Color(0xFFFF4D6A),
  };

  String get chipLabel => switch (this) {
    CombatDifficulty.easy => 'EASY',
    CombatDifficulty.medium => 'MED',
    CombatDifficulty.hard => 'HARD',
    CombatDifficulty.veryHard => 'V.HRD',
    CombatDifficulty.extreme => 'ACE',
  };
}

/// Complete combat balancing & rewards profile for a single campaign level.
@immutable
class LevelDifficultySpec {
  const LevelDifficultySpec({
    required this.stageNumber,
    required this.difficulty,
    required this.shortLabel,
    required this.operationTitle,
    required this.enemyMaxActive,
    required this.enemyHp,
    required this.enemySpeedY,
    required this.enemyFireCooldown,
    required this.enemyShotSpeed,
    required this.enemyShotDamage,
    required this.enemySpreadCount,
    required this.bossMaxHp,
    required this.bossFireCooldown,
    required this.bossSpreadCount,
    required this.creditsReward,
    required this.scrapReward,
    required this.xpReward,
  });

  final int stageNumber;
  final CombatDifficulty difficulty;
  final String shortLabel;
  final String operationTitle;
  final int enemyMaxActive;
  final double enemyHp;
  final double enemySpeedY;
  final double enemyFireCooldown;
  final double enemyShotSpeed;
  final double enemyShotDamage;
  final int enemySpreadCount;
  final double bossMaxHp;
  final double bossFireCooldown;
  final int bossSpreadCount;
  final int creditsReward;
  final int scrapReward;
  final int xpReward;
}

