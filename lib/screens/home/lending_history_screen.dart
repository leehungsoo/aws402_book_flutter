import 'package:aws402_book_flutter/services/loan_notification_service.dart';

const Color _bbBackground = Color(0xFFF4F4F9);
const Color _bbBorder = Color(0xFFE1E5EE);
const Color _bbCard = Color(0xFFFFFFFF);
const Color _bbPrimary = Color(0xFF1B3B6F);
const Color _bbSoftBlue = Color(0xFFE3EAF6);

const _navy = _bbPrimary;

// [형호]
/// 내가 빌린 책과 다른 사람에게 빌려준 책의 이력을 따로 관리
class LendingHistoryScreen extends StatefulWidget {
  const LendingHistoryScreen({super.key});

  @override
  State<LendingHistoryScreen> createState() => _LendingHistoryScreenState();
}

class _LendingHistoryScreenState extends State<LendingHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<LendingRecord> _records = [];
  bool _loading = true;
  final _dateFormat = DateFormat('yyyy.MM.dd');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 기존 기기에 저장된 내 대여 목록을 우선 대여 기록과 자동 연결
    await LoanBookStorage.instance.loadBooks();
    final records = await LendingRecordStorage.instance.loadRecords();
    if (!mounted) return;
    setState(() { _records = records; _loading = false; });
  }

  List<LendingRecord> _recordsFor(LendingDirection direction) {
    final records = _records.where((r) => r.direction == direction).toList();
    records.sort((a, b) {
      if (a.isReturned != b.isReturned) return a.isReturned ? 1 : -1;
      return a.dueAt.compareTo(b.dueAt);
    });
    return records;
  }

  Future<void> _addRecord(LendingDirection direction) async {
    final record = await showModalBottomSheet<LendingRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LendingRecordForm(direction: direction),
    );
    if (!mounted || record == null) return;
    await LendingRecordStorage.instance.saveRecord(record);
    await _load();
  }

  Future<void> _editRecord(LendingRecord record) async {
    final updated = await showModalBottomSheet<LendingRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LendingRecordForm(direction: record.direction, record: record),
    );
    if (!mounted || updated == null) return;
    await LendingRecordStorage.instance.saveRecord(updated);
    await _syncLinkedLoanBook(updated);
    await _load();
  }

  Future<void> _toggleReturned(LendingRecord record) async {
    final updated = record.isReturned
        ? record.copyWith(clearReturnedAt: true)
        : record.copyWith(returnedAt: DateTime.now());
    await LendingRecordStorage.instance.saveRecord(updated);
    await _syncLinkedLoanBook(updated);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(updated.isReturned ? '반납 완료로 기록했어요.' : '반납 완료 상태를 취소했어요.'),
    ));
  }

  Future<void> _syncLinkedLoanBook(LendingRecord record) async {
    final updatedBook = await LoanBookStorage.instance.updateBookFromLendingRecord(record);
    if (updatedBook != null) {
      await LoanNotificationService.instance.refreshLoanReminder(updatedBook);
    }
  }

  Future<void> _deleteRecord(LendingRecord record) async {
    // 1. 내가 빌려준 책이 아직 반납되지 않았다면 삭제 차단
    if (record.direction == LendingDirection.lent &&
        !record.isReturned) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '아직 반납되지 않은 책은 대여 기록을 삭제할 수 없습니다.',
          ),
        ),
      );
      return;
    }

    // 2. 기존 기능 유지: 도서 목록과 연결된 대여 기록은 직접 삭제하지 못하도록 보호
    if (record.loanBookId != null) {
      final books =
      await LoanBookStorage.instance.loadBooksWithoutHistorySync();

      if (!mounted) return;

      final linkedBookExists = books.any(
            (book) => book.id == record.loanBookId,
      );

      if (linkedBookExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '도서 목록과 연결된 기록입니다. '
                  '도서와 기록의 연결을 유지하기 위해 직접 삭제할 수 없습니다.',
            ),
          ),
        );
        return;
      }
    }

    // 3. 삭제 확인
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('대여 기록 삭제'),
        content: Text(
          '「${record.title}」 대여 기록을 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    // 4. 사용자가 삭제를 확인한 경우에만 처리
    if (!mounted || confirmed != true) return;

    await LendingRecordStorage.instance.deleteRecord(record.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final direction = _tabs.index == 0 ? LendingDirection.borrowed : LendingDirection.lent;
    final records = _recordsFor(direction);
    final activeCount = records.where((r) => !r.isReturned).length;
    return Scaffold(
      backgroundColor: _bbBackground,
      appBar: AppBar(
        backgroundColor: _bbCard,
        foregroundColor: _navy,
        title: const Text('대여 기록', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _navy,
          unselectedLabelColor: Colors.black54,
          indicatorColor: _navy,
          tabs: const [Tab(text: '내가 빌린 책'), Tab(text: '내가 빌려준 책')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRecord(direction),
        icon: const Icon(Icons.add),
        label: Text(direction == LendingDirection.borrowed ? '빌린 책 기록' : '빌려준 책 기록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _bbCard, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: _bbSoftBlue, borderRadius: BorderRadius.circular(14)),
                  child: Icon(direction == LendingDirection.borrowed ? Icons.call_received_rounded : Icons.call_made_rounded, color: _navy),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(direction == LendingDirection.borrowed ? '내가 빌린 책' : '내가 빌려준 책', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('전체 ${records.length}건 · 미반납 $activeCount건', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            if (records.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(color: _bbCard, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  const Icon(Icons.menu_book_outlined, size: 44, color: Colors.black38),
                  const SizedBox(height: 12),
                  Text(direction == LendingDirection.borrowed ? '아직 빌린 책 기록이 없어요.' : '아직 빌려준 책 기록이 없어요.', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('아래 버튼을 눌러 책과 상대방 정보를 기록해 보세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
                ]),
              )
            else
              ...records.map((record) => _RecordCard(
                record: record,
                dateFormat: _dateFormat,
                onEdit: () => _editRecord(record),
                onToggleReturned: () => _toggleReturned(record),
                onDelete: () => _deleteRecord(record),
              )),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.dateFormat, required this.onEdit, required this.onToggleReturned, required this.onDelete});
  final LendingRecord record;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onToggleReturned;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final overdue = record.isOverdue;
    final statusColor = record.isReturned ? Colors.green : (overdue ? Colors.red : const Color(0xFF3867D6));
    final status = record.isReturned ? '반납 완료' : (overdue ? '반납 지연' : '대여 중');
    return Card(
      color: _bbCard,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _bbBorder)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 13, 8, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (record.author.trim().isNotEmpty) ...[const SizedBox(height: 3), Text(record.author, style: const TextStyle(color: Colors.black54, fontSize: 12))],
            ])),
            PopupMenuButton<String>(
              tooltip: '기록 관리',
              onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))],
            ),
          ]),
          if (record.loanBookId != null) ...[
            const SizedBox(height: 2),
            const Text('내 대여 목록과 연결됨', style: TextStyle(fontSize: 11, color: _navy, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.person_outline, text: '${record.direction == LendingDirection.borrowed ? '빌려준 사람' : '빌려 간 사람'}: ${record.personName}'),
          if (record.personContact.trim().isNotEmpty) _InfoLine(icon: Icons.phone_outlined, text: '연락처: ${record.personContact}'),
          _InfoLine(icon: Icons.calendar_month_outlined, text: '대여일: ${dateFormat.format(record.lentAt)}'),
          _InfoLine(icon: Icons.event_outlined, text: '반납 예정일: ${dateFormat.format(record.dueAt)}'),
          if (record.isReturned) _InfoLine(icon: Icons.check_circle_outline, text: '반납일: ${dateFormat.format(record.returnedAt!)}'),
          if (record.memo.trim().isNotEmpty) _InfoLine(icon: Icons.notes, text: record.memo),
          const SizedBox(height: 9),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(30)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
            const Spacer(),
            TextButton.icon(onPressed: onToggleReturned, icon: Icon(record.isReturned ? Icons.undo : Icons.check_circle_outline, size: 17), label: Text(record.isReturned ? '미반납으로 변경' : '반납 완료 처리')),
          ]),
        ]),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.black45), const SizedBox(width: 7), Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
    ]),
  );
}

