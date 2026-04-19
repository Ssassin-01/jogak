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
  bool _isNavExpanded = false;

  late AnimationController _fadeController;
  late AnimationController _navAnimationController;
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

    _transformationController.addListener(_onTransformationChanged);
    
    _diariesFuture = ref.read(diaryRepositoryProvider).getAllDiaries(); // 초기 1회만 로드
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusOnMonth(_selectedMonth);
    });
  }

  void _onTransformationChanged() {
    // 스텔스 모드 삭제: 더 이상 내비게이션 투명도를 조절하지 않음
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _fadeController.dispose();
    _navAnimationController.dispose();
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
    // build 내에서 Future를 생성하지 않음

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
                                
                                // 4. 별빛 폭발 효과 레이어 (갤럭시 내부 좌표계)
                                if (_burstPosition != null)
                                   _buildBurstEffect(),

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
            ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).blur(begin: const Offset(10, 10), end: Offset.zero),
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
          
          const SizedBox(height: 60),
          FloatingActionButton.extended(
            onPressed: _injectDummyData, 
            elevation: 0,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            label: Text(
              '3개년 진실된 성계 생성', 
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: 1)
            ),
          ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.2, end: 0),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              // 1. 성좌의 인장 (Stellar Seal) - 더욱 화려하게
              GestureDetector(
                onTap: () => setState(() => _isNavExpanded = !_isNavExpanded),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [Colors.white10, AppColors.secondary.withValues(alpha: 0.3), Colors.white10],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(color: AppColors.secondary.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_selectedYear',
                                  style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w200, fontSize: 10, letterSpacing: 3),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _getAbbrMonth(_selectedMonth),
                                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 2),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      _isNavExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                      color: Colors.white24,
                                      size: 18,
                                    )
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              width: 1, height: 20, color: Colors.white10,
                            ),
                            Icon(Icons.auto_awesome_rounded, color: AppColors.secondary.withValues(alpha: 0.5), size: 16)
                              .animate(onPlay: (c) => c.repeat()).rotate(duration: 5.seconds),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate(target: _isNavExpanded ? 1 : 0).shimmer(duration: 2.seconds),

              // 2. 천체 확장 지도 (Celestial Expansion)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _buildExpandedMenu(years),
                crossFadeState: _isNavExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: 500.ms,
                sizeCurve: Curves.easeOutBack,
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildExpandedMenu(List<int> years) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 30, right: 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 0)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // 1. 연도 선택기 (Orbital Years)
                Row(
                  children: [
                    Text('ERA', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, letterSpacing: 4)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: years.map((y) => _buildYearChip(y)).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                // 2. 월 선택 그리드 (Star Map Grid)
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildMonthChip(null),
                    ...List.generate(12, (i) => _buildMonthChip(i + 1)),
                  ],
                ),
                const SizedBox(height: 20),
                // 3. Galactic Summary (감정 분포 요약) - Step 4
                _buildGalacticSummary(),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOutBack);
  }

  Widget _buildGalacticSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: AppColors.secondary.withValues(alpha: 0.4), size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GALACTIC RESONANCE', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
                const SizedBox(height: 4),
                // 추상적 막대 그래프 (Emotion Dist)
                Row(
                  children: [
                    _buildSummaryBar(AppColors.starlightJoy, 0.4),
                    _buildSummaryBar(AppColors.starlightCalm, 0.25),
                    _buildSummaryBar(AppColors.starlightSad, 0.15),
                    _buildSummaryBar(AppColors.nebulaPurple, 0.2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(Color color, double flex) {
     return Expanded(
       flex: (flex * 100).toInt(),
       child: Container(
         height: 3,
         margin: const EdgeInsets.symmetric(horizontal: 1),
         decoration: BoxDecoration(
           color: color.withValues(alpha: 0.6),
           borderRadius: BorderRadius.circular(2),
           boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)],
         ),
       ),
     );
  }

  Widget _buildYearChip(int year) {
    final isSelected = _selectedYear == year;
    return GestureDetector(
      onTap: () => _changeYear(year),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white10 : Colors.transparent),
        ),
        child: Text(
          '$year',
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.white24,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w200,
            fontSize: 15,
            letterSpacing: 1,
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
        duration: 400.ms,
        curve: Curves.easeOutBack,
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.secondary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: isSelected ? AppColors.secondary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
          boxShadow: isSelected ? [
            BoxShadow(color: AppColors.secondary.withValues(alpha: 0.15), blurRadius: 10)
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              month == null ? 'ALL' : '$month',
              style: GoogleFonts.outfit(
                color: isSelected ? AppColors.secondary : Colors.white38,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: month == null ? 10 : 16,
              ),
            ),
            if (isSelected && month != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary),
              ).animate().scale(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildBurstEffect() {
    return Positioned(
      left: _burstPosition!.dx - 100,
      top: _burstPosition!.dy - 100,
      child: Container(
        width: 200, height: 200,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 충격파
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: (_burstColor ?? Colors.white).withValues(alpha: 0.5), width: 2),
              ),
            ).animate().scale(begin: const Offset(0.1, 0.1), end: const Offset(2.0, 2.0), duration: 600.ms, curve: Curves.easeOutQuart).fadeOut(),
            
            // 빛의 조각들
            for (int i = 0; i < 8; i++)
              Transform.rotate(
                angle: i * (math.pi * 2 / 8),
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    width: 2, height: 15,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ).animate().moveY(begin: 0, end: -60, duration: 500.ms, curve: Curves.easeOutCubic).fadeOut(),
          ],
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
