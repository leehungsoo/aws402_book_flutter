import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookStatisticsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? completedBooks;

  const BookStatisticsScreen({
    super.key,
    this.completedBooks,
  });

  @override
  State<BookStatisticsScreen> createState() => _BookStatisticsScreenState();
}

class _BookStatisticsScreenState extends State<BookStatisticsScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = false;
  final Dio _dio = Dio();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    _books = widget.completedBooks ?? [];
    _fetchCompletedBooksFromApi();
  }

  Future<void> _fetchCompletedBooksFromApi() async {
    if (currentUser?.email == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get(
        '/api/bookstatistics',
        queryParameters: {'email': currentUser!.email},
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> rawList = response.data;
        setState(() {
          _books = rawList.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      debugPrint('완독 도서 통계 데이터 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateThisMonthBooks(List<Map<String, dynamic>> books) {
    final now = DateTime.now();
    int count = 0;
    for (var book in books) {

      if (book['finish_date'] != null) {
        try {
          DateTime finishDate = DateTime.parse(book['finish_date'].toString());
          if (finishDate.year == now.year && finishDate.month == now.month) {
            count++;
          }
        } catch (e) {
          debugPrint('날짜 파싱 오류 발생(${book['finish_date']}): $e');
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F0E6);
    const cardColor = Color(0xFFFAF9F5);
    const primaryColor = Color(0xFF8B5A2B);

    int totalCompleted = _books.length;
    int thisMonthCompleted = _calculateThisMonthBooks(_books);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          '읽은 책 통계',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '완독 통계 요약',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('총 완독 도서', '$totalCompleted권', primaryColor),
                      _buildStatItem('이번 달 독서', '$thisMonthCompleted권', primaryColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '완독 도서 리스트',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _books.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '아직 완료된 독서 기록이 없습니다.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  final book = _books[index];
                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: primaryColor),
                      title: Text(
                        book['title']?.toString() ?? '제목 없음',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '완독일: ${book['finish_date']?.toString().split(' ')[0] ?? '정보 없음'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}