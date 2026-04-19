import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/starfield_background.dart';
import 'package:jogak/features/diary/data/models/diary_schema.dart';
import 'package:jogak/features/diary/data/repositories/diary_repository.dart';
import 'package:jogak/features/diary/presentation/widgets/diary_detail_view.dart';

class GalaxyScreen extends ConsumerStatefulWidget {
  const GalaxyScreen({super.key});

  @override
  ConsumerState<GalaxyScreen> createState() => _GalaxyScreenState();
}

class _GalaxyScreenState extends ConsumerState<GalaxyScreen> with TickerProviderStateMixin {
  DiaryEntry? _selectedEntry;
  final TransformationController _transformationController = TransformationController();
  
  static const double _galaxySize = 3000.0; // 전체 크기 축소
  static const double _galaxyCenter = _galaxySize / 2;
  
  Future<List<DiaryEntry>>? _diariesFuture; // Future 캐싱
  
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth; // 초기값을 null로 설정하여 '전체 보기(ALL)'로 시작

  late AnimationController _fadeController;
  late AnimationController _navAnimationController;
  late AnimationController _burstController;

  Animation<Matrix4>? _navAnimation;
  Offset? _burstPosition;
  Color? _burstColor;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: 800.ms)..forward();
    _navAnimationController = AnimationController(vsync: this, duration: 1200.ms);
    _navAnimationController.addListener(() {
      if (_navAnimation != null) {
        _transformationController.value = _navAnimation!.value;
      }
    });

    _diariesFuture = ref.read(diaryRepositoryProvider).getAllDiaries(); // 초기 1회만 로드
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusOnMonth(_selectedMonth);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _fadeController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _changeYear(int year) {
    if (_selectedYear == year) return;
    
    _fadeController.reverse().then((_) {
      setState(() => _selectedYear = year);
      _fadeController.forward();
      
      // 연도 교체 후 마지막으로 보던 상태(전체 또는 특정 달) 유지
      _focusOnMonth(_selectedMonth);
    });
  }

  void _focusOnMonth(int? month) {
    setState(() {
      _selectedMonth = month;
    });
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetMatrix = Matrix4.identity();

    if (month == null) {
      // 1. 전체 보기 (Overview) 모드
      const double targetScope = 2500.0; // 범위를 줄여 더 가깝게 (화면에 가득 차도록)
      final double initialScale = math.min(screenWidth, screenHeight) / targetScope;
      targetMatrix
        ..translate(
          screenWidth / 2 - _galaxyCenter * initialScale,
          screenHeight / 2 - _galaxyCenter * initialScale,
        )
        ..scale(initialScale);
    } else {
      // 2. 특정 월 상세 보기 모드
      final targetCenter = _getClusterCenter(month);
      const double targetScale = 0.7; // 별자리가 화면에 여유롭게 들어오는 최적의 스케일 (하향 조정)

      targetMatrix
        ..translate(
          screenWidth / 2 - targetCenter.dx * targetScale,
          screenHeight / 2 - targetCenter.dy * targetScale,
        )
        ..scale(targetScale);
    }

    _navAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _navAnimationController, 
      curve: Curves.easeInOutQuart,
    ));

    _navAnimationController.forward(from: 0);
  }

  Map<int, Map<int, List<DiaryEntry>>> _groupDiaries(List<DiaryEntry> diaries) {
    final Map<int, Map<int, List<DiaryEntry>>> grouped = {};
    for (var entry in diaries) {
      final year = entry.date.year;
      final month = entry.date.month;
      grouped.putIfAbsent(year, () => {});
      grouped[year]!.putIfAbsent(month, () => []);
      grouped[year]![month]!.add(entry);
    }
    return grouped;
  }

  Offset _getClusterCenter(int month) {
    final double angle = (month - 1) * (math.pi * 2 / 12) - (math.pi / 2);
    const double orbitRadius = 900.0; // 궤도 반경 축소 (1300 -> 900)
    return Offset(
      _galaxyCenter + math.cos(angle) * orbitRadius,
      _galaxyCenter + math.sin(angle) * orbitRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 패럴랙스 배경 및 심해 성운 효과
          ValueListenableBuilder<Matrix4>(
            valueListenable: _transformationController,
            builder: (context, matrix, child) {
              final translation = matrix.getTranslation();
              final currentScale = matrix.getMaxScaleOnAxis();
              return Stack(
                children: [
                   StarfieldBackground(
                    parallaxOffset: Offset(translation.x / _galaxySize, translation.y / _galaxySize),
                    child: child,
                  ),
                  // 추가 성운 및 먼지 레이어 (심도 강화)
                  DeepSpaceAmbience(
                    parallaxOffset: Offset(translation.x / _galaxySize, translation.y / _galaxySize),
                    scale: currentScale,
                  ),
                ],
              );
            },
          ),

          FutureBuilder<List<DiaryEntry>>(
            future: _diariesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 1));
              }

              final diaries = snapshot.data ?? [];
              if (diaries.isEmpty) return _buildEmptyState();

              final groupedDiaries = _groupDiaries(diaries);
              final availableYears = groupedDiaries.keys.toList()..sort((a, b) => b.compareTo(a));
              
              final currentYearData = groupedDiaries[_selectedYear] ?? {};

              return ValueListenableBuilder<Matrix4>(
                valueListenable: _transformationController,
                builder: (context, matrix, _) {
                  final currentScale = matrix.getMaxScaleOnAxis();
                  final double detailAlpha = ((currentScale - 0.25) / 0.35).clamp(0.0, 1.0);

                  return Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transformationController,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(3000.0),
                        minScale: 0.1,
                        maxScale: 4.0,
                        child: Container(
                          width: _galaxySize,
                          height: _galaxySize,
                          color: Colors.transparent,
                          child: FadeTransition(
                            opacity: _fadeController,
                            child: Stack(
                              children: [
                                _buildYearTitle(_selectedYear),
                                for (int month = 1; month <= 12; month++)
                                  _buildZodiacCluster(
                                    year: _selectedYear,
                                    month: month,
                                    entries: currentYearData[month] ?? [],
                                    detailAlpha: detailAlpha,
                                  ),
                                
                                _buildGalacticCore(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      _buildNavigators(availableYears),
                      if (_burstPosition != null) _buildBurstEffect(),
                    ],
                  );
                },
              );
            },
          ),

          if (_selectedEntry != null)
            DiaryDetailView(
              entry: _selectedEntry!,
              onBack: () => setState(() => _selectedEntry = null),
            ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).blur(begin: const Offset(10, 10), end: Offset.zero),
          
          _buildOverlayUI(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 중심의 희미한 빛
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 100, spreadRadius: 40)
              ],
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.white.withValues(alpha: 0.15)),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 3.seconds, curve: Curves.easeInOut),
          
          const SizedBox(height: 40),
          Text(
            '아직 은하에 별이 심어지지 않았습니다.',
            style: GoogleFonts.gowunBatang(color: Colors.white54, fontSize: 16, letterSpacing: 2),
          ).animate().fadeIn(delay: 400.ms, duration: 1.seconds),
          const SizedBox(height: 12),
          Text(
             '당신의 일상들을 조각해 이곳을 빛나는 성단으로 채워주세요.',
             style: GoogleFonts.gowunBatang(color: Colors.white24, fontSize: 12, letterSpacing: 1),
          ).animate().fadeIn(delay: 800.ms, duration: 1.seconds),
        ],
      ),
    );
  }

  Widget _buildNavigators(List<int> years) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 82 + bottomPadding, // 하단바에 더 밀착
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 연도 선택 미니 칩 (ERA Selector)
          GestureDetector(
            onTap: () {
              final next = (years.indexOf(_selectedYear) + 1) % years.length;
              _changeYear(years[next]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text('$_selectedYear ERA', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5)),
            ),
          ),
          const SizedBox(height: 8),
          // 2. 무한 루프 아치 휠
          _buildInfiniteArchedDial(),
        ],
      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
    );
  }

  Widget _buildInfiniteArchedDial() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      height: 130, // 160에서 130으로 높이 축소 (다이어트)
      width: screenWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 아치형 글래스 리본 배경 (슬림화)
          Positioned(
            bottom: 10,
            child: ClipPath(
              clipper: _ArchClipper(curvature: 0.0012),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: screenWidth,
                  height: 100, // 120에서 100으로 축소
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.02),
                        Colors.white.withValues(alpha: 0.002),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 2. 아치 상단 미세 광채 라인
          Positioned(
            bottom: 10,
            child: CustomPaint(
              size: Size(screenWidth, 100),
              painter: _ArchTopLinePainter(curvature: 0.0012),
            ),
          ),
          // 3. 커스텀 무한 아치 휠
          SizedBox(
            width: screenWidth, height: 130, // 160에서 130으로 축소
            child: _InfiniteArchedRotary(
              selectedMonth: _selectedMonth,
              onMonthSelected: _focusOnMonth,
            ),
          ),
          // 4. 센터 하이라이트 인디케이터
          Positioned(
            bottom: 82, // 높이 축소에 맞춰 하향 조정
            child: Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: AppColors.secondary,
                boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 3)],
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.5, 1.5), duration: 1500.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildYearTitle(int year) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Text(
            '$year',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.02),
              fontSize: 600,
              fontWeight: FontWeight.w900,
              letterSpacing: 80,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZodiacCluster({
    required int year,
    required int month,
    required List<DiaryEntry> entries,
    required double detailAlpha,
  }) {
    final clusterCenter = _getClusterCenter(month);
    final avgEmotionColor = _getAverageEmotionColor(entries);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    
    final Map<int, List<DiaryEntry>> dayMap = {};
    for (var entry in entries) {
      dayMap.putIfAbsent(entry.date.day, () => []).add(entry);
    }

    return Positioned(
      left: clusterCenter.dx - 300,
      top: clusterCenter.dy - 300,
      child: SizedBox(
        width: 600, height: 600,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 성운 (줌 인 할수록 배경으로 녹아듬)
            Opacity(
              opacity: (0.15 + (1.0 - detailAlpha) * 0.85).clamp(0.0, 1.0),
              child: _buildMonthNebula(month, avgEmotionColor, detailAlpha > 0.5),
            ),
            
            // 월 정보 (서서히 사라짐)
            Opacity(
              opacity: (1.0 - detailAlpha * 1.5).clamp(0.0, 1.0),
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$month', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.4), fontSize: 70, fontWeight: FontWeight.w100)),
                    Text(_getZodiacName(month), style: GoogleFonts.gowunBatang(color: Colors.white.withValues(alpha: 0.15), fontSize: 13, letterSpacing: 6)),
                  ],
                ),
              ),
            ),

            // 별자리 상세 정보 (서서히 나타남)
            Opacity(
              opacity: detailAlpha,
              child: Transform.scale(
                scale: 0.95 + (detailAlpha * 0.05), // 미세하게 커지는 다가감 연출
                child: RepaintBoundary(
                  child: _buildZodiacPainter(month, daysInMonth, dayMap, detailAlpha),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNebula(int month, Color color, bool isDetail) {
    return Container(
      width: isDetail ? 650 : 380,
      height: isDetail ? 650 : 380,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: isDetail ? 0.03 : 0.25),
            color.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 5.seconds, curve: Curves.easeInOut);
  }

  Widget _buildZodiacPainter(int month, int daysCount, Map<int, List<DiaryEntry>> dayMap, double alpha) {
    final zodiacPoints = ZodiacData.getZodiacPoints(month, daysCount, 550); // 포인트 범위 축소
    final zodiacLines = ZodiacData.getZodiacLines(month, zodiacPoints);

    return Stack(
      children: [
        CustomPaint(
          size: const Size(600, 600),
          painter: ZodiacLinePainter(points: zodiacPoints, lines: zodiacLines, alpha: alpha),
        ),
        
        for (int i = 0; i < zodiacPoints.length; i++)
          _buildDailyStar(month, i + 1, zodiacPoints[i], dayMap[i + 1], alpha),
      ],
    );
  }

  Widget _buildDailyStar(int month, int day, Offset pos, List<DiaryEntry>? entries, double alpha) {
    final bool hasEntry = entries != null && entries.isNotEmpty;
    final emotionColor = hasEntry ? Color(entries.first.emotionColorValue) : Colors.white12;
    
    // 조각 개수에 따른 시각적 차별화
    final int piecesCount = hasEntry ? entries.first.pieces.length : 0;
    final double starSizeBase = hasEntry ? (5 + (piecesCount * 0.8)).clamp(5.0, 12.0) : 1.5;
    final bool isMagical = piecesCount >= 3;

    return Positioned(
      left: pos.dx + 25 - 25, top: pos.dy + 25 - 25, // GestureDetector 영역 확보
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 투명한 컨테이너도 터치를 인식하도록 설정
        onTap: hasEntry ? () async {
          // 별빛 폭발 효과 트리거
          final clusterCenter = _getClusterCenter(month);
          final absoluteX = clusterCenter.dx - 300 + pos.dx + 25;
          final absoluteY = clusterCenter.dy - 300 + pos.dy + 25;
          
          setState(() {
            _burstPosition = Offset(absoluteX, absoluteY);
            _burstColor = emotionColor;
            _selectedEntry = entries.first;
          });

          // 효과 자동 제거
          Future.delayed(800.ms, () {
            if (mounted) setState(() => _burstPosition = null);
          });
        } : null,
        child: Container(
          width: 50, height: 50,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasEntry) ...[
                // 외곽 광채 (Glow)
                Container(
                  width: (starSizeBase * 3) * (0.4 + alpha * 0.6), 
                  height: (starSizeBase * 3) * (0.4 + alpha * 0.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: emotionColor.withValues(alpha: (isMagical ? 0.6 : 0.3) * alpha), 
                        blurRadius: (starSizeBase * 2.5) * alpha, 
                        spreadRadius: (isMagical ? 4 : 1) * alpha
                      ),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: (1500 + (day % 5) * 200).ms),
                
                // 마법 같은 반짝임 효과 (조각이 많은 별)
                if (isMagical)
                  Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.4 * alpha), size: 14)
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 3.seconds)
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 2.seconds, curve: Curves.easeInOut),
              ],
              
              // 별 본체
              Container(
                width: starSizeBase,
                height: starSizeBase,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: hasEntry ? Colors.white.withValues(alpha: alpha.clamp(0.4, 1.0)) : Colors.white24.withValues(alpha: alpha),
                  boxShadow: hasEntry ? [
                    BoxShadow(color: Colors.white, blurRadius: 4 * alpha)
                  ] : null,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(target: hasEntry ? 1 : 0).scale(begin: const Offset(0.0, 0.0), end: const Offset(1.0, 1.0), curve: Curves.elasticOut, duration: 800.ms);
  }

  Widget _buildGalacticCore() => Center(child: Container(width: 3200, height: 3200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.secondary.withValues(alpha: 0.04), Colors.transparent]))));

  Widget _buildBurstEffect() => Positioned(left: _burstPosition!.dx - 100, top: _burstPosition!.dy - 100, child: Container(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _burstColor?.withValues(alpha: 0.6) ?? Colors.white, width: 1.5))).animate().scale(begin: const Offset(0.1, 0.1), end: const Offset(2.8, 2.8), duration: 600.ms, curve: Curves.easeOutExpo).fadeOut()])));

  Widget _buildOverlayUI() {
    return Positioned(
      bottom: 40, right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _injectDummyData,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            elevation: 0,
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white60, size: 16),
            label: const Text('진실된 성계 300개 생성', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Text(
            '조각들의 은하 5.0',
            style: GoogleFonts.gowunBatang(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAverageEmotionColor(List<DiaryEntry> entries) {
    if (entries.isEmpty) return AppColors.secondary;
    return Color(entries.first.emotionColorValue);
  }

  String _getZodiacName(int month) {
    return [
      "염소자리", "물병자리", "물고기자리", "양자리", "황소자리", "쌍둥이자리",
      "게자리", "사자자리", "처녀자리", "천칭자리", "전갈자리", "궁수자리"
    ][month - 1];
  }

  Future<void> _injectDummyData() async {
    final repo = ref.read(diaryRepositoryProvider);
    final years = [2024, 2025, 2026];
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('실제 별자리 형상에 300개의 별을 수놓는 중...'), duration: Duration(seconds: 1)),
    );

    for (var year in years) {
      for (int i = 0; i < 100; i++) {
        final month = (i % 12) + 1;
        final day = (i % 28) + 1;
        final date = DateTime(year, month, day);
        
        final colorValue = [
          AppColors.starlightJoy.toARGB32(),
          AppColors.starlightSad.toARGB32(),
          AppColors.starlightCalm.toARGB32(), 
          AppColors.nebulaBlue.toARGB32(),
          AppColors.nebulaPurple.toARGB32()
        ][math.Random().nextInt(5)];

        final entry = DiaryEntry()
          ..uuid = "mass_$year\_$i"
          ..date = date
          ..emotionColorValue = colorValue
          ..pieces = [
            PieceSchema()
              ..content = "기억 $year.$month.$day"
              ..posX = 150.0..posY = 150.0..scale = 1.0..typeIndex = 0
              ..emotionColorValue = colorValue
          ]
          ..strokes = [];
        
        await repo.saveDiaryEntry(entry);
      }
    }
    
    if (mounted) {
      setState(() {}); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('은하가 완성되었습니다. 상단 연도 바를 눌러 시공간을 탐험하세요!')),
      );
    }
  }
}

