import 'package:flutter/material.dart';
import 'package:jogak/core/widgets/orbital_navbar.dart';
import 'package:jogak/features/home/presentation/home_screen.dart';
import 'package:jogak/features/diary/presentation/diary_list_screen.dart';
import 'package:jogak/features/diary/presentation/diary_canvas_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SizedBox.shrink(), // Placeholder for center button action
    const DiaryListScreen(),
  ];

  void _onTap(int index) {
    if (index == 1) {
      // Navigate to Canvas Screen (Fullscreen)
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DiaryCanvasScreen()),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: OrbitalNavbar(
              currentIndex: _currentIndex,
              onTap: _onTap,
            ),
          ),
        ],
      ),
    );
  }
}
