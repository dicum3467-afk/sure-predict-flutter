import 'dart:ui';
import 'package:flutter/material.dart';

class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6, -0.8),
              radius: 1.3,
              colors: [
                Color(0xFF171A2E),
                Color(0xFF070A12),
              ],
            ),
          ),
        ),

        // Aurora blobs
        Positioned(
          top: -120,
          left: -80,
          child: _blob(const Color(0xFFB7A6FF), 260),
        ),
        Positioned(
          top: 90,
          right: -120,
          child: _blob(const Color(0xFF6EE7FF), 280),
        ),
        Positioned(
          bottom: -140,
          left: 40,
          child: _blob(const Color(0xFF22C55E), 260),
        ),

        // Blur layer
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(color: Colors.transparent),
        ),

        // Subtle noise overlay (fake via opacity)
        IgnorePointer(
          child: Container(color: Colors.white.withOpacity(0.02)),
        ),

        child,
      ],
    );
  }

  Widget _blob(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.28),
        shape: BoxShape.circle,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NeoBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const NeoBadge({super.key, required this.text, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
        color: c.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c.withOpacity(0.95)),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: c.withOpacity(0.95),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class NeoSegment extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const NeoSegment({
    super.key,
    required this.left,
    required this.right,
    required this.isLeftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(6),
      radius: 999,
      child: Row(
        children: [
          Expanded(
            child: _segBtn(
              context,
              label: left,
              selected: isLeftSelected,
              onTap: onLeft,
              active: cs.primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _segBtn(
              context,
              label: right,
              selected: !isLeftSelected,
              onTap: onRight,
              active: cs.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segBtn(BuildContext context,
      {required String label, required bool selected, required VoidCallback onTap, required Color active}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? active.withOpacity(0.16) : Colors.transparent,
          border: Border.all(
            color: selected ? active.withOpacity(0.35) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class NeoProgressBar extends StatelessWidget {
  final double a; // 1
  final double d; // X
  final double b; // 2
  const NeoProgressBar({super.key, required this.a, required this.d, required this.b});

  @override
  Widget build(BuildContext context) {
    double clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

    final aa = clamp01(a);
    final dd = clamp01(d);
    final bb = clamp01(b);

    // normalize
    final sum = (aa + dd + bb);
    final na = sum == 0 ? 0.33 : aa / sum;
    final nd = sum == 0 ? 0.33 : dd / sum;
    final nb = sum == 0 ? 0.34 : bb / sum;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06)),
        child: Row(
          children: [
            Expanded(flex: (na * 1000).round().clamp(1, 1000), child: _seg(const Color(0xFFB7A6FF))),
            Expanded(flex: (nd * 1000).round().clamp(1, 1000), child: _seg(const Color(0xFF6EE7FF))),
            Expanded(flex: (nb * 1000).round().clamp(1, 1000), child: _seg(const Color(0xFF22C55E))),
          ],
        ),
      ),
    );
  }

  Widget _seg(Color c) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [c.withOpacity(0.85), c.withOpacity(0.35)],
          ),
        ),
      );
}
