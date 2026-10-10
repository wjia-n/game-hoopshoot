import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/court_themes.dart';

/// Persisted settings + stats for Hoop Shoot. Survives app restarts.
///
/// Stores: audio toggles, player profile names (2 slots — solo + shootout),
/// theme/appearance choices (incl. custom theme colors), difficulty, Pro
/// unlock state, and lifetime stats.
class HoopSettings extends ChangeNotifier {
  static const _kMusic = 'hoopshoot_music_on';
  static const _kSfx = 'hoopshoot_sfx_on';
  static const _kVolume = 'hoopshoot_volume';
  static const _kDifficulty = 'hoopshoot_difficulty'; // 0 rookie, 1 street, 2 allstar
  static const _kMode = 'hoopshoot_last_mode';
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so a
  /// StringList would scramble name order on every app restart. NEVER use
  /// setStringList for ordered data on Android.
  static const _kNamesJson = 'hoopshoot_player_names_json';
  static const _kLegacyName = 'hoopshoot_player_name'; // one-time migration
  static const _kTheme = 'hoopshoot_theme_id';
  static const _kBall = 'hoopshoot_ball_style';
  static const _kHoopStyle = 'hoopshoot_hoop_style';
  static const _kBestClock = 'hoopshoot_best_clock';
  static const _kBestStreak = 'hoopshoot_best_streak';
  static const _kBestEndless = 'hoopshoot_best_endless';
  static const _kBestShootout = 'hoopshoot_best_shootout';
  static const _kGames = 'hoopshoot_games_played';
  static const _kBaskets = 'hoopshoot_total_baskets';
  static const _kSwishes = 'hoopshoot_total_swishes';
  static const _kIsPro = 'hoopshoot_is_pro';
  static const _kCustomPrefix = 'hoopshoot_custom_';

  static const defaultNames = ['Hooper', 'Rival'];

  /// Encode player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int difficulty = 0; // 0 rookie, 1 street, 2 all-star (pro)
  String lastMode = 'clock';
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int ballStyle = 0;
  int hoopStyle = 0;
  int bestClock = 0;
  int bestStreak = 0;
  int bestEndless = 0;
  int bestShootout = 0;
  int gamesPlayed = 0;
  int totalBaskets = 0;
  int totalSwishes = 0;
  bool isPro = true; // everything unlocked — no Pro version

