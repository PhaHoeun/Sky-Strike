import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/game_models.dart';

/// Result returned when attempting a subsystem upgrade transaction.
@immutable
class UpgradeResult {
  const UpgradeResult({
    required this.snapshot,
    required this.success,
    this.errorMessage,
  });

  final GameSnapshot snapshot;
  final bool success;
  final String? errorMessage;
}

/// Result returned after recording a completed sortie in SQLite.
@immutable
class MissionCompletionResult {
  const MissionCompletionResult({
    required this.snapshot,
    required this.summary,
  });

  final GameSnapshot snapshot;
  final MissionSummary summary;
}

/// Local SQLite repository persisting all player progress, jets, upgrades, and mission logs.
class GameDatabase {
  GameDatabase({this.databasePathOverride});

  static const String _dbFileName = 'sky_strike_progress.db';
  static const int _schemaVersion = 3;
  static bool _ffiInitialized = false;

  /// Optional path override (such as [inMemoryDatabasePath]) for isolated unit/widget tests.
  final String? databasePathOverride;
  Database? _db;

  /// Initializes sqflite_common_ffi in Flutter tests and on Linux/Windows hosts.
  /// Android, iOS, and macOS apps use native sqflite platform channels.
  static void ensureDatabaseFactoryInitialized() {
    if (_ffiInitialized || kIsWeb) return;
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isFlutterTest || Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  /// Opens (and seeds on first run) the SQLite database.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    ensureDatabaseFactoryInitialized();

    final String dbPath;
    if (databasePathOverride != null) {
      dbPath = databasePathOverride!;
    } else {
      final basePath = await getDatabasesPath();
      dbPath = p.join(basePath, _dbFileName);
    }

    _db = await openDatabase(
      dbPath,
      version: _schemaVersion,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _resetAndSeedClean(db);
        }
        if (oldVersion < 3) {
          await _createSettingsTable(db);
        }
      },
      onOpen: (db) async {
        final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM player_profile'),
            ) ??
            0;
        if (count == 0) {
          await _seedInitialData(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        rank_level INTEGER NOT NULL,
        rank_title TEXT NOT NULL,
        xp INTEGER NOT NULL,
        xp_to_next INTEGER NOT NULL,
        energy INTEGER NOT NULL,
        max_energy INTEGER NOT NULL,
        credits INTEGER NOT NULL,
        gems INTEGER NOT NULL,
        scrap_metal INTEGER NOT NULL,
        selected_jet_id TEXT NOT NULL,
        current_stage INTEGER NOT NULL,
        high_score INTEGER NOT NULL,
        missions_completed INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS jets (
        id TEXT PRIMARY KEY,
        callsign TEXT NOT NULL,
        short_name TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        tier_label TEXT NOT NULL,
        role_label TEXT NOT NULL,
        code_tag TEXT NOT NULL,
        speed INTEGER NOT NULL,
        armor INTEGER NOT NULL,
        firepower INTEGER NOT NULL,
        boost_delta INTEGER NOT NULL,
        power_rating REAL NOT NULL,
        unlock_level INTEGER NOT NULL,
        unlock_cost INTEGER NOT NULL,
        unlocked INTEGER NOT NULL,
        selected_camo TEXT NOT NULL,
        image_asset TEXT NOT NULL,
        accent_color INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS jet_upgrades (
        jet_id TEXT NOT NULL,
        subsystem TEXT NOT NULL,
        level INTEGER NOT NULL,
        PRIMARY KEY (jet_id, subsystem)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mission_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_number INTEGER NOT NULL,
        operation_name TEXT NOT NULL,
        jet_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        enemies_shot_down INTEGER NOT NULL,
        boss_destroyed INTEGER NOT NULL,
        credits_earned INTEGER NOT NULL,
        scrap_earned INTEGER NOT NULL,
        accuracy REAL NOT NULL,
        elapsed_seconds REAL NOT NULL,
        completed_at_iso TEXT NOT NULL
      )
    ''');

    await _createSettingsTable(db);
  }

  Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert(
      'app_settings',
      {'key': 'sound_muted', 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _seedInitialData(DatabaseExecutor db) async {
    await db.insert(
      'player_profile',
      GameSeedData.initialProfile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final jet in GameSeedData.initialJets) {
      await db.insert(
        'jets',
        jet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final levels = GameSeedData.initialLevelsForJet(jet.id);
      for (final entry in levels.entries) {
        await db.insert(
          'jet_upgrades',
          {
            'jet_id': jet.id,
            'subsystem': entry.key.dbKey,
            'level': entry.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> _resetAndSeedClean(DatabaseExecutor txn) async {
    await txn.delete('mission_history');
    await txn.delete('jet_upgrades');
    await txn.delete('jets');
    await txn.delete('player_profile');
    await _seedInitialData(txn);
  }

  /// Loads a complete immutable [GameSnapshot] from SQLite.
  Future<GameSnapshot> loadSnapshot([DatabaseExecutor? executor]) async {
    final exec = executor ?? await database;

    final profileRows = await exec.query('player_profile', where: 'id = 1');
    final profile = PlayerProfile.fromMap(profileRows.first);

    final jetRows = await exec.query('jets');
    final orderIndex = {
      for (var i = 0; i < GameSeedData.initialJets.length; i++)
        GameSeedData.initialJets[i].id: i,
    };
    final jets = jetRows.map(JetConfig.fromMap).toList()
      ..sort((a, b) => (orderIndex[a.id] ?? 99).compareTo(orderIndex[b.id] ?? 99));

    final upgradeRows = await exec.query('jet_upgrades');
    final Map<String, Map<SubsystemId, SubsystemUpgrade>> upgradesByJet = {};
    for (final row in upgradeRows) {
      final item = SubsystemUpgrade.fromMap(row);
      upgradesByJet.putIfAbsent(item.jetId, () => {})[item.subsystem] = item;
    }

    final historyRows = await exec.query(
      'mission_history',
      orderBy: 'id DESC',
      limit: 20,
    );
    final history = historyRows.map(MissionRecord.fromMap).toList();

    await _createSettingsTable(exec);
    final settingRows = await exec.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['sound_muted'],
    );
    final soundMuted =
        settingRows.isNotEmpty && (settingRows.first['value'] == '1');

    return GameSnapshot(
      profile: profile,
      jets: jets,
      upgradesByJet: upgradesByJet,
      history: history,
      soundMuted: soundMuted,
    );
  }

  /// Persists whether combat SFX & engine audio are muted.
  Future<GameSnapshot> setSoundMuted(bool muted) async {
    final db = await database;
    await _createSettingsTable(db);
    await db.insert(
      'app_settings',
      {'key': 'sound_muted', 'value': muted ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return loadSnapshot(db);
  }

  /// Sets the active hangar fighter if unlocked and persists the selection.
  Future<GameSnapshot> selectJet(String jetId) async {
    final db = await database;
    final rows = await db.query('jets', where: 'id = ?', whereArgs: [jetId]);
    if (rows.isNotEmpty && ((rows.first['unlocked'] as num).toInt() == 1)) {
      await db.update(
        'player_profile',
        {'selected_jet_id': jetId},
        where: 'id = 1',
      );
    }
    return loadSnapshot(db);
  }

  /// Updates the active camouflage preset for [jetId] in SQLite.
  Future<GameSnapshot> selectCamo(String jetId, String camoName) async {
    final db = await database;
    await db.update(
      'jets',
      {'selected_camo': camoName},
      where: 'id = ?',
      whereArgs: [jetId],
    );
    return loadSnapshot(db);
  }

  /// Attempts to unlock a locked hangar fighter using player credits.
  Future<UpgradeResult> unlockJet(String jetId) async {
    final db = await database;
    String? error;
    bool ok = false;

    await db.transaction((txn) async {
      final profileRow = (await txn.query('player_profile', where: 'id = 1')).first;
      final jetRow = (await txn.query('jets', where: 'id = ?', whereArgs: [jetId])).first;
      final profile = PlayerProfile.fromMap(profileRow);
      final jet = JetConfig.fromMap(jetRow);

      if (jet.unlocked) {
        await txn.update('player_profile', {'selected_jet_id': jetId}, where: 'id = 1');
        ok = true;
        return;
      }

      if (profile.credits < jet.unlockCost) {
        error = 'INSUFFICIENT CREDITS (${jet.unlockCost} REQUIRED)';
        return;
      }

      await txn.update(
        'player_profile',
        {
          'credits': profile.credits - jet.unlockCost,
          'selected_jet_id': jetId,
        },
        where: 'id = 1',
      );
      await txn.update('jets', {'unlocked': 1}, where: 'id = ?', whereArgs: [jetId]);
      ok = true;
    });

    return UpgradeResult(
      snapshot: await loadSnapshot(db),
      success: ok,
      errorMessage: error,
    );
  }

  /// Spends sortie fuel/energy before launching into aerial combat.
  Future<GameSnapshot> consumeSortieEnergy({int amount = 10}) async {
    final db = await database;
    await db.transaction((txn) async {
      final row = (await txn.query('player_profile', where: 'id = 1')).first;
      final current = (row['energy'] as num).toInt();
      final next = math.max(0, current - amount);
      await txn.update('player_profile', {'energy': next}, where: 'id = 1');
    });
    return loadSnapshot(db);
  }

  /// Atomically purchases a subsystem upgrade and boosts aircraft combat stats.
  Future<UpgradeResult> purchaseSubsystemUpgrade({
    required String jetId,
    required SubsystemId subsystem,
  }) async {
    final db = await database;
    bool upgraded = false;
    String? errorMessage;

    await db.transaction((txn) async {
      final profileRow = (await txn.query('player_profile', where: 'id = 1')).first;
      final jetRow = (await txn.query('jets', where: 'id = ?', whereArgs: [jetId])).first;
      final upgRow = (await txn.query(
        'jet_upgrades',
        where: 'jet_id = ? AND subsystem = ?',
        whereArgs: [jetId, subsystem.dbKey],
      )).first;

      final profile = PlayerProfile.fromMap(profileRow);
      final jet = JetConfig.fromMap(jetRow);
      final currentLevel = (upgRow['level'] as num).toInt();

      if (currentLevel >= subsystem.maxLevel) {
        errorMessage = '${subsystem.shortLabel} AT MAX SPEC';
        return;
      }

      final cost = subsystem.upgradeCostForLevel(currentLevel);
      if (profile.credits < cost) {
        errorMessage = 'INSUFFICIENT CREDITS ($cost REQ)';
        return;
      }

      final delta = subsystem.deltaPerLevel;
      final nextSpeed = math.min(100, jet.speed + delta.speed);
      final nextArmor = math.min(100, jet.armor + delta.armor);
      final nextFirepower = math.min(100, jet.firepower + delta.firepower);
      final nextPower = double.parse(
        ((nextSpeed * 0.36 + nextArmor * 0.24 + nextFirepower * 0.34) + jet.boostDelta * 0.9)
            .toStringAsFixed(1),
      );

      await txn.update(
        'player_profile',
        {'credits': profile.credits - cost},
        where: 'id = 1',
      );
      await txn.update(
        'jet_upgrades',
        {'level': currentLevel + 1},
        where: 'jet_id = ? AND subsystem = ?',
        whereArgs: [jetId, subsystem.dbKey],
      );
      await txn.update(
        'jets',
        {
          'speed': nextSpeed,
          'armor': nextArmor,
          'firepower': nextFirepower,
          'power_rating': nextPower,
        },
        where: 'id = ?',
        whereArgs: [jetId],
      );

      upgraded = true;
    });

    return UpgradeResult(
      snapshot: await loadSnapshot(db),
      success: upgraded,
      errorMessage: errorMessage,
    );
  }

  /// Persists mission victory rewards, XP level progression, and sortie history.
  Future<MissionCompletionResult> recordMissionVictory({
    required int stageNumber,
    required String jetId,
    required int score,
    required int enemiesShotDown,
    required bool bossDestroyed,
    required int creditsEarned,
    required int scrapEarned,
    required int xpEarned,
    required double accuracy,
    required double elapsedSeconds,
  }) async {
    final db = await database;
    late MissionSummary summary;
    final operationName = GameSeedData.operationNameForStage(stageNumber);

    await db.transaction((txn) async {
      final profileRow = (await txn.query('player_profile', where: 'id = 1')).first;
      final profile = PlayerProfile.fromMap(profileRow);

      final prevLevel = profile.rankLevel;
      var level = prevLevel;
      var xp = profile.xp + xpEarned;
      var xpToNext = profile.xpToNext;

      while (xp >= xpToNext) {
        xp -= xpToNext;
        level += 1;
        xpToNext += 250;
      }

      final nextRankTitle = level >= 20
          ? 'SKY MARSHAL'
          : (level >= 10
              ? 'APEX CMDR'
              : (level >= 5
                  ? 'ACE PILOT'
                  : (level >= 2 ? 'VANGUARD' : 'CADET')));

      final levelUps = level - prevLevel;
      final gemsEarned = (levelUps * 10) + (bossDestroyed ? 5 : 0);
      final nextStage = math.max(profile.currentStage, stageNumber + 1);
      final nextHighScore = math.max(profile.highScore, score);
      final nextEnergy = math.min(profile.maxEnergy, profile.energy + 5);

      await txn.update(
        'player_profile',
        {
          'rank_level': level,
          'rank_title': nextRankTitle,
          'xp': xp,
          'xp_to_next': xpToNext,
          'energy': nextEnergy,
          'credits': profile.credits + creditsEarned,
          'gems': profile.gems + gemsEarned,
          'scrap_metal': profile.scrapMetal + scrapEarned,
          'current_stage': nextStage,
          'high_score': nextHighScore,
          'missions_completed': profile.missionsCompleted + 1,
        },
        where: 'id = 1',
      );

      // Unlock any jets whose rank requirement has now been reached.
      await txn.update(
        'jets',
        {'unlocked': 1},
        where: 'unlock_level <= ?',
        whereArgs: [level],
      );

      await txn.insert('mission_history', {
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
        'completed_at_iso': DateTime.now().toUtc().toIso8601String(),
      });

      final rankGrade = accuracy >= 90
          ? 'S-RANK ACE'
          : (accuracy >= 75 ? 'A-RANK PILOT' : 'B-RANK FLIGHT');

      summary = MissionSummary(
        stageNumber: stageNumber,
        operationName: operationName,
        score: score,
        elapsedSeconds: elapsedSeconds,
        accuracy: accuracy,
        bossDestroyed: bossDestroyed,
        enemiesShotDown: enemiesShotDown,
        creditsEarned: creditsEarned,
        scrapEarned: scrapEarned,
        xpEarned: xpEarned,
        previousLevel: prevLevel,
        newLevel: level,
        xpProgress: (xp / xpToNext).clamp(0.0, 1.0),
        rankGrade: rankGrade,
      );
    });

    return MissionCompletionResult(
      snapshot: await loadSnapshot(db),
      summary: summary,
    );
  }

  /// Recharges hangar sortie energy using gems (or free supply if [gemCost] == 0).
  Future<UpgradeResult> rechargeEnergy({int amount = 30, int gemCost = 20}) async {
    final db = await database;
    bool ok = false;
    String? error;

    await db.transaction((txn) async {
      final profile = PlayerProfile.fromMap(
        (await txn.query('player_profile', where: 'id = 1')).first,
      );
      if (profile.gems < gemCost) {
        error = 'INSUFFICIENT GEMS ($gemCost REQ)';
        return;
      }
      final nextEnergy = math.min(profile.maxEnergy, profile.energy + amount);
      await txn.update(
        'player_profile',
        {
          'energy': nextEnergy,
          'gems': profile.gems - gemCost,
        },
        where: 'id = 1',
      );
      ok = true;
    });

    return UpgradeResult(
      snapshot: await loadSnapshot(db),
      success: ok,
      errorMessage: error,
    );
  }

  /// Exchanges gems for credits or grants tactical supply drops in the Shop sheet.
  Future<UpgradeResult> purchaseCreditPack({
    required int creditsAdded,
    required int gemCost,
  }) async {
    final db = await database;
    bool ok = false;
    String? error;

    await db.transaction((txn) async {
      final profile = PlayerProfile.fromMap(
        (await txn.query('player_profile', where: 'id = 1')).first,
      );
      if (profile.gems < gemCost) {
        error = 'INSUFFICIENT GEMS ($gemCost REQ)';
        return;
      }
      await txn.update(
        'player_profile',
        {
          'credits': profile.credits + creditsAdded,
          'gems': profile.gems - gemCost,
        },
        where: 'id = 1',
      );
      ok = true;
    });

    return UpgradeResult(
      snapshot: await loadSnapshot(db),
      success: ok,
      errorMessage: error,
    );
  }

  /// Resets all SQLite progress back to the clean initial tactical campaign state.
  Future<GameSnapshot> resetProgress() async {
    final db = await database;
    await db.transaction((txn) => _resetAndSeedClean(txn));
    return loadSnapshot(db);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}

