import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jogak/core/theme/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jogak/core/providers/settings_provider.dart';

class StarfieldBackground extends ConsumerStatefulWidget {
  final Widget? child;
  final Offset parallaxOffset;

  const StarfieldBackground({
    super.key,
    this.child,
    this.parallaxOffset = Offset.zero,
  });

  @override
  ConsumerState<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends ConsumerState<StarfieldBackground>
    with TickerProviderStateMixin {
  late List<StarModel> _stars;
  late List<ShootingStarModel> _shootingStars;
  late AnimationController _starController; // 별 애니메이션용

  // ── 쉐이더 관련 ──────────────────────────
  ui.FragmentShader? _nebulaShader;
  bool _isShaderLoaded = false;
  late Ticker _ticker;      // 호수 버전과 동일한 방식 — elapsed 초 단위
  double _elapsedTime = 0.0;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(80, (index) => StarModel());
    _shootingStars = List.generate(2, (index) => ShootingStarModel());

    // 별 깜빡임/유성 전용 컨트롤러
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Ticker 즉시 초기화 (쉐이더 로드 전에 _ticker가 사용되는 오류 방지)
    _ticker = createTicker((elapsed) {
      final isNebulaEnabled = ref.read(nebulaEnabledProvider);
      if (_isShaderLoaded && mounted && isNebulaEnabled) {
        setState(() {
          _elapsedTime = elapsed.inMilliseconds / 1000.0;
        });
      }
    });

    // 쉐이더 로드 (호수 버전과 동일한 방식)
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/cosmic_nebula.frag');
      if (mounted) {
        setState(() {
          _nebulaShader = program.fragmentShader();
          _isShaderLoaded = true;
          final isNebulaEnabled = ref.read(nebulaEnabledProvider);
          if (isNebulaEnabled) _ticker.start(); // 쉐이더 로드 완료 후 토글 확인하여 Ticker 시작
        });
      }
    } catch (e) {
      debugPrint('Failed to load cosmic_nebula shader: $e');
      // 쉐이더 실패 시에도 매끄러운 동작을 위해 ticker 시작 (별은 보이도록)
      final isNebulaEnabled = ref.read(nebulaEnabledProvider);
      if (mounted && isNebulaEnabled) _ticker.start();
    }
  }

  @override
  void dispose() {
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNebulaEnabled = ref.watch(nebulaEnabledProvider);

    // 전역 상태 변경 시 Ticker 제어
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (isNebulaEnabled) {
          if (!_ticker.isActive && _isShaderLoaded) _ticker.start();
        } else {
          if (_ticker.isActive) _ticker.stop();
        }
      }
    });

    return Stack(
      children: [
        // 1. Deep Space Base (짙은 검정)
        Container(color: AppColors.background),

        // 2. Cosmic Nebula Shader (fBm 기반, 호수 버전과 동일한 알고리즘)
        if (_isShaderLoaded && isNebulaEnabled)
          CustomPaint(
            size: Size.infinite,
            painter: NebulaShaderPainter(
              shader: _nebulaShader!,
              time: _elapsedTime, // 실제 경과 초 전달
            ),
          ),

        // 3. Stars & Shooting Stars (별 컨트롤러 사용)
        AnimatedBuilder(
          animation: _starController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: StarfieldPainter(
                stars: _stars,
                shootingStars: _shootingStars,
                parallaxOffset: widget.parallaxOffset,
                time: _starController.value,
              ),
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// fBm 쉐이더 기반 성운 페인터
class NebulaShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  NebulaShaderPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // uniform 순서: uTime(float), uSize(vec2=2floats)
    shader.setFloat(0, time);        // uTime — 실제 경과 초
    shader.setFloat(1, size.width);  // uSize.x
    shader.setFloat(2, size.height); // uSize.y

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(NebulaShaderPainter oldDelegate) =>
      oldDelegate.time != time;
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

    for (var star in stars) {
      double dx = (star.x * size.width) + (parallaxOffset.dx * 80 * star.depth);
      double dy = (star.y * size.height) + (parallaxOffset.dy * 80 * star.depth);

      dx = dx % size.width;
      dy = dy % size.height;

      final twinkle = 0.3 +
          (0.7 *
              (0.5 +
                  0.5 *
                      sin(time * 35 * star.twinkleSpeed * pi +
                          star.twinkleOffset)));
      paint.color = star.baseColor.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(dx, dy), star.size, paint);

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

    for (var ss in shootingStars) {
      final double durationFraction = 0.07;
      double activeProgress = (time - ss.startTime) / durationFraction;
      if (activeProgress < 0) activeProgress += (1.0 / durationFraction);

      if (activeProgress >= 0 && activeProgress <= 1.0) {
        final travelDistance =
            size.width * 1.2 * activeProgress * ss.speedMultiplier;
        final double startX =
            ss.x * size.width + cos(ss.angle) * travelDistance;
        final double startY =
            ss.y * size.height + sin(ss.angle) * travelDistance;

        final double opacity = sin(activeProgress * pi).clamp(0.0, 1.0);
        final double tailLength = 120.0 + (activeProgress * 60.0);
        final double endX = startX - cos(ss.angle) * tailLength;
        final double endY = startY - sin(ss.angle) * tailLength;

        final head = Offset(startX, startY);
        final tail = Offset(endX, endY);

        final streakPaint = Paint()
          ..shader = ui.Gradient.linear(
            head,
            tail,
            [
              Colors.white.withValues(alpha: opacity * 0.9),
              Colors.white.withValues(alpha: 0.0),
            ],
          )
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(head, tail, streakPaint);

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
