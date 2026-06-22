import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../l10n/app_localizations.dart';
import 'wheel_math.dart';

/// Vivid headline gradient (indigo → magenta → amber) shared by the icon + title.
const _kHeadlineGradient = LinearGradient(
  colors: [Color(0xFF667EEA), Color(0xFFF761A1), Color(0xFFFFC048)],
);

/// Fun winner-reveal one-liners, picked at random when the wheel lands. Works for
/// any poll (generic or Cravings). English-only flavour text, matching the
/// existing `_cravingsQuotes` pattern in event_detail_screen.dart.
const _kWheelQuotes = [
  'Blame the wheel, not me. 🤷',
  'Democracy is dead. The wheel rules now. 👑',
  'Your free will was an illusion anyway. 🌀',
  'This is legally binding. Probably. 📜',
  'Arguing? With a wheel? Bold move. 🛞',
  'Congrats to the winner, condolences to the rest. 🥲',
  'We let a spinning circle decide. Worth it. 🎡',
  'Take it up with physics. 🪐',
  'Indecisiveness: cured. You\'re welcome. 💊',
  'The wheel does not do refunds. 🚫',
  'Three hours of debate, one spin. Spin won. ⏱️',
  'It\'s not rigged. (It\'s totally rigged.) 🤫',
  'Objection overruled — by a wheel. 👨‍⚖️',
  'The wheel sees all. Kneel. 🙇',
  'You manifested this. Sort of. 🔮',
  'Fate is dramatic, but it delivered. 🎭',
  'No takesies-backsies. Wheel\'s orders. ✋',
  'Science could not decide. The wheel could. 🔬',
  'Cry about it (to the wheel). 😭',
  'The wheel believes in you. It is also never wrong. 🎯',
];

/// A playful "let fate decide" wheel for a poll. Reads the poll's current votes,
/// spins, and lands on a weighted-random option (arc size ∝ votes). Purely local
/// — it never mutates votes.
class PollWheelSheet extends StatefulWidget {
  final String question;
  final List<WheelSegment> segments;
  final AppLocalizations l10n;

  /// Restaurant/Cravings polls get a food-themed headline + icon.
  final bool isRestaurant;

  /// Injectable for deterministic tests; defaults to a fresh [Random].
  final Random? rng;

  const PollWheelSheet({
    super.key,
    required this.question,
    required this.segments,
    required this.l10n,
    this.isRestaurant = false,
    this.rng,
  });

  @override
  State<PollWheelSheet> createState() => _PollWheelSheetState();
}