class _LendingRecordForm extends StatefulWidget {
  const _LendingRecordForm({required this.direction, this.record});
  final LendingDirection direction;
  final LendingRecord? record;
  @override
  State<_LendingRecordForm> createState() => _LendingRecordFormState();
}

class _LendingRecordFormState extends State<_LendingRecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _person;
  late final TextEditingController _contact;
  late final TextEditingController _memo;
  late DateTime _lentAt;
  late DateTime _dueAt;
  late DateTime? _returnedAt;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _title = TextEditingController(text: record?.title ?? '');
    _author = TextEditingController(text: record?.author ?? '');
    _person = TextEditingController(text: record?.personName ?? '');
    _contact = TextEditingController(text: record?.personContact ?? '');
    _memo = TextEditingController(text: record?.memo ?? '');
    _lentAt = record?.lentAt ?? DateTime.now();
    _dueAt = record?.dueAt ?? DateTime.now().add(const Duration(days: 14));
    _returnedAt = record?.returnedAt;
  }

  @override
  void dispose() { _title.dispose(); _author.dispose(); _person.dispose(); _contact.dispose(); _memo.dispose(); super.dispose(); }

  Future<void> _pickDate({required bool due}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: due ? _dueAt : _lentAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: due ? '반납 예정일 선택' : '대여일 선택',
    );
    if (selected == null || !mounted) return;
    setState(() { if (due) { _dueAt = selected; } else { _lentAt = selected; } });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_dueAt.isBefore(DateTime(_lentAt.year, _lentAt.month, _lentAt.day))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반납 예정일은 대여일보다 빠를 수 없어요.')));
      return;
    }
    final now = DateTime.now();
    final record = LendingRecord(
      id: widget.record?.id ?? now.microsecondsSinceEpoch.toString(),
      title: _title.text.trim(), author: _author.text.trim(), direction: widget.direction,
      personName: _person.text.trim(), personContact: _contact.text.trim(),
      lentAt: _lentAt, dueAt: _dueAt, returnedAt: _returnedAt, memo: _memo.text.trim(),
      loanBookId: widget.record?.loanBookId,
    );
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final borrowed = widget.direction == LendingDirection.borrowed;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.record == null ? (borrowed ? '빌린 책 기록하기' : '빌려준 책 기록하기') : '대여 기록 수정', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          TextFormField(controller: _title, decoration: const InputDecoration(labelText: '책 제목 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.menu_book)), validator: (v) => v == null || v.trim().isEmpty ? '책 제목을 입력해 주세요.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _author, decoration: const InputDecoration(labelText: '저자 (선택)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextFormField(controller: _person, decoration: InputDecoration(labelText: borrowed ? '빌려준 사람 *' : '빌려 간 사람 *', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.people_outline)), validator: (v) => v == null || v.trim().isEmpty ? '상대방 이름을 입력해 주세요.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '연락처 (선택)', hintText: '전화번호 또는 연락 가능한 정보', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          _DateField(label: '대여일', value: dateFormat.format(_lentAt), onTap: () => _pickDate(due: false)),
          const SizedBox(height: 10),
          _DateField(label: '반납 예정일', value: dateFormat.format(_dueAt), onTap: () => _pickDate(due: true)),
          const SizedBox(height: 12),
          TextFormField(controller: _memo, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '메모 (선택)', hintText: '책 상태, 약속 사항 등', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes))),
          if (_returnedAt != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('현재 반납 완료 상태 · ${dateFormat.format(_returnedAt!)}', style: const TextStyle(color: Colors.green, fontSize: 12))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('기록 저장'))),
        ])),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.calendar_today_outlined), suffixIcon: const Icon(Icons.edit_calendar_outlined)),
      child: Text(value),
    ),
  );
}
