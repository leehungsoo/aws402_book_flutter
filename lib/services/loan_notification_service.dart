import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:aws402_book_flutter/models/loan_book_model.dart';

// [형호]
class LoanReminderSettings {
  const LoanReminderSettings({
    this.dueDateNotificationsEnabled = true,
    this.overdueNotificationsEnabled = true,
    this.readingReminderEnabled = false,
    this.dueReminderHour = 9,
    this.dueReminderMinute = 0,
    this.overdueReminderHour = 10,
    this.overdueReminderMinute = 0,
    this.readingReminderHour = 20,
    this.readingReminderMinute = 0,
  });

  final bool dueDateNotificationsEnabled;
  final bool overdueNotificationsEnabled;
  final bool readingReminderEnabled;
  final int dueReminderHour;
  final int dueReminderMinute;
  final int overdueReminderHour;
  final int overdueReminderMinute;
  final int readingReminderHour;
  final int readingReminderMinute;

  LoanReminderSettings copyWith({
    bool? dueDateNotificationsEnabled,
    bool? overdueNotificationsEnabled,
    bool? readingReminderEnabled,
    int? dueReminderHour,
    int? dueReminderMinute,
    int? overdueReminderHour,
    int? overdueReminderMinute,
    int? readingReminderHour,
    int? readingReminderMinute,
  }) {
    return LoanReminderSettings(
      dueDateNotificationsEnabled:
      dueDateNotificationsEnabled ?? this.dueDateNotificationsEnabled,
      overdueNotificationsEnabled:
      overdueNotificationsEnabled ?? this.overdueNotificationsEnabled,
      readingReminderEnabled:
      readingReminderEnabled ?? this.readingReminderEnabled,
      dueReminderHour: dueReminderHour ?? this.dueReminderHour,
      dueReminderMinute: dueReminderMinute ?? this.dueReminderMinute,
      overdueReminderHour: overdueReminderHour ?? this.overdueReminderHour,
      overdueReminderMinute: overdueReminderMinute ?? this.overdueReminderMinute,
      readingReminderHour: readingReminderHour ?? this.readingReminderHour,
      readingReminderMinute: readingReminderMinute ?? this.readingReminderMinute,
    );
  }

  String get dueTimeLabel => _formatTime(dueReminderHour, dueReminderMinute);
  String get overdueTimeLabel =>
      _formatTime(overdueReminderHour, overdueReminderMinute);
  String get readingTimeLabel =>
      _formatTime(readingReminderHour, readingReminderMinute);

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 반납 알림 및 독서 권장 알림을 Android 로컬 알림으로 예약.
class LoanNotificationService {
  LoanNotificationService._();
  static final LoanNotificationService instance = LoanNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _readingNotificationBaseId = 9000;
  static const int _testNotificationId = 9900;

  // 알람 권한에 따라 예약 방식을 결정합니다.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final canScheduleExact =
    await android?.canScheduleExactNotifications();

    if (canScheduleExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    timezone_data.initializeTimeZones();
    try {
      // flutter_timezone 4.x returns a timezone identifier String.
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(initializationSettings);
    _initialized = true;
    await _cancelLegacyLoanSchedules();
  }

  Future<void> _cancelLegacyLoanSchedules() async {
    // 예전 대여 알림 ID(100,000~134,317,729)와 현재 도서별 ID
    // (150,000,001~1,223,741,823)를 시작 시 정리함.
    // 이어지는 restoreSchedules()가 저장되어 있는 미반납 도서만 다시 예약하므로,
    // 삭제/반납 테스트 이후 저장 목록에 없는 책의 오래된 연체 알림도 제거됨.
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final isLegacyLoanId =
          request.id >= 100000 && request.id <= 134317729;
      if (isLegacyLoanId) {
        await _plugin.cancel(request.id);
      }
    }
  }