/// 황도 12궁 좌표 및 로직
class ZodiacData {
  static List<Offset> getZodiacPoints(int month, int daysCount, double size) {
    // 황도 12궁 실제 형상에 더 가까운 정밀 노드 (정규화 0~1)
    final Map<int, List<Offset>> skeletons = {
      1: [Offset(0.2, 0.4), Offset(0.35, 0.7), Offset(0.7, 0.8), Offset(0.85, 0.5), Offset(0.6, 0.25), Offset(0.35, 0.3), Offset(0.2, 0.4)], // Capricorn (심장형)
      2: [Offset(0.1, 0.2), Offset(0.3, 0.3), Offset(0.25, 0.5), Offset(0.4, 0.7), Offset(0.6, 0.6), Offset(0.8, 0.8), Offset(0.9, 0.6)], // Aquarius (물결)
      3: [Offset(0.1, 0.2), Offset(0.4, 0.5), Offset(0.5, 0.8), Offset(0.3, 0.9), Offset(0.5, 0.8), Offset(0.8, 0.5), Offset(0.9, 0.1)], // Pisces (V자 끈)
      4: [Offset(0.15, 0.4), Offset(0.45, 0.3), Offset(0.75, 0.45), Offset(0.85, 0.7)], // Aries (단순 곡선)
      5: [Offset(0.1, 0.1), Offset(0.4, 0.35), Offset(0.5, 0.5), Offset(0.4, 0.8), Offset(0.5, 0.5), Offset(0.85, 0.3), Offset(0.9, 0.1)], // Taurus (뿔)
      6: [Offset(0.2, 0.2), Offset(0.25, 0.8), Offset(0.35, 0.8), Offset(0.3, 0.2), Offset(0.2, 0.2), Offset(0.6, 0.2), Offset(0.65, 0.8), Offset(0.75, 0.8), Offset(0.7, 0.2), Offset(0.6, 0.2)], // Gemini (쌍둥이)
      7: [Offset(0.5, 0.1), Offset(0.5, 0.45), Offset(0.25, 0.8), Offset(0.5, 0.45), Offset(0.75, 0.8)], // Cancer (ㅅ자)
      8: [Offset(0.85, 0.85), Offset(0.45, 0.85), Offset(0.25, 0.65), Offset(0.25, 0.35), Offset(0.45, 0.2), Offset(0.65, 0.3), Offset(0.45, 0.5)], // Leo (낫 모양)
      9: [Offset(0.15, 0.2), Offset(0.2, 0.6), Offset(0.45, 0.8), Offset(0.7, 0.6), Offset(0.7, 0.2), Offset(0.7, 0.6), Offset(0.9, 0.8)], // Virgo (Y자)
      10: [Offset(0.5, 0.15), Offset(0.2, 0.5), Offset(0.5, 0.8), Offset(0.8, 0.5), Offset(0.5, 0.15), Offset(0.2, 0.5)], // Libra (저울/다이아)
      11: [Offset(0.15, 0.15), Offset(0.25, 0.45), Offset(0.5, 0.6), Offset(0.75, 0.45), Offset(0.85, 0.25), Offset(0.75, 0.45), Offset(0.8, 0.7), Offset(0.65, 0.9), Offset(0.4, 0.8)], // Scorpio (전갈 꼬리)
      12: [Offset(0.2, 0.8), Offset(0.5, 0.15), Offset(0.8, 0.8), Offset(0.5, 0.4), Offset(0.5, 0.8)], // Sagittarius (화살)
    };

    final controlPoints = skeletons[month] ?? [Offset(0.5, 0.5)];
    final path = Path();
    path.moveTo(controlPoints[0].dx * size, controlPoints[0].dy * size);
    for (int i = 1; i < controlPoints.length; i++) {
       path.lineTo(controlPoints[i].dx * size, controlPoints[i].dy * size);
    }

    final List<Offset> points = [];
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return List.generate(daysCount, (_) => Offset(size/2, size/2));
    
    final totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);
    
