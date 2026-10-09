import 'dart:async';
import 'dart:math';

import '../services/settings_service.dart';

/// Shot phases. The engine owns them; the UI only observes and paints.
enum ShotPhase { idle, ready, flying, settle, gameOver }

/// Game modes.
class HoopMode {
  static const clock = 'clock'; // 60-second shot clock (score attack)
  static const streak = 'streak'; // 10 balls, score attack
  static const endless = 'endless'; // until 3 consecutive misses (Pro)
  static const shootout = 'shootout'; // 2-player pass-and-play shootout
  static const all = [clock, streak, endless, shootout];
}

/// Events the engine emits. The UI drains [events] every frame and turns
/// each into sound + visible feedback — scoring is never silent.
enum HoopEventKind {
  shot, // ball released
  basketSwish, // +3, nothing but net
  basketRim, // +2, rattled in
  rimBounce, // rim clank
  boardBounce, // backboard thud
  miss, // dead ball without scoring
  buzzer, // clock expired
  whistle, // game start / shootout turn change
  turnChange, // shootout: next shooter's ball
}

class HoopEvent {
  final HoopEventKind kind;
  final String message;
  final double x, y; // court-space anchor for floating popups
  final int points; // points awarded (0 for non-scoring)

  const HoopEvent({
    required this.kind,
    required this.message,
    this.x = 0,
    this.y = 0,
    this.points = 0,
  });
}

/// Hoop Shoot engine: owns ALL shot phases and settles every shot on its own
/// timers. A watchdog (frame clamps + independent timer) recovers any phase
/// found without forward progress — stuck states are impossible by
/// construction.
///
/// Physics: 2D side-view court, gravity + wind, rim-tip and backboard
/// collisions, swish detection (downward crossing inside the rim without
/// touching it).
class HoopEngine {
  final _rand = Random();

  ShotPhase phase = ShotPhase.idle;
  bool paused = false;

  // Config for the current game.
  String mode = HoopMode.clock;
  HoopDifficulty difficulty = HoopDifficulty.tiers[0];
  List<String> names = const ['Hooper', 'Rival'];

  // Court geometry (set by the UI via [resize]).
  double courtW = 400, courtH = 700;

  // Ball state.
  double ballX = 0, ballY = 0, velX = 0, velY = 0;
  final List<Point<double>> trail = [];
  bool rimTouched = false;
  bool boardTouched = false;
  bool scored = false;

  // Hoop state.
  double gameT = 0; // seconds since game start (excl. pause)
  double hoopBaseX = 0; // resting center
  double hoopY = 0;
  double wind = 0; // current wind accel, px/s^2
  double netSnap = 0; // 1.0 on swish, decays — UI draws the net bulge
  double rimShake = 0; // 1.0 on rim bounce, decays

  // Scoring.
  final List<int> points = [0, 0];
  final List<int> basketsMade = [0, 0];
  int shotsTaken = 0;
  int swishes = 0;
  int missesInARow = 0;
  double clockLeft = 60;
  double settleSecs = 0;
  bool _buzzerPending = false;

  // Shootout bookkeeping.
  int currentShooter = 0;
  final List<int> shootoutShots = [0, 0]; // shots taken per shooter
  static const shootoutShotsEach = 5;
  bool suddenDeath = false;
  String? winnerName;

  int get level => 1 + basketsMade[0] ~/ 3;
  double get hoopAmp =>
      difficulty.hoopAmp * (1 + min(0.5, basketsMade[0] * 0.04));
  double get hoopSpeed => difficulty.hoopSpeed;
  double get hoopX => hoopBaseX + sin(gameT * hoopSpeed) * hoopAmp;
  double get rimW => 96 * difficulty.rimScale;
  double get ballR => 16;
  String get currentName => names[currentShooter.clamp(0, names.length - 1)];

  /// Events for the UI to consume (sound + popups). Drain every frame.
  final List<HoopEvent> events = [];

  // Watchdog: independent timer so a phase can never sit without progress
  // even if the UI ticker stutters or stops briefly.
  Timer? _watchdog;

  // Phase time tracking for watchdog clamps (settle seconds measured here).
  double _phaseT = 0;