  Future<bool> requestPermission() async {
    try {
      // 알림 서비스가 초기화되지 않았다면 먼저 초기화한다.
      if (!_initialized) {
        await initialize();
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Android 이외의 플랫폼에서는 여기서 Android 권한 검사를 하지 않는다.
      if (android == null) return true;

      // Android 알림 권한을 요청하고 현재 권한 상태를 확인한다.
      final granted = await android.requestNotificationsPermission();

      debugPrint(
        '[BaroBook 알림 권한 확인] '
            'initialized=$_initialized, granted=$granted',
      );

      return granted ?? true;
    } catch (e) {
      debugPrint('[BaroBook 알림 권한 확인 오류] $e');
      return false;
    }
  }
  Future<LoanReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return LoanReminderSettings(
      dueDateNotificationsEnabled:
      prefs.getBool('barobook.dueNotifications.enabled') ?? true,
      overdueNotificationsEnabled:
      prefs.getBool('barobook.overdueNotifications.enabled') ?? true,
      readingReminderEnabled:
      prefs.getBool('barobook.readingReminder.enabled') ?? false,
      dueReminderHour: prefs.getInt('barobook.dueNotifications.hour') ?? 9,
      dueReminderMinute: prefs.getInt('barobook.dueNotifications.minute') ?? 0,
      overdueReminderHour:
      prefs.getInt('barobook.overdueNotifications.hour') ?? 10,
      overdueReminderMinute:
      prefs.getInt('barobook.overdueNotifications.minute') ?? 0,
      readingReminderHour: prefs.getInt('barobook.readingReminder.hour') ?? 20,
      readingReminderMinute: prefs.getInt('barobook.readingReminder.minute') ?? 0,
    );
  }

  Future<void> applySettings(
      LoanReminderSettings settings,
      List<LoanBook> books,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'barobook.dueNotifications.enabled',
      settings.dueDateNotificationsEnabled,
    );
    await prefs.setBool(
      'barobook.overdueNotifications.enabled',
      settings.overdueNotificationsEnabled,
    );
    await prefs.setBool(
      'barobook.readingReminder.enabled',
      settings.readingReminderEnabled,
    );
    await prefs.setInt('barobook.dueNotifications.hour', settings.dueReminderHour);
    await prefs.setInt(
      'barobook.dueNotifications.minute',
      settings.dueReminderMinute,
    );
    await prefs.setInt(
      'barobook.overdueNotifications.hour',
      settings.overdueReminderHour,
    );
    await prefs.setInt(
      'barobook.overdueNotifications.minute',
      settings.overdueReminderMinute,
    );
    await prefs.setInt(
      'barobook.readingReminder.hour',
      settings.readingReminderHour,
    );
    await prefs.setInt(
      'barobook.readingReminder.minute',
      settings.readingReminderMinute,
    );

    if (!_initialized) return;

    for (final book in books) {
      if (book.isReturned) {
        await cancelLoanReminders(book.id);
      } else {
        await scheduleLoanReminders(book, settings: settings);
      }
    }

    if (settings.readingReminderEnabled) {
      await scheduleReadingEncouragement(settings);
    } else {
      await cancelReadingEncouragement();
    }
  }

  Future<void> restoreSchedules(List<LoanBook> books) async {
    if (!_initialized) return;

    final settings = await loadSettings();

    for (final book in books) {
      if (book.isReturned) {
        // 이미 반납한 도서의 예약은 취소함.
        await cancelLoanReminders(book.id);
      } else {
        // 앱 시작 시에는 기존 알림을 취소하지 않고 미래의 알림 예약만 복원함.
        await scheduleLoanReminders(
          book,
          settings: settings,
          cancelExisting: false,
        );
      }
    }

    if (settings.readingReminderEnabled) {
      // 반복 독서 알림도 기존 알림을 지우지 않고 복원함.
      await scheduleReadingEncouragement(
        settings,
        cancelExisting: false,
      );
    } else {
      await cancelReadingEncouragement();
    }
  }

  Future<void> refreshLoanReminder(LoanBook book) async {
    if (!_initialized) return;
    final settings = await loadSettings();
    if (!book.isReturned) {
      await scheduleLoanReminders(book, settings: settings);
    } else {
      await cancelLoanReminders(book.id);
    }
  }

