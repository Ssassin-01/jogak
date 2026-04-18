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
        // 1. Deep Space Background (Single Flat Dark color for better blending)
        Container(
          color: AppColors.background,
        ),

        // 2. Cosmic Fog & Nebula Layers (Subtler & Darker)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double value = _controller.value;
            return Stack(
              children: [
                // Deep Abyss Mist (Teal)
                _buildNebula(
                  const Color(0xFF005F73), // 더 선명한 청록
                  const Offset(0.5, 0.5),
                  3.0, 
                  value,
                  alpha: 0.25, // 농도 상향
                  distortAmount: 0.2,
                ),
                // Drifting Dark Nebula (Navy)
                _buildNebula(
                  const Color(0xFF101835),
                  const Offset(0.3, 0.4),
                  2.5,
                  value,
                  alpha: 0.2,
                  distortAmount: 0.15,
                ),
                // Glowing Soft Purple
                _buildNebula(
                  AppColors.nebulaPurple,
                  const Offset(0.7, 0.3),
                  2.2,
                  value,
                  alpha: 0.18,
                  distortAmount: 0.1,
                ),
                // Active Blue Smog
                _buildNebula(
                  AppColors.nebulaBlue,
                  const Offset(0.2, 0.7),
                  2.0,
                  value,
                  alpha: 0.15,
                  distortAmount: 0.25,
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
    double value, {
    double speedX = 0.0,
    double alpha = 0.2,
    double distortAmount = 0.05,
    double scaleX = 1.0, // 더 이상 scale을 외부에서 위젯 자체를 자르는 용도로 쓰지 않음
    double scaleY = 1.0,
  }) {
    final double angle = value * 2 * pi;
    final double xMove = sin(angle * 0.5) * 0.3; // 수평 움직임 강조
    
    // 화면 전체를 덮도록 Positioned.fill 유지
    final x = basePosition.dx + xMove + cos(angle * 1.0) * distortAmount;
    final y = basePosition.dy + sin(angle * 1.0) * distortAmount;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: FractionalOffset(x, y),
            radius: radius, // 충분히 큰 반경
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.5),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 1.0],
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
