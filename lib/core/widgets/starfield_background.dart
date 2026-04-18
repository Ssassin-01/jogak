import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:jogak/core/theme/app_colors.dart';

class StarfieldBackground extends StatefulWidget {
  final Widget? child;
  final Offset parallaxOffset;

  const StarfieldBackground({
    super.key,
    this.child,
    this.parallaxOffset = Offset.zero,
  });

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late List<StarModel> _stars;
  late List<ShootingStarModel> _shootingStars;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 일기를 쓰며 별이 추가될 예정이므로 배경 별은 최소화 (200 -> 80)
    _stars = List.generate(80, (index) => StarModel());
    _shootingStars = List.generate(2, (index) => ShootingStarModel());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // 더 천천히 움직이도록
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Deep Space Background
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                AppColors.background.withBlue(40).withValues(alpha: 0.8),
                AppColors.background,
              ],
            ),
          ),
        ),

        // 2. Cosmic Fog & Nebula Layers (Stretched for Lake-like Mist)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Horizontal Deep Mist Layer (Teal/Abyss)
                _buildNebula(
                  const Color(0xFF004D5C).withValues(alpha: 0.2), // 더 짙은 청록
                  const Offset(0.5, 0.6),
                  2.5,
                  _controller.value * 2 * pi,
                  distortAmount: 0.15,
                  scaleX: 2.0, // 수평으로 길게 늘림
                  scaleY: 0.8,
                ),
                // Drifting Fog Layer (Abyss Purple)
                _buildNebula(
                  AppColors.background.withBlue(90).withValues(alpha: 0.18),
                  const Offset(0.3, 0.4),
                  2.0,
                  (_controller.value * 0.7) * 2 * pi,
                  distortAmount: 0.12,
                  scaleX: 1.8,
                  scaleY: 0.6,
                ),
                // Glowing Nebula Mist (Purple)
                _buildNebula(
                  AppColors.nebulaPurple.withValues(alpha: 0.22),
                  const Offset(0.7, 0.3),
                  1.2,
                  (_controller.value * 1.5) * 2 * pi,
                  distortAmount: 0.1,
                  scaleX: 1.5,
                  scaleY: 1.2,
                ),
                // Active Mist Pocket (Blue)
                _buildNebula(
                  AppColors.nebulaBlue.withValues(alpha: 0.2),
                  const Offset(0.2, 0.8),
                  1.0,
                  ((_controller.value + 0.5) * 2.0) * 2 * pi,
                  distortAmount: 0.2,
                  scaleX: 1.4,
                  scaleY: 0.9,
                ),
                
                // Stars & Shooting Stars Layer
                CustomPaint(
                  size: Size.infinite,
                  painter: StarfieldPainter(
                    stars: _stars,
                    shootingStars: _shootingStars,
                    parallaxOffset: widget.parallaxOffset,
                    time: _controller.value,
                  ),
                ),
              ],
            );
          },
        ),

        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildNebula(
    Color color, 
    Offset basePosition, 
    double radius, 
    double angle, {
    double distortAmount = 0.05,
    double scaleX = 1.0,
    double scaleY = 1.0,
  }) {
    final x = basePosition.dx + cos(angle) * distortAmount + sin(angle * 1.3) * 0.03;
    final y = basePosition.dy + sin(angle * 0.8) * distortAmount + cos(angle * 1.6) * 0.03;

    return Positioned.fill(
      child: Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: FractionalOffset(x, y),
              radius: radius + sin(angle * 0.5) * 0.2, 
              colors: [color, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class StarModel {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = Random().nextDouble() * 1.3 + 0.3;
  final double twinkleSpeed = Random().nextDouble() * 0.06 + 0.02;
  final double twinkleOffset = Random().nextDouble() * 1000;
  final double depth = Random().nextDouble() * 0.8 + 0.2; 
  final Color baseColor = Random().nextDouble() > 0.85 
      ? (Random().nextBool() ? AppColors.nebulaBlue : AppColors.nebulaPurple)
      : Colors.white;
}

class ShootingStarModel {
  late double x;
  late double y;
  late double speedMultiplier;
  late double angle;
  late double startTime;
  
  ShootingStarModel() {
    reset();
  }
  
  void reset() {
    x = Random().nextDouble();
    y = Random().nextDouble() * 0.4;
    speedMultiplier = Random().nextDouble() * 2.5 + 1.2;
    angle = pi / 4 + (Random().nextDouble() - 0.5) * 0.4;
    startTime = Random().nextDouble() * 0.8;
  }
}

class StarfieldPainter extends CustomPainter {
  final List<StarModel> stars;
  final List<ShootingStarModel> shootingStars;
  final Offset parallaxOffset;
  final double time;

  StarfieldPainter({
    required this.stars,
    required this.shootingStars,
    required this.parallaxOffset,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint();

    // 1. Draw Static Stars
    for (var star in stars) {
      double dx = (star.x * size.width) + (parallaxOffset.dx * 80 * star.depth);
      double dy = (star.y * size.height) + (parallaxOffset.dy * 80 * star.depth);

      dx = dx % size.width;
      dy = dy % size.height;

      final twinkle = 0.3 + (0.7 * (0.5 + 0.5 * sin(time * 35 * star.twinkleSpeed * pi + star.twinkleOffset)));
      paint.color = star.baseColor.withValues(alpha: twinkle);

      canvas.drawCircle(Offset(dx, dy), star.size, paint);
      
      // 글로우 효과는 아주 큰 별에만 드물게 적용하여 성능 확보
      if (star.size > 1.25 && star.baseColor == Colors.white) {
        paint.color = Colors.white.withValues(alpha: twinkle * 0.15);
        canvas.drawCircle(
          Offset(dx, dy),
          star.size * 2.2,
          paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        paint.maskFilter = null;
      }
    }

    // 2. Draw Shooting Stars (Direct Path Gradient Fix)
    for (var ss in shootingStars) {
      final double durationFraction = 0.07; 
      double activeProgress = (time - ss.startTime) / durationFraction;
      if (activeProgress < 0) activeProgress += (1.0 / durationFraction);
      
      if (activeProgress >= 0 && activeProgress <= 1.0) {
        final travelDistance = size.width * 1.2 * activeProgress * ss.speedMultiplier;
        final double startX = ss.x * size.width + cos(ss.angle) * travelDistance;
        final double startY = ss.y * size.height + sin(ss.angle) * travelDistance;
        
        // 투명도 (점진적 등장 -> 소멸)
        final double opacity = sin(activeProgress * pi).clamp(0.0, 1.0);
        
        final double tailLength = 120.0 + (activeProgress * 60.0);
        final double endX = startX - cos(ss.angle) * tailLength;
        final double endY = startY - sin(ss.angle) * tailLength;

        final head = Offset(startX, startY);
        final tail = Offset(endX, endY);

        // Gradient follows the line exactly: Head is White, Tail is Transparent
        final streakPaint = Paint()
          ..shader = ui.Gradient.linear(
            head, 
            tail,
            [
              Colors.white.withValues(alpha: opacity * 0.9), 
              Colors.white.withValues(alpha: 0.0)
            ],
          )
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(head, tail, streakPaint);
        
        // 유성 머리 효과 (Glow)
        canvas.drawCircle(
          head, 
          2.5, 
          Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      } else if (activeProgress > 1.02) {
        if (Random().nextDouble() > 0.99) ss.reset();
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => true;
}
