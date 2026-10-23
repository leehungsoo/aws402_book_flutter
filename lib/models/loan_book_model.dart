import 'dart:convert';

// [형호]
/// BaroBook 내 대여 목록에서 사용하는 도서/대여 정보 모델
/// 실제 대여 기간과 독서 진도는 이 모델에서 따로 관리
class LoanBook {
  const LoanBook({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.borrowedAt,
    required this.dueAt,
    required this.totalPages,
    required this.currentPage,
    this.rating = 0,
    this.returnedAt,
    this.lenderName = '',
    this.lenderContact = '',
  });

  final String id;
  final String title;
  final String author;
  final String isbn;
  final DateTime borrowedAt;
  final DateTime dueAt;
  final int totalPages;
  final int currentPage;
  /// 사용자가 매긴 도서 별점(1~5). 0은 아직 평점을 매기지 않은 상태.
  final int rating;
  final DateTime? returnedAt;
  /// 내가 빌린 책을 빌려준 사람의 정보(선택). 대여 기록과 함께 동기화
  final String lenderName;
  final String lenderContact;

  bool get isReturned => returnedAt != null;

  /// 반납되지 않은 모든 도서는 완독 여부와 관계없이 대여 중으로 봄
  bool get isActiveLoan => !isReturned;

  /// 메인 '읽는 중인 책' 목록에 표시할 대상
  bool get isCurrentlyReading => isActiveLoan && !isCompleted;

  /// 완독했지만 아직 반납되지 않아 반납일을 계속 관리해야 하는 도서
  bool get isCompletedAwaitingReturn => isActiveLoan && isCompleted;

  DateTime get borrowedDate => dateOnly(borrowedAt);
  DateTime get dueDate => dateOnly(dueAt);

  /// 대여일과 반납 예정일 사이의 일수. 예: 10/1~10/15는 14일.
  int get loanDurationDays => dueDate.difference(borrowedDate).inDays;

  int get daysRemaining => dueDate.difference(dateOnly(DateTime.now())).inDays;

  bool get isOverdue => !isReturned && daysRemaining < 0;
  bool get isDueToday => !isReturned && daysRemaining == 0;
  bool get isDueSoon => !isReturned && daysRemaining >= 0 && daysRemaining <= 3;

  double get readingProgress {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0).toDouble();
  }

  int get readingProgressPercent => (readingProgress * 100).round();

  /// 100%에 도달하면 별도 버튼 없이 완독으로 계산
  /// 총 페이지가 0인 도서는 완독으로 처리하지 않음
  bool get isCompleted => totalPages > 0 && currentPage >= totalPages;

  LoanBook copyWith({
    String? title,
    String? author,
    String? isbn,
    DateTime? borrowedAt,
    DateTime? dueAt,
    int? totalPages,
    int? currentPage,
    int? rating,
    DateTime? returnedAt,
    bool clearReturnedAt = false,
    String? lenderName,
    String? lenderContact,
  }) {
    return LoanBook(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      borrowedAt: borrowedAt ?? this.borrowedAt,
      dueAt: dueAt ?? this.dueAt,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      rating: rating ?? this.rating,
      returnedAt: clearReturnedAt ? null : (returnedAt ?? this.returnedAt),
      lenderName: lenderName ?? this.lenderName,
      lenderContact: lenderContact ?? this.lenderContact,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'isbn': isbn,
    'borrowedAt': borrowedAt.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'totalPages': totalPages,
    'currentPage': currentPage,
    'rating': rating,
    'returnedAt': returnedAt?.toIso8601String(),
    'lenderName': lenderName,
    'lenderContact': lenderContact,
  };

  factory LoanBook.fromJson(Map<String, dynamic> json) {
    return LoanBook(
      id: (json['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: (json['title'] as String?) ?? '제목 없는 책',
      author: (json['author'] as String?) ?? '',
      isbn: (json['isbn'] as String?) ?? '',
      borrowedAt: _dateFromJson(json['borrowedAt']),
      dueAt: _dateFromJson(json['dueAt']),
      totalPages: _intFromJson(json['totalPages']),
      currentPage: _intFromJson(json['currentPage']),
      rating: _intFromJson(json['rating']).clamp(0, 5).toInt(),
      returnedAt: json['returnedAt'] == null
          ? null
          : _dateFromJson(json['returnedAt']),
      lenderName: json['lenderName'] as String? ?? '',
      lenderContact: json['lenderContact'] as String? ?? '',
    );
  }

  static List<LoanBook> decodeList(String value) {
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .map((item) => LoanBook.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _dateFromJson(dynamic value) {
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
