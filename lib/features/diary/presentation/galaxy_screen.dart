import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/starfield_background.dart';
import 'package:jogak/features/diary/data/models/diary_schema.dart';
import 'package:jogak/features/diary/data/repositories/diary_repository.dart';
import 'package:jogak/features/diary/presentation/widgets/diary_detail_view.dart';
import 'dart:math' as math;

class GalaxyScreen extends ConsumerStatefulWidget {
  const GalaxyScreen({super.key});

  @override
  ConsumerState<GalaxyScreen> createState() => _GalaxyScreenState();
}

class _GalaxyScreenState extends ConsumerState<GalaxyScreen> {
  DiaryEntry? _selectedEntry;
  final TransformationController _transformationController = TransformationController();
  
  // 은하 지도 크기 (가상 공간)
  static const double _galaxySize = 4000.0;
  
  @override
  void initState() {
    super.initState();
    // 초기 위치를 은하 중심(Center)으로 설정
    _transformationController.value = Matrix4.identity()
      ..translate(-(_galaxySize / 2 - 200), -(_galaxySize / 2 - 400));
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diariesFuture = ref.watch(diaryRepositoryProvider).getAllDiaries();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 패럴랙스 배경 (InteractiveViewer 이동과 연동)
          ValueListenableBuilder<Matrix4>(
            valueListenable: _transformationController,
            builder: (context, matrix, child) {
              final translation = matrix.getTranslation();
              return StarfieldBackground(
                parallaxOffset: Offset(translation.x / _galaxySize, translation.y / _galaxySize),
                child: child,
              );
            },
          ),

          // 2. 우주 지도 (InteractiveViewer)
          FutureBuilder<List<DiaryEntry>>(
            future: diariesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
              }

              final diaries = snapshot.data ?? [];

              return InteractiveViewer(
                transformationController: _transformationController,
                constrained: false, // 4000x4000 영역을 자유롭게 탐험하기 위해 필수
                boundaryMargin: const EdgeInsets.all(100.0), // 너무 먼 이탈 방지
                minScale: 0.1,
                maxScale: 2.5,
                child: Container(
                  width: _galaxySize,
                  height: _galaxySize,
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      // 모든 성좌 배치
                      for (int i = 0; i < diaries.length; i++)
                        _buildConstellationMarker(diaries[i], i),
                      
                      // 중심부 장식 (은하핵 느낌)
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.05),
                                blurRadius: 150,
                                spreadRadius: 100,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. 안내 문구 (최초 진입 시 가이드)
          if (_selectedEntry == null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.unfold_more_rounded, color: Colors.white24, size: 20),
                      Text(
                        '성좌를 드래그하고 터치하여 기억을 찾아보세요',
                        style: GoogleFonts.gowunBatang(
                          color: Colors.white24,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1.seconds).fadeOut(delay: 5.seconds),
                ),
              ),
            ),

          // 4. 고정 UI (상단 타이틀)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '당신의 은하',
                  style: GoogleFonts.gowunBatang(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),

          // 4. 테스트용 더미 생성 버튼 (우측 하단)
          Positioned(
            bottom: 100,
            right: 20,
            child: Opacity(
              opacity: 0.2,
              child: FloatingActionButton.small(
                onPressed: _injectDummyData,
                backgroundColor: Colors.white10,
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
            ),
          ),

          // 5. 상세 보기 오버레이
          if (_selectedEntry != null)
            DiaryDetailView(
              entry: _selectedEntry!,
              onBack: () => setState(() => _selectedEntry = null),
            ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
        ],
      ),
    );
  }

  Widget _buildConstellationMarker(DiaryEntry entry, int index) {
    // 나선형 배치 알고리즘
    final double theta = index * 0.75; // 각도
    final double radius = 300 + (index * 120); // 반지름
    
    final double posX = (_galaxySize / 2) + math.cos(theta) * radius;
    final double posY = (_galaxySize / 2) + math.sin(theta) * radius;

    final dateStr = "${entry.date.month} / ${entry.date.day}";
    final emotionColor = Color(entry.emotionColorValue);

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onTap: () => setState(() => _selectedEntry = entry),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 성좌 실루엣
            SizedBox(
              width: 180,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: emotionColor.withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(140, 100),
                    painter: MiniConstellationPainter(
                      pieces: entry.pieces,
                      emotionColor: emotionColor,
                    ),
                  ),
                ],
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .moveY(begin: -8, end: 8, duration: (2500 + (index % 7) * 400).ms, curve: Curves.easeInOutSine),
            
            const SizedBox(height: 8),
            
            Text(
              dateStr,
              style: GoogleFonts.gowunBatang(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _injectDummyData() async {
    final repo = ref.read(diaryRepositoryProvider);
    
    for (int i = 0; i < 20; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final color = [
        AppColors.starlightJoy, 
        AppColors.starlightSad, 
        AppColors.starlightCalm, 
        AppColors.nebulaBlue, 
        AppColors.nebulaPurple
      ][i % 5];

      final entry = DiaryEntry()
        ..uuid = "dummy_$i"
        ..date = date
        ..emotionColorValue = color.toARGB32()
        ..pieces = [
          PieceSchema()
            ..content = "기억의 조각 $i"
            ..posX = 150.0 + (math.Random().nextDouble() * 100)
            ..posY = 150.0 + (math.Random().nextDouble() * 100)
            ..scale = 1.0
            ..typeIndex = 0 // text
            ..emotionColorValue = color.toARGB32()
          ,
          PieceSchema()
            ..content = "또 다른 조각"
            ..posX = 250.0 + (math.Random().nextDouble() * 50)
            ..posY = 100.0 + (math.Random().nextDouble() * 50)
            ..scale = 0.8
            ..typeIndex = 0
            ..emotionColorValue = color.toARGB32()
        ]
        ..strokes = [];
      
      await repo.saveDiaryEntry(entry);
    }
    
    if (mounted) {
      setState(() {}); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('20개의 성좌가 은하 지도에 흩뿌려졌습니다.')),
      );
    }
  }
}

class MiniConstellationPainter extends CustomPainter {
  final List<PieceSchema> pieces;
  final Color emotionColor;

  MiniConstellationPainter({required this.pieces, required this.emotionColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (pieces.isEmpty) return;

    final paint = Paint()
      ..color = emotionColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    double minX = 10000, minY = 10000, maxX = -10000, maxY = -10000;
    for (var p in pieces) {
      if (p.posX < minX) minX = p.posX;
      if (p.posY < minY) minY = p.posY;
      if (p.posX > maxX) maxX = p.posX;
      if (p.posY > maxY) maxY = p.posY;
    }

    const padding = 15.0;
    double contentWidth = maxX - minX;
    double contentHeight = maxY - minY;
    if (contentWidth == 0) contentWidth = 1;
    if (contentHeight == 0) contentHeight = 1;

    double scaleX = (size.width - padding * 2) / contentWidth;
    double scaleY = (size.height - padding * 2) / contentHeight;
    double scale = math.min(scaleX, scaleY);

    List<Offset> points = [];
    for (var p in pieces) {
      final x = padding + (p.posX - minX) * scale;
      final y = padding + (p.posY - minY) * scale;
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      // 곡선으로 연결 시도 (Optional)
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (var p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
      // 별의 은은한 광채
      canvas.drawCircle(p, 6, Paint()
        ..color = emotionColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
