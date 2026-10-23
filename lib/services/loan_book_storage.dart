import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/models/lending_record_model.dart'
    show LendingRecord;
import 'package:aws402_book_flutter/services/lending_record_storage.dart';

// [형호]
class LoanBookStorage {
  LoanBookStorage._();
  static final LoanBookStorage instance = LoanBookStorage._();

  static const String _storageKey = 'barobook.loanBooks.v1';

  /// 대여 목록이 저장(등록/수정/반납/삭제)될 때마다 값이 1씩 증가함.
  /// 홈 화면은 이 값을 구독해, 바코드 → 도서 정보 → 등록처럼 화면이 여러 번
  /// 바뀌는 흐름에서도 등록 직후 목록을 자동으로 새로 고쳐짐.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// 화면에서 일반적으로 도서를 불러옴. 이때 대여 기록도 자동 동기화함.
  Future<List<LoanBook>> loadBooks() => _loadBooks(syncHistory: true);

  /// 대여 기록을 편집하는 도중 역동기화가 발생하지 않도록 사용.
  /// 이 메서드는 기존 기록을 읽기만 하며, 자동으로 대여 기록을 덮어쓰지 않음.
  Future<List<LoanBook>> loadBooksWithoutHistorySync() =>
      _loadBooks(syncHistory: false);

  Future<List<LoanBook>> _loadBooks({required bool syncHistory}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    late final List<LoanBook> books;

    // 최초 실행에는 예시 책 대신 빈 목록으로 시작한다.
    // 최초 실행에는 예시 책 대신 빈 목록으로 시작한다.
    if (raw == null) {
      books = <LoanBook>[];

      await prefs.setString(_storageKey, jsonEncode(<Map<String, dynamic>>[]));
    } else {
      // 저장된 목록을 먼저 읽는다.
      List<LoanBook> decodedBooks;

      try {
        decodedBooks = LoanBook.decodeList(raw);
      } catch (_) {
        decodedBooks = <LoanBook>[];
      }

      // 테스트용 예시 책만 제거한다.
      final cleanedBooks = decodedBooks
          .where((book) => !book.id.startsWith('demo-'))
          .toList();

      // books에는 최종 목록을 한 번만 대입한다.
      books = cleanedBooks;

      // 테스트용 책을 제거했다면 변경된 목록을 저장한다.
      if (cleanedBooks.length != decodedBooks.length) {
        await prefs.setString(
          _storageKey,
          jsonEncode(cleanedBooks.map((book) => book.toJson()).toList()),
        );
      }
    }

    // 기존 테스트 데이터도 이 시점에 한번씩 대여 기록과 맞춰짐.
    if (syncHistory) {
      await LendingRecordStorage.instance.syncWithLoanBooks(books);
    }
    return books;
  }

  Future<void> saveBooks(List<LoanBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(books.map((book) => book.toJson()).toList()),
    );
    changes.value++;
  }

  Future<void> saveBook(LoanBook book) async {
    final books = await loadBooksWithoutHistorySync();
    final index = books.indexWhere((item) => item.id == book.id);
    if (index < 0) {
      books.add(book);
    } else {
      books[index] = book;
    }
    await saveBooks(books);
    // 신규 등록, 반납일 연장, 반납 완료 등의 변경이 대여 기록에 반영됩니다.
    await LendingRecordStorage.instance.syncWithLoanBooks(books);
  }

  /// 대여 기록 화면에서 수정한 정보를 원본 대여 목록에도 반영.
  /// history -> loan sync 단계에서는 자동 역동기화를 끄고 명시적으로 저장.
  Future<LoanBook?> updateBookFromLendingRecord(LendingRecord record) async {
    final linkedId = record.loanBookId;
    if (linkedId == null) return null;
    final books = await loadBooksWithoutHistorySync();
    final index = books.indexWhere((book) => book.id == linkedId);
    if (index < 0) return null;

    final current = books[index];
    final updated = current.copyWith(
      title: record.title,
      author: record.author,
      borrowedAt: record.lentAt,
      dueAt: record.dueAt,
      returnedAt: record.returnedAt,
      clearReturnedAt: record.returnedAt == null,
      lenderName: record.personName,
      lenderContact: record.personContact,
    );
    books[index] = updated;
    await saveBooks(books);
    return updated;
  }

  Future<void> deleteBook(String id) async {
    final books = await loadBooksWithoutHistorySync();
    final index = books.indexWhere((book) => book.id == id);

    // 이미 삭제되었거나 존재하지 않는 ID는 아무 작업도 하지 않음.
    if (index < 0) return;

    final book = books[index];
    if (!book.isReturned) {
      // 미반납 도서 삭제는 반납 알림과 대여 관리의 연속성을 깨뜨릴 수 있으므로
      // UI와 무관하게 저장소 계층에서도 삭제를 차단.
      throw StateError('미반납 도서는 삭제할 수 없습니다. 먼저 반납 완료 처리해 주세요.');
    }

    books.removeAt(index);
    await saveBooks(books);
    // 반납 완료 도서를 목록에서 지워도 연결된 대여 이력은 과거 기록으로 보존.
  }

  List<LoanBook> _sampleBooks() {
    final today = dateOnly(DateTime.now());
    return [
      LoanBook(
        id: 'demo-convenience-store',
        title: '불편한 편의점',
        author: '김호연',
        isbn: '',
        borrowedAt: today.subtract(const Duration(days: 10)),
        dueAt: today.add(const Duration(days: 1)),
        totalPages: 288,
        currentPage: 124,
      ),
      LoanBook(
        id: 'demo-clean-code',
        title: '클린 코드',
        author: '로버트 C. 마틴',
        isbn: '',
        borrowedAt: today.subtract(const Duration(days: 18)),
        dueAt: today.subtract(const Duration(days: 2)),
        totalPages: 464,
        currentPage: 260,
      ),
      LoanBook(
        id: 'demo-atomic-habits',
        title: '아주 작은 습관의 힘',
        author: '제임스 클리어',
        isbn: '',
        borrowedAt: today.subtract(const Duration(days: 3)),
        dueAt: today.add(const Duration(days: 5)),
        totalPages: 320,
        currentPage: 87,
      ),
    ];
  }
}
