import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/starfield_background.dart';
// import 'package:jogak/core/services/audio_service.dart';
import 'package:jogak/features/diary/domain/models/diary_piece.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jogak/core/providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Offset _parallaxOffset = Offset.zero;
  String? _activeSnippet; // 파편 터치 시 보여줄 일기 내용

  @override
  void initState() {
    super.initState();
    // _startBgm(); // 로그 제거를 위해 주석 처리
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
    final isNebulaEnabled = ref.watch(nebulaEnabledProvider);

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
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: Offset.zero, end: _parallaxOffset),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, smoothedOffset, child) {
            return StarfieldBackground(
              parallaxOffset: smoothedOffset,
              child: Stack(
                children: [
                  // 우주 공간 속 별(기억의 파편) 레이어
                  ...mockDiaryPieces.asMap().entries.map((entry) {
                    final index = entry.key;
                    final piece = entry.value;
                    return MemoryShard(
                      piece: piece,
                      index: index,
                      onTap: () => _showSnippet(piece.content),
                    );
                  }),

                  // 활성화된 별의 텍스트 레이어
                  if (_activeSnippet != null)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.background.withValues(alpha: 0.8),
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
                              fontSize: 20, 
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2.0,
                              height: 1.6,
                              shadows: [
                                Shadow(
                                  color: AppColors.secondary.withValues(alpha: 0.5),
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

                  // 중앙 감성 텍스트 (Space Greeting)
                  Center(
                    child: Transform.translate(
                      offset: Offset(
                        smoothedOffset.dx * 40,
                        smoothedOffset.dy * 40,
                      ),
                      child: Opacity(
                        opacity: _activeSnippet == null ? 1.0 : 0.2, 
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '오늘 당신의 우주는',
                              style: GoogleFonts.nanumPenScript(
                                fontSize: 28,
                                color: AppColors.textPrimary.withValues(alpha: 0.7),
                                letterSpacing: 1.2,
                              ),
                            ).animate().fadeIn(duration: 1200.ms).slideY(begin: 0.2),
                            const SizedBox(height: 8),
                            Text(
                              '어떤 성좌를 그리나요?',
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

                  // 좌측 상단 발열 제어 토글 (전역 설정)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 20,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(nebulaEnabledProvider.notifier).state = !isNebulaEnabled;
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNebulaEnabled ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded,
                              color: isNebulaEnabled ? AppColors.nebulaBlue : Colors.white38,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isNebulaEnabled ? 'Nebula On' : 'Power Saving',
                              style: GoogleFonts.gowunBatang(
                                color: isNebulaEnabled ? Colors.white70 : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1.seconds),
                ],
              ),
            );
          },
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
    final randomX = ((index * 137) % 300) + 50.0;
    final randomY = ((index * 191) % 400) + 150.0;
    
    return Positioned(
      left: randomX,
      top: randomY,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
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
              
              const SizedBox.shrink()
                .animate(target: piece.content.hashCode.toDouble()) 
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
