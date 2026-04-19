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
  
  static const double _galaxySize = 4000.0; // 연도들이 중첩되므로 지도 크기를 적정 수준으로 조정
  static const double _galaxyCenter = _galaxySize / 2;
  
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  bool _isNavExpanded = false;
  double _navOpacity = 1.0;
  Timer? _navHideTimer;

  late AnimationController _fadeController;
  late AnimationController _navAnimationController;
  Animation<Matrix4>? _navAnimation;

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

    _transformationController.addListener(_onTransformationChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusOnMonth(_selectedMonth);
    });
  }

  void _onTransformationChanged() {
    if (_navOpacity > 0 && !_isNavExpanded) {
      setState(() => _navOpacity = 0.0);
    }
    _navHideTimer?.cancel();
    _navHideTimer = Timer(1500.ms, () {
      if (mounted) setState(() => _navOpacity = 1.0);
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _fadeController.dispose();
    _navAnimationController.dispose();
    _navHideTimer?.cancel();
    super.dispose();
  }

  String _getAbbrMonth(int? month) {
    if (month == null) return 'ALL';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
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
      _isNavExpanded = false; // 선택 시 자동 축소
    });
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetMatrix = Matrix4.identity();

    if (month == null) {
      // 1. 전체 보기 (Overview) 모드
      const double targetScope = 3200.0;
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
    const double orbitRadius = 1300.0;
    return Offset(
      _galaxyCenter + math.cos(angle) * orbitRadius,
      _galaxyCenter + math.sin(angle) * orbitRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final diariesFuture = ref.watch(diaryRepositoryProvider).getAllDiaries();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 패럴랙스 배경
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

          FutureBuilder<List<DiaryEntry>>(
            future: diariesFuture,
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
                    ],
                  );
                },
              );
            },
          ),

          _buildOverlayUI(),

          if (_selectedEntry != null)
            DiaryDetailView(
              entry: _selectedEntry!,
              onBack: () => setState(() => _selectedEntry = null),
            ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.white24),
          const SizedBox(height: 20),
          Text('은하가 비어있습나다. 3개년 데이터를 생성해보세요.', style: GoogleFonts.gowunBatang(color: Colors.white38)),
          const SizedBox(height: 40),
          FloatingActionButton.extended(
            onPressed: () {}, 
            backgroundColor: Colors.white10,
            label: const Text('3개년 진실된 성계 생성', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigators(List<int> years) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: _navOpacity,
          duration: 500.ms,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 성좌의 인장 캡슐 (Stellar Seal)
              GestureDetector(
                onTap: () => setState(() => _isNavExpanded = !_isNavExpanded),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_selectedYear',
                            style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.w200, fontSize: 13, letterSpacing: 2),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('✦', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
                          ),
                          Text(
                            _getAbbrMonth(_selectedMonth),
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 2),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isNavExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white24,
                            size: 16,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate(target: _isNavExpanded ? 1 : 0).shimmer(duration: 2.seconds),

              // 2. 확장 메뉴 (Blooming Expansion)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _buildExpandedMenu(years),
                crossFadeState: _isNavExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: 400.ms,
                sizeCurve: Curves.easeOutQuart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedMenu(List<int> years) {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 30, right: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // 연도 스크롤
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: years.map((y) => _buildYearChip(y)).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10, height: 1),
          ),
          // 월 그리드
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildMonthChip(null),
              ...List.generate(12, (i) => _buildMonthChip(i + 1)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildYearChip(int year) {
    final isSelected = _selectedYear == year;
    return GestureDetector(
      onTap: () => _changeYear(year),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$year',
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.white24,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w200,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthChip(int? month) {
    final isSelected = _selectedMonth == month;
    return GestureDetector(
      onTap: () => _focusOnMonth(month),
      child: AnimatedContainer(
        duration: 300.ms,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.transparent),
        ),
        child: Text(
          month == null ? 'ALL' : '$month',
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: month == null ? 10 : 14,
            letterSpacing: month == null ? 1 : 0,
          ),
        ),
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
      left: clusterCenter.dx - 450,
      top: clusterCenter.dy - 450,
      child: SizedBox(
        width: 900, height: 900,
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
    final zodiacPoints = ZodiacData.getZodiacPoints(month, daysCount, 850);
    final zodiacLines = ZodiacData.getZodiacLines(month, zodiacPoints);

    return Stack(
      children: [
        CustomPaint(
          size: const Size(900, 900),
          painter: ZodiacLinePainter(points: zodiacPoints, lines: zodiacLines, alpha: alpha),
        ),
        
        for (int i = 0; i < zodiacPoints.length; i++)
          _buildDailyStar(i + 1, zodiacPoints[i], dayMap[i + 1], alpha),
      ],
    );
  }

  Widget _buildDailyStar(int day, Offset pos, List<DiaryEntry>? entries, double alpha) {
    final bool hasEntry = entries != null && entries.isNotEmpty;
    final emotionColor = hasEntry ? Color(entries.first.emotionColorValue) : Colors.white12;
    final isMultiple = hasEntry && entries.length > 1;

    return Positioned(
      left: pos.dx + 25, top: pos.dy + 25,
      child: GestureDetector(
        onTap: hasEntry ? () => setState(() => _selectedEntry = entries.first) : null,
        child: Container(
          width: 50, height: 50,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasEntry)
                Container(
                  width: (isMultiple ? 14 : 9) * (0.5 + alpha * 0.5), 
                  height: (isMultiple ? 14 : 9) * (0.5 + alpha * 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: emotionColor.withValues(alpha: 0.5 * alpha), 
                        blurRadius: (isMultiple ? 18 : 10) * alpha, 
                        spreadRadius: (isMultiple ? 5 : 2) * alpha
                      ),
                    ],
                  ),
                ),
              
              Container(
                width: hasEntry ? (isMultiple ? 7 : 5) : 1.5,
                height: hasEntry ? (isMultiple ? 7 : 5) : 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: hasEntry ? Colors.white.withValues(alpha: alpha.clamp(0.2, 1.0)) : Colors.white24.withValues(alpha: alpha)
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(target: hasEntry ? 1 : 0).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2));
  }

  Widget _buildGalacticCore() {
    return Center(
      child: Container(
        width: 2500, height: 2500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

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
      path.lineTo(points[i].dx + 50, points[i].dy + 50);
    }
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
    canvas.drawPath(path, guidePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
