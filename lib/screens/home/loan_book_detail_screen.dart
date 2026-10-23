import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/services/loan_book_storage.dart';
import 'package:aws402_book_flutter/services/loan_notification_service.dart';

// [형호]
const Color _bbPrimary = Color(0xFF1B3B6F);
const Color _bbSoftBlue = Color(0xFFE3EAF6);

class LoanBookDetailScreen extends StatefulWidget {
  const LoanBookDetailScreen({super.key, required this.book});

  final LoanBook book;

  @override
  State<LoanBookDetailScreen> createState() => _LoanBookDetailScreenState();
}

class _LoanBookDetailScreenState extends State<LoanBookDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late LoanBook _book;
  late final TextEditingController _totalPagesController;
  late final TextEditingController _currentPageController;
  bool _savingProgress = false;
  bool _savingRating = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _totalPagesController = TextEditingController(text: '${_book.totalPages}');
    _currentPageController = TextEditingController(text: '${_book.currentPage}');
  }

  @override
  void dispose() {
    _totalPagesController.dispose();
    _currentPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('대여 도서 상세'),
        actions: [
          IconButton(
            tooltip: _book.isReturned
                ? '반납 완료 도서 삭제'
                : '반납 완료 후 삭제 가능',
            onPressed: _busy || !_book.isReturned ? null : _deleteBook,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 86,
                          decoration: BoxDecoration(
                            color: _bbSoftBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 34,
                            color: Color(0xFF3867D6),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _book.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_book.author.isEmpty ? '저자 정보 없음' : _book.author),
                              if (_book.isbn.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('ISBN ${_book.isbn}', style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _infoLine('대여일', dateFormat.format(_book.borrowedDate)),
                    _infoLine('반납 예정일', dateFormat.format(_book.dueDate)),
                    _infoLine('대여 기간', '${_book.loanDurationDays}일'),
                    _infoLine('상태', _statusLabel()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '독서 진행률',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _book.readingProgress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: const Color(0xFFE8ECF4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_book.currentPage} / ${_book.totalPages}페이지 · ${_book.readingProgressPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_book.isCompleted) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '완독했어요! 독서 진행률 100%로 완독 처리되었습니다.',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _totalPagesController,
                        enabled: !_book.isReturned,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: '총 페이지 수',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final total = int.tryParse(value ?? '');
                          final current = int.tryParse(_currentPageController.text) ?? 0;
                          if (total == null || total < 1) return '총 페이지는 1 이상이어야 해요.';
                          if (current > total) return '읽은 페이지가 총 페이지보다 많아요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _currentPageController,
                        enabled: !_book.isReturned,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: '현재까지 읽은 페이지',
                          helperText: '읽은 페이지를 수정한 뒤 저장하세요.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final current = int.tryParse(value ?? '');
                          final total = int.tryParse(_totalPagesController.text) ?? 0;
                          if (current == null || current < 0) return '0 이상의 값을 입력해 주세요.';
                          if (current > total) return '총 페이지 수를 넘을 수 없어요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _book.isReturned || _savingProgress
                              ? null
                              : _saveProgress,
                          icon: _savingProgress
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.save_outlined),
                          label: const Text('독서 진행률 저장'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_book.isReturned) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이 책의 평점',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '읽는 중에도 별점을 남길 수 있어요. 평점은 언제든 수정할 수 있습니다.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(
                          5,
                              (index) => IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: '${index + 1}점',
                            onPressed: _savingRating || _busy
                                ? null
                                : () => _saveRating(index + 1),
                            icon: Icon(
                              index < _book.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: _bbPrimary,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _book.rating > 0
                            ? '내 평점: ${_book.rating}점'
                            : '아직 평점을 선택하지 않았어요.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '선택한 별을 한 번 더 누르면 평점이 해제됩니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      if (_savingRating) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '대여 기간 관리',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('반납 예정일을 연장하면 기존 알림을 취소하고 새 날짜에 맞춰 다시 예약합니다.'),
                    if (!_book.isReturned) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: _bbSoftBlue.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _bbPrimary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '미반납 도서는 반납 알림과 대여 기록을 유지하기 위해 삭제할 수 없습니다. 반납 완료 처리 후 삭제할 수 있습니다.',
                                style: TextStyle(fontSize: 12, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _book.isReturned || _busy ? null : _extendDueDate,
                        icon: const Icon(Icons.event_repeat),
                        label: const Text('반납 예정일 연장'),
                      ),
                    ),
                    if (!_book.isReturned) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _markReturned,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('반납 완료 처리'),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text(
                        '반납 완료된 도서는 독서 진행률 수정과 반납일 연장이 잠겨 있어요.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  String _statusLabel() {
    if (_book.isReturned) return '반납 완료';
    if (_book.isOverdue) return '연체 ${_book.daysRemaining.abs()}일';
    if (_book.isDueToday) return '오늘 반납';
    return 'D-${_book.daysRemaining}';
  }

  Future<void> _saveProgress() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingProgress = true);
    try {
      final updated = _book.copyWith(
        totalPages: int.parse(_totalPagesController.text),
        currentPage: int.parse(_currentPageController.text),
      );
      await LoanBookStorage.instance.saveBook(updated);
      if (!mounted) return;
      setState(() {
        _book = updated;
        _savingProgress = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isCompleted
              ? '독서 진행률 100%! 완독으로 자동 처리했어요.'
              : '독서 진행률을 저장했어요.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingProgress = false);
      _showError('독서 진행률 저장에 실패했어요: $error');
    }
  }

  /// 읽는 중인 책의 별점을 저장합니다. 선택한 별을 다시 누르면 평점이 해제됩니다.
  Future<void> _saveRating(int value) async {
    if (_savingRating || _book.isReturned) return;

    final next = _book.rating == value ? 0 : value;
    setState(() => _savingRating = true);

    try {
      final updated = _book.copyWith(rating: next);
      // SharedPreferences에 저장하고, changes 알림을 통해 홈 화면의
      // 기존 백엔드 동기화 흐름에도 평점 변경을 전달합니다.
      await LoanBookStorage.instance.saveBook(updated);
      if (!mounted) return;

      setState(() {
        _book = updated;
        _savingRating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next == 0 ? '평점을 해제했어요.' : '${next}점으로 저장했어요.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingRating = false);
      _showError('평점 저장에 실패했어요: $error');
    }
  }

  Future<void> _extendDueDate() async {
    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    final afterCurrentDueDate = _book.dueDate.add(const Duration(days: 1));
    final earliest = afterCurrentDueDate.isAfter(tomorrow)
        ? afterCurrentDueDate
        : tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: earliest,
      firstDate: earliest,
      lastDate: DateTime(2100),
      helpText: '새 반납 예정일 선택',
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = _book.copyWith(dueAt: dateOnly(picked));
      await LoanBookStorage.instance.saveBook(updated);
      await LoanNotificationService.instance.refreshLoanReminder(updated);
      if (!mounted) return;
      setState(() {
        _book = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '반납일을 ${DateFormat('yyyy.MM.dd').format(updated.dueDate)}로 연장했어요.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('반납일 연장에 실패했어요: $error');
    }
  }

  Future<void> _markReturned() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('반납 완료 처리'),
        content: Text('「${_book.title}」 도서를 반납 완료로 표시할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('반납 완료'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = _book.copyWith(returnedAt: DateTime.now());
      await LoanBookStorage.instance.saveBook(updated);
      await LoanNotificationService.instance.refreshLoanReminder(updated);
      if (!mounted) return;
      setState(() {
        _book = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반납 완료 처리했고 반납 알림을 취소했어요.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('반납 처리에 실패했어요: $error');
    }
  }

  Future<void> _deleteBook() async {
    // UI 버튼을 우회해 호출하더라도 미반납 도서는 삭제하지 않음
    if (!_book.isReturned) {
      _showError('미반납 도서는 삭제할 수 없습니다. 먼저 반납 완료 처리해 주세요.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('반납 완료 도서 삭제'),
        content: Text('「${_book.title}」을(를) 대여 목록에서 삭제할까요? 대여 기록은 보존됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await LoanBookStorage.instance.deleteBook(_book.id);
      // 삭제가 성공한 뒤에만 오래된 알림 예약을 정리
      await LoanNotificationService.instance.cancelLoanReminders(_book.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('도서 삭제에 실패했습니다: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
