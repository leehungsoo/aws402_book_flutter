import 'package:aws402_book_flutter/routes/app_routes.dart';
import 'package:flutter/material.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<StatefulWidget> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  // 책등록 modal
  void _addBooks() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return
          SafeArea(child: Wrap(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('책 등록하기', style: TextStyle(fontSize: 24.0)),
                    ),
                    Divider(thickness: 1, color: Colors.black87),
                    Container(
                      padding: EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(Icons.search),
                                Text(
                                  '검색해서 등록하기',
                                  style: TextStyle(fontSize: 18.0),
                                ),
                              ],
                            ),
                          ),
                          Divider(),
                          Padding(
                            padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: GestureDetector(
                              // onTap: () => Navigator.popAndPushNamed(context, AppRoutes.scanner),
                              onTap: () => Navigator.popAndPushNamed(context, AppRoutes.bookInfo, arguments: {"barcode":"9791140715541"}),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Icon(Icons.qr_code_outlined),
                                  Text(
                                    '바코드로 등록하기',
                                    style: TextStyle(fontSize: 18.0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(),
                          Padding(
                            padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(Icons.keyboard),
                                Text('직접 입력하기', style: TextStyle(fontSize: 18.0)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return
        Container(
          decoration: BoxDecoration(color: Colors.yellow),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '어서오세요',
                            style: TextStyle(
                              fontSize: 36.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '읽고 있는 책을 등록해 볼까요?',
                            style: TextStyle(fontSize: 15.0),
                          ),
                        ],
                      ),
                      Spacer(),
                      Icon(Icons.settings, size: 36.0),
                    ],
                  ), //여기까지 상단 부분
                  SizedBox(height: 80.0),
                  GestureDetector(
                    onTap: _addBooks,
                    child: Container(
                      margin: EdgeInsets.only(left: 10.0, right: 10.0),
                      padding: EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                          bottomLeft: Radius.circular(16.0),
                          bottomRight: Radius.circular(96.0),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '책을 추가해 보세요.',
                            style: TextStyle(
                              fontSize: 24.0,
                              color: Colors.black45,
                            ),
                          ),
                          Text(
                            '읽고 있는 책이 있나요?',
                            style: TextStyle(color: Colors.black26),
                          ),
                          SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
