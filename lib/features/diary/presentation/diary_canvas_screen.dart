import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/starfield_background.dart';
import 'package:jogak/features/diary/data/models/diary_schema.dart';
import 'package:jogak/features/diary/data/repositories/diary_repository.dart';

enum CanvasMode { hand, brush, text }
enum CanvasPieceType { text, photo }

class CanvasPiece {
  final String id;
  CanvasPieceType type;
  String content; 
  Offset position;
  double scale; 
  Color? emotionColor; // 조각의 감정 색상

  CanvasPiece({
    required this.id,
    this.type = CanvasPieceType.text,
    this.content = '',
    required this.position,
    this.scale = 1.0,
    this.emotionColor,
  });
}

class DrawingStroke {
  final List<Offset?> points;
  final Color color;
  final double width;

  DrawingStroke({required this.points, required this.color, required this.width});
}

class DiaryCanvasScreen extends ConsumerStatefulWidget {
  const DiaryCanvasScreen({super.key});

  @override
  ConsumerState<DiaryCanvasScreen> createState() => _DiaryCanvasScreenState();
}

class _DiaryCanvasScreenState extends ConsumerState<DiaryCanvasScreen> {
  final List<CanvasPiece> _pieces = [];
  final List<DrawingStroke> _strokes = [];
  
  CanvasMode _currentMode = CanvasMode.hand; 
  Color _selectedColor = AppColors.nebulaBlue; 
  double _strokeWidth = 4.0;

  final List<Color> _palette = [
    AppColors.starlightJoy,
    AppColors.nebulaBlue,
    AppColors.nebulaPurple,
    const Color(0xFFFDFDFD), // 화이트
    AppColors.starlightSad,
  ];

  bool _isSaving = false;

