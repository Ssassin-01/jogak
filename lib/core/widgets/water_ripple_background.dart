import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WaterRippleBackground extends StatefulWidget {
  final Widget? child;

  const WaterRippleBackground({super.key, this.child});

  @override
  State<WaterRippleBackground> createState() => _WaterRippleBackgroundState();
}

class _WaterRippleBackgroundState extends State<WaterRippleBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late Ticker _ticker;
  double _time = 0.0;
  Offset _touchPosition = Offset.zero;
  bool _isShaderLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      if (_isShaderLoaded) {
        setState(() {
          _time = elapsed.inMilliseconds / 1000.0;
        });
      }
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/yoonseul.frag');
      _shader = program.fragmentShader();
      setState(() {
        _isShaderLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isShaderLoaded) {
      return Container(color: const Color(0xFF020408));
    }

    return Listener(
      onPointerHover: (event) => _touchPosition = event.localPosition,
      onPointerDown: (event) => _touchPosition = event.localPosition,
      onPointerMove: (event) => _touchPosition = event.localPosition,
      child: CustomPaint(
        painter: YoonseulPainter(
          shader: _shader!,
          time: _time,
          touch: _touchPosition,
        ),
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class YoonseulPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Offset touch;

  YoonseulPainter({
    required this.shader,
    required this.time,
    required this.touch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // uniform 0: uTime
    shader.setFloat(0, time);
    // uniform 1, 2: uSize (x, y)
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    // uniform 3, 4: uTouch (x, y)
    shader.setFloat(3, touch.dx);
    shader.setFloat(4, touch.dy);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(YoonseulPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.touch != touch;
  }
}
