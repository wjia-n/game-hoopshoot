import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/hoopshoot_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.hoopshoot';

class _Popup {
  final String text;
  final double x, y;
  double t = 0;
  _Popup(this.text, this.x, this.y);
}

/// Live game screen: HUD, court, pause + game-over overlays.
/// The [HoopEngine] owns all phases; this screen only observes and paints.
class GameScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  final String mode;
  const GameScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late HoopEngine _engine;

  final List<_Popup> _popups = [];
  String _msg = '';
  double _msgBorn = -99;
  bool _paused = false;
  bool _gameOverShown = false;
  bool _newBest = false;
  String _gameOverHeadline = '';
  String _gameOverSubline = '';

  // Aim guide state.
  Offset? _panStart;
  Offset? _panNow;

  HoopSettings get s => widget.settings;
  HoopAudio get audio => widget.audio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = HoopEngine();
    _engine.startGame(
      gameMode: widget.mode,
      difficultyIndex: s.difficulty,
      playerNames: s.playerNames,
    );
    _ticker = createTicker(_tick)..start();
    audio.startGameMusic();
    audio.whistle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    audio.startMenuMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _engine.paused = true;
      if (mounted) setState(() => _paused = true);
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMilliseconds / 1000.0;
    _last = elapsed;
    if (!mounted || dt <= 0 || dt > 0.1) return;
    _engine.update(dt);
    _drainEvents();
    for (final p in _popups) {
      p.t += dt;
    }
    _popups.removeWhere((p) => p.t > 1.4);
    if (_engine.isGameOver && !_gameOverShown) {
      _onGameOver();
    }
    setState(() {});
  }

  void _drainEvents() {
    for (final e in _engine.events) {
      switch (e.kind) {
        case HoopEventKind.shot:
          audio.shoot();
        case HoopEventKind.basketSwish:
          audio.swish();
          audio.cheer();
        case HoopEventKind.basketRim:
          audio.swish();
          audio.cheer();
        case HoopEventKind.rimBounce:
          audio.rim();
        case HoopEventKind.boardBounce:
          audio.bounce();
        case HoopEventKind.miss:
          audio.bounce();
        case HoopEventKind.buzzer:
          audio.buzzer();
        case HoopEventKind.whistle:
          audio.whistle();
        case HoopEventKind.turnChange:
          audio.whistle();
      }
      if (e.message.isNotEmpty) {
        _msg = e.message;
        _msgBorn = _engine.gameT;
        if (e.kind == HoopEventKind.basketSwish ||
            e.kind == HoopEventKind.basketRim ||
            e.kind == HoopEventKind.miss) {
          _popups.add(_Popup(e.message, e.x, e.y));
        }
      }
    }
    _engine.events.clear();
  }

  Future<void> _onGameOver() async {
    _gameOverShown = true;
    final e = _engine;
    final pts = widget.mode == HoopMode.shootout ? e.winnerPoints : e.points[0];
    _newBest = await s.recordGame(
      mode: widget.mode,
      points: pts,
      baskets: e.basketsMade[0] + e.basketsMade[1],
      swishes: e.swishes,
    );
    audio.buzzer();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    audio.lose();
    setState(() {
      _gameOverHeadline = _headline(pts);
      _gameOverSubline = _subline(pts);
    });
    if (_newBest) {
      // Sensible review moment: a brand-new best, asked once per game.
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
  }

  String _headline(int pts) {
    final e = _engine;
    switch (widget.mode) {
      case HoopMode.clock:
        return 'Buzzer! $pts pts in 60s! 🏀';
      case HoopMode.streak:
        return '$pts pts — ${e.basketsMade[0]}/10 buckets! 🎯';
      case HoopMode.endless:
        return '3 straight misses — $pts pts! 🏀';
      case HoopMode.shootout:
        return '${e.winnerName ?? 'Tie'} takes the shootout! 🏆';
      default:
        return 'Game over!';
    }
  }

  String _subline(int pts) {
    final e = _engine;
    final total = e.basketsMade[0] + e.basketsMade[1];
    final base = widget.mode == HoopMode.shootout
        ? '${s.playerNames[0]} ${e.points[0]} — ${e.points[1]} ${s.playerNames[1]}'
        : '$total buckets · ${e.swishes} swishes';
    return _newBest ? 'NEW BEST! The gym goes wild! 🏆🔥\n$base' : base;
  }

  void _restart() {
    audio.gameStart();
    setState(() {
      _engine.dispose();
      _engine = HoopEngine();
      _engine.startGame(
        gameMode: widget.mode,
        difficultyIndex: s.difficulty,
        playerNames: s.playerNames,
      );
      _popups.clear();
      _msg = '';
      _paused = false;
      _gameOverShown = false;
      _newBest = false;
      audio.startGameMusic();
    });
  }

  void _togglePause() {
    audio.click();
    setState(() {
      _paused = !_paused;
      _engine.paused = _paused;
      if (_paused) {
        audio.onAppPaused();
      } else {
        audio.onAppResumed();
      }
    });
  }

  void _share() {
    audio.click();
    Share.share(
        'I just dropped ${_engine.points[0]} pts in Hoop Shoot! 🏀 Can you beat me? $_storeUrl');
  }

  void _quit() {
    audio.click();
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = s.theme;
    final e = _engine;
    final ballStyle = BallStyles.byIndex(s.ballStyle);
    final hoopStyle = HoopStyles.byIndex(s.hoopStyle);
    return Scaffold(
      backgroundColor: t.wall,
      body: SafeArea(
        child: Column(
          children: [
            _hud(t, e),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: LayoutBuilder(builder: (_, c) {
                  e.resize(c.maxWidth, c.maxHeight);
                  return GestureDetector(
                    onPanStart: (d) {
                      if (_paused || _gameOverShown) return;
                      _panStart = d.localPosition;
                      _panNow = d.localPosition;
                    },
                    onPanUpdate: (d) {
                      if (_paused || _gameOverShown) return;
                      setState(() => _panNow = d.localPosition);
                    },
                    onPanEnd: (d) {
                      _panStart = null;
                      _panNow = null;
                      if (_paused ||
                          _gameOverShown ||
                          e.phase != ShotPhase.ready) {
                        return;
                      }
                      final v = d.velocity.pixelsPerSecond;
                      final accepted =
                          e.flick(v.dx, v.dy);
                      if (!accepted && v.distance > 140) {
                        // A deliberate swipe the rules reject (weak or
                        // downward flick): soft "nope", no penalty.
                        audio.invalid();
                      }
                    },
                    onPanCancel: () {
                      _panStart = null;
                      _panNow = null;
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: _CourtPainter(
                          theme: t,
                          e: e,
                          ballStyle: ballStyle,
                          hoopStyle: hoopStyle,
                          popups: _popups,
                          aimStart: _panStart,
                          aimNow: _panNow,
                        ),
                        child: Container(),
                      ),
                    ),
                  );
                }),
              ),
            ),
            _messageBar(t, e),
            if (_paused) _pauseOverlay(t),
            if (_gameOverShown) _gameOverOverlay(t),
          ],
        ),
      ),
    );
  }

  Widget _hud(CourtThemeDef t, HoopEngine e) {
    final modeInfo = _modeHudText(e);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: t.rimColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.pause, color: Colors.white),
            onPressed: _togglePause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_scoreText(e),
                    style: HoopType.headline(18)),
                Text(modeInfo,
                    style: HoopType.body(12,
                        color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          if (e.difficulty.windMax > 0) _windChip(e),
          const SizedBox(width: 8),
          Text('Lvl ${e.level}',
              style: HoopType.body(13,
                  color: const Color(0xFFF0A050))),
        ],
      ),
    );
  }

  String _scoreText(HoopEngine e) {
    if (widget.mode == HoopMode.shootout) {
      return '${e.points[0]} – ${e.points[1]}';
    }
    return '${e.points[0]} pts';
  }

  String _modeHudText(HoopEngine e) {
    switch (widget.mode) {
      case HoopMode.clock:
        return '⏱ ${max(0, e.clockLeft.ceil())}s · ${e.currentName}';
      case HoopMode.streak:
        return '🎯 ${max(0, 10 - e.shotsTaken)}/10 left · ${e.currentName}';
      case HoopMode.endless:
        return '❌ ${e.missesInARow}/3 misses · ${e.currentName}';
      case HoopMode.shootout:
        final left = HoopEngine.shootoutShotsEach -
            e.shootoutShots[e.currentShooter];
        final tag = e.suddenDeath ? 'sudden death' : '$left shots left';
        return '${e.currentName} shoots · $tag';
      default:
        return e.currentName;
    }
  }

  Widget _windChip(HoopEngine e) {
    final w = e.wind;
    if (w.abs() < 8) return const SizedBox.shrink();
    final dir = w > 0 ? '→' : '←';
    final bars = (w.abs() / 40).clamp(1, 3).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('🌬 $dir ${'▮' * bars}',
          style: HoopType.body(12)),
    );
  }

  Widget _messageBar(CourtThemeDef t, HoopEngine e) {
    final showMsg = _msg.isNotEmpty && e.gameT - _msgBorn < 2.4;
    String hint;
    if (_gameOverShown) {
      hint = 'Game over! 🎉';
    } else if (_paused) {
      hint = 'Paused ⏸';
    } else if (showMsg) {
      hint = _msg;
    } else if (e.phase == ShotPhase.ready) {
      hint = 'Flick UP on the ball to shoot! 👆';
    } else {
      hint = '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: SizedBox(
        height: 24,
        child: Text(hint,
            textAlign: TextAlign.center,
            style: HoopType.body(15)),
      ),
    );
  }

  Widget _pauseOverlay(CourtThemeDef t) {
    return _overlay(
      t,
      title: 'Paused ⏸',
      children: [
        _overlayButton(t, 'Resume', Icons.play_arrow, _togglePause,
            primary: true),
        _overlayButton(t, 'Restart', Icons.refresh, _restart),
        _overlayButton(t, 'Quit to menu', Icons.home, _quit),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _miniToggle(
                icon: s.musicOn ? Icons.music_note : Icons.music_off,
                onTap: () {
                  audio.click();
                  s.setMusic(!s.musicOn);
                  audio.configure(
                      musicOn: s.musicOn,
                      sfxOn: s.sfxOn,
                      volume: s.volume);
                  if (s.musicOn) {
                    audio.startGameMusic();
                  }
                  setState(() {});
                }),
            const SizedBox(width: 12),
            _miniToggle(
                icon: s.sfxOn ? Icons.volume_up : Icons.volume_off,
                onTap: () {
                  audio.click();
                  s.setSfx(!s.sfxOn);
                  audio.configure(
                      musicOn: s.musicOn,
                      sfxOn: s.sfxOn,
                      volume: s.volume);
                  setState(() {});
                }),
          ],
        ),
      ],
    );
  }

  Widget _gameOverOverlay(CourtThemeDef t) {
    return _overlay(
      t,
      title: _gameOverHeadline,
      children: [
        Text(_gameOverSubline,
            textAlign: TextAlign.center,
            style: HoopType.body(14)),
        const SizedBox(height: 6),
        if (_newBest)
          Text('NEW BEST! 🏆🔥',
              style: HoopType.headline(16,
                  color: const Color(0xFFE8A820))),
        _overlayButton(t, 'Play again', Icons.refresh, _restart,
            primary: true),
        _overlayButton(t, 'Share score', Icons.share, _share),
        _overlayButton(t, 'Menu', Icons.home, _quit),
      ],
    );
  }

  Widget _overlay(CourtThemeDef t,
      {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF241407).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.rimColor, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 8),
              blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: HoopType.headline(22)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _overlayButton(CourtThemeDef t, String label, IconData icon,
      VoidCallback onTap,
      {bool primary = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label, style: HoopType.body(15)),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                primary ? t.rimColor : Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _miniToggle({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Court painter — pseudo-3D realistic court: arena wall, crowd, hardwood
// planks, painted key, metal pole + backboard, rope net, leather ball.
// ---------------------------------------------------------------------------

class _CourtPainter extends CustomPainter {
  final CourtThemeDef theme;
  final HoopEngine e;
  final BallStyle ballStyle;
  final HoopStyle hoopStyle;
  final List<_Popup> popups;
  final Offset? aimStart;
  final Offset? aimNow;

  _CourtPainter({
    required this.theme,
    required this.e,
    required this.ballStyle,
    required this.hoopStyle,
    required this.popups,
    this.aimStart,
    this.aimNow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final w = size.width;
    final h = size.height;
    final hx = e.hoopX + e.rimShake * 5 * sin(e.gameT * 60);
    final hy = e.hoopY;
    final hw = e.rimW;

    // Wall.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h * 0.42),
        Paint()
          ..shader = LinearGradient(
            colors: [t.wall.withValues(alpha: 0.75), t.wall],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, w, h * 0.42)));

    // Crowd band: rows of silhouettes.
    final crowdTop = h * 0.42;
    final crowdH = h * 0.10;
    canvas.drawRect(Rect.fromLTWH(0, crowdTop, w, crowdH),
        Paint()..color = t.crowd);
    final crowdRand = Random(7);
    for (double y = crowdTop + 6; y < crowdTop + crowdH - 2; y += 13) {
      for (double x = 4; x < w; x += 15) {
        final shade = crowdRand.nextDouble();
        canvas.drawCircle(
            Offset(x + crowdRand.nextDouble() * 6, y),
            5.2,
            Paint()
              ..color = t.wall
                  .withValues(alpha: 0.55 + shade * 0.4));
      }
    }

    // Hardwood floor: planks.
    final floorTop = crowdTop + crowdH;
    final plankH = 26.0;
    int row = 0;
    for (double y = floorTop; y < h; y += plankH, row++) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, plankH),
          Paint()..color = row.isEven ? t.floorLight : t.floorDark);
      canvas.drawRect(
          Rect.fromLTWH(0, y, w, 1.5),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.18));
      // Grain + seams.
      final g = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..strokeWidth = 1;
      final gr = Random(row * 31 + 3);
      for (int k = 0; k < 3; k++) {
        final gy = y + 4 + gr.nextDouble() * (plankH - 8);
        canvas.drawLine(Offset(0, gy), Offset(w, gy + gr.nextDouble() * 4 - 2), g);
      }
      final seamX = (row * 173) % w.toInt();
      canvas.drawRect(Rect.fromLTWH(seamX.toDouble(), y, 2, plankH),
          Paint()..color = Colors.black.withValues(alpha: 0.22));
    }

    // Painted key + free-throw circle + 3pt arc.
    final keyW = 150.0;
    final keyRect = RRect.fromLTRBR(
        w / 2 - keyW / 2, floorTop - 6, w / 2 + keyW / 2, floorTop + 150,
        const Radius.circular(6));
    canvas.drawRRect(keyRect,
        Paint()..color = t.keyColor.withValues(alpha: 0.88));
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(w / 2, floorTop + 150), width: 110, height: 110),
        0, pi,
        false,
        Paint()
          ..color = t.lineColor.withValues(alpha: 0.9)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(w / 2, hy + 40), width: w * 1.15, height: w * 1.15),
        0.35 * pi, 0.3 * pi,
        false,
        Paint()
          ..color = t.lineColor.withValues(alpha: 0.85)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke);

    // Pole (behind the hoop).
    final poleX = hx + hw / 2 + 30;
    final polePaint = Paint()
      ..color = const Color(0xFF4A4A52)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(poleX, 0), Offset(poleX, hy - 8), polePaint);
    final poleHi = Paint()
      ..color = const Color(0xFF8A8A96)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(poleX - 3, 0), Offset(poleX - 3, hy - 8), poleHi);

    // Backboard slab.
    final bx = hx + hw / 2 + 6;
    final boardRect = RRect.fromLTRBR(
        bx, hy - 118, bx + 16, hy - 8, const Radius.circular(3));
    canvas.drawRRect(
        boardRect,
        Paint()
          ..color = t.boardColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        boardRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(bx + 8, hy - 40), width: 12, height: 34),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    // Rim (ellipse bar).
    final rimPaint = Paint()
      ..color = hoopStyle.rim
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hx - hw / 2, hy), Offset(hx + hw / 2, hy), rimPaint);
    final rimHi = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(hx - hw / 2 + 4, hy - 2), Offset(hx + hw / 2 - 4, hy - 2), rimHi);

    // Net: diamond mesh, snapping down on a swish.
    final snap = e.netSnap;
    final netLen = 58 + snap * 22;
    final netPaint = Paint()
      ..color = hoopStyle.net
      ..strokeWidth = 2.4;
    const segs = 8;
    for (int i = 0; i <= segs; i++) {
      final x0 = hx - hw / 2 + hw * i / segs;
      final pinch = (x0 - hx) * 0.55;
      canvas.drawLine(Offset(x0, hy + 3),
          Offset(hx + pinch, hy + netLen * (0.55 + 0.45 * snap)), netPaint);
    }
    for (int r = 1; r <= 3; r++) {
      final yy = hy + netLen * r / 3.5;
      final wob = (hw / 2) * (1 - r / 5.5);
      canvas.drawLine(Offset(hx - wob, yy), Offset(hx + wob, yy), netPaint);
    }
    canvas.drawLine(Offset(hx - hw * 0.26, hy + netLen),
        Offset(hx + hw * 0.26, hy + netLen), netPaint);

    // Aim guide (dotted ballistic preview while dragging).
    if (aimStart != null && aimNow != null) {
      final dir = aimNow! - aimStart!;
      if (dir.distance > 24) {
        _drawAimGuide(canvas, dir);
      }
    }

    // Ball + trail.
    for (int i = 0; i < e.trail.length; i++) {
      final p = e.trail[i];
      canvas.drawCircle(
          Offset(p.x, p.y),
          5 + 9 * i / e.trail.length,
          Paint()
            ..color = ballStyle.base
                .withValues(alpha: 0.10 + 0.22 * i / e.trail.length));
    }
    if (e.phase == ShotPhase.ready ||
        e.phase == ShotPhase.flying ||
        e.phase == ShotPhase.settle && e.scored) {
      final bp = e.phase == ShotPhase.ready
          ? Offset(e.ballX, e.ballY)
          : Offset(e.ballX, e.ballY);
      _drawBall(canvas, bp, ballStyle, h);
    }

    // Score popups.
    for (final p in popups) {
      final a = (1 - p.t / 1.4).clamp(0.0, 1.0);
      final scale = 1 + 0.25 * (1 - min(1, p.t * 4));
      final tp = TextPainter(
        text: TextSpan(
            text: p.text,
            style: HoopType.headline(20 * scale)
                .copyWith(color: Colors.white.withValues(alpha: a))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(p.x - tp.width / 2, p.y - 40 - p.t * 55 - tp.height / 2));
    }
  }

  void _drawAimGuide(Canvas canvas, Offset dir) {
    final v = dir * 4.2; // px/s estimate
    double x = e.ballX;
    double y = e.ballY;
    double vx = v.dx;
    double vy = v.dy;
    const dt = 1 / 30;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (int i = 0; i < 14; i++) {
      vy += 1850 * dt;
      x += vx * dt;
      y += vy * dt;
      canvas.drawCircle(Offset(x, y), 4 - i * 0.18, dot);
      if (y > e.courtH) break;
    }
  }

  void _drawBall(Canvas canvas, Offset b, BallStyle s, double h) {
    // Floor shadow (shrinks as the ball rises).
    final heightFrac = (b.dy / h).clamp(0.0, 1.0);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(b.dx, h - 14),
            width: 64 * (1 - heightFrac * 0.45),
            height: 12),
        Paint()..color = Colors.black.withValues(alpha: 0.35 * (1 - heightFrac * 0.6)));

    const r = 16.0;
    // Body with a soft light falloff.
    canvas.drawCircle(
        b,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [s.base, s.panel],
            center: const Alignment(-0.35, -0.35),
            radius: 1.1,
          ).createShader(Rect.fromCircle(center: b, radius: r)));
    // Highlight.
    canvas.drawCircle(
        b + const Offset(-5, -6),
        5.5,
        Paint()..color = Colors.white.withValues(alpha: 0.35));
    // Seams: circle, vertical + horizontal, curved panels.
    final seam = Paint()
      ..color = s.seam
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(b, r - 1, seam);
    canvas.drawLine(b + const Offset(0, -r), b + const Offset(0, r), seam);
    canvas.drawLine(b + const Offset(-r, 0), b + const Offset(r, 0), seam);
    canvas.drawArc(Rect.fromCircle(center: b + const Offset(-r * 0.9, 0), radius: r * 0.85),
        -1.1, 2.2, false, seam);
    canvas.drawArc(Rect.fromCircle(center: b + const Offset(r * 0.9, 0), radius: r * 0.85),
        pi - 1.1, 2.2, false, seam);
  }

  @override
  bool shouldRepaint(covariant _CourtPainter o) => true;
}
