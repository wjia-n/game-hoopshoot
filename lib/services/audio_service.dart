import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Hoop Shoot — all sounds synthesized in code as WAV
/// bytes. No asset files. Warm arena sounds: bouncing leather, chain/nylon
/// nets, rim clang, buzzer, whistle, crowd cheer.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class HoopAudio {
  /// Per-game pitch character (hoopshoot): 0.88x. Makes SFX unique.
  static const double _pitchMul = 0.880;

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  HoopAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _bounce() {
    // Hollow leather thump: low sine thud + leather slap noise.
    final n = (_rate * 0.16).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.85 * sin(2 * pi * 130 * t) * exp(-t * 28) +
              0.35 * sin(2 * pi * 260 * t) * exp(-t * 60) +
              0.18 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90));
    }
    return out;
  }

  List<double> _swish() {
    // Net snap: short burst of filtered noise with a descending whistle.
    final n = (_rate * 0.32).round();
    final out = List<double>.filled(n, 0);
    double lp = 0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final raw = _rand.nextDouble() * 2 - 1;
      lp += 0.25 * (raw - lp);
      final whoosh = lp * 2.2 * sin(pi * (i / n).clamp(0.0, 1.0));
      final snap = (i < n ~/ 6)
          ? sin(2 * pi * (900 + 600 * i / n) * t) * exp(-t * 30)
          : 0.0;
      out[i] = (whoosh * 0.9 + snap * 0.5) * _env(i, n, attack: 0.05);
    }
    return out;
  }

  List<double> _rimClang() {
    // Metal rim ping: struck-bar harmonics, quick decay.
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.55 * sin(2 * pi * 1180 * t) * exp(-t * 12) +
              0.3 * sin(2 * pi * 1770 * t) * exp(-t * 16) +
              0.2 * sin(2 * pi * 2360 * t) * exp(-t * 22));
    }
    return out;
  }

  List<double> _buzzer() {
    // Game buzzer: harsh square-ish blast at 220Hz.
    final n = (_rate * 1.1).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final sq = sin(2 * pi * 220 * t).sign * 0.55;
      final h2 = sin(2 * pi * 440 * t) * 0.3;
      out[i] = (sq + h2) * _env(i, n, attack: 0.01);
    }
    return out;
  }

  List<double> _whistle() {
    // Ref whistle: trilling ~2400Hz tone.
    final n = (_rate * 0.6).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final trill = 1 + 0.35 * sin(2 * pi * 28 * t);
      out[i] = _env(i, n, attack: 0.02) *
          sin(2 * pi * 2350 * trill * t) *
          0.55;
    }
    return out;
  }

  List<double> _cheer() {
    // Crowd burst: shaped noise swell, 1.2s.
    final n = (_rate * 1.2).round();
    final out = List<double>.filled(n, 0);
    double lp = 0;
    for (int i = 0; i < n; i++) {
      final raw = _rand.nextDouble() * 2 - 1;
      lp += 0.12 * (raw - lp);
      final swell = sin(pi * (i / n).clamp(0.0, 1.0));
      out[i] = lp * 2.4 * swell * 0.8;
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0)); // slow swell in/out
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // A# arpeggiated 3 – 0 – 4 – 5, 16s loop. Unique to hoopshoot.
        final notes = [311.12, 391.99, 466.16, 391.99, 233.08, 293.66, 349.23, 293.66, 349.23, 440.00, 523.25, 440.00, 391.99, 466.16, 587.32, 466.16];
        final out = <double>[];
        final noteLen = 16.0 / notes.length;
        for (final n in notes) {
          out.addAll(_tone(n, noteLen * 0.9, harmonics: 0.3));
          final gap = List<double>.filled((_rate * noteLen * 0.1).round(), 0);
          out.addAll(gap);
        }
        // Soft pad underneath
        final pad = _padChord([311.12, 391.99, 466.16], 16.0);
        for (int i = 0; i < out.length && i < pad.length; i++) {
          out[i] += pad[i] * 0.3;
        }
        return out;
      });


  Uint8List _gameBytes() => _clip('music_game', () {
        // A# bass + melody 3 – 0 – 4 – 5, 16s loop. Unique to hoopshoot.
        final bassNotes = [155.56, 116.54, 174.62, 196.00];
        final melNotes = [932.32, 698.46, 1046.50, 1174.64];
        final out = List<double>.filled((_rate * 16).round(), 0);
        final segLen = (_rate * 4).round();
        for (int s = 0; s < 4; s++) {
          final bass = _tone(bassNotes[s], 3.5, harmonics: 0.4);
          final mel = _tone(melNotes[s], 1.2, harmonics: 0.25);
          for (int i = 0; i < bass.length && s * segLen + i < out.length; i++) {
            out[s * segLen + i] += bass[i] * 0.5;
          }
          final melStart = s * segLen + segLen ~/ 4;
          for (int i = 0; i < mel.length && melStart + i < out.length; i++) {
            out[melStart + i] += mel[i] * 0.35;
          }
        }
        return out;
      });


  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> shoot() => _play(_clip('shoot', () => _tone(320, 0.14, freqEnd: 640)));
  Future<void> bounce() => _play(_clip('bounce', _bounce));
  Future<void> swish() => _play(_clip('swish', _swish));
  Future<void> rim() => _play(_clip('rim', _rimClang));
  Future<void> buzzer() => _play(_clip('buzzer', _buzzer));
  Future<void> whistle() => _play(_clip('whistle', _whistle));
  Future<void> cheer() => _play(_clip('cheer', _cheer));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _arp([392.0, 523.25, 659.25], 0.12, 0.03)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