  Future<void> scheduleLoanReminders(
      LoanBook book, {
        LoanReminderSettings? settings,
        bool cancelExisting = true,
      }) async {
    if (!_initialized) return;

    // 반납 완료된 도서는 예약을 유지하지 않음.
    if (book.isReturned) {
      await cancelLoanReminders(book.id);
      return;
    }

    // 도서 정보나 설정이 변경될 때는 기존 예약을 갱신합.
    // 앱 시작 시 단순 복원이라면 cancelExisting: false로 호출.
    if (cancelExisting) {
      await cancelLoanReminders(book.id);
    }

    final actualSettings = settings ?? await loadSettings();

    if (actualSettings.dueDateNotificationsEnabled) {
      final dayBefore = book.dueDate.subtract(const Duration(days: 1));
      await _scheduleOne(
        id: _notificationIdFor(book.id, 1),
        title: '반납일이 내일이에요 📚',
        body: '「${book.title}」 반납일이 내일입니다. 책을 반납할 준비를 해보세요.',
        date: dayBefore,
        hour: actualSettings.dueReminderHour,
        minute: actualSettings.dueReminderMinute,
        channelId: 'barobook_return_reminders',
        channelName: '도서 반납 알림',
      );
      await _scheduleOne(
        id: _notificationIdFor(book.id, 2),
        title: '오늘은 반납일이에요 📚',
        body: '「${book.title}」 오늘까지 반납해주세요.',
        date: book.dueDate,
        hour: actualSettings.dueReminderHour,
        minute: actualSettings.dueReminderMinute,
        channelId: 'barobook_return_reminders',
        channelName: '도서 반납 알림',
      );
    }

    if (actualSettings.overdueNotificationsEnabled) {
      await _scheduleOverdueReminder(book, settings: actualSettings);
    }
  }

  Future<void> _scheduleOverdueReminder(
      LoanBook book, {
        required LoanReminderSettings settings,
      }) async {
    final now = tz.TZDateTime.now(tz.local);
    final notificationTime = book.isOverdue
        ? _nextOverdueNotificationTime(now, settings)
        : _overdueStartTime(book, settings);

    if (!notificationTime.isAfter(now)) return;

    final id = _notificationIdFor(book.id, 3);
    final scheduleMode = await _resolveScheduleMode();

    debugPrint(
      '[BaroBook 연체 알림 예약] '
          'id=$id, '
          '예약시각=$notificationTime, '
          '방식=$scheduleMode',
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'barobook_overdue_reminders',
        '도서 연체 알림',
        channelDescription: '반납일이 지난 대여 도서에 대한 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      '도서가 연체 중이에요 ⚠️',
      '「${book.title}」 반납일이 지났어요. 반납 여부를 확인해주세요.',
      notificationTime,
      details,
      androidScheduleMode: scheduleMode,
      // 실제 연체 중인 책만 일일 반복.
      // 아직 기한이 남은 책은 반납 예정일 다음 날에 한 번만 알림.
      matchDateTimeComponents:
      book.isOverdue ? DateTimeComponents.time : null,
    );
  }

  tz.TZDateTime _overdueStartTime(
      LoanBook book,
      LoanReminderSettings settings,
      ) {
    final firstOverdueDate = book.dueDate.add(const Duration(days: 1));
    return tz.TZDateTime(
      tz.local,
      firstOverdueDate.year,
      firstOverdueDate.month,
      firstOverdueDate.day,
      settings.overdueReminderHour,
      settings.overdueReminderMinute,
    );
  }

