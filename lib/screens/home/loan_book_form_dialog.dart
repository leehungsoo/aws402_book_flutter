import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:aws402_book_flutter/models/loan_book_model.dart';

// [형호]
class LoanBookFormDialog extends StatefulWidget {
  const LoanBookFormDialog({
    super.key,
    this.initialTitle = '',
    this.initialAuthor = '',
    this.initialIsbn = '',
  });

  final String initialTitle;
  final String initialAuthor;
  final String initialIsbn;

  @override
  State<LoanBookFormDialog> createState() => _LoanBookFormDialogState();
}

class _LoanBookFormDialogState extends State<LoanBookFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _isbnController;
  final _lenderNameController = TextEditingController();
  final _lenderContactController = TextEditingController();
  final _totalPagesController = TextEditingController(text: '300');
  final _currentPageController = TextEditingController(text: '0');
  final _loanDurationController = TextEditingController(text: '14');
  late DateTime _borrowedAt;
  late DateTime _dueAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _authorController = TextEditingController(text: widget.initialAuthor);
    _isbnController = TextEditingController(text: widget.initialIsbn);
    _borrowedAt = dateOnly(DateTime.now());
    _dueAt = _borrowedAt.add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _lenderNameController.dispose();
    _lenderContactController.dispose();
    _totalPagesController.dispose();
    _currentPageController.dispose();
    _loanDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('대여 목록에 책 추가'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '책 제목 *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? '책 제목을 입력해 주세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: '저자',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _isbnController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ISBN (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lenderNameController,
                  decoration: const InputDecoration(
                    labelText: '빌려준 사람 (선택)',
                    helperText: '입력하면 대여 기록에도 자동으로 표시돼요.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lenderContactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '빌려준 사람 연락처 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _totalPagesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '총 페이지 수 *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final total = int.tryParse(value ?? '');
                    final current = int.tryParse(_currentPageController.text) ?? 0;
                    if (total == null || total < 1) return '총 페이지 수를 1 이상 입력해 주세요.';
                    if (current > total) return '읽은 페이지는 총 페이지보다 클 수 없어요.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _currentPageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '현재 읽은 페이지',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final current = int.tryParse(value ?? '');
                    final total = int.tryParse(_totalPagesController.text) ?? 0;
                    if (current == null || current < 0) return '0 이상의 페이지를 입력해 주세요.';
                    if (current > total) return '읽은 페이지는 총 페이지보다 클 수 없어요.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _loanDurationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '대여 기간 (일) *',
                    helperText: '기본 14일 · 기간을 바꾸면 반납 예정일도 자동 변경돼요.',
                    border: OutlineInputBorder(),
                    suffixText: '일',
                  ),
                  onChanged: (value) {
                    final days = int.tryParse(value);
                    if (days == null || days < 1 || days > 3650) return;
                    setState(() {
                      _dueAt = _borrowedAt.add(Duration(days: days));
                    });
                  },
                  validator: (value) {
                    final days = int.tryParse(value ?? '');
                    if (days == null || days < 1) return '대여 기간은 1일 이상이어야 해요.';
                    if (days > 3650) return '대여 기간은 3650일 이하로 입력해 주세요.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _dateTile(
                  title: '대여일',
                  date: _borrowedAt,
                  onTap: () => _pickDate(isBorrowedDate: true),
                ),
                _dateTile(
                  title: '반납 예정일',
                  date: _dueAt,
                  onTap: () => _pickDate(isBorrowedDate: false),
                ),
                const SizedBox(height: 4),
                const Text(
                  '저장하면 내 대여 목록과 대여 기록이 자동으로 연결돼요. 바코드 등록도 저장 완료 시 동일하게 연결됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('대여 목록에 추가'),
        ),
      ],
    );
  }

  Widget _dateTile({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(DateFormat('yyyy.MM.dd').format(date)),
      trailing: const Icon(Icons.calendar_month_outlined),
      onTap: onTap,
    );
  }

  Future<void> _pickDate({required bool isBorrowedDate}) async {
    final current = isBorrowedDate ? _borrowedAt : _dueAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isBorrowedDate) {
        _borrowedAt = dateOnly(picked);
        final days = int.tryParse(_loanDurationController.text) ?? 14;
        _dueAt = _borrowedAt.add(Duration(days: days > 0 ? days : 14));
      } else {
        _dueAt = dateOnly(picked);
        final days = _dueAt.difference(_borrowedAt).inDays;
        _loanDurationController.text = days > 0 ? '$days' : '14';
        if (days <= 0) {
          _dueAt = _borrowedAt.add(const Duration(days: 14));
        }
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_dueAt.isAfter(_borrowedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반납 예정일은 대여일 이후로 설정해 주세요.')),
      );
      return;
    }

    final book = LoanBook(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      isbn: _isbnController.text.trim(),
      borrowedAt: _borrowedAt,
      dueAt: _dueAt,
      totalPages: int.parse(_totalPagesController.text),
      currentPage: int.parse(_currentPageController.text),
      lenderName: _lenderNameController.text.trim(),
      lenderContact: _lenderContactController.text.trim(),
    );
    Navigator.of(context).pop(book);
  }
}
