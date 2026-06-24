import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/event.dart';

// ── Per-type theme ────────────────────────────────────────────────────────

class EventTypeBannerTheme {
  final List<Color> gradientColors;
  final List<IconData> icons;
  const EventTypeBannerTheme({required this.gradientColors, required this.icons});
}

const eventTypeTripBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFF1A237E), Color(0xFF1565C0), Color(0xFF29B6F6)],
  icons: [
    Icons.flight_rounded,
    Icons.luggage_rounded,
    Icons.map_rounded,
    Icons.beach_access_rounded,
    Icons.train_rounded,
    Icons.camera_alt_rounded,
    Icons.public_rounded,
    Icons.hotel_rounded,
  ],
);

const eventTypeQuickBitesBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFFB300)],
  icons: [
    Icons.restaurant_rounded,
    Icons.local_pizza_rounded,
    Icons.ramen_dining_rounded,
    Icons.local_cafe_rounded,
    Icons.lunch_dining_rounded,
    Icons.cake_rounded,
    Icons.wine_bar_rounded,
    Icons.emoji_food_beverage_rounded,
  ],
);

const eventTypeBirthdayBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFFAD1457), Color(0xFFE91E63), Color(0xFFFF8A65)],
  icons: [
    Icons.cake_rounded,
    Icons.celebration_rounded,
    Icons.card_giftcard_rounded,
    Icons.emoji_emotions_rounded,
    Icons.local_fire_department_rounded,
    Icons.favorite_rounded,
    Icons.stars_rounded,
    Icons.auto_awesome_rounded,
  ],
);

const eventTypeWeddingBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFBA68C8)],
  icons: [
    Icons.favorite_rounded,
    Icons.local_florist_rounded,
    Icons.diamond_rounded,
    Icons.celebration_rounded,
    Icons.wine_bar_rounded,
    Icons.camera_alt_rounded,
    Icons.auto_awesome_rounded,
    Icons.music_note_rounded,
  ],
);

const eventTypeTournamentBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF64DD17)],
  icons: [
    Icons.emoji_events_rounded,
    Icons.sports_tennis_rounded,
    Icons.account_tree_rounded,
    Icons.leaderboard_rounded,
    Icons.military_tech_rounded,
    Icons.scoreboard_rounded,
    Icons.workspace_premium_rounded,
    Icons.stadium_rounded,
  ],
);

const eventTypeSignupBannerTheme = EventTypeBannerTheme(
  gradientColors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF26A69A)],
  icons: [
    Icons.checklist_rounded,
    Icons.group_add_rounded,
    Icons.how_to_reg_rounded,
    Icons.event_seat_rounded,
    Icons.leaderboard_rounded,
    Icons.timer_rounded,
    Icons.sports_rounded,
    Icons.emoji_events_rounded,
  ],
);

EventTypeBannerTheme bannerThemeFor(EventType type) => switch (type) {
      EventType.trip => eventTypeTripBannerTheme,
      EventType.quickBites => eventTypeQuickBitesBannerTheme,
      EventType.birthday => eventTypeBirthdayBannerTheme,
      EventType.wedding => eventTypeWeddingBannerTheme,
      EventType.tournament => eventTypeTournamentBannerTheme,
      EventType.signup => eventTypeSignupBannerTheme,
    };

// ── Icon-pattern CustomPainter ─────────────────────────────────────────────

class _IconSpec {
  final double xFraction;
  final double yFraction;
  final double size;
  final double rotation;
  const _IconSpec(this.xFraction, this.yFraction, this.size, this.rotation);
}

const _specs = [
  _IconSpec(0.05, 0.15, 28, 0.18),
  _IconSpec(0.22, 0.55, 22, -0.25),
  _IconSpec(0.40, 0.10, 32, 0.10),
  _IconSpec(0.58, 0.65, 20, 0.30),
  _IconSpec(0.72, 0.20, 26, -0.15),
  _IconSpec(0.88, 0.50, 30, 0.20),
  _IconSpec(0.15, 0.80, 24, -0.35),
  _IconSpec(0.50, 0.40, 18, 0.40),
  _IconSpec(0.78, 0.80, 28, -0.10),
  _IconSpec(0.92, 0.10, 20, 0.28),
  _IconSpec(0.33, 0.70, 22, 0.12),
  _IconSpec(0.65, 0.40, 26, -0.22),
];

class EventIconPatternPainter extends CustomPainter {
  final List<IconData> icons;
  final Color color;

  const EventIconPatternPainter({required this.icons, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < _specs.length; i++) {
      final spec = _specs[i];
      final icon = icons[i % icons.length];
      tp.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: spec.size,
          color: color,
        ),
      );
      tp.layout();
      canvas.save();
      canvas.translate(spec.xFraction * size.width, spec.yFraction * size.height);
      canvas.rotate(spec.rotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(EventIconPatternPainter old) =>
      old.icons != icons || old.color != color;
}

// ── Banner widget ──────────────────────────────────────────────────────────

/// Full-bleed gradient + icon-pattern background for Trip and Quick Bites.
/// Pass [height] to control the banner's rendered size.
class EventTypeBanner extends StatelessWidget {
  final EventTypeBannerTheme theme;
  final double height;

  const EventTypeBanner({super.key, required this.theme, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.gradientColors,
              ),
            ),
          ),
          CustomPaint(
            painter: EventIconPatternPainter(
              icons: theme.icons,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
