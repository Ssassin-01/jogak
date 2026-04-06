import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/water_ripple_background.dart';
import 'package:jogak/core/services/audio_service.dart';
import 'package:jogak/features/diary/domain/models/diary_piece.dart';
import 'package:jogak/features/diary/presentation/diary_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Offset _parallaxOffset = Offset.zero;
  String? _activeSnippet; // 파편 터치 시 보여줄 일기 내용

  @override
  void initState() {
    super.initState();
    _startBgm();
  }

  void _startBgm() async {
    await AudioService().playBgm();
  }

  void _showSnippet(String content) {
    setState(() => _activeSnippet = content);
    HapticFeedback.mediumImpact();
    
    // 3초 후 텍스트 사라짐
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _activeSnippet = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _parallaxOffset = Offset(
              (event.localPosition.dx / MediaQuery.of(context).size.width) - 0.5,
              (event.localPosition.dy / MediaQuery.of(context).size.height) - 0.5,
            );
          });
        },
        child: WaterRippleBackground(
          child: Stack(
            children: [
              // 수면 위 기억의 파편 레이어
              ...mockDiaryPieces.asMap().entries.map((entry) {
                final index = entry.key;
                final piece = entry.value;
                return MemoryShard(
                  piece: piece,
                  index: index,
                  onTap: () => _showSnippet(piece.content),
                );
              }),

              // 활성화된 파편의 텍스트 레이어
              if (_activeSnippet != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.background.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Center(
                      child: Text(
                        _activeSnippet!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.gowunBatang(
                          fontSize: 20, // 가소성 위해 폰트 크기 살짝 키움
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2.0,
                          height: 1.6,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ).animate()
                        .fadeIn(duration: 1200.ms)
                        .blur(begin: const Offset(15.0, 15.0), end: Offset.zero, duration: 1500.ms)
                        .moveY(begin: 10, end: 0, duration: 2000.ms, curve: Curves.easeOutBack)
                        .then(delay: 2000.ms)
                        .fadeOut(duration: 800.ms),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms),

              // 중앙 감성 텍스트 (Poetic Greeting with Parallax)
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(
                    _parallaxOffset.dx * 30,
                    _parallaxOffset.dy * 30,
                    0,
                  ),
                  child: Opacity(
                    opacity: _activeSnippet == null ? 1.0 : 0.2, // 텍스트 출력 시 투명도 조절
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '오늘 당신의 호수는',
                          style: GoogleFonts.nanumPenScript(
                            fontSize: 28,
                            color: AppColors.textPrimary.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                          ),
                        ).animate().fadeIn(duration: 1200.ms).slideY(begin: 0.2),
                        const SizedBox(height: 8),
                        Text(
                          '어떤 색인가요?',
                          style: GoogleFonts.nanumPenScript(
                            fontSize: 34,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: AppColors.secondary.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 600.ms, duration: 1200.ms).scale(begin: const Offset(0.95, 0.95)),
                      ],
                    ),
                  ),
                ),
              ),
              
              // 하단 조각(Archive)으로 이동하는 버튼
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 20,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiaryListScreen()),
                    );
                  },
                  child: Text(
                    '기억의 바다',
                    style: GoogleFonts.gowunBatang(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ).animate().fadeIn(delay: 1500.ms),
              ),

              // 하단 추상적 기록 시작 버튼 (Emotional Breath-Floating Gate)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      // TODO: 일기 쓰기 화면으로 이동
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 호흡하는 후광 효과 (Breathing Aura)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.5, 1.5), duration: 2500.ms)
                          .fadeOut(duration: 2500.ms),
                        
                        // 추상적 메인 오브젝트 (Liquid-like Glass)
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface.withValues(alpha: 0.2),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: const Icon(
                              Icons.add_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .shimmer(duration: 3.seconds, color: AppColors.secondary.withValues(alpha: 0.3)),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .moveY(begin: -5, end: 5, duration: 2000.ms, curve: Curves.easeInOut),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryShard extends StatelessWidget {
  final DiaryPiece piece;
  final int index;
  final VoidCallback onTap;

  const MemoryShard({
    super.key,
    required this.piece,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 호수 위에 무작위하게 배치 (간단한 수식을 이용한 분포)
    final randomX = ((index * 137) % 300) + 50.0;
    final randomY = ((index * 191) % 400) + 150.0;
    
    return Positioned(
      left: randomX,
      top: randomY,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque, // 터치 영역 확장 시 투명 영역도 클릭 되도록 설정
        child: Container(
          width: 50, // 터치 인식 범위 확대 (기존 8 -> 50)
          height: 50,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 별의 외형 (실제 보이는 모습은 유지)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: piece.emotionColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: piece.emotionColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: (2000 + index * 200).ms)
                .shimmer(duration: 3000.ms),
              
              // 터치 시 일시적인 '플래시' 효과 레이어 (반응성 강화)
              const SizedBox.shrink()
                .animate(target: piece.content.hashCode.toDouble()) // 어떤 방식으로든 상태 변화 시 트리거
                .toggle(builder: (_, value, child) => child)
                .custom(
                  duration: 500.ms,
                  builder: (context, value, child) => Container(
                    width: 30 * value,
                    height: 30 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece.emotionColor.withValues(alpha: 0.3 * (1 - value)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ).animate().moveY(begin: -5, end: 5, duration: 2500.ms, curve: Curves.easeInOutSine),
    );
  }
}
