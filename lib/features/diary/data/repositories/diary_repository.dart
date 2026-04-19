import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:jogak/features/diary/data/models/diary_schema.dart';
import 'package:path_provider/path_provider.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  throw UnimplementedError('Isar has not been initialized');
});

class DiaryRepository {
  final Isar isar;

  DiaryRepository(this.isar);

  static Future<Isar> init() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [DiaryEntrySchema],
      directory: dir.path,
    );
  }

  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    await isar.writeTxn(() async {
      await isar.diaryEntrys.put(entry);
    });
  }

  Future<List<DiaryEntry>> getAllDiaries() async {
    return await isar.diaryEntrys.where().sortByDateDesc().findAll();
  }

  Future<void> deleteDiary(int id) async {
    await isar.writeTxn(() async {
      await isar.diaryEntrys.delete(id);
    });
  }
}
