import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jogak/core/theme/app_theme.dart';
import 'package:jogak/features/home/presentation/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: JogakApp(),
    ),
  );
}

class JogakApp extends StatelessWidget {
  const JogakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오늘의 조각',
      theme: AppTheme.dark,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
