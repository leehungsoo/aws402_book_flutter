import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookStatisticsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? completedBooks;
  final int targetBookCount;

  const BookStatisticsScreen({
    super.key,
    this.completedBooks,
    this.targetBookCount = 0,
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

  // 서버로부터 최신 완독 리스트를 실시간으로 불러옴
  Future<void> _fetchCompletedBooksFromApi() async {
    if (currentUser?.email == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get(
        // 'http://10.0.2.2:8080/api/bookstatistics',
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

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F0E6);
    const cardColor = Color(0xFFFAF9F5);
    const primaryColor = Color(0xFF8B5A2B);

    int totalCompleted = _books.length;
    int remainingBooks = widget.targetBookCount > 0
        ? (widget.targetBookCount - totalCompleted).clamp(0, widget.targetBookCount)
        : 0;

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
        actions: [
          // 다른 페이지에서 완독 처리 후 바로 최신화할 수 있도록 수동 새로고침 버튼 제공
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _fetchCompletedBooksFromApi,
            tooltip: '새로고침',
          ),
        ],
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
                      _buildStatItem(
                        widget.targetBookCount > 0 ? '목표 남은 권수' : '설정된 목표',
                        widget.targetBookCount > 0 ? '$remainingBooks권' : '미설정',
                        primaryColor,
                      ),
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
                      // 저자, 대여일, 완독일 표시
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('저자: ${book['author']?.toString() ?? '정보 없음'}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          Text('대여일: ${book['rentSDate']?.toString().split(' ')[0] ?? '정보 없음'}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          Text('완독일: ${book['finishDate']?.toString().split(' ')[0] ?? '정보 없음'}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                      isThreeLine: true,
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