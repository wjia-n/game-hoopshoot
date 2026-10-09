import 'package:flutter/material.dart';

/// Court theme catalog for Hoop Shoot — real physical court art direction:
/// hardwood floors, painted keys, arena walls, metal rims, rope nets.
/// No neon, no cyberpunk, no AI-dashboard looks.

class CourtThemeDef {
  final String id;
  final String name;
  final bool isPro;
  final Color wall; // gym wall above the court
  final Color crowd; // crowd band silhouette color
  final Color floorLight; // light hardwood plank
  final Color floorDark; // dark hardwood plank
  final Color keyColor; // painted key / free-throw area
  final Color lineColor; // court lines
  final Color rimColor;
  final Color netColor;
  final Color boardColor;
  final Color ballShadow;

  const CourtThemeDef({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.wall,
    required this.crowd,
    required this.floorLight,
    required this.floorDark,
    required this.keyColor,
    required this.lineColor,
    required this.rimColor,
    required this.netColor,
    required this.boardColor,
    required this.ballShadow,
  });

  Color get text => Colors.white;
}

class CourtThemes {
  static const List<CourtThemeDef> all = [
    CourtThemeDef(
      id: 'classic',
      name: 'Classic Arena',
      wall: Color(0xFF3E2A1A),
      crowd: Color(0xFF241708),
      floorLight: Color(0xFFD29A5B),
      floorDark: Color(0xFFB87F42),
      keyColor: Color(0xFF8C2F24),
      lineColor: Color(0xFFF7EFDD),
      rimColor: Color(0xFFE06428),
      netColor: Color(0xFFF4EFE4),
      boardColor: Color(0xFFDCEAF5),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'street',
      name: 'Street Court',
      wall: Color(0xFF2C3540),
      crowd: Color(0xFF161C22),
      floorLight: Color(0xFF5B6B76),
      floorDark: Color(0xFF49555F),
      keyColor: Color(0xFF8C2F24),
      lineColor: Color(0xFFF2F2F2),
      rimColor: Color(0xFF9AA3AB),
      netColor: Color(0xFFD8DDE2),
      boardColor: Color(0xFFC9D4DC),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'college',
      name: 'College Classic',
      wall: Color(0xFF1E2A52),
      crowd: Color(0xFF111838),
      floorLight: Color(0xFFD8AC63),
      floorDark: Color(0xFFB8894A),
      keyColor: Color(0xFF1E3A7A),
      lineColor: Color(0xFFF7EFDD),
      rimColor: Color(0xFFE06428),
      netColor: Color(0xFFF4EFE4),
      boardColor: Color(0xFFDCEAF5),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'sunset',
      name: 'Sunset Gym',
      wall: Color(0xFF57301B),
      crowd: Color(0xFF33190C),
      floorLight: Color(0xFFE0A45E),
      floorDark: Color(0xFFC4884A),
      keyColor: Color(0xFFB45A1E),
      lineColor: Color(0xFFFFF3DE),
      rimColor: Color(0xFFC44E1C),
      netColor: Color(0xFFF9EFD8),
      boardColor: Color(0xFFE7D9C4),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'playground',
      name: 'Playground Concrete',
      wall: Color(0xFF3B4A42),
      crowd: Color(0xFF1F2823),
      floorLight: Color(0xFF7E8B83),
      floorDark: Color(0xFF6A7770),
      keyColor: Color(0xFF2F6E4E),
      lineColor: Color(0xFFF2F2F2),
      rimColor: Color(0xFFB8BEC4),
      netColor: Color(0xFFEFEBE0),
      boardColor: Color(0xFFD3DBD2),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'prohardwood',
      name: 'Pro Hardwood',
      isPro: true,
      wall: Color(0xFF241407),
      crowd: Color(0xFF120A04),
      floorLight: Color(0xFF8A5A2E),
      floorDark: Color(0xFF6E4422),
      keyColor: Color(0xFF101010),
      lineColor: Color(0xFFD8C27A),
      rimColor: Color(0xFFD95F22),
      netColor: Color(0xFFF1EADC),
      boardColor: Color(0xFFD8E6F2),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'ocean',
      name: 'Ocean Court',
      isPro: true,
      wall: Color(0xFF0E3A46),
      crowd: Color(0xFF08222A),
      floorLight: Color(0xFF3E8CA0),
      floorDark: Color(0xFF2F6F80),
      keyColor: Color(0xFF0E5A70),
      lineColor: Color(0xFFF0F8FA),
      rimColor: Color(0xFFE06428),
      netColor: Color(0xFFF0F4F2),
      boardColor: Color(0xFFCFE6EA),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'desert',
      name: 'Desert Court',
      isPro: true,
      wall: Color(0xFF5A3A1E),
      crowd: Color(0xFF38210F),
      floorLight: Color(0xFFD8B878),
      floorDark: Color(0xFFB8965C),
      keyColor: Color(0xFF9A5E2A),
      lineColor: Color(0xFFFDF4E0),
      rimColor: Color(0xFFB84E1E),
      netColor: Color(0xFFF9F0DC),
      boardColor: Color(0xFFE8DCC4),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'championship',
      name: 'Championship Gold',
      isPro: true,
      wall: Color(0xFF141414),
      crowd: Color(0xFF080808),
      floorLight: Color(0xFFC9A24A),
      floorDark: Color(0xFFA8823A),
      keyColor: Color(0xFF0E0E0E),
      lineColor: Color(0xFFF7E7B8),
      rimColor: Color(0xFFE8A820),
      netColor: Color(0xFFF8EDD2),
      boardColor: Color(0xFF1E1E1E),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'winter',
      name: 'Winter Ice',
      isPro: true,
      wall: Color(0xFF2A3E55),
      crowd: Color(0xFF16222F),
      floorLight: Color(0xFFB9CFDD),
      floorDark: Color(0xFF9DB4C8),
      keyColor: Color(0xFF4E7EA8),
      lineColor: Color(0xFFFFFFFF),
      rimColor: Color(0xFFD05A28),
      netColor: Color(0xFFF5FAFD),
      boardColor: Color(0xFFD6EAF6),
      ballShadow: Color(0xFF2A3E55),
    ),
    CourtThemeDef(
      id: 'forest',
      name: 'Forest Retreat',
      isPro: true,
      wall: Color(0xFF1E3320),
      crowd: Color(0xFF101D11),
      floorLight: Color(0xFF6E9A68),
      floorDark: Color(0xFF578057),
      keyColor: Color(0xFF2E5A34),
      lineColor: Color(0xFFEFF6E8),
      rimColor: Color(0xFFE06428),
      netColor: Color(0xFFF2F4E8),
      boardColor: Color(0xFFD4E2CE),
      ballShadow: Color(0xFF000000),
    ),
    CourtThemeDef(
      id: 'bricklane',
      name: 'Brick Lane',
      isPro: true,
      wall: Color(0xFF4A2218),
      crowd: Color(0xFF2B130D),
      floorLight: Color(0xFFA8674A),
      floorDark: Color(0xFF8C5340),
      keyColor: Color(0xFF6E2A1C),
      lineColor: Color(0xFFF8EADC),
      rimColor: Color(0xFF7A7F84),
      netColor: Color(0xFFF5ECE0),
      boardColor: Color(0xFFD9CFC2),
      ballShadow: Color(0xFF000000),
    ),
  ];

