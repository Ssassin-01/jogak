import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jogak/core/theme/app_colors.dart';

class OrbitalNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const OrbitalNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return SizedBox(
      height: 100 + bottomPadding,
      width: double.infinity,
      child: Stack(
        children: [
          // 1. Arch Background with Glassmorphism
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 100 + bottomPadding),
              painter: OrbitalArchPainter(),
            ),
          ),
          
          // 2. Navigation Items
          Positioned(
            bottom: bottomPadding + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.auto_awesome_outlined, '성좌'),
                _buildNavItem(1, Icons.add_circle_outline_rounded, '기록', isCenter: true),
                _buildNavItem(2, Icons.library_books_outlined, '은하'),
              ],
            ),
          ),
          
          // 3. Selection Indicator (The Moon)
          _buildSelectionIndicator(context, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isCenter = false}) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.5),
              size: isCenter ? 32 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(BuildContext context, double bottomPadding) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width / 3;
    final targetX = (currentIndex * itemWidth) + (itemWidth / 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      left: targetX - 5,
      bottom: bottomPadding + 70, // Positioned above the icon
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.8),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class OrbitalArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Arch parameters
    final sideY = 40.0;

    path.moveTo(0, sideY);
    path.quadraticBezierTo(size.width / 2, -20, size.width, sideY);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Backdrop filter simulation (actual blur handled by widget if needed, but here we just paint)
    canvas.drawPath(path, paint);

    // Subtle edge light
    final lightPath = Path();
    lightPath.moveTo(0, sideY);
    lightPath.quadraticBezierTo(size.width / 2, -20, size.width, sideY);
    
    canvas.drawPath(
      lightPath,
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
