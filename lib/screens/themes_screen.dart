import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';
import 'pro_screen.dart';

/// Themes: 12+ court themes, 8 ball styles, 8 hoop styles + custom creator.
class ThemesScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  const ThemesScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  HoopSettings get s => widget.settings;
  HoopAudio get audio => widget.audio;

  void _openPro() {
    final store = StoreService();
    store.init();
    audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                ProScreen(audio: audio, settings: s, store: store)))
        .then((_) => setState(() {}));
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
        title: Text('Court & Gear', style: HoopType.headline(22)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('COURT THEMES'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.78),
            itemCount: CourtThemes.all.length + 1, // + custom creator
            itemBuilder: (_, i) {
              if (i == CourtThemes.all.length) {
                return _customCard();
              }
              final th = CourtThemes.all[i];
              return _themeCard(th, th.id == s.themeId);
            },
          ),
          _section('BALL STYLE'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
            itemCount: BallStyles.all.length,
            itemBuilder: (_, i) {
              final b = BallStyles.byIndex(i);
              final locked = b.isPro && !s.isPro;
              return _ballCard(b, i == s.ballStyle, locked);
            },
          ),
          _section('HOOP STYLE'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35),
            itemCount: HoopStyles.all.length,
            itemBuilder: (_, i) {
              final hs = HoopStyles.byIndex(i);
              final locked = hs.isPro && !s.isPro;
              return _hoopCard(hs, i == s.hoopStyle, locked);
            },
          ),
          if (s.themeId == 'custom') _customCreator(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(label, style: HoopType.label(12)),
    );
  }

  Widget _lockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A820),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 11, color: Colors.black),
          const SizedBox(width: 3),
          Text('PRO', style: HoopType.label(9, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _themeCard(CourtThemeDef th, bool selected) {
    final locked = th.isPro && !s.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _openPro();
          return;
        }
        audio.click();
        s.setTheme(th.id);
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            th.wall,
                            th.floorLight,
                            th.floorDark,
                            th.keyColor,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
                  ),
                  child: Text(th.name,
                      textAlign: TextAlign.center,
                      style: HoopType.body(10)),
                ),
              ],
            ),
            if (locked)
              Positioned(
                  top: 6, right: 6, child: _lockedBadge()),
            if (selected)
              const Positioned(
                top: 6,
                left: 6,
                child: Icon(Icons.check_circle,
                    color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customCard() {
    final selected = s.themeId == 'custom';
    final locked = !s.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _openPro();
          return;
        }
        audio.click();
        s.setTheme('custom');
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.brush,
                      color: Colors.white, size: 30),
                  const SizedBox(height: 6),
                  Text('My\nCreation',
                      textAlign: TextAlign.center,
                      style: HoopType.body(11)),
                ],
              ),
            ),
            if (locked)
              Positioned(
                  top: 6, right: 6, child: _lockedBadge()),
            if (selected)
              const Positioned(
                top: 6,
                left: 6,
                child: Icon(Icons.check_circle,
                    color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ballCard(BallStyle b, bool selected, bool locked) {
    return GestureDetector(
      onTap: () {
        if (locked) {
          _openPro();
          return;
        }
        audio.click();
        s.setBallStyle(BallStyles.all.indexOf(b));
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [b.base, b.panel],
                    center: const Alignment(-0.35, -0.35),
                    radius: 1.1,
                  ),
                  border: Border.all(color: b.seam, width: 2),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Text(b.name,
                  textAlign: TextAlign.center,
                  style: HoopType.body(9)),
            ),
            if (locked)
              Positioned(
                  top: 5, right: 5, child: _lockedBadge()),
          ],
        ),
      ),
    );
  }

  Widget _hoopCard(HoopStyle hs, bool selected, bool locked) {
    return GestureDetector(
      onTap: () {
        if (locked) {
          _openPro();
          return;
        }
        audio.click();
        s.setHoopStyle(HoopStyles.all.indexOf(hs));
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hs.rim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int k = 0; k < 5; k++)
                        Container(
                          width: 3,
                          height: 20,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          color: hs.net,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(hs.name,
                      textAlign: TextAlign.center,
                      style: HoopType.body(9)),
                ],
              ),
            ),
            if (locked)
              Positioned(
                  top: 5, right: 5, child: _lockedBadge()),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------ custom creator

  static const _swatches = [
    0xFFD29A5B,
    0xFFB87F42,
    0xFF8C2F24,
    0xFF1E3A7A,
    0xFF2E5A34,
    0xFF101010,
    0xFFC9A24A,
    0xFF4E7EA8,
    0xFFE06428,
    0xFF5B6B76,
    0xFF7E8B83,
    0xFFF7EFDD,
    0xFF3E2A1A,
    0xFFDCEAF5,
    0xFF6E4422,
    0xFF9AA3AB,
  ];

  Widget _customCreator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('DESIGN YOUR COURT (PRO)'),
        for (final key in HoopSettings.customColorLabels.keys)
          _colorRow(key, HoopSettings.customColorLabels[key]!),
        Center(
          child: TextButton(
            onPressed: () {
              audio.click();
              s.resetCustomColors();
              setState(() {});
            },
            child: Text('Reset my creation',
                style: HoopType.body(13,
                    color: Colors.white.withValues(alpha: 0.7))),
          ),
        ),
      ],
    );
  }

  Widget _colorRow(String key, String label) {
    final current = Color(s.customColors[key] ?? 0xFF000000);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: HoopType.body(13)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sw in _swatches)
                GestureDetector(
                  onTap: () {
                    audio.click();
                    s.setCustomColor(key, sw);
                    setState(() {});
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(sw),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: current.value == sw
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                          width: current.value == sw ? 3 : 1),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
