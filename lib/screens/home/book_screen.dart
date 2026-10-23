import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aws402_book_flutter/routes/app_routes.dart';
// [형호 추가] 로컬 도서 데이터로 독서 통계를 계산
import 'package:aws402_book_flutter/services/reading_report_service.dart';
// [형호 추가] 백엔드 동기화 및 독서 리포트 조회
import 'package:aws402_book_flutter/services/barobook_backend_service.dart';
// [형호 추가] LoanBook 모델 사용
import 'package:aws402_book_flutter/models/loan_book_model.dart';
// [형호 추가] 기기에 저장된 대여 목록 조회 및 변경 감지
import '../../services/loan_book_storage.dart';

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

  // [형호 추가] 기기에 저장된 개인 대여 목록
  List<LoanBook> _loanBooks = [];

  @override
  void initState() {
    super.initState();
    // [형호 연동] 화면이 켜질 때 독서 리포트를 불러오고, 책 등록/진행률 저장/반납/별점 등으로 대여 데이터가 바뀌면 자동으로 다시 불러옴
    // (바코드 → 도서 정보 → 등록처럼 화면이 여러 번 바뀌는 흐름에서도 홈 수치가 최신으로 유지됨)
    LoanBookStorage.instance.changes.addListener(_onLoanDataChanged);
    fetchReadingReport();
  }

  @override
  void dispose() {
    LoanBookStorage.instance.changes.removeListener(_onLoanDataChanged);
    super.dispose();
  }

  void _onLoanDataChanged() {
    if (mounted) fetchReadingReport();
  }

  // =========================================================
  // [형호씨 작업 연결 공간 2: MySQL 데이터 GET 함수]
  // 형호씨가 Spring Boot 등으로 만든 API 주소를 아래에 넣으면 됩니다.
  // =========================================================
  // [형호 수정] 로컬 대여 목록 읽기
  Future<void> fetchReadingReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    ReadingReport? localReport;

    try {
      // 1. 기기에 저장된 기존 대여 목록 읽기
      final localBooks = await LoanBookStorage.instance.loadBooks();

      if (!mounted) return;

      setState(() {
        _loanBooks = localBooks;
      });

      localReport = ReadingReport.fromBooks(localBooks);

      // 2. 이 ZIP 백엔드의 GET/POST/PUT /api/books 경로로 동기화
      // 동기화 실패가 독서 리포트 조회까지 막지 않도록 별도로 처리합니다.
      try {
        await BaroBookBackendService.instance.syncLocalBooks(localBooks);
      } catch (syncError, stackTrace) {
        debugPrint('도서 동기화 실패: $syncError');
        debugPrint('$stackTrace');
      }

      // 3. Java 백엔드의 GET /api/reading-report 조회
      final data = await BaroBookBackendService.instance.getReadingReport();
      final completed = data['completedBooksCount'];
      final rating = data['averageRating'];
      final progress = data['progressPercent'];

      if (!mounted) return;

      setState(() {
        completedBooksCount = completed is num ? completed.toInt() : 0;
        averageRating = rating is num ? rating.toDouble() : 0.0;
        progressPercent = progress is num
            ? progress.toInt().clamp(0, 100).toInt()
            : 0;
        progressRatio = progressPercent / 100.0;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('독서 리포트 조회 실패: $error');
      debugPrint('$stackTrace');

      // 서버에 연결할 수 없으면 현재 기기의 기록을 표시합니다.
      if (!mounted) return;

      if (localReport != null) {
        setState(() {
          completedBooksCount = localReport!.completedBooksCount;
          averageRating = localReport!.averageRating;
          progressPercent = localReport!.progressPercent;
          progressRatio = localReport!.progressRatio;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // [흥수씨 & 정민씨 작업 연결 공간: 책 등록 바텀 시트]
  // =========================================================
  void _addBooks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF9F5),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '책 등록하기',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10,),
              // 내용: 도서 검색·등록 화면으로 이동할 수 있도록 라우팅을 연결한다.
              ListTile(
                tileColor: const Color(0xFFE8DED0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.search,size: 30,),
                title: const Text('검색해서 등록하기',style: TextStyle(fontSize: 18),),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, AppRoutes.searchRegister);
                },
              ),
              const Divider(thickness: 1, color: Colors.black12, ),
              ListTile(
                tileColor: const Color(0xFFE8DED0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.qr_code_scanner,size: 30,),
                title: const Text('바코드로 등록하기',style: TextStyle(fontSize: 18),),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, AppRoutes.scanner);
                },
              ),
              const Divider(thickness: 1, color: Colors.black12),
              ListTile(
                tileColor: const Color(0xFFE8DED0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.edit,size: 30,),
                title: const Text('직접 등록하기',style: TextStyle(fontSize: 18),),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.register,
                    arguments: {'readonly': false},
                  );
                },
              ),
              const Divider(thickness: 1, color: Colors.black12),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  //[작업 영역: 전체 UI 구조 및 디자인]
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final Color mainColor = const Color(0xFF1B3B6F);
    final Color subColor = const Color(0xFF98D7C2);
    final Color bgColor = const Color(0xFFF4F4F9);
    final Color cardColor = Colors.white;
    final currentlyReadingBooks = _loanBooks // [형호 추가] 읽는 중인 책」 목록
        .where((book) => book.isCurrentlyReading)
        .toList();

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

                // 등록된 읽는 중인 책 목록
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '읽는 중인 책',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('${currentlyReadingBooks.length}권'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (currentlyReadingBooks.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '아직 읽는 중인 책이 없어요.\n위에서 책을 등록해 보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        SizedBox(
                          height: 165,
                          // [형호 추가] 각 책의 제목과 저자, 진행률 표시
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: currentlyReadingBooks.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final book = currentlyReadingBooks[index];

                              return Container(
                                width: 150,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 30,
                                      color: mainColor,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      book.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author.isEmpty ? '저자 미상' : book.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    LinearProgressIndicator(
                                      value: book.readingProgress,
                                      color: mainColor,
                                      backgroundColor: Colors.black12,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '독서 진행률 ${book.readingProgressPercent}%',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 형호씨 MySQL 데이터가 화면에 뿌려지는 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '나의 독서 리포트',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      //[형호 추가] 완독 도서 수 / 평균 평점
                      Row(
                        children: [
                          // [형호 추가] 완독 도서 수
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '완독 도서 수',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isLoading ? '-' : '$completedBooksCount',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(
                                      Icons.menu_book,
                                      size: 40,
                                      color: mainColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // [형호 추가] 평균 평점
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '평균 평점',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          // [형호 추가] 평균 평점
                                          isLoading
                                              ? '-'
                                              : averageRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 2,
                                        ),
                                        child: Icon(
                                          Icons.star,
                                          size: 18,
                                          color: mainColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(
                                      Icons.show_chart,
                                      size: 40,
                                      color: mainColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // [형호 추가] 전체 독서 진행률 - 원형 게이지 하나만 표시
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 112,
                              height: 112,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: progressRatio.clamp(0.0, 1.0).toDouble(),
                                    strokeWidth: 10,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: Colors.black12,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(mainColor),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isLoading ? '-' : '$progressPercent%',
                                          style: TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold,
                                            color: mainColor,
                                          ),
                                        ),
                                        const Text(
                                          '진행률',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '전체 독서 진행률',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '등록된 책의 읽은 페이지를 합산한 비율이에요.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isLoading
                                        ? '독서 기록을 불러오는 중...'
                                        : '현재 $progressPercent% 읽었어요.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: mainColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
