import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jogak/features/diary/data/models/diary_schema.dart';
import 'package:jogak/features/diary/presentation/diary_canvas_screen.dart'; // For CanvasPieceType index check

class DiaryDetailView extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onBack;

  const DiaryDetailView({
    super.key,
    required this.entry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 드로잉 레이어
          CustomPaint(
            painter: StaticDrawingPainter(strokes: entry.strokes),
          ),

          // 2. 조각 레이어
          ...entry.pieces.map((piece) => _buildStaticPiece(piece)),

          // 3. UI 조작 레이어
          Positioned(
            top: 60,
            left: 20,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
            ),
          ),
          
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "${entry.date.year}년 ${entry.date.month}월 ${entry.date.day}일",
                  style: GoogleFonts.gowunBatang(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Color(entry.emotionColorValue),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticPiece(PieceSchema piece) {
    return Positioned(
      left: piece.posX - 140,
      top: piece.posY - 120,
      child: Transform.scale(
        scale: piece.scale,
        child: Container(
          width: 280,
          height: 240,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(280, 240),
                painter: StarlightShardPainter(
                  seed: piece.content.hashCode, // Use content hash as seed
                  glowColor: piece.emotionColorValue != null 
                      ? Color(piece.emotionColorValue!) 
                      : const Color(0xFF64B5F6),
                ),
              ),
              if (piece.typeIndex == CanvasPieceType.text.index)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(35.0),
                    child: Center(
                      child: Text(
                        piece.content,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.gowunBatang(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                )
              else if (piece.typeIndex == CanvasPieceType.photo.index)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(piece.content, width: 220, height: 180, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StaticDrawingPainter extends CustomPainter {
  final List<StrokeSchema> strokes;

  StaticDrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length < 2) continue;

      final path = Path();
      // Flattened [x1, y1, x2, y2, ...] handling
      for (int i = 0; i < stroke.points.length - 1; i += 2) {
        final x = stroke.points[i];
        final y = stroke.points[i+1];
        
        if (x == -1.0 && y == -1.0) continue; // Skip separator
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
