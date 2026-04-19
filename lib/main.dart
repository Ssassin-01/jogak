import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jogak/core/theme/app_theme.dart';
import 'package:jogak/features/diary/data/repositories/diary_repository.dart';
import 'package:jogak/features/home/presentation/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Isar 초기화
  final isar = await DiaryRepository.init();
  
  runApp(
    ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(DiaryRepository(isar)),
      ],
      child: const JogakApp(),
    ),
  );
}

class JogakApp extends StatelessWidget {
  const JogakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '조각',
      theme: AppTheme.dark,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
