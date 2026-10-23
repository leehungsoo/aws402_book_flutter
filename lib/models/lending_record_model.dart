import 'dart:convert';

enum LendingDirection { borrowed, lent }

// [형호]
/// 내가 빌리거나 다른 사람에게 빌려준 책의 이력을 나타냄
class LendingRecord {
  const LendingRecord({
    required this.id,
    required this.title,
    required this.author,
    required this.direction,
    required this.personName,
    required this.personContact,
    required this.lentAt,
    required this.dueAt,
    this.returnedAt,
    this.memo = '',
    this.loanBookId,
  });

  final String id;
  final String title;
  final String author;
  final LendingDirection direction;
  /// 내가 빌린 기록이면 책을 빌려준 사람, 내가 빌려준 기록이면 빌려 간 사람.
  final String personName;
  final String personContact;
  final DateTime lentAt;
  final DateTime dueAt;
  final DateTime? returnedAt;
  final String memo;
  /// 연결된 내 대여 목록 도서 ID. 기존 기록에는 없을 수 있음
  final String? loanBookId;

  bool get isReturned => returnedAt != null;
  bool get isOverdue => !isReturned && dateOnly(dueAt).isBefore(dateOnly(DateTime.now()));

  LendingRecord copyWith({
    String? title,
    String? author,
    LendingDirection? direction,
    String? personName,
    String? personContact,
    DateTime? lentAt,
    DateTime? dueAt,
    DateTime? returnedAt,
    bool clearReturnedAt = false,
    String? memo,
    String? loanBookId,
  }) => LendingRecord(
    id: id,
    title: title ?? this.title,
    author: author ?? this.author,
    direction: direction ?? this.direction,
    personName: personName ?? this.personName,
    personContact: personContact ?? this.personContact,
    lentAt: lentAt ?? this.lentAt,
    dueAt: dueAt ?? this.dueAt,
    returnedAt: clearReturnedAt ? null : (returnedAt ?? this.returnedAt),
    memo: memo ?? this.memo,
    loanBookId: loanBookId ?? this.loanBookId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'direction': direction.name,
    'personName': personName,
    'personContact': personContact,
    'lentAt': lentAt.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'returnedAt': returnedAt?.toIso8601String(),
    'memo': memo,
    'loanBookId': loanBookId,
  };

  factory LendingRecord.fromJson(Map<String, dynamic> json) => LendingRecord(
    id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? '제목 없는 책',
    author: json['author'] as String? ?? '',
    direction: LendingDirection.values.firstWhere(
          (value) => value.name == json['direction'],
      orElse: () => LendingDirection.borrowed,
    ),
    personName: json['personName'] as String? ?? '',
    personContact: json['personContact'] as String? ?? '',
    lentAt: _parseDate(json['lentAt']),
    dueAt: _parseDate(json['dueAt']),
    returnedAt: json['returnedAt'] == null ? null : _parseDate(json['returnedAt']),
    memo: json['memo'] as String? ?? '',
    loanBookId: json['loanBookId'] as String?,
  );

  static List<LendingRecord> decodeList(String value) {
    final list = jsonDecode(value) as List<dynamic>;
    return list.map((item) => LendingRecord.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime _parseDate(dynamic value) => value is String ? (DateTime.tryParse(value) ?? DateTime.now()) : DateTime.now();
