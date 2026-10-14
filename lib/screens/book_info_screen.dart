import 'dart:io';

import 'package:aws402_book_flutter/models/book_model.dart';
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
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        '${kakaoDocumentItem.title}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 20.0,
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            kakaoDocumentItem.thumbnail,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kakaoDocumentItem.authors),
              Text(kakaoDocumentItem.publisher)
            ],
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
      appBar: AppBar(
        actions: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Icon(Icons.star),
          ),
        ],
      ),
      body:
        isLoading ?
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
        )
    );
  }

}