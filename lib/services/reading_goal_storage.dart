import 'package:shared_preferences/shared_preferences.dart';

// [형호]
/// 로그인/서버 연동 전까지 독서 목표 권수를 기기에 저장.
/// 서버 연동 후에는 사용자 프로필의 target_book_count 필드로 옮길 수 있음.
class ReadingGoalStorage {
  ReadingGoalStorage._();

  static final ReadingGoalStorage instance = ReadingGoalStorage._();
  static const String _targetBookCountKey = 'barobook.targetBookCount.v1';

  /// 설정하지 않은 상태는 0으로 반환함.
  Future<int> loadTargetBookCount() async {
    final preferences = await SharedPreferences.getInstance();
    final count = preferences.getInt(_targetBookCountKey) ?? 0;
    return count > 0 ? count : 0;
  }

  /// 목표는 1권 이상이어야 함. 0 이하 값은 저장하지 않음.
  Future<void> saveTargetBookCount(int count) async {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', '목표 권수는 1 이상이어야 합니다.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_targetBookCountKey, count);
  }
}