    for (int i = 0; i < daysCount; i++) {
      final double distance = (i / (daysCount - 1)) * totalLength;
      double currentDist = 0;
      Offset targetPos = Offset(controlPoints.last.dx * size, controlPoints.last.dy * size);
      
      for (final metric in metrics) {
        if (currentDist + metric.length >= distance) {
          final tangent = metric.getTangentForOffset(distance - currentDist);
          if (tangent != null) {
            targetPos = tangent.position;
          }
          break;
        }
        currentDist += metric.length;
      }
      points.add(targetPos);
    }
    return points;
  }

  static List<int> getZodiacLines(int month, List<Offset> points) {
    return List.generate(points.length - 1, (index) => index);
  }
}

class ZodiacLinePainter extends CustomPainter {
  final List<Offset> points;
  final List<int> lines;
  final double alpha;
  ZodiacLinePainter({required this.points, required this.lines, required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 * alpha)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * alpha)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(points[0].dx + 25, points[0].dy + 25);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx + 25, points[i].dy + 25);
    }
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
    canvas.drawPath(path, guidePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 심해 성운 및 먼지 레이어 (공간 심도 강화)
class DeepSpaceAmbience extends StatelessWidget {
  final Offset parallaxOffset;
  final double scale;

  const DeepSpaceAmbience({
    super.key,
    required this.parallaxOffset,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 거대 성운 (Nebula Layers)
        Positioned.fill(
          child: RepaintBoundary(
            child: _NebulaLayer(parallaxOffset: parallaxOffset, scale: scale),
          ),
        ),
        // 2. 우주 먼지 (Dust Particles)
        Positioned.fill(
          child: RepaintBoundary(
            child: _DustLayer(parallaxOffset: parallaxOffset),
          ),
        ),
      ],
    );
  }
}

