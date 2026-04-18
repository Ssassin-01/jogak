import 'package:flutter/material.dart';
import 'package:jogak/core/theme/app_colors.dart';

class DiaryPiece {
  final String id;
  final String content;
  final DateTime date;
  final Color emotionColor;

  DiaryPiece({
    required this.id,
    required this.content,
    required this.date,
    required this.emotionColor,
  });
}

// 초기 테스트용 임시 데이터
final List<DiaryPiece> mockDiaryPieces = [
  DiaryPiece(
    id: '1',
    content: '어제의 초신성은 유난히 따뜻했다. 당신도 보았을까?',
    date: DateTime.now().subtract(const Duration(days: 1)),
    emotionColor: AppColors.starlightJoy, 
  ),
  DiaryPiece(
    id: '2',
    content: '성운 사이를 유영하는 기분이야. 고요함이 마음을 채운다.',
    date: DateTime.now().subtract(const Duration(days: 3)),
    emotionColor: AppColors.starlightCalm,
  ),
  DiaryPiece(
    id: '3',
    content: '마음 한구석에 남은 보랏빛 기억을 성좌로 기록해두고 싶어.',
    date: DateTime.now().subtract(const Duration(days: 5)),
    emotionColor: AppColors.starlightExcited,
  ),
  DiaryPiece(
    id: '4',
    content: '조각조각 흩어진 생각들이 모여 하나의 별자리를 만든다.',
    date: DateTime.now().subtract(const Duration(days: 7)),
    emotionColor: AppColors.starlightSad,
  ),
];
