import 'package:aws402_book_flutter/screens/home/loan_actions.dart';
import 'package:aws402_book_flutter/screens/home/loan_dashboard_section.dart';
import 'package:flutter/material.dart';

/// - 대여 중 / 반납 임박 / 연체 요약, 읽는 중인 책(독서 진행률, D-Day)
/// - 책을 누르면 읽은 페이지 저장, 반납 예정일 연장, 반납 완료, 완독 별점
/// - 대여 기록, 반납/독서 알림 설정
class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<StatefulWidget> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  // [형호 연동]
  static const Color _background = Color(0xFFF4F4F9);
  static const Color _primary = Color(0xFF1B3B6F);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '나의 독서 기록',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '대여 기간과 독서 진행률을 한눈에 확인해요.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '책 직접 대여 등록',
                    onPressed: () => LoanActions.registerLoanBook(context),
                    icon: const Icon(Icons.add_circle_outline, color: _primary),
                  ),
                  IconButton(
                    tooltip: '알림 설정',
                    onPressed: () => LoanActions.openReminderSettings(context),
                    icon: const Icon(Icons.notifications_active_outlined, color: _primary),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // 홈 화면에는 독서 리포트가 있으므로 여기서는 숨김.
              const LoanDashboardSection(showReport: false),
            ],
          ),
        ),
      ),
    );
  }
}
