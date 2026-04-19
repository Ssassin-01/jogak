import 'package:isar/isar.dart';

part 'diary_schema.g.dart';

@collection
class DiaryEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  late DateTime date;

  late int emotionColorValue;

  late List<PieceSchema> pieces;

  late List<StrokeSchema> strokes;

  String? constellationId;
}

@embedded
class PieceSchema {
  late int typeIndex; // CanvasPieceType index
  late String content;
  late double posX;
  late double posY;
  late double scale;
  int? emotionColorValue;
}

@embedded
class StrokeSchema {
  late List<double> points; // Flattened [x1, y1, x2, y2, ...]
  late int colorValue;
  late double width;
}
