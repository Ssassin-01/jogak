import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jogak/core/theme/app_colors.dart';

class DiaryListScreen extends StatelessWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('별의 기록'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDiaryItem(
            title: '낙성대 산책로의 봄',
            date: '2024년 4월 2일',
            mood: 'happy',
            content: '오늘 날씨가 너무 좋아서 산책을 나갔다. 꽃들이 고개 내미는 모습이 정말 아름다웠다.',
          ),
          const SizedBox(height: 16),
          // 시간 잠금 (Time-lock) 샘플
          _buildLockedItem(
            title: '나의 미래에게',
            lockInfo: '2025년 1월 1일 공개',
            isTimeLock: true,
          ),
          const SizedBox(height: 16),
          // 장소 잠금 (Geo-lock) 샘플
          _buildLockedItem(
            title: '그곳에서의 기억',
            lockInfo: '근처 300m 이내 접근 시 공개',
            isTimeLock: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildDiaryItem({
    required String title,
    required String date,
    required String mood,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildMoodCharacter(mood),
              ],
            ),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, 
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedItem({
    required String title,
    required String lockInfo,
    required bool isTimeLock,
  }) {
    return Stack(
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Opacity(
                opacity: 0.05,
                child: Text('여기에 아주 소중한 기억이 담겨 있습니다. 잠금이 해제되면 내용을 확인하실 수 있습니다.'),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: AppColors.surface.withValues(alpha: 0.3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isTimeLock ? Icons.timer_outlined : Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(lockInfo, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodCharacter(String mood) {
    Color color;
    switch (mood) {
      case 'happy': color = AppColors.starlightJoy; break;
      case 'sad': color = AppColors.starlightSad; break;
      case 'calm': color = AppColors.starlightCalm; break;
      default: color = AppColors.primary;
    }
    
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
