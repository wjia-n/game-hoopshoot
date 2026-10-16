import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';
import '../transfer/transfer_ui.dart';

/// Settings: audio, renameable player profiles, stats, reset.
class SettingsScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HoopSettings get s => widget.settings;
  HoopAudio get audio => widget.audio;
  late final TextEditingController _name0;
  late final TextEditingController _name1;
  late final FocusNode _focus0;
  late final FocusNode _focus1;

  @override
  void initState() {
    super.initState();
    _name0 = TextEditingController(text: s.playerNames[0]);
    _name1 = TextEditingController(text: s.playerNames[1]);
    // Commit on focus loss: whatever is in the field when the user taps
    // away is the name, even if they never hit done/check.
    _focus0 = FocusNode()..addListener(() {
      if (!_focus0.hasFocus) s.setPlayerName(0, _name0.text);
    });
    _focus1 = FocusNode()..addListener(() {
      if (!_focus1.hasFocus) s.setPlayerName(1, _name1.text);
    });
  }

  @override
  void dispose() {
    _name0.dispose();
    _name1.dispose();
    _focus0.dispose();
    _focus1.dispose();
    super.dispose();
  }

  void _applyAudio() {
    audio.configure(
        musicOn: s.musicOn, sfxOn: s.sfxOn, volume: s.volume);
    if (!s.musicOn) {
      audio.stopMusic();
    } else {
      audio.startMenuMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = s.theme;
    return Scaffold(
      backgroundColor: t.wall,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Settings', style: HoopType.headline(22)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
              TransferSaveTile(gameSlug: 'hoopshoot'),
          _section('SOUND'),
          SwitchListTile(
            title: Text('Music', style: HoopType.body(15)),
            value: s.musicOn,
            activeThumbColor: t.rimColor,
            onChanged: (v) {
              audio.click();
              s.setMusic(v);
              _applyAudio();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text('Sound effects', style: HoopType.body(15)),
            value: s.sfxOn,
            activeThumbColor: t.rimColor,
            onChanged: (v) {
              audio.click();
              s.setSfx(v);
              _applyAudio();
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Volume', style: HoopType.body(15)),
                Expanded(
                  child: Slider(
                    value: s.volume,
                    activeColor: t.rimColor,
                    onChanged: (v) {
                      s.setVolume(v);
                      _applyAudio();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          _section('PLAYERS'),
          Text(
            'Tap a name to rename. Names are used in shootout mode and on the scoreboard.',
            style: HoopType.body(12,
                color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 8),
          _nameField(0, _name0, _focus0, 'Player 1 (you)'),
          const SizedBox(height: 8),
          _nameField(1, _name1, _focus1, 'Player 2 (shootout rival)'),
          _section('STATS'),
          _statRow('Games played', '${s.gamesPlayed}'),
          _statRow('Total buckets', '${s.totalBaskets}'),
          _statRow('Total swishes', '${s.totalSwishes}'),
          _statRow('Best: Shot Clock', '${s.bestClock} pts'),
          _statRow('Best: Streak', '${s.bestStreak} pts'),
          _statRow('Best: Endless', '${s.bestEndless} pts'),
          _statRow('Best: Shootout winner', '${s.bestShootout} pts'),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                audio.click();
                // Keep it honest: stats reset by re-recording zeroes is a
                // user-facing wipe; confirmed below.
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF2A1C10),
                    title: Text('Reset stats?',
                        style: HoopType.headline(20)),
                    content: Text(
                        'This wipes your bests and lifetime stats.',
                        style: HoopType.body(14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                            style: HoopType.body(14,
                                color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          s.bestClock = 0;
                          s.bestStreak = 0;
                          s.bestEndless = 0;
                          s.bestShootout = 0;
                          s.gamesPlayed = 0;
                          s.totalBaskets = 0;
                          s.totalSwishes = 0;
                          // Persist via a save round-trip.
                          await s.setVolume(s.volume);
                          setState(() {});
                        },
                        child: Text('Reset',
                            style: HoopType.body(14,
                                color: const Color(0xFFF0A050))),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Reset all stats',
                  style: HoopType.body(14,
                      color: Colors.white.withValues(alpha: 0.7))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(label, style: HoopType.label(12)),
    );
  }

  Widget _nameField(int index, TextEditingController c, FocusNode f,
      String hint) {
    return TextField(
      controller: c,
      focusNode: f,
      maxLength: 14,
      style: HoopType.body(16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: HoopType.body(14,
            color: Colors.white.withValues(alpha: 0.4)),
        counterText: '',
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, color: Colors.white70),
          onPressed: () {
            audio.click();
            s.setPlayerName(index, c.text);
            FocusScope.of(context).unfocus();
            setState(() {});
          },
        ),
      ),
      // Save on EVERY keystroke: names are never lost mid-edit, and the
      // JSON-string persistence keeps slot order stable across restarts.
      onChanged: (v) => s.setPlayerName(index, v),
      onSubmitted: (v) {
        audio.click();
        s.setPlayerName(index, v);
        FocusScope.of(context).unfocus();
        setState(() {});
      },
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: HoopType.body(14,
                  color: Colors.white.withValues(alpha: 0.8))),
          Text(value,
              style: HoopType.headline(15,
              )),
        ],
      ),
    );
  }
}
