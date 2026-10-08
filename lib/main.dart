import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const HoopShootApp());

class HoopShootApp extends StatelessWidget {
  const HoopShootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.softBlob,
      title: 'Hoop Shoot',
      tagline: 'Swish shot after shot in arcade basketball',
      emoji: '🏀',
      slug: 'hoopshoot',
      howToPlay:
          '• FLICK UP on the ball to shoot. Aim with your flick angle!\n• Swish (nothing but net) = 3 pts, off the rim = 2 pts.\n• Two modes: 60-second Shot Clock, or 10-ball Streak.\n• The hoop starts sliding sideways from level 3. Buckets get buckets! 🪣',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => HoopShootScreen(players: players, callbacks: cb),
    );
  }
}
