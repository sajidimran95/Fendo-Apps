import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Soft mesh atmosphere — modern light auth backdrop.
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_drift.value);
        return Container(
          decoration: const BoxDecoration(gradient: AppColors.heroWash),
          child: Stack(
            children: [
              Positioned(
                top: -120 + t * 24,
                right: -80,
                child: _Blob(
                  size: 320,
                  color: AppColors.mint.withValues(alpha: 0.22),
                ),
              ),
              Positioned(
                top: 180 - t * 18,
                left: -100,
                child: _Blob(
                  size: 260,
                  color: const Color(0xFF7ED9C4).withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                bottom: -40 + t * 20,
                right: 40,
                child: Transform.rotate(
                  angle: t * math.pi * 0.05,
                  child: _Blob(
                    size: 200,
                    color: AppColors.amber.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Soft vignette for depth
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                        AppColors.canvas.withValues(alpha: 0.55),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