class _NebulaLayer extends StatelessWidget {
  final Offset parallaxOffset;
  final double scale;

  const _NebulaLayer({required this.parallaxOffset, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildNebula(
          context,
          color: AppColors.nebulaPurple.withValues(alpha: 0.08),
          alignment: const Alignment(-0.8, -0.6),
          size: 800 * scale,
          duration: 30.seconds,
          offsetMultiplier: 40,
        ),
        _buildNebula(
          context,
          color: AppColors.nebulaBlue.withValues(alpha: 0.06),
          alignment: const Alignment(0.7, 0.5),
          size: 1000 * scale,
          duration: 45.seconds,
          offsetMultiplier: 30,
        ),
      ],
    );
  }

  Widget _buildNebula(
    BuildContext context, {
    required Color color,
    required Alignment alignment,
    required double size,
    required Duration duration,
    required double offsetMultiplier,
  }) {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 100),
      alignment: Alignment(
        alignment.x + (parallaxOffset.dx * offsetMultiplier),
        alignment.y + (parallaxOffset.dy * offsetMultiplier),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.01), Colors.transparent],
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: duration, curve: Curves.easeInOut);
  }
}

class _DustLayer extends StatelessWidget {
  final Offset parallaxOffset;
  const _DustLayer({required this.parallaxOffset});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DustPainter(parallaxOffset: parallaxOffset),
    );
  }
}

