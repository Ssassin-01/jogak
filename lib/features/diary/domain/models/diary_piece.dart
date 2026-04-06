import 'package:flutter/material.dart';

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
    content: '어제의 노을은 유난히 따뜻했다. 당신도 보았을까?',
    date: DateTime.now().subtract(const Duration(days: 1)),
    emotionColor: const Color(0xFFF1E4C3), // warm
  ),
  DiaryPiece(
    id: '2',
    content: '빗방울이 호수 위로 떨어지는 소리가 음악처럼 들려.',
    date: DateTime.now().subtract(const Duration(days: 3)),
    emotionColor: const Color(0xFF30628A), // calm/blue
  ),
  DiaryPiece(
    id: '3',
    content: '마음 한구석에 남은 보랏빛 기억을 선명하게 기록해두고 싶어.',
    date: DateTime.now().subtract(const Duration(days: 5)),
    emotionColor: const Color(0xFF342A5E), // misty purple
  ),
  DiaryPiece(
    id: '4',
    content: '조각조각 흩어진 생각들이 모여 나를 만든다.',
    date: DateTime.now().subtract(const Duration(days: 7)),
    emotionColor: const Color(0xFFC0C0C0), // silver
  ),
];
