import 'dart:async';

import 'package:flutter/material.dart';

import '../services/book_api.dart';
import '../routes/app_routes.dart';


// 내용: 카카오 도서 검색 및 선택 화면을 구성하는 상태 기반 위젯을 추가한다.
class BookSearchRegisterScreen extends StatefulWidget {
  const BookSearchRegisterScreen({super.key});


  // 내용: 검색 화면의 검색어와 결과 목록을 관리할 State 객체를 생성한다.
  @override
  State<BookSearchRegisterScreen> createState() => _State();
}


// 내용: 검색어, 페이지 번호, 검색 결과 목록 및 로딩 상태를 관리한다.
class _State extends State<BookSearchRegisterScreen> {
  final query = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> books = [];
  Timer? debounce;
  int page = 1;
  bool loading = false, end = false;
  String term = '';


  // 내용: 검색 목록 하단에 가까워지면 다음 페이지를 불러오도록 스크롤 감시를 등록한다.
  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.pixels >= scroll.position.maxScrollExtent - 250)
        load();
    });
  }


  // 내용: 검색어 입력기, 스크롤 컨트롤러 및 검색 지연 타이머를 해제한다.
  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    scroll.dispose();
    super.dispose();
  }


  // 내용: 검색어 입력 후 400ms 동안 추가 입력이 없으면 목록을 초기화하고 새 검색을 시작한다.
  void changed(String s) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      term = s.trim();
      page = 1;
      end = false;
      books.clear();
      setState(() {});
      load();
    });
  }


  // 내용: 카카오 책 검색 API에서 검색 결과를 페이지 단위로 가져와 목록에 누적한다.
  Future<void> load() async {
    if (loading || end || term.isEmpty) return;
    loading = true;
    setState(() {});
    try {

      // 내용: 도서 조회 또는 등록을 위해 서버 API를 호출하도록 연결한다.
      final response = await BookApi.kakao.get(
        '',
        queryParameters: {
          'query': term,
          'page': page,
          'size': 50,
          'sort': 'accuracy',
        },
      );
      if (!mounted) return;
      final docs = (response.data['documents'] as List)
          .cast<Map<String, dynamic>>();
      books.addAll(docs);
      page++;
      end = response.data['meta']['is_end'] == true;
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('검색 오류: $e')));
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }


  // 내용: 선택한 책의 ISBN 중복 여부를 확인하고 미등록 도서만 읽기 전용 등록 화면으로 이동한다.
  Future<void> choose(Map<String, dynamic> book) async {
    try {
      if (await BookApi.exists('${book['isbn'] ?? ''}')) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('이미 등록된 책입니다.')));
        return;
      }

      // 내용: 도서 검색·등록 화면으로 이동할 수 있도록 라우팅을 연결한다.
      if (mounted)
        Navigator.pushNamed(
          context,
          AppRoutes.register,
          arguments: {'book': book, 'readonly': true},
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('중복 확인 오류: $e')));
    }
  }

  // 내용: 검색 입력창과 책 표지·제목·저자·출판사 목록 및 추가 로딩 표시를 구성한다.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('책을 찾아보세요!')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: query,
            onChanged: changed,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            enableSuggestions: true,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: '책 제목을 입력하세요',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFFAF9F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: books.length + (loading ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == books.length)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              final book = books[i];
              final image = '${book['thumbnail'] ?? ''}';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: ListTile(
                  onTap: () => choose(book),
                  leading: image.isEmpty
                      ? const SizedBox(width: 65, child: Icon(Icons.book))
                      : Image.network(
                          image,
                          width: 65,
                          height: 95,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.book),
                        ),
                  title: Text(
                    '${book['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${(book['authors'] as List? ?? []).join(', ')}\n${book['publisher'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
