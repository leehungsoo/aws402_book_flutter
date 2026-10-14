import 'dart:io';

import 'package:aws402_book_flutter/models/kakao_book_model.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BookInfoScreen extends StatefulWidget{
  final String title;
  const BookInfoScreen({super.key, required this.title});



  @override
  State<StatefulWidget> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> {
  bool isLoading = true;
  List<KakaoDocumentItem> kakaoDocumentItems = [];

  final options = BaseOptions(
      baseUrl: 'https://dapi.kakao.com/v3/search/book',
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 3),
      headers: {
        Headers.contentTypeHeader: Headers.jsonContentType,
        Headers.acceptHeader: Headers.jsonContentType,
        HttpHeaders.authorizationHeader: 'KakaoAK ${dotenv.env['BOOK_API_KEY']}'
      }
  );
  late Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(options);
  }

  @override
  void dispose() {
    super.dispose();
    _dio.close();
  }

  Future<Widget> _getBookInfo(String? barcode) async {
    try {
      Response response = await _dio.get(
          '',
          queryParameters: {
            'target': 'isbn',
            'query': barcode,
          }
      );
      if (response.statusCode == 200) {
        var data = response.data;
        print('$data');
        print(data['documents'].runtimeType);
        final List<dynamic> kakaoDocuments = data['documents'];
        print('kakaoDocuments $kakaoDocuments');
        final List<KakaoDocumentItem> kakaoDocumentItems = kakaoDocuments.map((
            item) => KakaoDocumentItem.fromJson(jsonData: item)).toList();
        print(kakaoDocumentItems.length);
        setState(() => this.kakaoDocumentItems = kakaoDocumentItems);
      }
    } catch (e, s) {
      debugPrint('$e, $s');
    } finally {
      setState(() {
        isLoading = false;
      });
    }

    return Center(
      child: Text('도서 정보가 없습니다.'),
    );
  }

  Widget bookInfoWidget() {
  KakaoDocumentItem kakaoDocumentItem = kakaoDocumentItems[0];

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${kakaoDocumentItem.title}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 30.0,
          fontWeight: FontWeight.bold
        ),
      ),
      SizedBox(height: 10.0,),
      Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: Image.network(
              kakaoDocumentItem.thumbnail,
              width: 100,
              fit: BoxFit.fitWidth,
            ),
          ),
          SizedBox(width: 10.0,),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kakaoDocumentItem.authors,),
                  SizedBox(height: 10.0,),
                  Text(kakaoDocumentItem.publisher)
                ],
              )
          ),
        ],
      )

    ],
  );
}

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String barcode = arguments["barcode"] as String;

    if(isLoading)_getBookInfo(barcode);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          margin: EdgeInsets.only(right: 16.0),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(Icons.star),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
      body:
        Stack(
          children: [
            Container(
              height: 200,
              margin: EdgeInsets.only(right: 16.0),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(40.0))
              ),
            ),
            Container(
              padding: EdgeInsets.all(20.0),
              child: isLoading ?
              Center(
                child: CircularProgressIndicator(),
              )
                  :
              kakaoDocumentItems.isNotEmpty ?
              SingleChildScrollView(
                child: Center(
                  child: bookInfoWidget(),
                ),
              )
                  :
              Center(
                child: Text('찾으시는 도서가 존재하지 않습니다.'),
              ),
            ),
          ],
        ),


    );
  }

}