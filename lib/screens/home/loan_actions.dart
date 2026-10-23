import 'package:flutter/material.dart';

import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/screens/home/loan_book_form_dialog.dart';
import 'package:aws402_book_flutter/screens/home/loan_reminder_settings_dialog.dart';
import 'package:aws402_book_flutter/services/loan_book_storage.dart';
import 'package:aws402_book_flutter/services/loan_notification_service.dart';

// [형호]
class LoanActions {
  const LoanActions._();

  /// 대여 정보 입력 폼을 띄우고, 저장 + 반납 알림 예약까지 처리
  /// - 직접 입력: 인자 없이 호출
  /// - 도서 정보 화면(카카오 검색 결과)에서 등록: 제목/저자/ISBN을 넘겨 호출
  /// 저장되면 true를 반환
  static Future<bool> registerLoanBook(
      BuildContext context, {
        String title = '',
        String author = '',
        String isbn = '',
      }) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<LoanBook>(
      context: context,
      builder: (_) => LoanBookFormDialog(
        initialTitle: title,
        initialAuthor: author,
        initialIsbn: isbn,
      ),
    );

    if (result == null || !context.mounted) {
      return false;
    }

    // 1. 기존 로컬 저장소에 도서 저장
    try {
      await LoanBookStorage.instance.saveBook(result);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('책을 저장하지 못했어요: $error'),
          ),
        );
      }
      return false;
    }

    // 2. 기존 반납 알림 예약 유지
    String? reminderError;

    try {
      await LoanNotificationService.instance
          .refreshLoanReminder(result);
    } catch (error) {
      reminderError = error.toString();
    }

    // 3. 저장 결과 표시
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            reminderError == null
                ? '대여 목록에 등록했어요.'
                : '책은 저장했지만 알림 예약에 실패했어요: $reminderError',
          ),
        ),
      );
    }

    return true;
  }

  /// 반납/독서 알림 설정 다이얼로그를 염(홈 화면 우측 상단 설정 아이콘)
  static Future<void> openReminderSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = LoanNotificationService.instance;

    final granted = await service.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('알림 권한을 확인해 주세요. 기기 설정에서 바로북 알림을 허용해야 합니다.'),
        ),
      );
    }

    final currentSettings = await service.loadSettings();
    if (!context.mounted) return;
    final updated = await showDialog<LoanReminderSettings>(
      context: context,
      builder: (_) =>
          LoanReminderSettingsDialog(initialSettings: currentSettings),
    );
    if (updated == null) return;

    try {
      final books = await LoanBookStorage.instance.loadBooks();
      await service.applySettings(updated, books);
      messenger.showSnackBar(
        const SnackBar(content: Text('알림 설정을 저장했어요.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('알림 설정을 적용하지 못했어요: $error')),
      );
    }
  }

  /// 알림이 정상적으로 뜨는지 확인하는 테스트 알림
  static Future<void> sendTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = LoanNotificationService.instance;

    final granted = await service.requestPermission();
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('기기 설정에서 바로북 알림 권한을 허용해 주세요.')),
      );
      return;
    }
    try {
      await service.showTestNotification();
      messenger.showSnackBar(
        const SnackBar(content: Text('테스트 알림을 요청했어요.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('테스트 알림을 표시하지 못했어요: $error')),
      );
    }
  }
}
