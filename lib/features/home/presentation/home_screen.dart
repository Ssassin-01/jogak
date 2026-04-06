import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jogak/core/theme/app_colors.dart';
import 'package:jogak/core/widgets/water_ripple_background.dart';
import 'package:jogak/features/diary/presentation/diary_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: WaterRippleBackground(
        child: Stack(
          children: [
            // 중앙 감성 텍스트 (Poetic Greeting)
            Center(
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
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '어떤 색인가요?',
                    style: GoogleFonts.nanumPenScript(
                      fontSize: 32,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 하단 조각(Archive)으로 이동하는 버튼 (은은한 텍스트)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: TextButton(
                onPressed: () {
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
              ),
            ),

            // 하단 기록 시작 버튼 (Water-drop Gate)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO: 일기 쓰기 화면으로 이동
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.4),
                          AppColors.primary.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface.withValues(alpha: 0.8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
