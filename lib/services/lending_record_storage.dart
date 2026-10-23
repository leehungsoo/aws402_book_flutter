import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:aws402_book_flutter/models/lending_record_model.dart';
import 'package:aws402_book_flutter/models/loan_book_model.dart';

// [형호]
/// 대여 기록 로컬 저장소.
/// LoanBook과 연결된 기록은 LoanBookStorage에서 불러오거나 저장할 때 자동 동기화.
class LendingRecordStorage {
  LendingRecordStorage._();
  static final LendingRecordStorage instance = LendingRecordStorage._();
  static const String _key = 'barobook.lendingRecords.v1';

  Future<List<LendingRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <LendingRecord>[];
    try {
      return LendingRecord.decodeList(raw);
    } catch (_) {
      return <LendingRecord>[];
    }
  }

  Future<void> saveRecords(List<LendingRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(records.map((record) => record.toJson()).toList()));
  }

  Future<void> saveRecord(LendingRecord record) async {
    final records = await loadRecords();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await saveRecords(records);
  }

  Future<void> deleteRecord(String id) async {
    final records = await loadRecords();
    records.removeWhere((record) => record.id == id);
    await saveRecords(records);
  }

  /// 현재 내 대여 목록을 대여 기록에 반영.
  /// 기존 대여 기록 중 제목/저자/날짜가 맞는 미연결 기록이 있으면 재사용해
  /// 연락처·메모와 같은 테스트 데이터를 잃거나 중복 기록을 만들지 않음.
  Future<void> syncWithLoanBooks(List<LoanBook> books) async {
    final records = await loadRecords();
    var changed = false;

    for (final book in books) {
      var recordIndex = records.indexWhere(
            (record) => record.loanBookId == book.id && record.direction == LendingDirection.borrowed,
      );

      if (recordIndex < 0) {
        recordIndex = _findLegacyMatch(records, book);
      }

      if (recordIndex >= 0) {
        final old = records[recordIndex];
        final updated = old.copyWith(
          title: book.title,
          author: book.author,
          direction: LendingDirection.borrowed,
          personName: book.lenderName.isNotEmpty ? book.lenderName : old.personName,
          personContact: book.lenderContact.isNotEmpty ? book.lenderContact : old.personContact,
          lentAt: book.borrowedAt,
          dueAt: book.dueAt,
          returnedAt: book.returnedAt,
          clearReturnedAt: book.returnedAt == null,
          loanBookId: book.id,
        );
        if (!_sameRecord(old, updated)) {
          records[recordIndex] = updated;
          changed = true;
        }
      } else {
        records.add(LendingRecord(
          id: 'loan-book-${book.id}',
          loanBookId: book.id,
          title: book.title,
          author: book.author,
          direction: LendingDirection.borrowed,
          personName: book.lenderName,
          personContact: book.lenderContact,
          lentAt: book.borrowedAt,
          dueAt: book.dueAt,
          returnedAt: book.returnedAt,
        ));
        changed = true;
      }
    }

    if (changed) await saveRecords(records);
  }

  int _findLegacyMatch(List<LendingRecord> records, LoanBook book) {
    final candidates = <int>[];
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      if (record.direction != LendingDirection.borrowed || record.loanBookId != null) continue;
      if (_normalise(record.title) != _normalise(book.title)) continue;
      if (record.author.trim().isNotEmpty && book.author.trim().isNotEmpty &&
          _normalise(record.author) != _normalise(book.author)) continue;
      candidates.add(i);
    }
    if (candidates.isEmpty) return -1;

    // 같은 제목 기록이 여러 건이거나 하나뿐이더라도, 대여일·반납 예정일이 일치하는
    // 단 하나의 기록만 연결. 어느 기록인지 모호하면 임의로 합치지 않음.
    var bestIndex = -1;
    var bestScore = 0;
    var bestCount = 0;
    for (final index in candidates) {
      final record = records[index];
      var score = 0;
      if (_sameDay(record.lentAt, book.borrowedAt)) score += 2;
      if (_sameDay(record.dueAt, book.dueAt)) score += 1;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
        bestCount = 1;
      } else if (score == bestScore && score > 0) {
        bestCount++;
      }
    }
    return bestScore > 0 && bestCount == 1 ? bestIndex : -1;
  }

  bool _sameRecord(LendingRecord a, LendingRecord b) =>
      a.title == b.title && a.author == b.author && a.direction == b.direction &&
          a.personName == b.personName && a.personContact == b.personContact &&
          a.lentAt == b.lentAt && a.dueAt == b.dueAt && a.returnedAt == b.returnedAt &&
          a.memo == b.memo && a.loanBookId == b.loanBookId;

  String _normalise(String value) => value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