class _DustPainter extends CustomPainter {
  final Offset parallaxOffset;
  _DustPainter({required this.parallaxOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // 시드 고정
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.15);

    for (int i = 0; i < 40; i++) {
      final xBase = random.nextDouble() * size.width;
      final yBase = random.nextDouble() * size.height;
      final depth = random.nextDouble() * 0.5 + 0.5;
      final dustSize = random.nextDouble() * 1.5 + 0.5;

      final dx = (xBase + parallaxOffset.dx * 150 * depth) % size.width;
      final dy = (yBase + parallaxOffset.dy * 150 * depth) % size.height;

      canvas.drawCircle(Offset(dx, dy), dustSize, paint);
      
      // 약간의 번짐 효과
      if (random.nextDouble() > 0.7) {
        canvas.drawCircle(
          Offset(dx, dy), 
          dustSize * 3, 
          Paint()..color = Colors.white.withValues(alpha: 0.03)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) => oldDelegate.parallaxOffset != parallaxOffset;
}

/// 아치형 글래스 영역을 위한 커스텀 클리퍼
class _ArchClipper extends CustomClipper<Path> {
  final double curvature;
  _ArchClipper({required this.curvature});

  @override
  Path getClip(Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double mid = w / 2;

    // 상단 아치 곡선 (y = curvature * x^2 기반)
    path.moveTo(0, h);
    for (double x = 0; x <= w; x += 1) {
      final double dx = x - mid;
      final double dy = curvature * (dx * dx);
      path.lineTo(x, dy);
    }
    path.lineTo(w, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

/// 아치 상단에 얇은 광채 라인을 그리는 페인터
class _ArchTopLinePainter extends CustomPainter {
  final double curvature;
  _ArchTopLinePainter({required this.curvature});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.15), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 10))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    final double w = size.width;
    final double mid = w / 2;

    for (double x = 0; x <= w; x += 1) {
      final double dx = x - mid;
      final double dy = curvature * (dx * dx);
      if (x == 0) path.moveTo(x, dy); else path.lineTo(x, dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfiniteArchedRotary extends StatefulWidget {
  final int? selectedMonth;
  final Function(int?) onMonthSelected;
  const _InfiniteArchedRotary({required this.selectedMonth, required this.onMonthSelected});

  @override
  State<_InfiniteArchedRotary> createState() => _InfiniteArchedRotaryState();
}

class _InfiniteArchedRotaryState extends State<_InfiniteArchedRotary> {
  late FixedExtentScrollController _controller;
  double _currentPixelOffset = 0.0;
  final double itemExtent = 100.0;
  
  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.selectedMonth ?? 0);
    _controller.addListener(() {
      if (mounted) setState(() => _currentPixelOffset = _controller.offset);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getAbbr(int i) => i == 0 ? 'ALL' : ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][i - 1];

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: -1,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: itemExtent,
        perspective: 0.00001, // 매우 평평하게 하여 Y축 커스텀 시뮬레이션
        diameterRatio: 10.0,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          final realIndex = index % 13;
          widget.onMonthSelected(realIndex == 0 ? null : realIndex);
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: List.generate(13, (i) {
            return RotatedBox(
              quarterTurns: 1,
              child: _ArchedItem(
                index: i,
                currentOffset: _currentPixelOffset,
                itemExtent: itemExtent,
                label: _getAbbr(i),
                isSelected: (i == 0 && widget.selectedMonth == null) || (widget.selectedMonth == i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ArchedItem extends StatelessWidget {
  final int index;
  final double currentOffset;
  final double itemExtent;
  final String label;
  final bool isSelected;

  const _ArchedItem({
    required this.index,
    required this.currentOffset,
    required this.itemExtent,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 무한 루프 상태에서의 실제 수평 거리 계산
    // ListWheelScrollView 내부에서 아이템은 index * itemExtent에 위치함
    // 하지만 Looping Delegate이므로 현재 오프셋 주변의 아이템만 고려
    double itemPos = index * itemExtent;
    double diff = itemPos - currentOffset;
    
    // 무한 루프이므로 가장 가까운 복제본 거리를 찾음
    final double totalWidth = 13 * itemExtent;
    while (diff > totalWidth / 2) diff -= totalWidth;
    while (diff < -totalWidth / 2) diff += totalWidth;

    // 2. 아치 궤적 수학 공식 (Rainbow Shape)
    // 곡률(Curvature)을 가파르게 조절하여 하단바와 조화로운 곡선 구현
    final double curvature = 0.0012; 
    final double yOffset = curvature * (diff * diff); 
// 포물선 공식: y = a * x^2 (아래로 내려감)
    
    // 3. 거리 기반 시각 효과
    final double opacity = (1.0 - (diff.abs() / (totalWidth / 2))).clamp(0.02, 1.0);
    final double scale = isSelected ? 1.0 : (1.0 - (diff.abs() / totalWidth)).clamp(0.6, 0.9);

    return Transform.translate(
      offset: Offset(0, yOffset), // 실제로는 RotatedBox 때문에 수직 스크롤러에서 Y축이 수평면의 수직(즉, 화면의 Y)이 됨
      child: Transform.rotate(
        angle: diff * 0.0005, // 곡선 궤적에 맞춰 글자 살짝 비틀기
        child: AnimatedScale(
          duration: 300.ms,
          scale: scale,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? AppColors.secondary : Colors.white.withValues(alpha: opacity * 0.2),
                fontSize: 24,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w200,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
