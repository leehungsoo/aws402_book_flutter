import 'package:flutter/material.dart';

import 'package:aws402_book_flutter/services/loan_notification_service.dart';

// [형호]
class LoanReminderSettingsDialog extends StatefulWidget {
  const LoanReminderSettingsDialog({
    super.key,
    required this.initialSettings,
  });

  final LoanReminderSettings initialSettings;

  @override
  State<LoanReminderSettingsDialog> createState() =>
      _LoanReminderSettingsDialogState();
}

class _LoanReminderSettingsDialogState
    extends State<LoanReminderSettingsDialog> {
  late bool _dueEnabled;
  late bool _overdueEnabled;
  late bool _readingEnabled;
  late int _dueHour;
  late int _dueMinute;
  late int _overdueHour;
  late int _overdueMinute;
  late int _readingHour;
  late int _readingMinute;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _dueEnabled = settings.dueDateNotificationsEnabled;
    _overdueEnabled = settings.overdueNotificationsEnabled;
    _readingEnabled = settings.readingReminderEnabled;
    _dueHour = settings.dueReminderHour;
    _dueMinute = settings.dueReminderMinute;
    _overdueHour = settings.overdueReminderHour;
    _overdueMinute = settings.overdueReminderMinute;
    _readingHour = settings.readingReminderHour;
    _readingMinute = settings.readingReminderMinute;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('알림 설정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('반납 D-Day 알림'),
              subtitle: const Text('반납 하루 전과 당일에 알려드려요.'),
              value: _dueEnabled,
              onChanged: (value) => setState(() => _dueEnabled = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('연체 알림'),
              subtitle: const Text('반납일 다음 날부터 알려드리고, 연체 중에는 매일 반복해요.'),
              value: _overdueEnabled,
              onChanged: (value) => setState(() => _overdueEnabled = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _dueEnabled,
              leading: const Icon(Icons.alarm),
              title: const Text('반납 알림 시간'),
              subtitle: Text(_timeLabel(_dueHour, _dueMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _dueEnabled ? () => _pickTime(isReading: false) : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _overdueEnabled,
              leading: const Icon(Icons.notification_important_outlined),
              title: const Text('연체 알림 시간'),
              subtitle: Text(_timeLabel(_overdueHour, _overdueMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _overdueEnabled
                  ? () => _pickTime(isOverdue: true)
                  : null,
            ),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('독서 권장 알림'),
              subtitle: const Text('요일별 독서 메시지를 매주 보내요.'),
              value: _readingEnabled,
              onChanged: (value) => setState(() => _readingEnabled = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _readingEnabled,
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('독서 알림 시간'),
              subtitle: Text(_timeLabel(_readingHour, _readingMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap:
              _readingEnabled ? () => _pickTime(isReading: true) : null,
            ),
            const SizedBox(height: 8),
            const Text(
              '현재 버전은 휴대전화에 예약하는 로컬 알림입니다. 앱이 알림 권한을 받아야 표시됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            LoanReminderSettings(
              dueDateNotificationsEnabled: _dueEnabled,
              overdueNotificationsEnabled: _overdueEnabled,
              readingReminderEnabled: _readingEnabled,
              dueReminderHour: _dueHour,
              dueReminderMinute: _dueMinute,
              overdueReminderHour: _overdueHour,
              overdueReminderMinute: _overdueMinute,
              readingReminderHour: _readingHour,
              readingReminderMinute: _readingMinute,
            ),
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickTime({bool isReading = false, bool isOverdue = false}) async {
    final initial = TimeOfDay(
      hour: isReading
          ? _readingHour
          : isOverdue
          ? _overdueHour
          : _dueHour,
      minute: isReading
          ? _readingMinute
          : isOverdue
          ? _overdueMinute
          : _dueMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      if (isReading) {
        _readingHour = picked.hour;
        _readingMinute = picked.minute;
      } else if (isOverdue) {
        _overdueHour = picked.hour;
        _overdueMinute = picked.minute;
      } else {
        _dueHour = picked.hour;
        _dueMinute = picked.minute;
      }
    });
  }

  String _timeLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
