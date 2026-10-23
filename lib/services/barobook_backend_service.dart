import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/loan_book_model.dart';


class BaroBookBackendService {
  BaroBookBackendService._();

  static final BaroBookBackendService instance = BaroBookBackendService._();

  static String get userId {
    final configured = (dotenv.env['BAROBOOK_USER_ID'] ??
        dotenv.env['BAROBOOK_REPORT_USER_ID'] ??
        'demo-user')
        .trim();
    return configured.isEmpty ? 'demo-user' : configured;
  }

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _normalizeBaseUrl(
        dotenv.env['BAROBOOK_API_BASE_URL'] ??
            dotenv.env['BAROBOOK_REPORT_API_BASE_URL'] ??
            dotenv.env['API_BASE_URL'] ??
            'http://10.0.2.2:8080/api/',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  String _normalizeBaseUrl(String value) {
    return '${value.trim().replaceAll(RegExp(r'/+$'), '')}/';
  }

  // 로컬 테스트 백엔드 주소를 /api/ 형태로 정규화한다.
  String _normalizeLocalApiBaseUrl(String? configured) {
    final value = configured?.trim().isNotEmpty == true
        ? configured!.trim()
        : 'http://10.0.2.2:8080';

    final normalized = value.replaceAll(RegExp(r'/+$'), '');
    final path = Uri.parse(normalized).path;

    final apiBase =
    path.endsWith('/api') ? normalized : '$normalized/api';

    return '$apiBase/';
  }

  dynamic _unwrap(dynamic body) {
    if (body is! Map) return body;
    final result = body['result'];
    if (result != null && result.toString() != 'success') {
      throw StateError(
        'BaroBook API 실패: ${body['message'] ?? body['error'] ?? result}',
      );
    }
    return body.containsKey('data') ? body['data'] : body;
  }

  Map<String, dynamic> _toRequestBody(LoanBook book) => {
    'id': book.id,
    'userId': userId,
    'title': book.title,
    'author': book.author,
    'isbn': book.isbn,
    'borrowedAt': _dateTime(book.borrowedAt),
    'dueAt': _dateTime(book.dueAt),
    'totalPages': book.totalPages,
    'currentPage': book.currentPage,
    'rating': book.rating,
    'returnedAt': book.returnedAt == null
        ? null
        : _dateTime(book.returnedAt!),
    'lenderName': book.lenderName,
    'lenderContact': book.lenderContact,
  };

  String _dateTime(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;

  List<Map<String, dynamic>> _mapList(dynamic raw, String errorMessage) {
    final value = _unwrap(raw);
    if (value is! List) throw FormatException(errorMessage);
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// GET /api/reading-report?userId=...
  Future<Map<String, dynamic>> getReadingReport() async {
    final response = await _dio.get<dynamic>(
      'reading-report',
      queryParameters: {'userId': userId},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('독서 리포트 응답이 객체 형식이 아닙니다.');
  }

  /// GET /api/books?userId=...
  Future<List<Map<String, dynamic>>> getBooks() async {
    final response = await _dio.get<dynamic>(
      'books',
      queryParameters: {'userId': userId},
    );
    return _mapList(response.data, '서버 도서 목록 응답이 배열 형식이 아닙니다.');
  }

  /// POST/PUT /api/books
  Future<void> syncLocalBooks(List<LoanBook> books) async {
    final existing = await getBooks();
    final existingIds = existing
        .where((item) => item['id'] != null)
        .map((item) => item['id'].toString())
        .toSet();

    for (final book in books) {
      final body = _toRequestBody(book);
      if (existingIds.contains(book.id)) {
        await _dio.put<dynamic>(
          'books/${Uri.encodeComponent(book.id)}',
          queryParameters: {'userId': userId},
          data: body,
        );
      } else {
        await _dio.post<dynamic>('books', data: body);
        existingIds.add(book.id);
      }
    }
    debugPrint('BaroBook: 로컬 도서 ${books.length}권 서버 동기화 완료');
  }

  /// GET /api/book/info?isbn=...
  Future<Map<String, dynamic>> getBookInfoByIsbn(String isbn) async {
    final normalized = isbn.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(isbn, 'isbn', 'ISBN은 비어 있을 수 없습니다.');
    }
    final response = await _dio.get<dynamic>(
      'book/info',
      queryParameters: {'isbn': normalized},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('도서 정보 응답이 객체 형식이 아닙니다.');
  }

  /// POST /api/book/info.
  Future<Map<String, dynamic>> insertBookInfo(
      Map<String, dynamic> bookInfo,
      ) async {
    final response = await _dio.post<dynamic>('book/info', data: bookInfo);
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('도서 정보 저장 응답이 객체 형식이 아닙니다.');
  }

  /// PATCH /api/books/{id}/progress
  Future<void> updateProgress({
    required String id,
    required int currentPage,
    int? rating,
  }) async {
    await _dio.patch<dynamic>(
      'books/${Uri.encodeComponent(id)}/progress',
      queryParameters: {'userId': userId},
      data: {
        'currentPage': currentPage,
        if (rating != null) 'rating': rating,
      },
    );
  }

  /// PATCH /api/books/{id}/rating
  Future<void> updateRating({required String id, required int rating}) async {
    await _dio.patch<dynamic>(
      'books/${Uri.encodeComponent(id)}/rating',
      queryParameters: {'userId': userId},
      data: {'rating': rating},
    );
  }

  /// PATCH /api/books/{id}/return
  Future<void> returnBook(String id) async {
    await _dio.patch<dynamic>(
      'books/${Uri.encodeComponent(id)}/return',
      queryParameters: {'userId': userId},
    );
  }

  /// DELETE /api/books/{id};
  Future<void> deleteBook(String id) async {
    await _dio.delete<dynamic>(
      'books/${Uri.encodeComponent(id)}',
      queryParameters: {'userId': userId},
    );
  }

  /// GET /api/lending-records?userId=...&direction=...
  Future<List<Map<String, dynamic>>> getLendingRecords({String? direction}) async {
    final response = await _dio.get<dynamic>(
      'lending-records',
      queryParameters: {
        'userId': userId,
        if (direction != null) 'direction': direction,
      },
    );
    return _mapList(response.data, '대여 기록 응답이 배열 형식이 아닙니다.');
  }

  /// GET /api/reading-goal?userId=...
  Future<Map<String, dynamic>> getReadingGoal() async {
    final response = await _dio.get<dynamic>(
      'reading-goal',
      queryParameters: {'userId': userId},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('독서 목표 응답이 객체 형식이 아닙니다.');
  }

  /// PUT /api/reading-goal?userId=...
  Future<void> saveReadingGoal(int targetBookCount) async {
    await _dio.put<dynamic>(
      'reading-goal',
      queryParameters: {'userId': userId},
      data: {'targetBookCount': targetBookCount},
    );
  }
}
