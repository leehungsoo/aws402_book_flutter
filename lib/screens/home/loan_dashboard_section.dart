import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/screens/home/lending_history_screen.dart';
import 'package:aws402_book_flutter/screens/home/loan_actions.dart';
import 'package:aws402_book_flutter/screens/home/loan_book_detail_screen.dart';
import 'package:aws402_book_flutter/services/loan_book_storage.dart';
import 'package:aws402_book_flutter/services/loan_notification_service.dart';
import 'package:aws402_book_flutter/services/reading_report_service.dart';

// [형호]
const Color _bbBorder = Color(0xFFE1E5EE);
const Color _bbCard = Color(0xFFFFFFFF);
const Color _bbPrimary = Color(0xFF1B3B6F);
const Color _bbSoftBlue = Color(0xFFE3EAF6);

// 홈(BookScreen) 하단에 붙는 대여·독서 관리 영역
class LoanDashboardSection extends StatefulWidget {
  const LoanDashboardSection({super.key, this.showReport = true});

  /// false면 '나의 독서 리포트' 영역을 숨깁니다.
  /// (홈 화면에는 팀장님이 만든 리포트 UI가 따로 있어, '나의 독서 기록' 탭에서는 숨김)
  final bool showReport;

  @override
  State<LoanDashboardSection> createState() => _LoanDashboardSectionState();
}

class _LoanDashboardSectionState extends State<LoanDashboardSection>
    with WidgetsBindingObserver {
  List<LoanBook> _books = <LoanBook>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 책 등록/수정/반납 등 저장이 일어나면 자동으로 목록을 다시 불러옴
    LoanBookStorage.instance.changes.addListener(_onStorageChanged);
    _loadBooks(restoreSchedules: true);
  }

  @override
  void dispose() {
    LoanBookStorage.instance.changes.removeListener(_onStorageChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStorageChanged() {
    if (mounted) unawaited(_loadBooks());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 복귀 시 책 목록만 다시 불러옴
    if (state == AppLifecycleState.resumed && !_loading) {
      unawaited(_loadBooks());
    }
  }

  Future<void> _loadBooks({bool restoreSchedules = false}) async {
    try {
      final books = await LoanBookStorage.instance.loadBooks();

      if (restoreSchedules) {
        await LoanNotificationService.instance.restoreSchedules(books);
      }

      if (!mounted) return;

      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('대여 목록을 불러오지 못했어요: $error')),
      );
    }
  }

  // 독서 상태와 대여 상태는 분리해서 계산
  // 완독한 도서도 실제 반납 전까지는 대여 수/반납 알림 대상에 포함
  int get _activeCount => _books.where((book) => book.isActiveLoan).length;
  int get _dueSoonCount => _books.where((book) => book.isDueSoon).length;
  int get _overdueCount => _books.where((book) => book.isOverdue).length;
  int get _completedCount => _books.where((book) => book.isCompleted).length;

  // 전체 독서 진행률: 총 페이지 대비 읽은 페이지 비율(0.0~1.0).
  double get _overallProgress {
    var total = 0;
    var read = 0;
    for (final book in _books) {
      if (book.totalPages <= 0) continue;
      total += book.totalPages;
      read += book.currentPage.clamp(0, book.totalPages).toInt();
    }
    return total == 0 ? 0 : read / total;
  }

  List<LoanBook> get _currentlyReadingBooks => _sortByDueDate(
    _books.where((book) => book.isCurrentlyReading),
  );

  List<LoanBook> get _completedAwaitingReturnBooks => _sortByDueDate(
    _books.where((book) => book.isCompletedAwaitingReturn),
  );

  List<LoanBook> _sortByDueDate(Iterable<LoanBook> source) {
    final books = source.toList();
    // 반납일이 가장 급한 책부터 보여줘 연체/임박 도서를 놓치지 않게 함
    books.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return books;
  }

  Future<void> _openBookDetail(LoanBook book) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LoanBookDetailScreen(book: book),
      ),
    );
    if (mounted) await _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final overallPercent = (_overallProgress * 100).round();
    final report = ReadingReport.fromBooks(_books);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showReport) ...[
          const Text(
            '나의 독서 리포트',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _bbPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 154,
                  child: _ReportCard(
                    label: '완독 도서 수',
                    value: '$_completedCount',
                    unit: '권',
                    icon: Icons.auto_stories_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 154,
                  child: _RatingReportCard(report: report),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressReportCard(percent: overallPercent, value: _overallProgress),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: '대여 중',
                count: _activeCount,
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF3867D6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: '반납 임박',
                count: _dueSoonCount,
                icon: Icons.alarm,
                color: const Color(0xFFD18A20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: '연체',
                count: _overdueCount,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD94B4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                '읽는 중인 책',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _bbPrimary, letterSpacing: -0.4),
              ),
            ),
            Text('${_currentlyReadingBooks.length}권', style: const TextStyle(color: Colors.black54)),
            IconButton(
              tooltip: '테스트 알림 보내기',
              onPressed: () => LoanActions.sendTestNotification(context),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_currentlyReadingBooks.isEmpty &&
            _completedAwaitingReturnBooks.isEmpty)
          Card(
            elevation: 0,
            color: _bbCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: const BorderSide(color: _bbBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.auto_stories_outlined, size: 42, color: Colors.black38),
                  const SizedBox(height: 10),
                  Text(_books.isEmpty ? '아직 등록한 책이 없어요.' : '현재 읽는 중인 책이 없어요.'),
                  const SizedBox(height: 4),
                  Text(
                    _books.isEmpty
                        ? '홈에서 책을 추가하거나, 위의 + 버튼으로 대여 관리를 시작해 보세요.'
                        : '완독한 책과 반납 완료한 책은 마이 페이지에서 확인할 수 있어요.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_currentlyReadingBooks.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              '현재 읽는 중인 책이 없어요.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          )
        else
          _ReadingBookCarousel(
            key: ValueKey(
              _currentlyReadingBooks.map((book) => book.id).join('|'),
            ),
            books: _currentlyReadingBooks,
            onBookTap: _openBookDetail,
          ),
        if (_completedAwaitingReturnBooks.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '완독 · 반납 대기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _bbPrimary, letterSpacing: -0.3),
                ),
              ),
              Text(
                '${_completedAwaitingReturnBooks.length}권',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._completedAwaitingReturnBooks.map(
                (book) => _LoanBookCard(
              book: book,
              onTap: () => _openBookDetail(book),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          '읽는 중인 책은 진행률을, 완독한 책은 반납 예정일을 계속 관리할 수 있어요.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        const Divider(color: _bbBorder, height: 1),
        const SizedBox(height: 18),
        _buildLendingHistoryEntry(),
        const SizedBox(height: 96),
      ],
    );
  }

  Widget _buildLendingHistoryEntry() {
    return Material(
      color: _bbCard,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const LendingHistoryScreen()),
          );
          if (mounted) await _loadBooks();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _bbSoftBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded, color: _bbPrimary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '대여 기록',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _bbPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '내가 빌린 책과 빌려준 책을 확인해요.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _bbPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

// 나의 독서 리포트의 숫자 카드(예: 완독 도서 수 12권).
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _bbCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _bbBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: _bbPrimary),
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(icon, size: 39, color: _bbPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingReportCard extends StatelessWidget {
  const _RatingReportCard({required this.report});

  final ReadingReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _bbCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _bbBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('평균 평점', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  report.hasRating ? report.averageRating.toStringAsFixed(1) : '—',
                  style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: _bbPrimary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, size: 19, color: _bbPrimary),
                const SizedBox(width: 3),
                Text('/ 5.0', style: TextStyle(fontSize: 13, color: _bbPrimary)),
              ],
            ),
            const Spacer(),
            const Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.trending_up_rounded, size: 39, color: _bbPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// 전체 독서 진행률 바(예: 65%).
