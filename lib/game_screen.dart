import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Hoop Shoot — flick-to-shoot arcade basketball. Swish=3, rim=2.
class HoopShootScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const HoopShootScreen({super.key, required this.players, required this.callbacks});

  @override
  State<HoopShootScreen> createState() => _HoopShootScreenState();
}

class _HoopShootScreenState extends State<HoopShootScreen>
    with SingleTickerProviderStateMixin {
  final rnd = Random();
  late Ticker _ticker;
  Duration _last = Duration.zero;

  String? mode; // 'clock' | 'streak'
  bool over = false;
  double gameT = 0; // seconds elapsed in mode

  // ball physics
  Offset ball = Offset.zero, vel = Offset.zero;
  bool flying = false, scored = false, rimTouched = false;
  double lastY = 0;
  List<Offset> trail = [];
  Size court = Size.zero;

  int points = 0, baskets = 0, shots = 0;
  int bestClock = 0, bestStreak = 0;
  String msg = 'Pick a mode to hit the court! 🏀';
  double _msgT = 0;

  int get level => 1 + baskets ~/ 3;
  double get hoopAmp =>
      level >= 3 ? min(150.0, (level - 2) * 50.0) : 0.0;
  double get hoopSpeed => 1.1 + level * 0.28;
  double get hoopX =>
      court.width / 2 + sin(gameT * hoopSpeed) * hoopAmp;
  double get hoopY => court.height * 0.20;
  double get rimW => 96;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        bestClock = p.getInt('hoopshoot_best_clock') ?? 0;
        bestStreak = p.getInt('hoopshoot_best_streak') ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startMode(String m) {
    setState(() {
      mode = m;
      over = false;
      gameT = 0;
      points = 0;
      baskets = 0;
      shots = 0;
      flying = false;
      _resetBall();
      msg = m == 'clock'
          ? '60 seconds — light it up! 🔥'
          : '10 balls. Make every one count! 🎯';
      _msgT = gameT;
    });
    Sfx.click();
  }

  void _resetBall() {
    ball = Offset(
        court.width / 2 + (rnd.nextDouble() - 0.5) * 60, court.height * 0.86);
    vel = Offset.zero;
    flying = false;
    scored = false;
    rimTouched = false;
    trail = [];
    lastY = ball.dy;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMilliseconds / 1000.0;
    _last = elapsed;
    if (!mounted || mode == null || over || dt <= 0 || dt > 0.1) return;
    setState(() {
      gameT += dt;
      if (flying) _physics(dt);
      if (mode == 'clock' && gameT >= 60) _endGame();
    });
  }

  void _physics(double dt) {
    lastY = ball.dy;
    vel += Offset(0, 1850 * dt);
    ball += vel * dt;
    trail.add(ball);
    if (trail.length > 14) trail.removeAt(0);
    const br = 16.0;
    // rim collision (two rim tips)
    for (final rx in [hoopX - rimW / 2, hoopX + rimW / 2]) {
      final rp = Offset(rx, hoopY);
      final d = (ball - rp).distance;
      if (d < br + 6 && d > 0.01) {
        final n = (ball - rp) / d;
        ball = rp + n * (br + 6);
        final vn = vel.dx * n.dx + vel.dy * n.dy;
        if (vn < 0) vel = vel - n * (1.5 * vn);
        if (!rimTouched) {
          rimTouched = true;
          Sfx.tap();
        }
      }
    }
    // swish detection: crossing rim plane downward inside the rim
    if (!scored &&
        lastY < hoopY &&
        ball.dy >= hoopY &&
        vel.dy > 0 &&
        (ball.dx - hoopX).abs() < rimW / 2 - br * 0.4) {
      _basket();
    }
    // dead ball
    if (ball.dy > court.height + 60 ||
        ball.dx < -60 ||
        ball.dx > court.width + 60) {
      if (!scored) {
        msg = _missQuip();
        _msgT = gameT;
        Sfx.lose();
      }
      _nextBall();
    }
  }

  String _missQuip() =>
      ['Airball... the crowd goes mild 😅', 'Brick! 🧱', 'So close! Rim says no 🙅', 'Off target — shake it off! 💪']
          [rnd.nextInt(4)];

  void _basket() {
    scored = true;
    baskets++;
    final gained = rimTouched ? 2 : 3;
    points += gained;
    widget.players[0].score = points;
    widget.callbacks.refreshHud();
    msg = rimTouched ? 'Rattled in! +2 🏀' : 'SWISH! +3 🔥';
    _msgT = gameT;
    Sfx.win();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || over) return;
      setState(_nextBall);
    });
  }

  void _nextBall() {
    if (mode == 'streak' && shots >= 10) {
      _endGame();
      return;
    }
    _resetBall();
  }

  void _flick(Offset v) {
    if (mode == null || over || flying) return;
    if (v.dy > -320) return;
    setState(() {
      final scaled = v * 0.72;
      final maxV = 2350.0;
      vel = scaled.distance > maxV ? scaled / scaled.distance * maxV : scaled;
      flying = true;
      shots++;
      msg = '';
    });
    Sfx.move();
  }

  void _endGame() {
    if (over) return;
    setState(() => over = true);
    widget.players[0].score = points;
    widget.callbacks.refreshHud();
    SharedPreferences.getInstance().then((p) {
      if (mode == 'clock' && points > bestClock) {
        p.setInt('hoopshoot_best_clock', points);
      }
      if (mode == 'streak' && points > bestStreak) {
        p.setInt('hoopshoot_best_streak', points);
      }
    });
    final best = mode == 'clock' ? max(bestClock, points) : max(bestStreak, points);
    Sfx.win();
    widget.callbacks.finish(
      headline: mode == 'clock'
          ? 'Buzzer! You dropped $points pts! 🏀'
          : '$points pts on 10 balls — $baskets/10 buckets! 🏀',
      subline: points >= best && points > 0
          ? 'NEW BEST! The gym goes wild! 🏆🔥'
          : 'Best: $best. Run it back? 💪',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Column(
      children: [
        _hud(t),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: LayoutBuilder(builder: (_, c) {
              court = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                onPanEnd: (d) {
                  if (mode == null || over || flying) return;
                  _flick(d.velocity.pixelsPerSecond);
                },
                child: CustomPaint(
                  painter: _CourtPainter(
                    t: t,
                    ball: ball,
                    trail: trail,
                    flying: flying,
                    hoopX: hoopX,
                    hoopY: hoopY,
                    rimW: rimW,
                    hasBall: mode != null,
                    ballSpot: Offset(court.width / 2, court.height * 0.86),
                  ),
                  child: Container(),
                ),
              );
            }),
          ),
        ),
        if (mode == null) _modeChooser(t) else _hintBar(t),
      ],
    );
  }

  Widget _hud(GameTheme t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$points pts',
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(
            mode == null
                ? '🏀'
                : mode == 'clock'
                    ? '⏱ ${max(0, 60 - gameT.floor())}s'
                    : '🎯 ${max(0, 10 - shots)}/10 left',
            style: TextStyle(color: t.muted, fontWeight: FontWeight.w800),
          ),
          Text('Lvl $level',
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _modeChooser(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          Text(msg,
              style: TextStyle(
                  color: t.text, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: WajihaButton(
                  label: 'Shot Clock',
                  emoji: '⏱',
                  primary: true,
                  onTap: () => _startMode('clock'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WajihaButton(
                  label: 'Streak x10',
                  emoji: '🎯',
                  onTap: () => _startMode('streak'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Bests — clock: $bestClock · streak: $bestStreak',
              style: TextStyle(color: t.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _hintBar(GameTheme t) {
    final showMsg = msg.isNotEmpty && gameT - _msgT < 2.2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        over
            ? 'Game over! 🎉'
            : showMsg
                ? msg
                : (flying ? '' : 'Flick UP on the ball to shoot! 👆'),
        style:
            TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  final GameTheme t;
  final Offset ball;
  final List<Offset> trail;
  final bool flying, hasBall;
  final double hoopX, hoopY, rimW;
  final Offset ballSpot;

  _CourtPainter({
    required this.t,
    required this.ball,
    required this.trail,
    required this.flying,
    required this.hasBall,
    required this.hoopX,
    required this.hoopY,
    required this.rimW,
    required this.ballSpot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // court
    canvas.drawRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height,
            const Radius.circular(18)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              t.primary.withValues(alpha: 0.35),
              t.background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    // court lines
    final line = Paint()
      ..color = t.text.withValues(alpha: 0.25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.86), width: 220, height: 220),
        pi, pi, false, line);
    // pole
    final pole = Paint()
      ..color = t.muted
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hoopX + rimW / 2 + 34, hoopY - 10),
        Offset(hoopX + rimW / 2 + 34, 0), pole);
    // rim
    final rimPaint = Paint()
      ..color = t.accent
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hoopX - rimW / 2, hoopY),
        Offset(hoopX + rimW / 2, hoopY), rimPaint);
    // net
    final net = Paint()
      ..color = t.text.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (int i = 0; i <= 4; i++) {
      final x0 = hoopX - rimW / 2 + rimW * i / 4;
      canvas.drawLine(Offset(x0, hoopY + 3),
          Offset(hoopX + (x0 - hoopX) * 0.55, hoopY + 52), net);
    }
    canvas.drawLine(Offset(hoopX - rimW * 0.28, hoopY + 52),
        Offset(hoopX + rimW * 0.28, hoopY + 52), net);
    // trail
    for (int i = 0; i < trail.length; i++) {
      canvas.drawCircle(
          trail[i],
          5 + 9 * i / trail.length,
          Paint()
            ..color =
                t.secondary.withValues(alpha: 0.12 + 0.25 * i / trail.length));
    }
    // ball
    if (hasBall) {
      final b = flying ? ball : ballSpot;
      canvas.drawCircle(b, 16, Paint()..color = t.secondary);
      final seam = Paint()
        ..color = t.background.withValues(alpha: 0.7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(b, 16, seam);
      canvas.drawLine(b + const Offset(-16, 0), b + const Offset(16, 0), seam);
      canvas.drawLine(b + const Offset(0, -16), b + const Offset(0, 16), seam);
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter o) => true;
}
