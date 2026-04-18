import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';

enum CanvasMode { hand, brush, text }
enum CanvasPieceType { text, photo }

class CanvasPiece {
  final String id;
  CanvasPieceType type;
  String content; 
  Offset position;
  double scale; 

  CanvasPiece({
    required this.id,
    this.type = CanvasPieceType.text,
    this.content = '',
    required this.position,
    this.scale = 1.0,
  });
}

class DrawingStroke {
  final List<Offset?> points;
  final Color color;
  final double width;

  DrawingStroke({required this.points, required this.color, required this.width});
}

class DiaryCanvasScreen extends StatefulWidget {
  const DiaryCanvasScreen({super.key});

  @override
  State<DiaryCanvasScreen> createState() => _DiaryCanvasScreenState();
}

class _DiaryCanvasScreenState extends State<DiaryCanvasScreen> {
  final List<CanvasPiece> _pieces = [];
  final List<DrawingStroke> _strokes = [];
  
  CanvasMode _currentMode = CanvasMode.hand; 
  Color _selectedColor = const Color(0xFF2C3E50); 
  double _strokeWidth = 4.0;

  final List<Color> _palette = [
    const Color(0xFF2C3E50),
    const Color(0xFFE74C3C),
    const Color(0xFF27AE60),
    const Color(0xFF2980B9),
    const Color(0xFFF39C12),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _addTextPiece(Offset(size.width / 2, size.height / 2 - 100));
    });
  }
  
  void _addTextPiece(Offset position) {
    setState(() {
      _pieces.add(CanvasPiece(
        id: DateTime.now().toString(),
        type: CanvasPieceType.text,
        position: position,
      ));
    });
    HapticFeedback.lightImpact();
  }

  void _addPhotoPiece() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _pieces.add(CanvasPiece(
        id: DateTime.now().toString(),
        type: CanvasPieceType.photo,
        content: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?q=80&w=400',
        position: Offset(size.width / 2 + 50, size.height / 2 + 50),
      ));
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    // 캔버스 내의 모든 보라색(Purple) 테마 요소를 물리적으로 제거
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark, // 테마와 밝기를 일치시켜 오류 해결
          primary: Colors.white,
          secondary: Colors.white24,
          surface: const Color(0xFF0F0F1B),
          onSurface: Colors.white70,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black45,
          selectionColor: Color(0x33000000),
          selectionHandleColor: Colors.black45,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 깊은 어둠 배경
            Container(color: const Color(0xFF0F0F1B)),
            
            // 2. 종이 조각 레이어
            ..._pieces.map((piece) => _buildPiece(piece)).toList(),

            // 3. 통합 드로잉 레이어
            IgnorePointer(
              ignoring: _currentMode != CanvasMode.brush,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _strokes.add(DrawingStroke(
                      points: [details.localPosition],
                      color: _selectedColor,
                      width: _strokeWidth,
                    ));
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    if (_strokes.isNotEmpty) {
                      _strokes.last.points.add(details.localPosition);
                    }
                  });
                },
                onPanEnd: (_) => setState(() => _strokes.last.points.add(null)),
                child: CustomPaint(
                  painter: DrawingPainter(strokes: _strokes),
                  size: Size.infinite,
                ),
              ),
            ),

            if (_currentMode == CanvasMode.brush) _buildDrawingOptions(),
            _buildToolbar(),
            _buildHeader(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white60),
          ),
          Text(
            _modeTitle(),
            style: GoogleFonts.gowunBatang(color: Colors.white60, fontSize: 13, letterSpacing: 1),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('완성', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _modeTitle() {
    switch (_currentMode) {
      case CanvasMode.hand: return '조각 이동 및 크기 조절 모드';
      case CanvasMode.brush: return '자유 드로잉 모드';
      case CanvasMode.text: return '글쓰기 및 기록 모드';
    }
  }

  Widget _buildPiece(CanvasPiece piece) {
    return Positioned(
      left: piece.position.dx - (140 * piece.scale),
      top: piece.position.dy - (120 * piece.scale),
      child: GestureDetector(
        onScaleUpdate: _currentMode == CanvasMode.hand ? (details) {
          setState(() {
            if (details.scale != 1.0) {
              piece.scale = (piece.scale * details.scale).clamp(0.4, 4.0);
            } else {
              piece.position += details.focalPointDelta;
            }
          });
        } : null,
        child: Transform.scale(
          scale: piece.scale,
          child: Container(
            width: 280,
            height: 240,
            decoration: const BoxDecoration(color: Colors.transparent), // 혹시 모를 배경색 제거
            child: Stack(
              children: [
                // 1. 수제 종이 배경 (오직 흰색/회색 계열만 사용)
                CustomPaint(
                  size: const Size(280, 240),
                  painter: TornPaperPainter(seed: piece.id.hashCode),
                ),
                
                // 2. 텍스트 입력 영역 (패딩을 완전히 제거하여 종이 전체를 활용)
                if (piece.type == CanvasPieceType.text)
                  Positioned.fill( // 전체 영역을 채움
                    child: Padding(
                      padding: const EdgeInsets.all(15.0), // 최소한의 테두리 여백만 남김
                      child: TextField(
                        autofocus: piece.content.isEmpty,
                        maxLines: null,
                        cursorColor: Colors.black54,
                        textAlign: TextAlign.start,
                        onChanged: (v) => piece.content = v,
                        style: GoogleFonts.gowunBatang(
                          fontSize: 18,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: '이 종이 위에 자유롭게 기록하세요...',
                          hintStyle: TextStyle(color: Colors.black12, fontSize: 16),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none, // 포커스 시 보라색 선 차단
                          filled: false, // 배경색 채우기 차단
                        ),
                      ),
                    ),
                  )
                else if (piece.type == CanvasPieceType.photo)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(piece.content, width: 220, height: 180, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildDrawingOptions() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            ..._palette.map((color) => _paletteItem(color)).toList(),
            const Divider(color: Colors.white12, height: 20),
            _strokeWidthItem(3.0),
            _strokeWidthItem(7.0),
            _strokeWidthItem(12.0),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _paletteItem(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }

  Widget _strokeWidthItem(double width) {
    bool isSelected = _strokeWidth == width;
    return GestureDetector(
      onTap: () => setState(() => _strokeWidth = width),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: width + 5,
        height: width + 5,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 40)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolbarItem(Icons.back_hand_rounded, '손(이동)', isActive: _currentMode == CanvasMode.hand, () {
                setState(() => _currentMode = CanvasMode.hand);
              }),
              _toolbarSeparator(),
              _toolbarItem(Icons.brush_rounded, '그리기', isActive: _currentMode == CanvasMode.brush, () {
                setState(() => _currentMode = CanvasMode.brush);
              }),
              _toolbarSeparator(),
              _toolbarItem(Icons.text_fields_rounded, '텍스트', isActive: _currentMode == CanvasMode.text, () {
                setState(() => _currentMode = CanvasMode.text);
              }),
              _toolbarSeparator(),
              _toolbarItem(Icons.undo_rounded, '취소', () {
                if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
              }),
              _toolbarSeparator(),
              _toolbarItem(Icons.image_outlined, '사진', () => _addPhotoPiece()),
            ],
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack),
    );
  }

  Widget _toolbarItem(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white24, size: 24),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white12, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _toolbarSeparator() => Container(width: 0.5, height: 25, color: Colors.white10);
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: 0.6)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.width
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class TornPaperPainter extends CustomPainter {
  final int seed;
  TornPaperPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double width = size.width;
    final double height = size.height;

    path.moveTo(10, 10);
    for (double i = 10; i <= width - 10; i += 6) {
      path.lineTo(i, 10 + ((i % 10 < 5) ? 1.0 : -1.0));
    }
    for (double i = 10; i <= height - 10; i += 6) {
      path.lineTo(width - 10 + ((i % 12 < 6) ? 1.5 : -1.5), i);
    }
    for (double i = width - 10; i >= 10; i -= 6) {
      path.lineTo(i, height - 10 + ((i % 8 < 4) ? 1.0 : -1.0));
    }
    for (double i = height - 10; i >= 10; i -= 6) {
      path.lineTo(10 + ((i % 14 < 7) ? 1.8 : -1.8), i);
    }
    path.close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.15), 10.0, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFDFDFD));
    
    final dotPaint = Paint()..color = Colors.black.withValues(alpha: 0.012);
    for (int i = 0; i < 20; i++) {
      double x = (seed + i * 149) % width.toInt() + 0.0;
      double y = (seed + i * 197) % height.toInt() + 0.0;
      canvas.drawCircle(Offset(x, y), 0.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
