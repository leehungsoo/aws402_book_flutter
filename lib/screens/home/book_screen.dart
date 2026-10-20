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
  // 형호씨가 백엔드(MySQL)에서 받아올 데이터가 담기는 그릇입니다.
  // =========================================================
  int completedBooksCount = 0;       // 완독 도서 수
  double averageRating = 0.0;        // 평균 평점
  int progressPercent = 0;           // 진행율 퍼센트
  double progressRatio = 0.0;        // 진행율 막대 비율 (0.0 ~ 1.0)
  bool isLoading = false;            // 로딩 상태 (데이터를 불러오는 중인지 확인)

  @override
  void initState() {
    super.initState();
    // 화면이 켜질 때 형호씨의 MySQL 데이터를 불러옵니다.
    // fetchReadingReport(); // (백엔드 서버 켜지면 주석 해제)
  }

  // =========================================================
  // [형호씨 작업 연결 공간 2: MySQL 데이터 GET 함수]
  // 형호씨가 Spring Boot 등으로 만든 API 주소를 아래에 넣으면 됩니다.
  // =========================================================
  Future<void> fetchReadingReport() async {
    // TODO: 형호씨, 실제 백엔드 API 주소로 변경해 주세요!
    const String apiUrl = 'https://api.example.com/api/users/reading-report';

    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // DB에서 가져온 값을 변수에 덮어씌우면 만든 화면이 자동 업데이트됨
          completedBooksCount = data['completedBooksCount'] ?? 0;
          averageRating = (data['averageRating'] ?? 0.0).toDouble();
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
  // '책을 추가해 보세요'를 누르면 올라오는 메뉴입니다.
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
                          // --------------------------------------------------
                          // 1. 검색해서 등록하기 [정민씨 파트]
                          // --------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // 모달 먼저 닫기
                                // TODO: 정민씨 작업 완료 후, AppRoutes에 등록하고 아래 주석 풀기!
                                // Navigator.pushNamed(context, AppRoutes.정민씨라우트명_검색);

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
                          // --------------------------------------------------
                          // 2. 바코드로 등록하기 [흥수씨 파트]
                          // --------------------------------------------------
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
                          // --------------------------------------------------
                          // 3. 바코드로 등록하기 (Test) [흥수씨 파트]
                          // --------------------------------------------------
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
                          // --------------------------------------------------
                          //  4. 직접 입력하기 [정민씨 파트]
                          // --------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // 모달 먼저 닫기
                                // TODO: 정민씨 작업 완료 후, AppRoutes에 등록하고 아래 주석 풀기!
                                // Navigator.pushNamed(context, AppRoutes.정민씨라우트명_직접입력);

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
  //[작업 영역: 전체 UI 구조 및 디자인]
  // =========================================================
  @override
  Widget build(BuildContext context) {
    // 추천 색상 테마: 딥 네이비 & 소프트 화이트
    final Color mainColor = const Color(0xFF1B3B6F);
    final Color subColor = const Color(0xFF98D7C2);
    final Color bgColor = const Color(0xFFF4F4F9);
    final Color cardColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchReadingReport, // 형호씨 함수 연결 (당겨서 새로고침)
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
                          image: AssetImage('assets/images/main_image.jpg'), // 메인 이미지
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: _addBooks, // 흥수씨/정민씨 메뉴 호출
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

                // 형호씨 MySQL 데이터가 화면에 뿌려지는 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('나의 독서 리포트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('완독 도서 수', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(isLoading ? '-' : '$completedBooksCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Align(alignment: Alignment.centerRight, child: Icon(Icons.menu_book, size: 40, color: mainColor))
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('평균 평점', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(isLoading ? '-' : '$averageRating', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                      Padding(padding: const EdgeInsets.only(bottom: 6.0, left: 2.0), child: Icon(Icons.star, size: 18, color: mainColor)),
                                      const Padding(padding: EdgeInsets.only(bottom: 4.0), child: Text(' / 5.0', style: TextStyle(fontSize: 14))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(alignment: Alignment.centerRight, child: Icon(Icons.show_chart, size: 40, color: mainColor))
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