  /// Custom theme colors (ARGB ints). Defaults mirror the Classic Arena.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'wall': 0xFF3E2A1A,
    'crowd': 0xFF241708,
    'floorLight': 0xFFD29A5B,
    'floorDark': 0xFFB87F42,
    'keyColor': 0xFF8C2F24,
    'lineColor': 0xFFF7EFDD,
    'rimColor': 0xFFE06428,
    'netColor': 0xFFF4EFE4,
    'boardColor': 0xFFDCEAF5,
  };

  static const Map<String, String> customColorLabels = {
    'wall': 'Arena wall',
    'crowd': 'Crowd',
    'floorLight': 'Floor (light plank)',
    'floorDark': 'Floor (dark plank)',
    'keyColor': 'Painted key',
    'lineColor': 'Court lines',
    'rimColor': 'Rim',
    'netColor': 'Net',
    'boardColor': 'Backboard',
  };

  /// Builds the user-designed custom theme from stored colors.
  CourtThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return CourtThemeDef(
      id: 'custom',
      name: 'My Creation',
      wall: c('wall'),
      crowd: c('crowd'),
      floorLight: c('floorLight'),
      floorDark: c('floorDark'),
      keyColor: c('keyColor'),
      lineColor: c('lineColor'),
      rimColor: c('rimColor'),
      netColor: c('netColor'),
      boardColor: c('boardColor'),
      ballShadow: const Color(0xFF000000),
    );
  }

  CourtThemeDef get theme => CourtThemes.byId(themeId, custom: customTheme);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    difficulty = (p.getInt(_kDifficulty) ?? 0).clamp(0, 2);
    lastMode = p.getString(_kMode) ?? 'clock';
    // Player names: prefer the order-safe JSON key. One-time migrations from
    // older formats: the legacy single-name key, then defaults.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getString(_kLegacyName);
      playerNames = legacy != null && legacy.trim().isNotEmpty
          ? [legacy.trim(), defaultNames[1]]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, BallStyles.all.length - 1);
    hoopStyle = (p.getInt(_kHoopStyle) ?? 0).clamp(0, HoopStyles.all.length - 1);
    bestClock = p.getInt(_kBestClock) ?? 0;
    bestStreak = p.getInt(_kBestStreak) ?? 0;
    bestEndless = p.getInt(_kBestEndless) ?? 0;
    bestShootout = p.getInt(_kBestShootout) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    totalBaskets = p.getInt(_kBaskets) ?? 0;
    totalSwishes = p.getInt(_kSwishes) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kMode, lastMode);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kLegacyName); // drop the legacy key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBall, ballStyle);
    await p.setInt(_kHoopStyle, hoopStyle);
    await p.setInt(_kBestClock, bestClock);
    await p.setInt(_kBestStreak, bestStreak);
    await p.setInt(_kBestEndless, bestEndless);
    await p.setInt(_kBestShootout, bestShootout);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBaskets, totalBaskets);
    await p.setInt(_kSwishes, totalSwishes);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || CourtThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (HoopStyles.isPro(hoopStyle)) {
      hoopStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // All-Star is Pro
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setLastMode(String m) async {
    lastMode = m;
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || CourtThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.all.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setHoopStyle(int v) async {
    v = v.clamp(0, HoopStyles.all.length - 1);
    if (!isPro && HoopStyles.isPro(v)) return;
    hoopStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished game and update bests. Returns true if a new best.
  Future<bool> recordGame({
    required String mode,
    required int points,
    required int baskets,
    required int swishes,
    int? shootoutWinner, // shootout score of the winner for the best entry
  }) async {
    gamesPlayed++;
    totalBaskets += baskets;
    totalSwishes += swishes;
    var newBest = false;
    switch (mode) {
      case 'clock':
        if (points > bestClock) {
          bestClock = points;
          newBest = true;
        }
      case 'streak':
        if (points > bestStreak) {
          bestStreak = points;
          newBest = true;
        }
      case 'endless':
        if (points > bestEndless) {
          bestEndless = points;
          newBest = true;
        }
      case 'shootout':
        if (points > bestShootout) {
          bestShootout = points;
          newBest = true;
        }
    }
    notifyListeners();
    await _save();
    return newBest;
  }
}

/// Difficulty tiers: clear progression in hoop movement, rim size, wind.
class HoopDifficulty {
  final String name;
  final String tagline;
  final bool isPro;
  final double hoopAmp; // px sideways movement (at 800px court width scale)
  final double hoopSpeed; // rad/s
  final double rimScale; // 1.0 = standard rim
  final double windMax; // px/s^2 wind gusts

  const HoopDifficulty({
    required this.name,
    required this.tagline,
    this.isPro = false,
    required this.hoopAmp,
    required this.hoopSpeed,
    required this.rimScale,
    required this.windMax,
  });

  static const List<HoopDifficulty> tiers = [
    HoopDifficulty(
      name: 'Rookie',
      tagline: 'Steady hoop, easy rim — learn to flick.',
      hoopAmp: 0,
      hoopSpeed: 0,
      rimScale: 1.12,
      windMax: 0,
    ),
    HoopDifficulty(
      name: 'Street',
      tagline: 'The hoop drifts. Read it and shoot.',
      hoopAmp: 120,
      hoopSpeed: 0.9,
      rimScale: 1.0,
      windMax: 60,
    ),
    HoopDifficulty(
      name: 'All-Star',
      tagline: 'Fast hoop, tight rim, gusty wind.',
      isPro: true,
      hoopAmp: 165,
      hoopSpeed: 1.5,
      rimScale: 0.88,
      windMax: 140,
    ),
  ];

  static HoopDifficulty of(int i) => tiers[i.clamp(0, tiers.length - 1)];
}