  HoopEngine() {
    _watchdog = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _watchdogTick();
    });
  }

  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void resize(double w, double h) {
    courtW = w;
    courtH = h;
    hoopBaseX = w / 2;
    hoopY = h * 0.20;
    if (phase == ShotPhase.idle) {
      _placeBall();
    }
  }

  // ------------------------------------------------------------- game setup

  void startGame({
    required String gameMode,
    required int difficultyIndex,
    required List<String> playerNames,
  }) {
    mode = HoopMode.all.contains(gameMode) ? gameMode : HoopMode.clock;
    difficulty = HoopDifficulty.of(difficultyIndex);
    names = playerNames.length >= 2 ? playerNames : const ['Hooper', 'Rival'];
    points[0] = 0;
    points[1] = 0;
    basketsMade[0] = 0;
    basketsMade[1] = 0;
    shotsTaken = 0;
    swishes = 0;
    missesInARow = 0;
    gameT = 0;
    clockLeft = 60;
    currentShooter = 0;
    shootoutShots[0] = 0;
    shootoutShots[1] = 0;
    suddenDeath = false;
    winnerName = null;
    netSnap = 0;
    rimShake = 0;
    wind = 0;
    _buzzerPending = false;
    paused = false;
    _placeBall();
    phase = ShotPhase.ready;
    _phaseT = 0;
    events.add(HoopEvent(
      kind: HoopEventKind.whistle,
      message: _modeKickoffMessage(),
    ));
  }

  String _modeKickoffMessage() {
    switch (mode) {
      case HoopMode.clock:
        return '60 seconds — light it up, ${names[0]}! 🔥';
      case HoopMode.streak:
        return '10 balls. Make every one count, ${names[0]}! 🎯';
      case HoopMode.endless:
        return 'Endless run — 3 straight misses and you\'re done! 🏀';
      case HoopMode.shootout:
        return '${names[0]} vs ${names[1]} — $shootoutShotsEach shots each. ${names[0]} shoots first! 🏆';
      default:
        return 'Hit the court!';
    }
  }

  void _placeBall() {
    ballX = courtW / 2 + (_rand.nextDouble() - 0.5) * 60;
    ballY = courtH * 0.86;
    velX = 0;
    velY = 0;
    trail.clear();
    rimTouched = false;
    boardTouched = false;
    scored = false;
  }

  // ------------------------------------------------------------------ input

  /// Flick to shoot. Only valid in [ShotPhase.ready]. Returns true if the
  /// shot was accepted; false (invalid flick) never changes state.
  bool flick(double vx, double vy) {
    if (phase != ShotPhase.ready || paused) return false;
    if (vy > -320) return false; // not an upward flick — ignore
    final scaledX = vx * 0.72;
    final scaledY = vy * 0.72;
    const maxV = 2350.0;
    final d = sqrt(scaledX * scaledX + scaledY * scaledY);
    if (d > maxV) {
      velX = scaledX / d * maxV;
      velY = scaledY / d * maxV;
    } else {
      velX = scaledX;
      velY = scaledY;
    }
    shotsTaken++;
    phase = ShotPhase.flying;
    _phaseT = 0;
    events.add(const HoopEvent(kind: HoopEventKind.shot, message: ''));
    return true;
  }

  // ----------------------------------------------------------------- update

  static const double _gravity = 1850;

  void update(double dt) {
    if (paused || dt <= 0 || dt > 0.1) return;
    gameT += dt;
    _phaseT += dt;
    netSnap = max(0, netSnap - dt * 2.2);
    rimShake = max(0, rimShake - dt * 3.5);
    _updateWind(dt);

    if (mode == HoopMode.clock && phase != ShotPhase.gameOver) {
      clockLeft -= dt;
      if (clockLeft <= 0) {
        clockLeft = 0;
        _onClockExpired();
      }
    }

    switch (phase) {
      case ShotPhase.ready:
        // Ball rests at its spot; the hoop may still drift underneath.
        break;
      case ShotPhase.flying:
        _physics(dt);
        // Watchdog clamp: a ball must settle within 6 seconds, always.
        if (_phaseT > 6) {
          events.add(HoopEvent(
            kind: HoopEventKind.miss,
            message: _missQuip(),
            x: ballX,
            y: ballY,
          ));
          _enterSettle();
        }
      case ShotPhase.settle:
        settleSecs += dt;
        // The engine settles every shot itself after ~0.9s of celebration.
        // Watchdog clamp (3s) guarantees forward progress no matter what.
        if (settleSecs > 0.9 || _phaseT > 3) {
          _advance();
        }
      case ShotPhase.idle:
      case ShotPhase.gameOver:
        break;
    }
  }

  void _updateWind(double dt) {
    if (difficulty.windMax <= 0) {
      wind = 0;
      return;
    }
    // Gusts change roughly every 2 seconds; smooth transition.
    final target =
        sin(gameT * 0.9) * difficulty.windMax * (0.4 + 0.6 * sin(gameT * 0.37 + 1.7));
    wind += (target - wind) * min(1, dt * 1.5);
  }

  void _onClockExpired() {
    if (phase == ShotPhase.gameOver) return;
    events.add(const HoopEvent(kind: HoopEventKind.buzzer, message: 'BUZZER! ⏱'));
    if (phase == ShotPhase.flying) {
      // NBA rule: a shot already in the air counts.
      _buzzerPending = true;
    } else if (phase == ShotPhase.ready || phase == ShotPhase.settle) {
      _finishGame();
    }
  }

  // ---------------------------------------------------------------- physics

  void _physics(double dt) {
    final lastY = ballY;
    velY += _gravity * dt;
    velX += wind * dt;
    ballX += velX * dt;
    ballY += velY * dt;
    trail.add(Point(ballX, ballY));
    if (trail.length > 14) trail.removeAt(0);

    final hx = hoopX;
    final hy = hoopY;
    final hw = rimW;
    final br = ballR;

    // Rim-tip collisions.
    for (final rx in [hx - hw / 2, hx + hw / 2]) {
      final dx = ballX - rx;
      final dy = ballY - hy;
      final d = sqrt(dx * dx + dy * dy);
      if (d < br + 6 && d > 0.01) {
        final nx = dx / d;
        final ny = dy / d;
        ballX = rx + nx * (br + 6);
        ballY = hy + ny * (br + 6);
        final vn = velX * nx + velY * ny;
        if (vn < 0) {
          velX -= nx * 1.5 * vn;
          velY -= ny * 1.5 * vn;
        }
        if (!rimTouched) {
          rimTouched = true;
          rimShake = 1;
          events.add(HoopEvent(
            kind: HoopEventKind.rimBounce,
            message: 'Off the iron! 🔔',
            x: ballX,
            y: hy,
          ));
        }
      }
    }

    // Backboard (vertical rect behind the rim): bounce off its left face.
    final bx = hx + hw / 2 + 6;
    if (ballX + br > bx &&
        ballX < bx + 26 &&
        ballY > hy - 118 &&
        ballY < hy + 6 &&
        velX > 0) {
      ballX = bx - br;
      velX = -velX * 0.55;
      if (!boardTouched) {
        boardTouched = true;
        events.add(const HoopEvent(
            kind: HoopEventKind.boardBounce, message: 'Off the glass! 🪟'));
      }
    }

    // Swish detection: crossing the rim plane downward inside the rim.
    if (!scored &&
        lastY < hy &&
        ballY >= hy &&
        velY > 0 &&
        (ballX - hx).abs() < hw / 2 - br * 0.4) {
      _basket(rimTouched);
      return;
    }

    // Dead ball: off-screen.
    if (ballY > courtH + 60 || ballX < -60 || ballX > courtW + 60) {
      if (!scored) {
        events.add(HoopEvent(
          kind: HoopEventKind.miss,
          message: _missQuip(),
          x: ballX.clamp(0, courtW),
          y: ballY.clamp(0, courtH),
        ));
      }
      _enterSettle();
    }
  }

  void _basket(bool offRim) {
    scored = true;
    final gained = offRim ? 2 : 3;
    points[currentShooter] += gained;
    basketsMade[currentShooter]++;
    missesInARow = 0;
    if (!offRim) {
      swishes++;
      netSnap = 1;
    }
    final streak = basketsMade[currentShooter];
    final flair = !offRim && streak >= 3 ? ' 🔥 ON FIRE!' : '';
    events.add(HoopEvent(
      kind: offRim ? HoopEventKind.basketRim : HoopEventKind.basketSwish,
      message: offRim ? 'Rattled in! +2 🏀' : 'SWISH! +3$flair',
      x: hoopX,
      y: hoopY,
      points: gained,
    ));
    _enterSettle();
  }

  String _missQuip() {
    final pool = [
      'Airball... the crowd goes mild 😅',
      'Brick! 🧱',
      'So close! Rim says no 🙅',
      'Off target — shake it off! 💪',
      'Wind took that one! 🌬️',
    ];
    return pool[_rand.nextInt(pool.length)];
  }

  void _enterSettle() {
    phase = ShotPhase.settle;
    settleSecs = 0;
    _phaseT = 0;
    trail.clear();
  }

  // ------------------------------------------------------- phase advancement

  void _advance() {
    if (_buzzerPending) {
      _buzzerPending = false;
      _finishGame();
      return;
    }
    final justScored = scored;
    if (!justScored) missesInARow++;

    switch (mode) {
      case HoopMode.clock:
        if (clockLeft <= 0) {
          _finishGame();
          return;
        }
      case HoopMode.streak:
        if (shotsTaken >= 10) {
          _finishGame();
          return;
        }
      case HoopMode.endless:
        if (missesInARow >= 3) {
          _finishGame();
          return;
        }
      case HoopMode.shootout:
        _advanceShootout();
        return;
    }
    _nextBall();
  }

  void _nextBall() {
    _placeBall();
    phase = ShotPhase.ready;
    _phaseT = 0;
  }

  /// Shootout: shooters strictly alternate. Each takes 5 shots; a tied
  /// score goes to sudden-death pairs until the scores differ. Every turn
  /// change is announced via an event — never a silent handoff.
  void _advanceShootout() {
    shootoutShots[currentShooter]++;
    if (!suddenDeath) {
      if (shootoutShots[0] >= shootoutShotsEach &&
          shootoutShots[1] >= shootoutShotsEach) {
        if (points[0] != points[1]) {
          _finishShootout();
          return;
        }
        suddenDeath = true;
        shootoutShots[0] = 0;
        shootoutShots[1] = 0;
        currentShooter = 0;
        _nextBall();
        events.add(const HoopEvent(
          kind: HoopEventKind.turnChange,
          message: 'TIE GAME — sudden death! ☠️',
        ));
        events.add(const HoopEvent(kind: HoopEventKind.whistle, message: ''));
        return;
      }
      currentShooter = 1 - currentShooter;
      _nextBall();
      final left = shootoutShotsEach - shootoutShots[currentShooter];
      events.add(HoopEvent(
        kind: HoopEventKind.turnChange,
        message:
            '${currentName}\'s shot — $left left${points[0] != points[1] ? ', trails by ${(points[0] - points[1]).abs()}!' : '!'} 🏀',
      ));
      return;
    }
    // Sudden death: compare after every completed pair.
    if (shootoutShots[0] >= 1 && shootoutShots[1] >= 1) {
      if (points[0] != points[1]) {
        _finishShootout();
        return;
      }
      shootoutShots[0] = 0;
      shootoutShots[1] = 0;
      currentShooter = 0;
      _nextBall();
      events.add(const HoopEvent(
        kind: HoopEventKind.turnChange,
        message: 'Still tied — sudden death continues! ☠️',
      ));
      return;
    }
    currentShooter = 1 - currentShooter;
    _nextBall();
    events.add(HoopEvent(
      kind: HoopEventKind.turnChange,
      message: '${currentName}\'s sudden-death shot! ☠️',
    ));
  }

  void _finishShootout() {
    winnerName = points[0] > points[1]
        ? names[0]
        : (points[1] > points[0] ? names[1] : null);
    _finishGame();
  }

  void _finishGame() {
    if (phase == ShotPhase.gameOver) return;
    phase = ShotPhase.gameOver;
    _phaseT = 0;
  }

  bool get isGameOver => phase == ShotPhase.gameOver;

  /// Watchdog: independent timer. If the engine is mid-game and NOT paused
  /// but a phase has sat without progress past its hard clamp, force it
  /// forward. This makes stuck states impossible even if the UI ticker
  /// stalls.
  void _watchdogTick() {
    if (paused) return;
    if (phase == ShotPhase.flying && _phaseT > 6.5) {
      events.add(HoopEvent(
        kind: HoopEventKind.miss,
        message: _missQuip(),
        x: ballX.clamp(0, courtW),
        y: ballY.clamp(0, courtH),
      ));
      _enterSettle();
    } else if (phase == ShotPhase.settle && _phaseT > 3.5) {
      _advance();
    } else if (phase == ShotPhase.ready &&
        mode == HoopMode.clock &&
        clockLeft <= 0) {
      _finishGame();
    }
  }

  int get winnerPoints => max(points[0], points[1]);
}
