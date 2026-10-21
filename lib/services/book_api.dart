import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 날짜: 2026-10-20
// 수정자: 구정민
// 내용: 카카오 도서 검색과 Spring Boot 도서 조회·등록 API 호출을 한곳에서 관리한다.
class BookApi {
  static final Dio server = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  static final Dio kakao = Dio(
    BaseOptions(
      baseUrl: 'https://dapi.kakao.com/v3/search/book',
      headers: {
        'Authorization': 'KakaoAK ${dotenv.env['KAKAO_API_KEY'] ?? ''}',
      },
    ),
  );

  // 내용: 선택한 책 표지 파일을 서버로 업로드한다.
  static Future<String> uploadCover(String path) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(path)});
    final res = await server.post('/book/cover', data: form);
    if (res.data['result'] != 'success') throw Exception('표지 업로드 실패');
    return res.data['data']['url'] as String;
  }

  // 내용: ISBN이 이미 등록되어 있는지 Spring Boot 서버에 조회한다.
  static Future<bool> exists(String isbn) async {
    final res = await server.get(
      '/book/exists',
      queryParameters: {'isbn': isbn},
    );
    return res.data['data']['exists'] == true;
  }

  // 내용: 도서 등록 정보를 서버로 전송한다.
  static Future<void> save(Map<String, dynamic> book) async {
    final res = await server.post('/book/info', data: book);
    if (res.data['result'] != 'success') throw Exception(res.data['data']);
  }

  //내용: ISBN 값을 카카오 API에서 가져온다.
  static Future<Map<String, dynamic>?> byIsbn(String isbn) async {
    final res = await kakao.get(
      '',
      queryParameters: {'target': 'isbn', 'query': isbn, 'size': 10},
    );
    final docs = (res.data['documents'] as List);
    if (docs.isEmpty) return null;
    final matches = docs
        .cast<Map<String, dynamic>>()
        .where((d) => (d['isbn'] as String? ?? '').split(' ').contains(isbn))
        .toList();
    return matches.isNotEmpty ? matches.first : null;
  }
}
