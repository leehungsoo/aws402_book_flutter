import 'package:aws402_book_flutter/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScreen extends StatefulWidget {
  final String title;
  const BarcodeScreen({super.key, required this.title});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final double boxWidth = 250.0;
  final double boxHeight = 200.0;
  Barcode? _barcode;

  Widget _barcodePreview(Barcode? value) {
    if (value == null) {
      return const Text(
        'Scan something!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'No display value.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
        Navigator.popAndPushNamed(
          context,
          AppRoutes.bookInfo,
          arguments: {"barcode": barcodes.barcodes.firstOrNull?.displayValue},
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 1. 애니메이션 컨트롤러 설정 (2초 동안 위에서 아래로 이동)
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 2. 0.0(맨 위)에서 1.0(맨 아래)까지 부드럽게 움직이도록 설정
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 3. 위아래로 무한 반복 실행
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('바코드를 촬영해 주세요')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black38, // 외부 영역 색상 및 투명도
              BlendMode.srcOut, // 안쪽 네모를 제외한 바깥쪽만 색을 칠함
            ),
            child: Stack(
              children: [
                // 투명한 배경을 전체에 깔아줍니다.
                Container(
                  color: Colors.transparent,
                ),
                // 가운데 뚫어줄 네모 영역의 크기와 위치를 잡습니다.
                Center(
                  child: Container(
                    width: boxWidth,
                    height: boxHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2), // 하얀색 테두리
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      // 정상적으로 계산되도록 수정된 부분
                      final double currentTop = _animation.value * boxHeight;

                      return Positioned(
                        top: currentTop,
                        left: 0,
                        right: 0,
                        child: child!,
                      );
                    },
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(200),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}