  tz.TZDateTime _nextOverdueNotificationTime(
      tz.TZDateTime now,
      LoanReminderSettings settings,
      ) {
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.overdueReminderHour,
      settings.overdueReminderMinute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  Future<void> cancelLoanReminders(String loanId) async {
    if (!_initialized) return;

    // Cancel the current IDs.
    for (var suffix = 1; suffix <= 3; suffix++) {
      await _plugin.cancel(_notificationIdFor(loanId, suffix));
    }

    // Also cancel IDs created by the previous version. This removes stale
    // alarms when the app is upgraded to the collision-safe ID scheme below.
    for (var suffix = 1; suffix <= 3; suffix++) {
      await _plugin.cancel(_legacyNotificationIdFor(loanId, suffix));
    }
  }

  Future<void> scheduleReadingEncouragement(
      LoanReminderSettings settings, {
        bool cancelExisting = true,
      }) async {
    if (!_initialized) return;

    // 시간이나 설정을 변경하는 경우에는 기존 반복 예약을 갱신.
    // 단순 복원에서는 표시 중인 알림을 지우지 않음.
    if (cancelExisting) {
      await cancelReadingEncouragement();
    }

    const messages = <String>[
      '오늘도 책 한 페이지부터 시작해 봐요. 작은 독서가 쌓여 큰 습관이 됩니다.',
      '잠깐의 독서 시간 어때요? 지금 읽는 한 문장이 새로운 생각을 열어줄 거예요.',
      '바로북과 함께 오늘의 독서 목표를 향해 한 걸음 더 나아가 봐요.',
      '바쁜 하루에도 10분 독서는 가능해요. 책을 펼쳐 볼까요?',
      '읽었던 페이지를 기록하고 오늘의 독서도 이어가 보세요.',
      '꾸준함이 독서의 힘이에요. 오늘도 조금씩 읽어 봐요.',
      '오늘 하루를 마무리하며 좋아하는 책과 함께 잠깐 쉬어가요.',
    ];
    final now = tz.TZDateTime.now(tz.local);
    final scheduleMode = await _resolveScheduleMode();

    // 요일별 메시지를 한 번씩 예약하고, 각 알림은 매주 같은 요일에 반복.
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      var daysUntil = (weekday - now.weekday + 7) % 7;
      var date = now.add(Duration(days: daysUntil));
      var scheduled = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        settings.readingReminderHour,
        settings.readingReminderMinute,
      );
      if (!scheduled.isAfter(now)) {
        date = date.add(const Duration(days: 7));
        scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          settings.readingReminderHour,
          settings.readingReminderMinute,
        );
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'barobook_reading_encouragement',
          '독서 권장 알림',
          channelDescription: '매일 독서 습관을 돕는 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      final id = _readingNotificationBaseId + weekday;

      debugPrint(
        '[BaroBook 독서 알림 예약] '
            'id=$id, '
            '예약시각=$scheduled, '
            '방식=$scheduleMode',
      );

      await _plugin.zonedSchedule(
        id,
        '📖 오늘의 독서 시간',
        messages[weekday - 1],
        scheduled,
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelReadingEncouragement() async {
    if (!_initialized) return;
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _plugin.cancel(_readingNotificationBaseId + weekday);
    }
  }

  Future<void> showTestNotification() async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'barobook_test_notifications',
        'BaroBook 테스트 알림',
        channelDescription: '알림 기능 확인용',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      _testNotificationId,
      'BaroBook 알림 테스트',
      '알림이 정상적으로 설정되어 있어요.',
      details,
    );
  }

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
  }) async {
    final scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

    final scheduleMode = await _resolveScheduleMode();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'BaroBook 대여 및 반납 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    debugPrint(
      '[BaroBook 알림 예약] '
          'id=$id, '
          '예약시각=$scheduled, '
          '방식=$scheduleMode',
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: scheduleMode,
    );
  }

  int _notificationIdFor(String value, int suffix) {
    // 알림 종류별 ID를 4칸 슬롯으로 분리해 서로 다른 suffix가 인접한 해시 값 때문에 겹치지 않도록 함.
    // 새 ID 범위는 구버전 예약 범위보다 높게 설정함.
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = ((hash * 31) + unit) & 0x0FFFFFFF;
    }
    return 150000000 + (hash * 4) + suffix;
  }

  int _legacyNotificationIdFor(String value, int suffix) {
    // 이전 버전에서 사용한 ID 계산식. 업그레이드 후 예약된 구 알림을 취소하는 용도로만 사용.
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = ((hash * 31) + unit) & 0x03FFFFFF;
    }
    return 100000 + (hash * 2) + suffix;
  }
}
