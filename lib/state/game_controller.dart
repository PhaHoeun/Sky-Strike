import 'package:flutter/foundation.dart';

import '../audio/battle_audio.dart';
import '../data/game_database.dart';
import '../models/game_models.dart';

/// Reactive controller synchronizing UI state with local SQLite persistence.
class GameController extends ChangeNotifier {
  GameController({GameDatabase? database})
      : _database = database ?? GameDatabase();

  final GameDatabase _database;
  GameSnapshot? _snapshot;
  bool _loading = true;
  String? _statusMessage;

  GameSnapshot? get snapshot => _snapshot;
  bool get isLoading => _loading;
  String? get statusMessage => _statusMessage;

  PlayerProfile get profile => _snapshot?.profile ?? GameSeedData.initialProfile;
  List<JetConfig> get jets => _snapshot?.jets ?? GameSeedData.initialJets;
  JetConfig get selectedJet => _snapshot?.selectedJet ?? GameSeedData.initialJets.first;
  List<MissionRecord> get history => _snapshot?.history ?? const [];
  bool get soundMuted => _snapshot?.soundMuted ?? false;

  Map<SubsystemId, SubsystemUpgrade> upgradesFor(String jetId) {
    return _snapshot?.upgradesFor(jetId) ?? const {};
  }

  /// Loads persisted SQLite game progress on startup.
  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    _snapshot = await _database.loadSnapshot();
    await BattleAudio.instance.setMuted(soundMuted);
    _loading = false;
    notifyListeners();
  }

  Future<void> selectJet(String jetId) async {
    _snapshot = await _database.selectJet(jetId);
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> selectCamo(String jetId, String camoName) async {
    _snapshot = await _database.selectCamo(jetId, camoName);
    _statusMessage = 'LIVERY UPDATED // $camoName';
    notifyListeners();
  }

  Future<UpgradeResult> unlockJet(String jetId) async {
    final res = await _database.unlockJet(jetId);
    _snapshot = res.snapshot;
    _statusMessage = res.success ? 'AIRFRAME UNLOCKED' : res.errorMessage;
    notifyListeners();
    return res;
  }

  Future<void> beginSortie() async {
    _snapshot = await _database.consumeSortieEnergy(amount: 10);
    notifyListeners();
  }

  Future<UpgradeResult> upgradeSubsystem(SubsystemId subsystem) async {
    final res = await _database.purchaseSubsystemUpgrade(
      jetId: selectedJet.id,
      subsystem: subsystem,
    );
    _snapshot = res.snapshot;
    _statusMessage = res.success
        ? '${subsystem.shortLabel} UPGRADED'
        : res.errorMessage;
    notifyListeners();
    return res;
  }

  Future<MissionSummary> completeMission({
    required int stageNumber,
    required int score,
    required int enemiesShotDown,
    required bool bossDestroyed,
    int creditsEarned = 450,
    int scrapEarned = 50,
    int xpEarned = 1250,
    double accuracy = 94.6,
    double elapsedSeconds = 164.18,
  }) async {
    final res = await _database.recordMissionVictory(
      stageNumber: stageNumber,
      jetId: selectedJet.id,
      score: score,
      enemiesShotDown: enemiesShotDown,
      bossDestroyed: bossDestroyed,
      creditsEarned: creditsEarned,
      scrapEarned: scrapEarned,
      xpEarned: xpEarned,
      accuracy: accuracy,
      elapsedSeconds: elapsedSeconds,
    );
    _snapshot = res.snapshot;
    notifyListeners();
    return res.summary;
  }

  Future<UpgradeResult> rechargeEnergy({int amount = 30, int gemCost = 20}) async {
    final res = await _database.rechargeEnergy(amount: amount, gemCost: gemCost);
    _snapshot = res.snapshot;
    _statusMessage = res.success ? '+$amount FUEL CELL LOADED' : res.errorMessage;
    notifyListeners();
    return res;
  }

  Future<UpgradeResult> buyCreditsPack({
    required int creditsAdded,
    required int gemCost,
  }) async {
    final res = await _database.purchaseCreditPack(
      creditsAdded: creditsAdded,
      gemCost: gemCost,
    );
    _snapshot = res.snapshot;
    _statusMessage = res.success ? '+$creditsAdded CREDITS ACQUIRED' : res.errorMessage;
    notifyListeners();
    return res;
  }

  Future<void> setSoundMuted(bool muted) async {
    await BattleAudio.instance.setMuted(muted);
    _snapshot = await _database.setSoundMuted(muted);
    if (!muted) {
      BattleAudio.instance.playSfx(BattleSfx.uiClick);
    }
    notifyListeners();
  }

  Future<void> toggleSoundMuted() => setSoundMuted(!soundMuted);

  Future<void> resetAllProgress() async {
    _snapshot = await _database.resetProgress();
    _statusMessage = 'CAMPAIGN TELEMETRY RESET';
    notifyListeners();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }
}

