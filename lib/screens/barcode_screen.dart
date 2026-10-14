import 'package:aws402_book_flutter/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class BarcodeScreen extends StatefulWidget{
  final String title;
  const BarcodeScreen({super.key, required this.title});

  @override
  State<StatefulWidget> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
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
        Navigator.popAndPushNamed(context, AppRoutes.bookInfo, arguments: {"barcode" : barcodes.barcodes.firstOrNull?.displayValue});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('바코드를 촬영해 주세요')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              height: 100,
              color: Colors.black12,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: 100,
              color: Colors.black12,
            ),
          ),
          // Align(
          //   alignment: Alignment.center,
          //   child: Container(
          //     width: 1,
          //     height: double.infinity,
          //     color: Colors.red,
          //   ),
          // ),
          // Align(
          //   alignment: Alignment.bottomCenter,
          //   child: Container(
          //     alignment: Alignment.bottomCenter,
          //     height: 100,
          //     color: const Color.fromRGBO(0, 0, 0, 0.4),
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //       children: [
          //         Expanded(child: Center(child: _barcodePreview(_barcode))),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
