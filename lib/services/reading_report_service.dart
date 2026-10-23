import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/services/loan_book_storage.dart';

// [형호]
/// 홈 화면 '나의 독서 리포트'에 표시할 값(완독 도서 수, 평균 평점, 전체 독서 진행율).
class ReadingReport {
  const ReadingReport({
    required this.completedBooksCount,
    required this.averageRating,
    required this.ratedBooksCount,
    required this.progressPercent,
    required this.progressRatio,
  });

  const ReadingReport.empty()
      : completedBooksCount = 0,
        averageRating = 0.0,
        ratedBooksCount = 0,
        progressPercent = 0,
        progressRatio = 0.0;

  final int completedBooksCount;

  /// 별점을 매긴 완독 도서의 평균(소수 첫째 자리). 평점이 하나도 없으면 0.0.
  final double averageRating;
  final int ratedBooksCount;
  final int progressPercent;

  /// 진행율 막대 비율 (0.0 ~ 1.0)
  final double progressRatio;

  bool get hasRating => ratedBooksCount > 0;

  /// 대여 목록(로컬)으로 리포트를 계산
  factory ReadingReport.fromBooks(List<LoanBook> books) {
    final completed = books.where((book) => book.isCompleted).toList();

    final rated = completed.where((book) => book.rating > 0).toList();
    final ratingSum = rated.fold<int>(0, (sum, book) => sum + book.rating);
    final average = rated.isEmpty
        ? 0.0
        : double.parse((ratingSum / rated.length).toStringAsFixed(1));

    var totalPages = 0;
    var readPages = 0;
    for (final book in books) {
      if (book.totalPages <= 0) continue;
      totalPages += book.totalPages;
      readPages += book.currentPage.clamp(0, book.totalPages).toInt();
    }
    final ratio = totalPages == 0 ? 0.0 : readPages / totalPages;

    return ReadingReport(
      completedBooksCount: completed.length,
      averageRating: average,
      ratedBooksCount: rated.length,
      progressPercent: (ratio * 100).round(),
      progressRatio: ratio,
    );
  }
}

class ReadingReportService {
  const ReadingReportService._();

  /// 기기에 저장된 대여/독서 데이터로 리포트를 만듬.
  static Future<ReadingReport> load() async {
    final books = await LoanBookStorage.instance.loadBooks();
    return ReadingReport.fromBooks(books);
  }
}
