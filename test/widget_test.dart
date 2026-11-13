import 'dart:io';

import 'package:fighting_jet/audio/battle_audio.dart';
import 'package:fighting_jet/data/game_database.dart';
import 'package:fighting_jet/game/dogfight_engine.dart';
import 'package:fighting_jet/game/dogfight_sprites.dart';
import 'package:fighting_jet/main.dart';
import 'package:fighting_jet/models/game_models.dart';
import 'package:fighting_jet/screens/gameplay_hud_screen.dart';
import 'package:fighting_jet/state/game_controller.dart';
import 'package:fighting_jet/theme/avionics_theme.dart';
import 'package:fighting_jet/widgets/jet_360_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

/// Pumps simulated frames while yielding to real OS threads so SQLite FFI isolate
/// transactions and real combat ticks advance cleanly inside `testWidgets`.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  await tester.pump(const Duration(milliseconds: 50));
}

/// Steps the combat Ticker forward smoothly to simulate real-time dogfight frames.
Future<void> pumpBattleFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AvionicsText.useGoogleFonts = false;
    GameDatabase.ensureDatabaseFactoryInitialized();
  });

  group('GameDatabase SQLite Persistence', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sky_strike_db_test_');
      dbPath = p.join(tempDir.path, 'progress.db');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('seeds clean zero-start rookie campaign data accurately', () async {
      final db = GameDatabase(databasePathOverride: dbPath);
      final snap = await db.loadSnapshot();
      await db.close();

      expect(snap.profile.rankLevel, 1);
      expect(snap.profile.rankTitle, 'CADET');
      expect(snap.profile.xp, 0);
      expect(snap.profile.energy, 100);
      expect(snap.profile.credits, 0);
      expect(snap.profile.gems, 0);
      expect(snap.profile.scrapMetal, 0);
      expect(snap.profile.currentStage, 1);
      expect(snap.profile.highScore, 0);
      expect(snap.profile.missionsCompleted, 0);
      expect(snap.history, isEmpty);

      expect(snap.profile.selectedJetId, 'f22');
      expect(snap.selectedJet.callsign, 'F-22 APEX RAPTOR');
      expect(snap.selectedJet.unlocked, isTrue);
      expect(snap.selectedJet.speed, 78);
      expect(snap.selectedJet.armor, 72);
      expect(snap.selectedJet.firepower, 76);
      expect(snap.upgradesFor('f22')[SubsystemId.engine]?.level, 1);
      expect(snap.upgradesFor('f22')[SubsystemId.cannon]?.level, 1);

      expect(snap.jets.firstWhere((j) => j.id == 'f35').unlocked, isFalse);
      expect(snap.jets.firstWhere((j) => j.id == 'su57').unlocked, isFalse);
      expect(snap.jets.firstWhere((j) => j.id == 'x02').unlocked, isFalse);
    });

    test('persists mission rewards, rank unlocks, jet selection, and upgrades across DB reopen', () async {
      final db1 = GameDatabase(databasePathOverride: dbPath);

      // Cannot upgrade at 0 credits on fresh install
      final failUpgrade = await db1.purchaseSubsystemUpgrade(
        jetId: 'f22',
        subsystem: SubsystemId.engine,
      );
      expect(failUpgrade.success, isFalse);

      // Complete sortie -> earns credits, scrap, XP -> ranks up and unlocks F-35 (Lvl 3+)
      final victoryRes = await db1.recordMissionVictory(
        stageNumber: 1,
        jetId: 'f22',
        score: 28500,
        enemiesShotDown: 6,
        bossDestroyed: true,
        creditsEarned: 1000,
        scrapEarned: 40,
        xpEarned: 1900, // 0->500 (L2), +750 (L3), remaining 650/1000
        accuracy: 92.4,
        elapsedSeconds: 32.0,
      );
      expect(victoryRes.summary.creditsEarned, 1000);
      expect(victoryRes.summary.scrapEarned, 40);
      expect(victoryRes.snapshot.profile.rankLevel, 3);
      expect(victoryRes.snapshot.profile.gems, 25); // 2 level ups * 10 + 5 boss

      await db1.selectJet('f35');

      final upgradeRes = await db1.purchaseSubsystemUpgrade(
        jetId: 'f22',
        subsystem: SubsystemId.engine,
      );
      expect(upgradeRes.success, isTrue);
      expect(upgradeRes.snapshot.profile.credits, 200); // 1000 - 800 cost for LVL 1->2
      await db1.close();

      final db2 = GameDatabase(databasePathOverride: dbPath);
      final reloaded = await db2.loadSnapshot();
      await db2.close();

      expect(reloaded.profile.selectedJetId, 'f35');
      expect(reloaded.jets.firstWhere((j) => j.id == 'f35').unlocked, isTrue);
      expect(reloaded.profile.credits, 200);
      expect(reloaded.profile.scrapMetal, 40);
      expect(reloaded.profile.gems, 25);
      expect(reloaded.profile.rankLevel, 3);
      expect(reloaded.profile.rankTitle, 'VANGUARD');
      expect(reloaded.profile.currentStage, 2);
      expect(reloaded.profile.highScore, 28500);
      expect(reloaded.profile.missionsCompleted, 1);
      expect(reloaded.history.first.stageNumber, 1);
      expect(reloaded.history.first.enemiesShotDown, 6);

      final f22 = reloaded.jets.firstWhere((j) => j.id == 'f22');
      expect(f22.speed, 84);
      expect(f22.armor, 76);
      expect(f22.firepower, 79);
      expect(reloaded.upgradesFor('f22')[SubsystemId.engine]?.level, 2);
      expect(reloaded.soundMuted, isFalse);

      // Verify mute preference persists across SQLite reopen
      final db3 = GameDatabase(databasePathOverride: dbPath);
      final mutedSnap = await db3.setSoundMuted(true);
      expect(mutedSnap.soundMuted, isTrue);
      await db3.close();

      final db4 = GameDatabase(databasePathOverride: dbPath);
      final persistedMuteSnap = await db4.loadSnapshot();
      expect(persistedMuteSnap.soundMuted, isTrue);
      await db4.close();
    });
  });

  group('DogfightEngine Auto-Bullets & Joystick Control', () {
    test('auto-fires 20MM bullets while user steers Flight Yoke and scales Easy to Ace levels without popups', () {
      final easy = GameSeedData.levelSpecForStage(1);
      final hard = GameSeedData.levelSpecForStage(3);
      final ace = GameSeedData.levelSpecForStage(5);

      expect(easy.shortLabel, 'EASY');
      expect(hard.shortLabel, 'HARD');
      expect(ace.shortLabel, 'ACE');
      expect(easy.bossMaxHp, 1100);
      expect(hard.bossMaxHp, greaterThan(easy.bossMaxHp));
      expect(ace.bossMaxHp, greaterThan(hard.bossMaxHp));
      expect(hard.enemyHp, greaterThan(easy.enemyHp));
      expect(ace.enemyHp, greaterThan(hard.enemyHp));
      expect(ace.enemySpreadCount, greaterThan(easy.enemySpreadCount));
      expect(ace.bossSpreadCount, greaterThan(easy.bossSpreadCount));

      // Initialize with Auto-Bullets enabled and neutral joystick
      final engine = DogfightEngine(
        jet: GameSeedData.initialJets.first,
        upgrades: const {},
        stageNumber: 1,
        autoFire: true,
      );

      expect(engine.autoFire, isTrue);
      expect(engine.enemies.length, easy.enemyMaxActive);
      final idleX = engine.player.x;

      // Without joystick input, jet holds steady heading while auto-firing bullets
      for (var i = 0; i < 15; i++) {
        engine.update(0.03);
      }
      expect(engine.player.x, closeTo(idleX, 0.001));
      expect(engine.shotsFired, greaterThan(4));

      // User steers right with Flight Yoke joystick
      engine.setFlightInput(1.0, -0.3);
      for (var i = 0; i < 10; i++) {
        engine.update(0.03);
      }
      expect(engine.player.x, greaterThan(idleX));
      expect(engine.player.bankAngle, greaterThan(0.1));

      // Track targets with joystick + Overdrive + FOX-2 missiles to clear Level 1
      StageClearReport? clearReport;
      for (var step = 0; step < 750 && clearReport == null; step++) {
        if (!engine.overdriveActive && engine.overdriveCharge >= 95) {
          engine.activateOverdrive();
        }
        final targetX =
            engine.enemies.isNotEmpty ? engine.enemies.first.x : engine.boss.x;
        final dx = (targetX - engine.player.x) * 5.0;
        engine.setFlightInput(dx.clamp(-1.0, 1.0), 0);
        if (step % 25 == 0 && engine.missileSalvo > 0) {
          engine.fireFox2Salvo();
        }
        engine.update(0.03);
        clearReport ??= engine.takePendingStageClear();
      }

      expect(clearReport, isNotNull);
      expect(clearReport!.stageNumber, 1);
      expect(engine.victoryTriggered, isFalse);
      expect(engine.isStageTransitioning, isTrue);
      expect(engine.baseDestroyPercent, 100);
      expect(engine.score, greaterThan(15000));

      // Let 1.0s transition timer complete automatically -> advances to Level 2 with zero popup
      final level1Score = engine.score;
      for (var i = 0; i < 40 && engine.stageNumber == 1; i++) {
        engine.update(0.03);
      }
      expect(engine.stageNumber, 2);
      expect(engine.levelSpec.shortLabel, 'MEDIUM');
      expect(engine.isStageTransitioning, isFalse);
      expect(engine.boss.maxHp, GameSeedData.levelSpecForStage(2).bossMaxHp);
      expect(engine.score, greaterThanOrEqualTo(level1Score));

      // Verify Stage 5 (Ace) fires multi-shot enemy spread patterns
      final aceEngine = DogfightEngine(
        jet: GameSeedData.initialJets.first,
        upgrades: const {},
        stageNumber: 5,
      );
      int maxEnemyProjectiles = 0;
      for (var i = 0; i < 110; i++) {
        aceEngine.update(0.03);
        final enemyShots = aceEngine.projectiles.where((p) => !p.fromPlayer).length;
        if (enemyShots > maxEnemyProjectiles) {
          maxEnemyProjectiles = enemyShots;
        }
      }
      expect(maxEnemyProjectiles, greaterThanOrEqualTo(3));

      aceEngine.dispose();
      engine.dispose();
    });

    test('triggers defeat when player jet is hit by many enemy bullets unless active shield blocks', () {
      final engine = DogfightEngine(
        jet: GameSeedData.initialJets.first,
        upgrades: const {},
        stageNumber: 3,
      );

      // Active SHIELD dome blocks enemy rounds cleanly
      engine.activateShield();
      for (var i = 0; i < 3; i++) {
        engine.projectiles.add(
          CombatProjectile(
            x: engine.player.x,
            y: engine.player.y - 0.01,
            vx: 0,
            vy: 0.5,
            damage: 10,
            fromPlayer: false,
            isMissile: false,
          ),
        );
        engine.update(0.03);
      }
      expect(engine.hullPercent, 100);
      expect(engine.defeatTriggered, isFalse);

      // Deactivate Shield dome -> sustained enemy bullets pierce hull and trigger defeat
      engine.activateShield();
      expect(engine.shieldActive, isFalse);

      for (var i = 0; i < 24 && !engine.defeatTriggered; i++) {
        engine.projectiles.add(
          CombatProjectile(
            x: engine.player.x,
            y: engine.player.y - 0.01,
            vx: 0,
            vy: 0.5,
            damage: 10,
            fromPlayer: false,
            isMissile: false,
          ),
        );
        engine.update(0.03);
      }

      expect(engine.enemyHitsTaken, greaterThan(5));
      expect(engine.player.hull, 0);
      expect(engine.hullPercent, 0);
      expect(engine.defeatTriggered, isTrue);

      engine.dispose();
    });
  });

  group('SkyStrikeApp 4-Screen Auto-Bullets & Same-Screen Level Flow', () {
    late Directory tempDir;
    late GameDatabase db;
    late GameController controller;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('sky_strike_ui_test_');
      db = GameDatabase(databasePathOverride: p.join(tempDir.path, 'ui.db'));
      controller = GameController(database: db);
      await controller.initialize();
    });

    tearDown(() async {
      await db.close();
      controller.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'steers with Flight Yoke + Auto-Bullets from Easy -> Medium -> Hard in same battle screen & persists SQLite rewards',
      (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(SkyStrikeApp(controller: controller));
        await tester.pumpAndSettle();

        // 1. Hangar / Jet Select Screen starts clean from rookie Level 1 & 0 currency
        expect(find.text('F-22 APEX RAPTOR'), findsOneWidget);
        expect(find.text('CADET'), findsOneWidget);
        expect(find.text('LVL 1'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2)); // 0 Credits & 0 Gems
        expect(find.text('TO BATTLE!'), findsOneWidget);

        // Navigate to Screen 4: Engineering starts at LVL 1 and blocks upgrade at 0 Credits
        await tester.tap(find.byKey(const Key('upgrade_stats_button')));
        await tester.pumpAndSettle();
        expect(find.text('ENGINEERING // F-22'), findsOneWidget);
        expect(find.text('LVL 1'), findsWidgets);
        expect(find.text('800'), findsOneWidget);

        await tester.tap(find.byKey(const Key('upgrade_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('LVL 1'), findsWidgets);
        expect(controller.profile.credits, 0);

        await tester.tap(find.text('HOME'));
        await tester.pumpAndSettle();

        // 2. Launch Battle -> Starts Level 1 (EASY) with Auto-Bullets ON & Joystick control
        await tester.tap(find.byKey(const Key('to_battle_button')));
        await pumpUntilFound(tester, find.byKey(const Key('dogfight_sky_arena')));
        await pumpBattleFrames(tester, 18);

        expect(find.text('LVL 01 • EASY'), findsOneWidget);
        expect(find.text('AUTO BULLETS: ON'), findsOneWidget);
        expect(find.byKey(const Key('level_chip_1')), findsOneWidget);
        expect(find.byKey(const Key('level_chip_5')), findsOneWidget);

        // Pilot steers manually with Flight Yoke & triggers Shield + Overdrive + FOX 2
        await tester.drag(find.byKey(const Key('flight_yoke_pad')), const Offset(12, -6));
        await pumpBattleFrames(tester, 4);
        await tester.drag(find.byKey(const Key('flight_yoke_pad')), const Offset(-12, 0));
        await tester.tap(find.byKey(const Key('toggle_shield_button')));
        await tester.tap(find.byKey(const Key('overdrive_button')));
        await pumpBattleFrames(tester, 16);

        var sawTransitionSignal = false;
        for (var round = 0; round < 55; round++) {
          expect(find.text('MISSION ACCOMPLISHED!'), findsNothing);
          if (find.byKey(const Key('stage_clear_toast_banner')).evaluate().isNotEmpty ||
              find.text('LVL 02 • MEDIUM').evaluate().isNotEmpty) {
            sawTransitionSignal = true;
            break;
          }
          if (round % 4 == 0) {
            await tester.tap(find.byKey(const Key('overdrive_button')));
          }
          await tester.tap(find.byKey(const Key('fire_missile_button')));
          await pumpBattleFrames(tester, 16);
        }

        expect(sawTransitionSignal, isTrue);
        expect(find.text('MISSION ACCOMPLISHED!'), findsNothing);
        expect(find.byKey(const Key('next_mission_button')), findsNothing);

        // Seamless automatic transition in the SAME battle screen into Level 2 (MEDIUM)
        if (find.text('LVL 02 • MEDIUM').evaluate().isEmpty) {
          await pumpBattleFrames(tester, 38);
        }
        expect(find.text('LVL 02 • MEDIUM'), findsOneWidget);
        expect(find.text('MISSION ACCOMPLISHED!'), findsNothing);

        // Tap 3 HARD chip directly inside the same battle screen
        await tester.tap(find.byKey(const Key('level_chip_3')));
        await pumpBattleFrames(tester, 8);
        expect(find.text('LVL 03 • HARD'), findsOneWidget);

        // Swiping from left edge or system back cannot leave gameplay screen to Home
        await tester.dragFrom(const Offset(2, 480), const Offset(300, 0));
        await pumpBattleFrames(tester, 6);
        final arenaCtx = tester.element(find.byKey(const Key('dogfight_sky_arena')));
        await Navigator.of(arenaCtx).maybePop();
        await pumpBattleFrames(tester, 4);
        expect(find.text('LVL 03 • HARD'), findsOneWidget);
        expect(find.text('TO BATTLE!'), findsNothing);

        // Tap PAUSE button -> verify GAME PAUSED popup with RESUME and RETURN TO HOME
        expect(find.text('PAUSE'), findsOneWidget);
        await tester.tap(find.byKey(const Key('pause_tac_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('GAME PAUSED'), findsOneWidget);
        expect(find.text('RESUME'), findsOneWidget);
        expect(find.text('RETURN TO HOME'), findsOneWidget);

        // Hardware/back pop cannot bypass Pause modal back to Home either
        await Navigator.of(tester.element(find.text('GAME PAUSED'))).maybePop();
        await tester.pump();
        expect(find.text('GAME PAUSED'), findsOneWidget);

        // Tap RESUME -> returns directly to active combat on Stage 03
        await tester.tap(find.byKey(const Key('pause_resume_button')));
        await pumpBattleFrames(tester, 6);
        expect(find.text('GAME PAUSED'), findsNothing);
        expect(find.text('LVL 03 • HARD'), findsOneWidget);

        // Tap PAUSE again -> tap RETURN TO HOME -> returns to Hangar/Home
        await tester.tap(find.byKey(const Key('pause_tac_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const Key('pause_return_home_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        // Verify SQLite persisted first-clear rewards from 0 -> 250 Credits & LVL 2
        expect(find.text('F-22 APEX RAPTOR'), findsOneWidget);
        await pumpUntilFound(tester, find.text('250'));
        expect(find.text('250'), findsOneWidget);
        expect(find.text('LVL 2'), findsOneWidget);
      },
    );

    testWidgets(
      'updates top 360-degree Hangar jet showcase on every fleet selection and supports 360 orbit controls',
      (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(SkyStrikeApp(controller: controller));
        await tester.pumpAndSettle();

        // 1. Default top stage displays selected F-22 Raptor in 360 viewer
        Jet360Viewer topViewer() => tester.widget<Jet360Viewer>(
          find.byKey(const Key('hero_jet_360_viewer')),
        );
        expect(topViewer().jet.id, 'f22');
        expect(find.text('LOCK // F-22'), findsOneWidget);
        expect(find.text('F-22 APEX RAPTOR'), findsOneWidget);

        // 2. Selecting locked SU-57 Phantom shows SU-57 on top immediately
        await tester.tap(find.byKey(const Key('jet_card_su57')));
        await tester.pumpAndSettle();
        expect(topViewer().jet.id, 'su57');
        expect(find.text('LOCK // SU-57'), findsOneWidget);
        expect(find.text('SU-57 PHANTOM'), findsNWidgets(2));
        expect(find.text('PREVIEW // LOCKED LVL 5'), findsOneWidget);

        // 3. Scroll fleet carousel right & select X-02 Wyvern -> top stage updates to X-02
        await tester.drag(find.byType(ListView).first, const Offset(-260, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('jet_card_x02')));
        await tester.pumpAndSettle();
        expect(topViewer().jet.id, 'x02');
        expect(find.text('LOCK // X-02'), findsOneWidget);
        expect(find.text('X-02 WYVERN'), findsNWidgets(2));

        // 4. Grant credits & unlock F-35 Valkyrie via runAsync (SQLite FFI), then select it on top
        await tester.runAsync(() async {
          await controller.completeMission(
            stageNumber: 1,
            score: 12000,
            creditsEarned: 1500,
            scrapEarned: 40,
            xpEarned: 600,
            enemiesShotDown: 12,
            bossDestroyed: true,
            accuracy: 88.0,
            elapsedSeconds: 30,
          );
          await controller.unlockJet('f35');
          await controller.selectJet('f22');
        });
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(260, 0));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('jet_card_f35')));
        await pumpUntilFound(tester, find.text('LOCK // F-35'));
        expect(topViewer().jet.id, 'f35');
        expect(find.text('LOCK // F-35'), findsOneWidget);
        expect(find.text('F-35 VALKYRIE'), findsNWidgets(2));
        expect(find.text('RADAR: ACTIVE'), findsOneWidget);

        // 5. Cycle camo updates active livery cleanly
        expect(find.text('CAMO: OBSIDIAN NAVY'), findsOneWidget);
        await tester.tap(find.byKey(const Key('cycle_camo_button')));
        await pumpUntilFound(tester, find.text('CAMO: STEALTH SLATE'));
        expect(find.text('CAMO: STEALTH SLATE'), findsOneWidget);
        expect(topViewer().jet.selectedCamo, 'STEALTH SLATE');

        // 6. Dragging the top stage rotates 360 degrees & updates orientation heading
        final beforeDrag = tester
            .widget<Text>(find.byKey(const Key('hero_jet_orientation_label')))
            .data;
        await tester.drag(
          find.byKey(const Key('jet_360_gesture_area')),
          const Offset(160, -35),
        );
        await tester.pumpAndSettle();
        final afterDrag = tester
            .widget<Text>(find.byKey(const Key('hero_jet_orientation_label')))
            .data;
        expect(afterDrag, isNot(beforeDrag));

        // 7. Toggling INSPECT 360° activates continuous turntable rotation
        await tester.tap(find.byKey(const Key('inspect_360_button')));
        await tester.pump();
        expect(find.text('360° ACTIVE'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        final duringSpin = tester
            .widget<Text>(find.byKey(const Key('hero_jet_orientation_label')))
            .data;
        expect(duringSpin, isNot(afterDrag));

        // Stop auto-spin so idle settles cleanly
        await tester.tap(find.byKey(const Key('inspect_360_button')));
        await tester.pumpAndSettle();
        expect(find.text('INSPECT 360°'), findsOneWidget);
      },
    );

    testWidgets(
      'DogfightSpriteAtlas decodes 3D battle sprites and battlefield terrain across all jets, bank poses, enemies, and boss',
      (tester) async {
        final atlas = DogfightSpriteAtlas.instance;
        await tester.runAsync(() async {
          atlas.ensureLoaded();
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while ((atlas.bossSprite == null || atlas.battlefieldTile == null) &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });

        expect(atlas.battlefieldTile, isNotNull);
        expect(atlas.battlefieldTile!.width, 768);
        expect(atlas.battlefieldTile!.height, 1536);

        for (final jetId in ['f22', 'f35', 'su57', 'x02']) {
          for (final bank in [-0.55, -0.25, 0.0, 0.25, 0.55]) {
            expect(atlas.playerSprite(jetId, bank), isNotNull);
          }
        }
        for (final jet in GameSeedData.initialJets) {
          atlas.ensureCustomJetLoaded(jet);
          final resolved = atlas.resolvePlayerSprite(jet, 0.0);
          expect(resolved.image, isNotNull);
          expect(resolved.image!.width, 512);
          expect(resolved.image!.height, 512);
        }
        final flanker = EnemyCraft(
          id: 1,
          callsign: 'SU-57 BOGIE-01',
          x: 0.5,
          y: 0.3,
          hp: 50,
          maxHp: 50,
          speedY: 0.1,
          swayFreq: 1.0,
          swayAmp: 0.1,
          phase: 0.0,
          fireCooldown: 1.0,
        );
        final ace = EnemyCraft(
          id: 3,
          callsign: 'SU-57 BOGIE-03',
          x: 0.5,
          y: 0.3,
          hp: 50,
          maxHp: 50,
          speedY: 0.1,
          swayFreq: 1.0,
          swayAmp: 0.1,
          phase: 0.0,
          fireCooldown: 1.0,
        );
        for (final b in [-0.30, 0.0, 0.30]) {
          flanker.bankAngle = b;
          ace.bankAngle = b;
          expect(atlas.enemySprite(flanker), isNotNull);
          expect(atlas.enemySprite(ace), isNotNull);
        }
        expect(atlas.bossSprite, isNotNull);
      },
    );

    testWidgets(
      'Battle Audio & Settings screen toggle mute/unmute state across Hangar, Settings, and Battle Pause',
      (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Verify DogfightEngine emits combat SFX events and BattleAudio respects mute
        final firedSfx = <BattleSfx>[];
        final sfxEngine = DogfightEngine(
          jet: GameSeedData.initialJets.first,
          upgrades: const {},
          stageNumber: 1,
          autoFire: true,
          onSoundEvent: firedSfx.add,
        );
        for (var i = 0; i < 10; i++) {
          sfxEngine.update(0.03);
        }
        sfxEngine.activateShield();
        sfxEngine.fireFox2Salvo();
        sfxEngine.activateOverdrive();
        expect(firedSfx, contains(BattleSfx.cannon));
        expect(firedSfx, contains(BattleSfx.shield));
        expect(firedSfx, contains(BattleSfx.missile));
        expect(firedSfx, contains(BattleSfx.overdrive));
        sfxEngine.dispose();

        await BattleAudio.instance.setMuted(false);
        final beforePlayCount = BattleAudio.instance.debugPlayedCount;
        BattleAudio.instance.playSfx(BattleSfx.missile);
        expect(BattleAudio.instance.debugPlayedCount, beforePlayCount + 1);

        await BattleAudio.instance.setMuted(true);
        BattleAudio.instance.playSfx(BattleSfx.missile);
        expect(BattleAudio.instance.debugPlayedCount, beforePlayCount + 1);
        await BattleAudio.instance.setMuted(false);

        await tester.pumpWidget(SkyStrikeApp(controller: controller));
        await tester.pumpAndSettle();

        // 1. Tap top-right Settings button on Hangar -> opens dedicated SettingsScreen
        await tester.tap(find.byKey(const Key('open_settings_button')));
        await tester.pumpAndSettle();
        expect(find.text('AVIONICS // SETTINGS'), findsOneWidget);
        expect(find.text('MUTE SOUND'), findsOneWidget);

        // 2. Mute sound via Settings toggle button -> updates UI, controller, and BattleAudio
        await tester.tap(find.byKey(const Key('sound_mute_toggle_button')));
        await pumpUntilFound(tester, find.text('UNMUTE SOUND'));
        expect(controller.soundMuted, isTrue);
        expect(BattleAudio.instance.isMuted, isTrue);

        // Preview button warns cleanly while muted
        await tester.tap(find.byKey(const Key('settings_test_sfx_button')));
        await tester.pumpAndSettle();
        expect(
          find.text('SOUND IS MUTED — TAP UNMUTE TO PREVIEW AUDIO'),
          findsOneWidget,
        );

        // Return to Hangar and verify muted state reflects in Pause menu & can be unmuted mid-battle
        await tester.tap(find.byKey(const Key('settings_back_home_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('to_battle_button')));
        await pumpUntilFound(tester, find.byKey(const Key('dogfight_sky_arena')));

        await tester.tap(find.byKey(const Key('pause_tac_button')));
        await pumpUntilFound(tester, find.byKey(const Key('pause_sound_toggle_button')));
        expect(find.text('SOUND: MUTED • UNMUTE'), findsOneWidget);

        await tester.tap(find.byKey(const Key('pause_sound_toggle_button')));
        await pumpUntilFound(tester, find.text('SOUND: ON • MUTE'));
        expect(controller.soundMuted, isFalse);
        expect(BattleAudio.instance.isMuted, isFalse);

        // Return cleanly to Home before tearDown closes controller/DB
        await tester.tap(find.byKey(const Key('pause_return_home_button')));
        await pumpUntilFound(tester, find.byKey(const Key('to_battle_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'GamingLoadingScreen renders preflight progress before transitioning to Hangar home',
      (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(SkyStrikeApp(controller: controller));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('gaming_loading_screen')), findsOneWidget);
        expect(find.text('SKY STRIKE'), findsOneWidget);
        expect(find.text('AIR SUPERIORITY PROTOCOL'), findsOneWidget);
        expect(find.byKey(const Key('loading_percent_label')), findsOneWidget);
        expect(find.byKey(const Key('loading_status_label')), findsOneWidget);

        // Progress finishes cleanly and replaces stack root with HangarScreen
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('gaming_loading_screen')), findsNothing);
        expect(find.text('TO BATTLE!'), findsOneWidget);

        // Navigating to Upgrades and returning lands back on Hangar, not loading
        await tester.tap(find.byKey(const Key('upgrade_stats_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('HOME'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('gaming_loading_screen')), findsNothing);
        expect(find.text('TO BATTLE!'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping TO BATTLE shows BattleLoadingScreen deployment UI before entering battlefield',
      (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(SkyStrikeApp(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('to_battle_button')));
        await pumpUntilFound(tester, find.byKey(const Key('battle_loading_screen')));

        expect(find.byKey(const Key('battle_loading_screen')), findsOneWidget);
        expect(find.text('SORTIE DEPLOYMENT // STAGE 01'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('battle_loading_screen')),
            matching: find.text('F-22 APEX RAPTOR'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('battle_loading_percent_label')), findsOneWidget);
        expect(find.byKey(const Key('battle_loading_status_label')), findsOneWidget);
        expect(find.byKey(const Key('dogfight_sky_arena')), findsNothing);

        // Automatically transitions into playable battlefield arena once deployment hits 100%
        await pumpUntilFound(tester, find.byKey(const Key('dogfight_sky_arena')));
        await pumpBattleFrames(tester, 9);
        expect(find.byKey(const Key('battle_loading_screen')), findsNothing);
        expect(find.byKey(const Key('dogfight_sky_arena')), findsOneWidget);

        // Pause -> Return Home goes directly back to Hangar, skipping battle loading screen
        await tester.tap(find.byKey(const Key('pause_tac_button')));
        await pumpUntilFound(tester, find.byKey(const Key('pause_return_home_button')));
        await tester.tap(find.byKey(const Key('pause_return_home_button')));
        await pumpUntilFound(tester, find.byKey(const Key('to_battle_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('battle_loading_screen')), findsNothing);
        expect(find.text('TO BATTLE!'), findsOneWidget);
      },
    );
  });

  group('Combat In-Battle Healing & Multi-Bullet Weapon Upgrades', () {
    test('in-battle healing repairs hull, updates pulse aura, and triggers emergency repair kits', () {
      final engine = DogfightEngine(
        jet: GameSeedData.initialJets.first,
        upgrades: const {},
        stageNumber: 1,
      );

      expect(engine.emergencyRepairKits, 2);
      expect(engine.hullPercent, 100);

      // Simulate combat damage to hull
      engine.player.hull = 30.0;
      expect(engine.hullPercent, lessThan(40));

      // Apply tactical repair canister (+35)
      engine.applyRepair(35.0);
      expect(engine.player.hull, 65.0);
      expect(engine.repairPulseTimer, greaterThan(0));
      expect(engine.callouts.any((c) => c.text == '+35 HULL REPAIRED'), isTrue);

      // Trigger Emergency Nanite Repair kit
      final usedKit = engine.triggerEmergencyRepair();
      expect(usedKit, isTrue);
      expect(engine.emergencyRepairKits, 1);
      expect(engine.player.hull, 100.0); // 65 + 35 = 100.0 (clamped to maxHull)
      expect(engine.repairPulseTimer, greaterThan(0));

      // Steer jet to fly over a Nanite Repair pickup in the arena
      engine.pickups.add(
        CombatPickup(
          id: 999,
          type: CombatPickupType.repair,
          x: engine.player.x,
          y: engine.player.y + 0.01,
          speedY: 0.05,
        ),
      );
      engine.update(0.03);
      expect(engine.pickups.where((p) => p.id == 999), isEmpty);
      expect(engine.repairPulseTimer, greaterThan(0));

      engine.dispose();
    });

    test('tactical bullet types switch weapon systems, spawn distinct projectile salvos, and piercing laser pierces targets', () {
      final engine = DogfightEngine(
        jet: GameSeedData.initialJets.first,
        upgrades: const {},
        stageNumber: 2,
        autoFire: false,
      );

      expect(engine.activeWeapon, PlayerWeaponType.vulcan);

      // Standard Vulcan burst
      engine.triggerCannonBurst();
      final vulcanProjectiles = engine.projectiles.where((p) => p.weaponType == PlayerWeaponType.vulcan).toList();
      expect(vulcanProjectiles.length, 2); // Twin tracers
      expect(vulcanProjectiles.first.pierces, isFalse);

      // Equip Plasma Spread
      engine.setWeapon(PlayerWeaponType.plasmaSpread, ammo: 120);
      expect(engine.activeWeapon, PlayerWeaponType.plasmaSpread);
      expect(engine.specialWeaponAmmo, 120);

      // Fire Plasma burst -> 5-way ionization fan (consumes 5 ammo)
      engine.triggerCannonBurst();
      final plasmaProjectiles = engine.projectiles.where((p) => p.weaponType == PlayerWeaponType.plasmaSpread).toList();
      expect(plasmaProjectiles.length, 5);
      expect(engine.specialWeaponAmmo, 115);

      // Equip Twin Laser Beam -> hyper-velocity piercing tachyon beams
      engine.setWeapon(PlayerWeaponType.laserBeam, ammo: 90);
      expect(engine.activeWeapon, PlayerWeaponType.laserBeam);
      engine.triggerCannonBurst();
      final laserProjectiles = engine.projectiles.where((p) => p.weaponType == PlayerWeaponType.laserBeam).toList();
      expect(laserProjectiles.length, 2);
      expect(laserProjectiles.first.pierces, isTrue);

      // Verify laser projectile pierces multiple enemy bogeys without disappearing
      final laser = laserProjectiles.first;
      final enemy1 = engine.enemies[0];
      laser.x = enemy1.x;
      laser.y = enemy1.y + 0.02;
      laser.vx = 0;
      laser.vy = -0.5;
      engine.update(0.03);
      expect(laser.hitEntityIds.contains(enemy1.id), isTrue);
      expect(engine.projectiles.contains(laser), isTrue); // Pierced through, still active

      // Equip Swarm Micro-Rockets
      engine.setWeapon(PlayerWeaponType.scatterMissile, ammo: 60);
      expect(engine.activeWeapon, PlayerWeaponType.scatterMissile);
      engine.triggerCannonBurst();
      final swarmProjectiles = engine.projectiles.where((p) => p.weaponType == PlayerWeaponType.scatterMissile).toList();
      expect(swarmProjectiles.length, 4);

      // Collecting a weapon pickup pod equips the new weapon system
      engine.pickups.add(
        CombatPickup(
          id: 888,
          type: CombatPickupType.plasmaSpread,
          x: engine.player.x,
          y: engine.player.y + 0.01,
          speedY: 0.05,
        ),
      );
      engine.update(0.03);
      expect(engine.activeWeapon, PlayerWeaponType.plasmaSpread);
      expect(engine.specialWeaponAmmo, 120);

      engine.dispose();
    });

    testWidgets('BottomWeaponsControlDeck displays active weapon, ammo, and emergency repair button', (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var repairTriggered = false;
      var cannonTapped = false;
      var cannonHeld = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomWeaponsControlDeck(
              autoFire: true,
              cannonAmmo: 250,
              activeWeapon: PlayerWeaponType.plasmaSpread,
              specialWeaponAmmo: 85,
              emergencyRepairKits: 2,
              missileSalvo: 4,
              overdriveCharge: 100,
              overdriveActive: false,
              shieldActive: false,
              yokeOffset: Offset.zero,
              onToggleAutoFire: () {},
              onYokeChanged: (_) {},
              onOverdrive: () {},
              onEmergencyRepair: () => repairTriggered = true,
              onCannonTap: () => cannonTapped = true,
              onCannonHoldChanged: (h) => cannonHeld = h,
              onToggleShield: () {},
              onFireMissile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify weapon deck displays Plasma Spread weapon, 85 ammo, and Emergency Repair button
      expect(find.byKey(const Key('fire_cannon_button')), findsOneWidget);
      expect(find.byKey(const Key('emergency_repair_button')), findsOneWidget);
      expect(find.text('PLASMA'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text('REPAIR x2'), findsOneWidget);
      expect(find.text('PLASMA: 85 // FOX-2: 4 // REP: x2'), findsOneWidget);

      // Tap Emergency Repair button -> triggers callback
      await tester.tap(find.byKey(const Key('emergency_repair_button')));
      await tester.pump();
      expect(repairTriggered, isTrue);

      // Tap Cannon button -> triggers callback
      await tester.tap(find.byKey(const Key('fire_cannon_button')));
      await tester.pump();
      expect(cannonTapped, isTrue);
      expect(cannonHeld, isFalse);
    });
  });
}