class _ProgressReportCard extends StatelessWidget {
  const _ProgressReportCard({required this.percent, required this.value});

  final int percent;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _bbCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _bbBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('전체 독서 진행률', style: TextStyle(fontSize: 14, color: Colors.black54)),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _bbPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: _bbBorder,
              color: _bbPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _bbCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _bbBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text('$count', style: const TextStyle(fontSize: 21, height: 1, fontWeight: FontWeight.w800, color: _bbPrimary)),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _ReadingBookCarousel extends StatefulWidget {
  const _ReadingBookCarousel({
    super.key,
    required this.books,
    required this.onBookTap,
  });

  final List<LoanBook> books;
  final ValueChanged<LoanBook> onBookTap;

  @override
  State<_ReadingBookCarousel> createState() =>
      _ReadingBookCarouselState();
}

class _ReadingBookCarouselState
    extends State<_ReadingBookCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return const SizedBox.shrink();
    }

    final startIndex = _currentPage > 0
        ? _currentPage - 1
        : 0;

    final endIndex =
    startIndex + 3 < widget.books.length
        ? startIndex + 3
        : widget.books.length;

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.books.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final book = widget.books[index];

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _LoanBookCard(
                  book: book,
                  onTap: () => widget.onBookTap(book),
                ),
              );
            },
          ),
        ),
        if (widget.books.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
              var index = startIndex;
              index < endIndex;
              index++
              )
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  width: index == _currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? _bbPrimary
                        : _bbBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${_currentPage + 1} / ${widget.books.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LoanBookCard extends StatelessWidget {
  const _LoanBookCard({required this.book, required this.onTap});

  final LoanBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final Color statusColor;
    final String status;
    if (book.isReturned) {
      status = '반납 완료';
      statusColor = Colors.grey;
    } else if (book.isOverdue) {
      status = '연체 ${book.daysRemaining.abs()}일';
      statusColor = const Color(0xFFD94B4B);
    } else if (book.isDueToday) {
      status = '오늘 반납';
      statusColor = const Color(0xFFD18A20);
    } else if (book.daysRemaining <= 3) {
      status = 'D-${book.daysRemaining}';
      statusColor = const Color(0xFFD18A20);
    } else {
      status = 'D-${book.daysRemaining}';
      statusColor = const Color(0xFF3867D6);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      color: _bbCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _bbBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 72,
                decoration: BoxDecoration(
                  color: _bbSoftBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF3867D6), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author.isEmpty ? '저자 정보 없음' : book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('대여 기간 ${book.loanDurationDays}일 · ${dateFormat.format(book.borrowedDate)}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text('반납 예정 ${dateFormat.format(book.dueDate)}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: book.readingProgress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: const Color(0xFFE8ECF4),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${book.currentPage}/${book.totalPages}페이지 · ${book.readingProgressPercent}%${book.isCompleted ? ' · 완독' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: book.isCompleted ? Colors.green : Colors.black54,
                              fontWeight: book.isCompleted ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
