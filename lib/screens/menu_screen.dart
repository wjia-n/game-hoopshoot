import 'package:flutter/material.dart';
import '../engine/hoopshoot_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

/// Main menu: logo, mode cards, difficulty tiers, best scores, nav buttons.
class MenuScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  HoopSettings get s => widget.settings;
  HoopAudio get audio => widget.audio;
  StoreService? _store;

  @override
  void initState() {
    super.initState();
    audio.startMenuMusic();
    // Lazy-init the store so the Pro badge can reflect real status.
    final store = StoreService();
    _store = store;
    store.init().then((_) {
      if (mounted) setState(() {});
    });
    store.proPurchased.addListener(_onPro);
  }

  
  @override
  void dispose() {
    _store?.proPurchased.removeListener(_onPro);
    super.dispose();
  }

  void _play(String mode) {
    audio.click();
    s.setLastMode(mode);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: audio,
          settings: s,
          mode: mode,
        ),
      ),
    );
  }

  void _howTo() {
    audio.click();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1C10),
        title: Text('How to play', style: HoopType.headline(22)),
        content: SingleChildScrollView(
          child: Text(
            '• FLICK UP on the ball to shoot — angle your flick to aim.\n'
            '• Nothing but net (swish) = 3 pts. Off the rim = 2 pts.\n'
            '• The hoop may drift and the wind may push the ball.\n\n'
            'MODES\n'
            '• Shot Clock: 60 seconds, as many buckets as you can.\n'
            '• Streak: 10 balls, make every one count.\n'
            '• Endless (PRO): shoot until 3 straight misses.\n'
            '• Shootout: pass-and-play, 5 shots each, sudden death on ties.\n\n'
            'DIFFICULTY\n'
            '• Rookie: steady hoop, easy rim.\n'
            '• Street: the hoop drifts, light wind.\n'
            '• All-Star (PRO): fast hoop, tight rim, gusty wind.',
            style: HoopType.body(14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
            child: Text('Got it!',
                style: HoopType.body(15,
                    color: const Color(0xFFF0A050))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = s.theme;
    return Scaffold(
      backgroundColor: t.wall,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header: logo + name.
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: t.rimColor.withValues(alpha: 0.8), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/hoopshoot_logo.png',
                      fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hoop Shoot', style: HoopType.display(30)),
                      Text('ARCADE BASKETBALL',
                          style: HoopType.label(11,
                              color: t.rimColor)),
                    ],
                  ),
                ),
                if (!s.isPro)
                  _ProBadge(
                      onTap: () => _openPro(),
                      label: 'PRO'),
              ],
            ),
            const SizedBox(height: 18),
            // Difficulty tiers.
            Text('DIFFICULTY', style: HoopType.label(12)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < HoopDifficulty.tiers.length; i++)
                  Expanded(child: _difficultyChip(i, t)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(HoopDifficulty.of(s.difficulty).tagline,
                  style: HoopType.body(12,
                      color: Colors.white.withValues(alpha: 0.7))),
            ),
            const SizedBox(height: 10),
            // Mode cards.
            Text('PICK YOUR GAME', style: HoopType.label(12)),
            const SizedBox(height: 8),
            _modeCard(
              t,
              title: 'Shot Clock',
              subtitle: '60 seconds. Buckets = glory. ⏱',
              best: 'Best: ${s.bestClock} pts',
              onTap: () => _play(HoopMode.clock),
            ),
            _modeCard(
              t,
              title: 'Streak',
              subtitle: '10 balls. Make every one count. 🎯',
              best: 'Best: ${s.bestStreak} pts',
              onTap: () => _play(HoopMode.streak),
            ),
            _modeCard(
              t,
              title: 'Endless',
              subtitle: '3 straight misses and you\'re done. 🏀',
              best: 'Best: ${s.bestEndless} pts',
              proLocked: !s.isPro,
              onTap: () => _play(HoopMode.endless),
            ),
            _modeCard(
              t,
              title: 'Shootout (2 players)',
              subtitle: 'Pass-and-play. 5 shots each. 🏆',
              best: s.bestShootout > 0
                  ? 'Winning score best: ${s.bestShootout}'
                  : 'No shootout yet',
              onTap: () => _play(HoopMode.shootout),
            ),
            const SizedBox(height: 18),
            // Nav buttons.
            Row(
              children: [
                Expanded(
                    child: _navButton(t, Icons.palette, 'Themes',
                        () => _open(ThemesScreen(audio: audio, settings: s)))),
                const SizedBox(width: 10),
                Expanded(
                    child: _navButton(t, Icons.settings, 'Settings',
                        () => _open(SettingsScreen(audio: audio, settings: s)))),
                const SizedBox(width: 10),
                Expanded(
                    child: _navButton(t, Icons.star, 'Pro',
                        () => _openPro())),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _howTo,
                child: Text('How to play',
                    style: HoopType.body(14,
                        color: Colors.white.withValues(alpha: 0.8))),
              ),
            ),
            Center(
              child: Text(
                'Swishes ${s.totalSwishes} · Buckets ${s.totalBaskets} · Games ${s.gamesPlayed}',
                style: HoopType.body(11,
                    color: Colors.white.withValues(alpha: 0.55)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _open(Widget screen) {
    audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => setState(() {}));
  }

  void _openPro() {
    final store = _store ?? StoreService();
    if (_store == null) {
      _store = store;
      store.init();
      store.proPurchased.addListener(_onPro);
    }
    audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ProScreen(
                audio: audio, settings: s, store: store)))
        .then((_) => setState(() {}));
  }

  Widget _difficultyChip(int i, CourtThemeDef t) {
    final d = HoopDifficulty.tiers[i];
    final selected = s.difficulty == i;
    final locked = d.isPro && !s.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _openPro();
          return;
        }
        audio.click();
        s.setDifficulty(i);
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? t.rimColor
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(Icons.lock, size: 13, color: Colors.white70),
            Text(
              d.name,
              textAlign: TextAlign.center,
              style: HoopType.body(13,
                  color: selected ? Colors.white : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(
    CourtThemeDef t, {
    required String title,
    required String subtitle,
    required String best,
    required VoidCallback onTap,
    bool proLocked = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (proLocked) {
          _openPro();
          return;
        }
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: t.rimColor.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: HoopType.headline(18)),
                      if (proLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8A820),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('PRO',
                              style: HoopType.label(10,
                                  color: Colors.black)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: HoopType.body(13,
                          color:
                              Colors.white.withValues(alpha: 0.75))),
                  const SizedBox(height: 3),
                  Text(best,
                      style: HoopType.body(12,
                          color: const Color(0xFFF0A050))),
                ],
              ),
            ),
            Icon(Icons.play_arrow,
                size: 34, color: t.rimColor),
          ],
        ),
      ),
    );
  }

  Widget _navButton(
      CourtThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.floorDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: HoopType.body(12)),
          ],
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _ProBadge({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8A820),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45,
                offset: Offset(0, 3),
                blurRadius: 6),
          ],
        ),
        child: Text(label,
            style: HoopType.label(13, color: Colors.black)),
      ),
    );
  }
}