  Future<void> _saveDiary() async {
    if (_pieces.isEmpty && _strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록할 조각이나 그림이 없습니다.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 현재 포커스 해제 (텍스트 입력 저장 보장)
      FocusScope.of(context).unfocus();
      
      final entry = DiaryEntry()
        ..uuid = DateTime.now().toIso8601String()
        ..date = DateTime.now()
        ..emotionColorValue = (_guideColor ?? AppColors.nebulaBlue).toARGB32()
        ..pieces = _pieces.map((p) => PieceSchema()
          ..typeIndex = p.type.index
          ..content = p.content
          ..posX = p.position.dx
          ..posY = p.position.dy
          ..scale = p.scale
          ..emotionColorValue = p.emotionColor?.toARGB32()
        ).toList()
        ..strokes = _strokes.map((s) => StrokeSchema()
          ..colorValue = s.color.toARGB32()
          ..width = s.width
          ..points = s.points.expand((p) => p != null ? [p.dx, p.dy] : [-1.0, -1.0]).toList()
        ).toList();

      await ref.read(diaryRepositoryProvider).saveDiaryEntry(entry);

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘의 조각이 저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 가이드 상태 관련 (별빛의 속삭임)
  int _guideStep = 0; // 0: idle, 1: mood select, 2: polishing, 3: result
  Color? _guideColor;
  double _polishProgress = 0.0;
  String _guideQuestion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pieces.isEmpty) {
        setState(() => _guideStep = 1);
      }
    });
  }
  
  void _addTextPieceWithContent(Offset position, String content, {Color? emotionColor}) {
    setState(() {
      _pieces.add(CanvasPiece(
        id: DateTime.now().toString(),
        type: CanvasPieceType.text,
        position: position,
        content: content,
        emotionColor: emotionColor,
      ));
    });
    HapticFeedback.mediumImpact();
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
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.nebulaPurple,
          brightness: Brightness.dark,
          primary: Colors.white,
          secondary: AppColors.secondary,
          surface: AppColors.background,
          onSurface: Colors.white70,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white30,
          selectionColor: Color(0x33FFFFFF),
          selectionHandleColor: Colors.white30,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        resizeToAvoidBottomInset: false,
        body: StarfieldBackground(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 조각 레이어
              ..._pieces.map((piece) => _buildPiece(piece)),
  
              // 2. 통합 드로잉 레이어
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
                  onPanEnd: (_) {
                    if (_strokes.isNotEmpty) {
                      setState(() => _strokes.last.points.add(null));
                    }
                  },
                  child: CustomPaint(
                    painter: DrawingPainter(strokes: _strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
  
              if (_currentMode == CanvasMode.brush) _buildDrawingOptions(),
              _buildToolbar(),
              _buildHeader(),

              // 3. 별빛의 속삭임 가이드 오버레이
              if (_guideStep > 0) _buildGuideOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedSwitcher(
            duration: 600.ms,
            child: _guideStepWidget(),
          ),
        ),
      ),
    );
  }

  Widget _guideStepWidget() {
    switch (_guideStep) {
      case 1: return _buildMoodSelection();
      case 2: return _buildPolishing();
      case 3: return _buildRevelation();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildMoodSelection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '오늘 당신의 밤하늘은 어떤 빛인가요?',
          style: GoogleFonts.gowunBatang(color: Colors.white, fontSize: 18, letterSpacing: 1),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _moodStar(AppColors.starlightJoy, '따스함'),
            _moodStar(AppColors.starlightSad, '시린'),
            _moodStar(AppColors.nebulaPurple, '짙은'),
            _moodStar(const Color(0xFFFDFDFD), '잔잔한'),
          ],
        ),
      ],
    );
  }

  Widget _moodStar(Color color, String label) {
    return GestureDetector(
      onTap: () => setState(() {
        _guideColor = color;
        _guideStep = 2;
        _guideQuestion = _getQuestionForMood(color);
      }),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
                gradient: RadialGradient(colors: [Colors.white, color]),
              ),
            ),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.gowunBatang(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale();
  }

  String _getQuestionForMood(Color color) {
    if (color == AppColors.starlightJoy) return '오늘 당신을 미소 짓게 한 순간은 무엇이었나요?';
    if (color == AppColors.starlightSad) return '마음의 무게를 1% 덜어낸다면 어떤 이야기를 비우고 싶나요?';
    if (color == AppColors.nebulaPurple) return '지금 당신을 불안하게 만드는 것들은 무엇인가요?';
    return '오늘 하루 중 당신이 가장 당신다웠던 순간은 언제인가요?';
  }

  Widget _buildPolishing() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _polishProgress = (_polishProgress + details.delta.distance / 1000).clamp(0.0, 1.0);
          if (_polishProgress >= 1.0 && _guideStep == 2) {
            _guideStep = 3;
            HapticFeedback.heavyImpact();
          } else if (Random().nextInt(10) == 0) {
            HapticFeedback.selectionClick();
          }
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '별빛을 지긋이 문질러 마음을 다듬어보세요',
            style: GoogleFonts.gowunBatang(color: Colors.white, fontSize: 16, height: 1.5),
          ).animate().fadeIn(),
          const SizedBox(height: 60),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200 * (1 + _polishProgress * 0.5),
                height: 200 * (1 + _polishProgress * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_guideColor ?? Colors.white).withValues(alpha: 0.2 + _polishProgress * 0.4),
                      blurRadius: 40 + _polishProgress * 60,
                      spreadRadius: 10 + _polishProgress * 20,
                    )
                  ],
                ),
              ),
              Container(
                width: 80 + _polishProgress * 40,
                height: 80 + _polishProgress * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white, _guideColor ?? Colors.white],
                    stops: [0.2 + _polishProgress * 0.3, 1.0],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
          Container(
            width: 200,
            height: 2,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(1)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 200 * _polishProgress,
                height: 2,
                decoration: BoxDecoration(
                  color: _guideColor,
                  boxShadow: [BoxShadow(color: (_guideColor ?? Colors.white).withValues(alpha: 0.5), blurRadius: 4)],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {
              final size = MediaQuery.of(context).size;
              _addTextPieceWithContent(
                Offset(size.width / 2, size.height / 2), 
                "", // 빈 내용
                emotionColor: _guideColor,
              );
              setState(() => _guideStep = 0);
              HapticFeedback.mediumImpact();
            },
            child: Text(
              '바로 기록 시작하기',
              style: GoogleFonts.gowunBatang(
                color: Colors.white38,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white12,
              ),
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildRevelation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '당신을 위한 질문의 조각이 완성되었습니다',
          style: GoogleFonts.gowunBatang(color: Colors.white60, fontSize: 14),
        ).animate().fadeIn(),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              _guideQuestion,
              textAlign: TextAlign.center,
              style: GoogleFonts.gowunBatang(
                color: Colors.white,
                fontSize: 18,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ).animate().scale(delay: 200.ms),
        const SizedBox(height: 60),
        Column(
          children: [
            ElevatedButton(
              onPressed: () {
                final size = MediaQuery.of(context).size;
                _addTextPieceWithContent(
                  Offset(size.width / 2, size.height / 2), 
                  _guideQuestion,
                  emotionColor: _guideColor,
                );
                setState(() => _guideStep = 0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _guideColor,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('조각에 기록 시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                final size = MediaQuery.of(context).size;
                _addTextPieceWithContent(
                  Offset(size.width / 2, size.height / 2), 
                  "", // 빈 내용
                  emotionColor: _guideColor,
                );
                setState(() => _guideStep = 0);
              },
              child: Text(
                '질문 없이 내 감정 기록하기',
                style: GoogleFonts.gowunBatang(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white30,
                ),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ],
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
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
          Text(
            _modeTitle(),
            style: GoogleFonts.gowunBatang(
              color: AppColors.secondary.withValues(alpha: 0.8),
              fontSize: 14,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveDiary,
            child: _isSaving 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)
                )
              : Text(
                  '완성',
                  style: GoogleFonts.gowunBatang(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _modeTitle() {
    switch (_currentMode) {
      case CanvasMode.hand: return '조각 이동 모드';
      case CanvasMode.brush: return '자유 드로잉 모드';
      case CanvasMode.text: return '글쓰기 및 기록 모드';
    }
  }

  Widget _buildPiece(CanvasPiece piece) {
    return Positioned(
      left: piece.position.dx - 140,
      top: piece.position.dy - 120,
      child: GestureDetector(
        onPanUpdate: _currentMode == CanvasMode.hand ? (details) {
          setState(() {
            piece.position += details.delta;
          });
        } : null,
        child: Container(
          width: 280,
          height: 240,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(280, 240),
                painter: StarlightShardPainter(
                  seed: piece.id.hashCode,
                  glowColor: piece.emotionColor ?? AppColors.nebulaBlue,
                ),
              ),
              if (piece.type == CanvasPieceType.text)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(35.0),
                    child: Center(
                      child: TextField(
                        autofocus: piece.content.isEmpty,
                        maxLines: null,
                        cursorColor: Colors.white70,
                        textAlign: TextAlign.center,
                        onChanged: (v) => piece.content = v,
                        controller: TextEditingController(text: piece.content)..selection = TextSelection.fromPosition(TextPosition(offset: piece.content.length)),
                        style: GoogleFonts.gowunBatang(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '이 조각에 기억을 새기세요...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
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
        ).animate().fadeIn(duration: 400.ms),
      ),
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
            ..._palette.map((color) => _paletteItem(color)),
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
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: -5,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarItem(Icons.back_hand_rounded, '이동', isActive: _currentMode == CanvasMode.hand, () {
                      setState(() => _currentMode = CanvasMode.hand);
                    }),
                    _toolbarSeparator(),
                    _toolbarItem(Icons.brush_rounded, '그리기', isActive: _currentMode == CanvasMode.brush, () {
                      setState(() => _currentMode = CanvasMode.brush);
                    }),
                    _toolbarSeparator(),
                    _toolbarItem(Icons.text_fields_rounded, '기록', isActive: _currentMode == CanvasMode.text, () {
                      setState(() => _currentMode = CanvasMode.text);
                    }),
                    _toolbarSeparator(),
                    _toolbarItem(Icons.undo_rounded, '복구', () {
                      if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
                    }),
                    _toolbarSeparator(),
                    _toolbarItem(Icons.image_outlined, '추가', () => _addPhotoPiece()),
                  ],
                ),
              ),
            ),
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
            Icon(
              icon, 
              color: isActive ? AppColors.secondary : Colors.white.withValues(alpha: 0.3), 
              size: 22
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: isActive ? AppColors.secondary : Colors.white.withValues(alpha: 0.2), 
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              )
            ),
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
        ..color = stroke.color.withValues(alpha: 0.8)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.width
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..style = PaintingStyle.stroke;

      final glowPaint = Paint()
        ..color = stroke.color.withValues(alpha: 0.2)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.width * 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, glowPaint);
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class StarlightShardPainter extends CustomPainter {
  final int seed;
  final Color glowColor;
  StarlightShardPainter({required this.seed, this.glowColor = AppColors.nebulaBlue});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final random = Random(seed);

    path.moveTo(w * 0.1, h * 0.1);
    path.lineTo(w * 0.5 + (random.nextDouble() - 0.5) * 20, h * 0.05);
    path.lineTo(w * 0.9, h * 0.15);
    path.lineTo(w * 0.95 + (random.nextDouble() - 0.5) * 15, h * 0.5);
    path.lineTo(w * 0.85, h * 0.9);
    path.lineTo(w * 0.5 + (random.nextDouble() - 0.5) * 20, h * 0.95);
    path.lineTo(w * 0.05, h * 0.85);
    path.lineTo(w * 0.1, h * 0.45);
    path.close();

    canvas.drawShadow(path, glowColor.withValues(alpha: 0.4), 15.0, true);

    final fillPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w / 2, h / 2),
        w,
        [
          const Color(0x331E293B), 
          const Color(0x660F172A), 
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 5.0);
    
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, borderPaint);

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 5; i++) {
      double x1 = random.nextDouble() * w;
      double y1 = random.nextDouble() * h;
      canvas.drawLine(Offset(x1, y1), Offset(x1 + 15, y1 + 5), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
