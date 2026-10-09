import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';
import 'menu_screen.dart';

/// Launch flow: brief WAJIHA company moment → game splash
/// (logo + name + animated loading line + "Credits: WAJIHA").
class SplashScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _showCompany = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _showCompany = false);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17100B),
      body: _showCompany ? _companyMoment() : _gameSplash(context),
    );
  }

  Widget _companyMoment() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/wajiha_logo.png', width: 120, height: 120,
              fit: BoxFit.contain),
          const SizedBox(height: 14),
          Text('W A J I H A', style: HoopType.label(20)),
        ],
      ),
    );
  }

  Widget _gameSplash(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: const Color(0xFFE06428), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/hoopshoot_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(height: 22),
          Text('Hoop Shoot', style: HoopType.display(52)),
          const SizedBox(height: 6),
          Text(
            'ARCADE BASKETBALL',
            style: HoopType.label(13,
                color: const Color(0xFFE06428)),
          ),
          const SizedBox(height: 30),
          // Animated loading line.
          SizedBox(
            width: 220,
            child: AnimatedBuilder(
              animation: _loader,
              builder: (_, _) => Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(
                          color: const Color(0xFFE06428)
                              .withValues(alpha: 0.5)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _loader.value.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF0A050),
                              Color(0xFFE06428),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loader.value < 1
                        ? 'Lacing up the sneakers…'
                        : 'Ready!',
                    style: HoopType.body(13,
                        color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 44),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Text('Credits: WAJIHA', style: HoopType.label(14)),
            ],
          ),
        ],
      ),
    );
  }
}