class _PollWheelSheetState extends State<PollWheelSheet>
    with TickerProviderStateMixin {
  late final Random _rng = widget.rng ?? Random();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  Animation<double> _rotationAnim = const AlwaysStoppedAnimation(0);
  double _rotation = 0;
  int _lastTickIndex = -1;
  int? _winnerIndex;
  String? _resultQuote;
  bool _spinning = false;
  List<_Particle> _particles = const [];

  @override
  void initState() {
    super.initState();
    _spin.addListener(_onSpinTick);
    _spin.addStatusListener(_onSpinStatus);
  }

  @override
  void dispose() {
    _spin.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onSpinTick() {
    setState(() => _rotation = _rotationAnim.value);
    // Ratchet haptics only during the slow-down phase so it doesn't spam early.
    if (_spin.value > 0.55) {
      final idx = indexAtPointer(widget.segments, _rotation);
      if (idx != _lastTickIndex) {
        _lastTickIndex = idx;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _spinning = false;
      _winnerIndex = indexAtPointer(widget.segments, _rotation);
      _resultQuote = _kWheelQuotes[_rng.nextInt(_kWheelQuotes.length)];
      _rotation = _rotation % (2 * pi);
      _particles = _makeParticles(widget.segments);
    });
    _confetti.forward(from: 0);
  }

  void _spinIt() {
    if (_spinning || widget.segments.length < 2) return;
    final winner = pickWeightedIndex(widget.segments, _rng);
    final jitter = (_rng.nextDouble() * 2 - 1) * 0.7;
    final target = targetAngleForIndex(
      widget.segments,
      winner,
      extraTurns: 5,
      jitter: jitter,
    );
    _rotationAnim = Tween<double>(begin: _rotation, end: target).animate(
      CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic),
    );
    setState(() {
      _spinning = true;
      _winnerIndex = null;
      _lastTickIndex = indexAtPointer(widget.segments, _rotation);
    });
    _spin.forward(from: 0);
  }

  List<_Particle> _makeParticles(List<WheelSegment> segs) {
    final palette = segs.map((s) => s.color).toList();
    return List.generate(44, (i) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 120 + _rng.nextDouble() * 220;
      return _Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 160,
        color: palette[_rng.nextInt(palette.length)],
        size: 5 + _rng.nextDouble() * 7,
        rot: _rng.nextDouble() * pi,
        rotSpeed: (_rng.nextDouble() * 2 - 1) * 6,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final winner = _winnerIndex != null ? widget.segments[_winnerIndex!] : null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    _kHeadlineGradient.createShader(bounds),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isRestaurant
                          ? Icons.restaurant_rounded
                          : Icons.casino_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isRestaurant
                            ? l10n.pollWheelHeadlineFood
                            : l10n.pollWheelHeadline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.question,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _buildWheelStack(),
              ),
              const SizedBox(height: 20),
              if (_spinning)
                _PillButton(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.pollWheelSpinning, style: _kPillTextStyle),
                    ],
                  ),
                )
              else
                _PillButton(
                  key: const Key('spinWheelButton'),
                  onTap: _spinIt,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.casino_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        winner == null
                            ? l10n.pollWheelSpin
                            : l10n.pollWheelSpinAgain,
                        style: _kPillTextStyle,
                      ),
                    ],
                  ),
                ),
              if (winner != null) ...[
                const SizedBox(height: 16),
                _ResultCard(
                  key: const Key('wheelResultCard'),
                  winner: winner,
                  header: _resultQuote ?? l10n.pollWheelResult,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheelStack() {
    return SizedBox(
      width: 300,
      height: 320,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Wheel + confetti share the lower 300×300 square.
          Positioned(
            top: 20,
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size.square(300),
                    painter: _WheelPainter(
                      segments: widget.segments,
                      rotation: _rotation,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _confetti,
                    builder: (_, _) => _confetti.isAnimating ||
                            _confetti.isCompleted
                        ? CustomPaint(
                            size: const Size.square(300),
                            painter: _ConfettiPainter(
                              particles: _particles,
                              progress: _confetti.value,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          // Fixed pointer at top, biting into the rim.
          const Positioned(
            top: 4,
            child: SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(painter: _PointerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wheel ────────────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<WheelSegment> segments;
  final double rotation;

  _WheelPainter({required this.segments, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;
    final total = totalWeight(segments);
    if (total == 0) return;

    // Drop shadow under the wheel.
    canvas.drawCircle(
      center,
      radius + 3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;

    var start = -pi / 2;
    for (final seg in segments) {
      final sweep = 2 * pi * seg.weight / total;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = seg.color);
      canvas.drawArc(rect, start, sweep, true, divider);
      _paintLabel(canvas, seg, radius, start + sweep / 2, sweep);
      start += sweep;
    }
    canvas.restore();

    // Glossy radial highlight for depth.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.65],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Outer ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 5,
    );

    // Center hub.
    canvas.drawCircle(center, radius * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * 0.16,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black12
        ..strokeWidth = 2,
    );
    final hub = TextPainter(
      text: const TextSpan(text: '🎡', style: TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    )..layout();
    hub.paint(canvas, center - Offset(hub.width / 2, hub.height / 2));
  }

  void _paintLabel(
      Canvas canvas, WheelSegment seg, double radius, double mid, double sweep) {
    final showText = sweep >= 0.30;
    final label = seg.emoji != null
        ? (showText ? '${seg.emoji} ${seg.label}' : seg.emoji!)
        : (showText ? seg.label : '•');
    final fontSize = (radius * 0.085).clamp(9.0, 14.0);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 0.66);

    canvas.save();
    canvas.rotate(mid);
    final flip = cos(mid) < 0; // keep text from being fully upside-down
    if (flip) canvas.rotate(pi);
    final d = radius * 0.58;
    final dx = flip ? -d - tp.width / 2 : d - tp.width / 2;
    tp.paint(canvas, Offset(dx, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation || old.segments != segments;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height) // tip pointing down
      ..lineTo(size.width * 0.18, 0)
      ..lineTo(size.width * 0.82, 0)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFF2D2D3A));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}

// ─── Confetti ───────────────────────────────────────────────────────────────

class _Particle {
  final double vx, vy, size, rot, rotSpeed;
  final Color color;
  const _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final origin = Offset(size.width / 2, size.height * 0.12);
    const gravity = 520.0;
    final t = progress * 1.3; // seconds-ish
    final fade = progress < 0.65 ? 1.0 : (1 - (progress - 0.65) / 0.35);

    for (final p in particles) {
      final x = origin.dx + p.vx * t;
      final y = origin.dy + p.vy * t + 0.5 * gravity * t * t;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.rotSpeed * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─── Pill button ──────────────────────────────────────────────────────────────

const _kPillTextStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w800,
  fontSize: 16,
  letterSpacing: 0.3,
);

/// Rounded gradient pill used for the Spin / Spinning / Spin-again states, so
/// the action button stays playful and consistent across all three. A null
/// [onTap] (the spinning state) renders the same look but is non-interactive.
class _PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PillButton({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: _kHeadlineGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF761A1).withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return pill;
    return HoverShimmer(
      borderRadius: BorderRadius.circular(30),
      child: AppTappable(onTap: onTap, child: pill),
    );
  }
}

// ─── Result card ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final WheelSegment winner;
  final String header;

  const _ResultCard({super.key, required this.winner, required this.header});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * v.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [winner.color.withValues(alpha: 0.16), winner.color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: winner.color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            Text(header,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: winner.color)),
            const SizedBox(height: 8),
            if (winner.emoji != null)
              Text(winner.emoji!, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 4),
            Text(
              winner.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
