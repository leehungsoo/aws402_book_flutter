import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../routes/app_routes.dart';
import '../services/book_api.dart';

// 날짜: 2026-10-20
// 수정자: 구정민
// 내용: BarcodeScreen 클래스를 추가하거나 변경하여 관련 기능을 구현한다.
class BarcodeScreen extends StatefulWidget {
  final String title;

  const BarcodeScreen({super.key, required this.title});


  // 내용: createState 메서드에서 해당 화면 또는 데이터의 처리 로직을 구현한다.
  @override
  State<BarcodeScreen> createState() => _State();
}


// 내용: _State 클래스를 추가하거나 변경하여 관련 기능을 구현한다.
class _State extends State<BarcodeScreen> {
  bool busy = false;
  String? lastIsbn;
  final scanner = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );


  // 내용: detected 메서드에서 해당 화면 또는 데이터의 처리 로직을 구현
  // 바코드 중복 인식을 차단하고 ISBN 중복 확인 후 도서 등록 화면으로 이동한다.
  Future<void> detected(BarcodeCapture capture) async {
    if (busy || capture.barcodes.isEmpty) return;

    final isbn = capture.barcodes.first.rawValue?.trim() ?? '';
    if (isbn.isEmpty) return;

    // 같은 바코드를 계속 인식하면 다시 처리하지 않음
    if (lastIsbn == isbn) return;

    busy = true;
    lastIsbn = isbn;

    try {
      if (await BookApi.exists(isbn)) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('이미 등록된 책입니다.'),
              duration: Duration(seconds: 2),
            ),
          );

        return;
      }

      final book = await BookApi.byIsbn(isbn);

      if (!mounted) return;

      if (book == null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('카카오에서 해당 ISBN 도서를 찾을 수 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        return;
      }

      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.register,
        arguments: {
          'book': book,
          'readonly': true,
        },
      );
    } catch (e) {
      if (!mounted) return;

      // 통신 오류가 발생한 경우에는 같은 ISBN을 다시 시도할 수 있도록 초기화
      lastIsbn = null;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('조회 실패: $e')),
        );
    } finally {
      busy = false;
    }
  }


  // 내용: dispose 메서드에서 해당 화면 또는 데이터의 처리 로직을 구현한다.
  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }


  // 내용: 바코드 스캔 결과로 ISBN을 확인하고 도서 등록 흐름에 연결한다.
  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('바코드를 촬영해 주세요'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scanner,
            onDetect: detected,
          ),
          Center(
            child: Container(
              width: 260,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
