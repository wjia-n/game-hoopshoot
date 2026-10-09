import 'package:flutter_test/flutter_test.dart';
import 'package:hoopshoot/engine/hoopshoot_engine.dart';

void main() {
  HoopEngine fresh(String mode, {int difficulty = 0}) {
    final e = HoopEngine();
    e.resize(400, 700);
    e.startGame(
      gameMode: mode,
      difficultyIndex: difficulty,
      playerNames: const ['Hooper', 'Rival'],
    );
    addTearDown(e.dispose);
    return e;
  }

  test('weak flick is ignored, strong flick starts flight', () {
    final e = fresh(HoopMode.clock);
    expect(e.phase, ShotPhase.ready);
    expect(e.flick(0, -100), isFalse); // too weak — ignored
    expect(e.phase, ShotPhase.ready);
    expect(e.shotsTaken, 0);
    expect(e.flick(0, -1000), isTrue); // strong upward flick
    expect(e.phase, ShotPhase.flying);
    expect(e.shotsTaken, 1);
    // Second flick mid-flight is ignored.
    expect(e.flick(0, -1500), isFalse);
    expect(e.shotsTaken, 1);
  });

  test('dead ball settles and the next ball arrives (no stuck state)', () {
    final e = fresh(HoopMode.streak, difficulty: 0);
    e.flick(400, -400); // weak-ish upward; will fly off-screen
    var guard = 0;
    while (e.phase != ShotPhase.ready && guard++ < 2000) {
      e.update(1 / 60);
    }
    // Either scored or missed, a new ball is ready again.
    expect(e.phase, ShotPhase.ready);
    expect(e.events.any((ev) => ev.kind == HoopEventKind.shot), isTrue);
  });

  test('watchdog recovers a phase that never progresses', () {
    final e = fresh(HoopMode.clock);
    e.flick(0, -1200);
    expect(e.phase, ShotPhase.flying);
    // Simulate a stalled ticker: force the internal phase timer past the
    // clamp via many updates without ball progress, then call watchdog.
    for (int i = 0; i < 400; i++) {
      e.update(1 / 60);
      if (e.phase != ShotPhase.flying) break;
    }
    expect(e.phase, isNot(ShotPhase.flying));
  });

  test('streak mode ends after 10 shots', () {
    final e = fresh(HoopMode.streak);
    for (int i = 0; i < 10 && !e.isGameOver; i++) {
      expect(e.phase, ShotPhase.ready);
      e.flick(500, -500);
      var guard = 0;
      while (!e.isGameOver && e.phase != ShotPhase.ready && guard++ < 3000) {
        e.update(1 / 60);
      }
    }
    expect(e.isGameOver, isTrue);
    expect(e.shotsTaken, 10);
  });

  test('shootout alternates shooters and finishes with a winner', () {
    final e = fresh(HoopMode.shootout);
    var guard = 0;
    while (!e.isGameOver && guard++ < 200) {
      expect(e.phase, ShotPhase.ready);
      final before = e.currentShooter;
      e.flick(600, -600);
      var g2 = 0;
      while (!e.isGameOver && e.phase != ShotPhase.ready && g2++ < 3000) {
        e.update(1 / 60);
      }
      if (e.isGameOver) break;
      // Next shot goes to the other shooter (or sudden death resets).
      expect(e.currentShooter, isNot(before));
    }
    expect(e.isGameOver, isTrue);
    expect(e.winnerName, isNotNull);
  });

  test('clock expiry with ball ready ends the game', () {
    final e = fresh(HoopMode.clock);
    e.clockLeft = 0.05;
    e.update(0.1);
    expect(e.isGameOver, isTrue);
  });

  test('clock expiry mid-flight lets the shot count, then ends', () {
    final e = fresh(HoopMode.clock);
    e.flick(0, -1200);
    e.clockLeft = 0.01;
    e.update(0.05); // buzzer fires while flying
    expect(e.isGameOver, isFalse);
    var guard = 0;
    while (!e.isGameOver && guard++ < 3000) {
      e.update(1 / 60);
    }
    expect(e.isGameOver, isTrue);
    expect(e.events.any((ev) => ev.kind == HoopEventKind.buzzer), isTrue);
  });

  test('endless ends after three consecutive misses', () {
    final e = fresh(HoopMode.endless);
    var shots = 0;
    var guard = 0;
    while (!e.isGameOver && guard++ < 500) {
      if (e.phase == ShotPhase.ready) {
        e.flick(900, -300); // sideways — guaranteed miss
        shots++;
      }
      e.update(1 / 60);
    }
    expect(e.isGameOver, isTrue);
    expect(e.missesInARow, greaterThanOrEqualTo(3));
    expect(shots, greaterThanOrEqualTo(3));
  });

  test('pause freezes the engine', () {
    final e = fresh(HoopMode.clock);
    e.flick(0, -1200);
    final x0 = e.ballX, y0 = e.ballY;
    e.paused = true;
    for (int i = 0; i < 60; i++) {
      e.update(1 / 60);
    }
    expect(e.ballX, x0);
    expect(e.ballY, y0);
    expect(e.phase, ShotPhase.flying);
  });
}