  /// User-created theme; [custom] is built from persisted colors.
  static CourtThemeDef byId(String id, {CourtThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      all.any((t) => t.id == id && t.isPro);
}

// ---------------------------------------------------------------------------
// Ball styles — drawn by the canvas painter, each with its own physical look.
// ---------------------------------------------------------------------------

class BallStyle {
  final String name;
  final bool isPro;
  final Color base;
  final Color seam;
  final Color panel;

  const BallStyle({
    required this.name,
    required this.base,
    required this.seam,
    required this.panel,
    this.isPro = false,
  });
}

class BallStyles {
  static const List<BallStyle> all = [
    BallStyle(
      name: 'Classic Leather',
      base: Color(0xFFE07020),
      seam: Color(0xFF3A1E0C),
      panel: Color(0xFFD05F18),
    ),
    BallStyle(
      name: 'Street Rubber',
      base: Color(0xFF2B2B30),
      seam: Color(0xFF0E0E10),
      panel: Color(0xFF3A3A40),
    ),
    BallStyle(
      name: 'Patriot',
      base: Color(0xFF1D4E9E),
      seam: Color(0xFFA31621),
      panel: Color(0xFFF0F0F0),
    ),
    BallStyle(
      name: 'Court Camo',
      base: Color(0xFF4E6E4A),
      seam: Color(0xFF223A20),
      panel: Color(0xFF8A7A4A),
    ),
    BallStyle(
      name: 'Pearl Marble',
      base: Color(0xFFECE7DC),
      seam: Color(0xFF8A8074),
      panel: Color(0xFFD8D2C6),
      isPro: true,
    ),
    BallStyle(
      name: 'Gold Trophy',
      base: Color(0xFFE8B62A),
      seam: Color(0xFF8A5E10),
      panel: Color(0xFFD89E1E),
      isPro: true,
    ),
    BallStyle(
      name: 'Midnight',
      base: Color(0xFF1A1A24),
      seam: Color(0xFF4A4A5E),
      panel: Color(0xFF262633),
      isPro: true,
    ),
    BallStyle(
      name: 'Half & Half',
      base: Color(0xFFB84E1E),
      seam: Color(0xFF1D4E9E),
      panel: Color(0xFF1D4E9E),
      isPro: true,
    ),
  ];

  static BallStyle byIndex(int i) => all[i.clamp(0, all.length - 1)];
  static bool isPro(int i) => byIndex(i).isPro;
}

// ---------------------------------------------------------------------------
// Hoop styles — rim + net color pairings.
// ---------------------------------------------------------------------------

class HoopStyle {
  final String name;
  final bool isPro;
  final Color rim;
  final Color net;

  const HoopStyle({
    required this.name,
    required this.rim,
    required this.net,
    this.isPro = false,
  });
}

class HoopStyles {
  static const List<HoopStyle> all = [
    HoopStyle(name: 'Arena Orange', rim: Color(0xFFE06428), net: Color(0xFFF4EFE4)),
    HoopStyle(name: 'Street Steel', rim: Color(0xFF9AA3AB), net: Color(0xFFD8DDE2)),
    HoopStyle(name: 'Retro Red', rim: Color(0xFFA31621), net: Color(0xFFF1EADC)),
    HoopStyle(name: 'Chrome Pro', rim: Color(0xFFD7DEE4), net: Color(0xFFFFFFFF), isPro: true),
    HoopStyle(name: 'Gold Rim', rim: Color(0xFFE8A820), net: Color(0xFFF8EDD2), isPro: true),
    HoopStyle(name: 'Blackout', rim: Color(0xFF222226), net: Color(0xFFE8E4D8), isPro: true),
    HoopStyle(name: 'Copper Classic', rim: Color(0xFFB87333), net: Color(0xFFF4EFE4), isPro: true),
    HoopStyle(name: 'Midnight Chrome', rim: Color(0xFF3A3F46), net: Color(0xFFE8E4D8), isPro: true),
  ];

  static HoopStyle byIndex(int i) => all[i.clamp(0, all.length - 1)];
  static bool isPro(int i) => byIndex(i).isPro;
}

// ---------------------------------------------------------------------------
// Text helpers — bold editorial type, warm court-room feel.
// ---------------------------------------------------------------------------

class HoopType {
  static TextStyle display(double size, {Color color = Colors.white}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 6),
        ],
      );

  static TextStyle headline(double size, {Color color = Colors.white}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color);

  static TextStyle body(double size, {Color color = Colors.white}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: color);

  static TextStyle label(double size, {Color color = Colors.white}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      );
}
