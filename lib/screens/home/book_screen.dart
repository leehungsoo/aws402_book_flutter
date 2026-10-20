import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aws402_book_flutter/routes/app_routes.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<StatefulWidget> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {

  // =========================================================
  // [형호씨 작업 연결 공간 1: 상태 변수 선언]
  // =========================================================
  int completedBooksCount = 0;       // 완독 도서 수
  int totalBookCount = 0;            // 전체 도서 수 (평균 평점에서 변경됨)
  int progressPercent = 0;           // 진행율 퍼센트
  double progressRatio = 0.0;        // 진행율 막대 비율 (0.0 ~ 1.0)
  bool isLoading = false;            // 로딩 상태

  @override
  void initState() {
    super.initState();
    // fetchReadingReport(); // (백엔드 서버 켜지면 주석 해제)
  }

  // =========================================================
  // [형호씨 작업 연결 공간 2: MySQL 데이터 GET 함수]
  // =========================================================
  Future<void> fetchReadingReport() async {
    const String apiUrl = 'https://api.example.com/api/users/reading-report';

    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          completedBooksCount = data['completedBooksCount'] ?? 0;
          totalBookCount = data['totalBookCount'] ?? 0; // 전체 도서 수 데이터 바인딩
          progressPercent = data['progressPercent'] ?? 0;
          progressRatio = (data['progressPercent'] ?? 0) / 100.0;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('MySQL 데이터 로드 실패: $e');
      setState(() => isLoading = false);
    }
  }

  // =========================================================
  // [흥수씨 & 정민씨 작업 연결 공간: 책 등록 바텀 시트]
  // =========================================================
  void _addBooks() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('책 등록하기', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(thickness: 1, color: Colors.black87),
                    Container(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Column(
                        children: [
                          // 1. 검색해서 등록하기 [정민씨 파트]
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('정민씨가 개발 중인 검색 기능입니다! 🛠️')),
                                );
                              },
                              child: Row(
                                children: const [
                                  Icon(Icons.search),
                                  SizedBox(width: 8),
                                  Text('검색해서 등록하기', style: TextStyle(fontSize: 18.0)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          // 2. 바코드로 등록하기 [흥수씨 파트]
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () => Navigator.popAndPushNamed(context, AppRoutes.scanner),
                              child: Row(
                                children: const [
                                  Icon(Icons.qr_code_outlined),
                                  SizedBox(width: 8),
                                  Text('바코드로 등록하기', style: TextStyle(fontSize: 18.0)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          // 3. 바코드로 등록하기 (Test) [흥수씨 파트]
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () => Navigator.popAndPushNamed(context, AppRoutes.bookInfo, arguments: {"barcode": "9791158393977"}),
                              child: Row(
                                children: const [
                                  Icon(Icons.qr_code_outlined),
                                  SizedBox(width: 8),
                                  Text('바코드로 등록하기 (Test)', style: TextStyle(fontSize: 18.0)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          // 4. 직접 입력하기 [정민씨 파트]
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('정민씨가 개발 중인 직접 입력 기능입니다! 🛠️')),
                                );
                              },
                              child: Row(
                                children: const [
                                  Icon(Icons.keyboard),
                                  SizedBox(width: 8),
                                  Text('직접 입력하기', style: TextStyle(fontSize: 18.0)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // [작업 영역: 전체 UI 구조 및 디자인]
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final Color mainColor = const Color(0xFF1B3B6F);
    final Color subColor = const Color(0xFF98D7C2);
    final Color bgColor = const Color(0xFFF4F4F9);
    final Color cardColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchReadingReport,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('어서오세요', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
                      SizedBox(height: 8),
                      Text('읽고 있는 책을 등록해 볼까요?', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                ),

                // 책장 이미지 + 바텀 시트 호출 버튼
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 260,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 40),
                      decoration: const BoxDecoration(
                        color: Colors.black12,
                        image: DecorationImage(
                          image: AssetImage('assets/images/main_image.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: _addBooks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 36, color: mainColor),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('책을 추가해 보세요.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainColor)),
                                  const SizedBox(height: 4),
                                  const Text('읽고 있는 책이 있나요?', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 독서 리포트 카드 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('나의 독서 리포트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // 1. 완독 도서 수 카드
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('완독 도서 수', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(isLoading ? '-' : '$completedBooksCount권', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Align(alignment: Alignment.centerRight, child: Icon(Icons.menu_book, size: 40, color: mainColor))
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 2. 전체 도서 수 카드
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('전체 도서 수', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(
                                    isLoading ? '-' : '$totalBookCount권',
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(alignment: Alignment.centerRight, child: Icon(Icons.library_books, size: 40, color: mainColor))
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 전체 독서 진행율 바 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('전체 독서 진행율', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(isLoading ? '-' : '$progressPercent%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 24,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  width: constraints.maxWidth * progressRatio,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(colors: [subColor, mainColor]),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}