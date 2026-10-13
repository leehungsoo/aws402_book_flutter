import 'package:aws402_book_flutter/models/book_model.dart';
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

  final options = BaseOptions(
    baseUrl: 'https://apis.data.go.kr/1371029/BookInformationService_v2',
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 3),
    // headers: {
    //   Headers.contentTypeHeader : Headers.jsonContentType,
    //   Headers.acceptHeader : Headers.jsonContentType,
    // }
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

    try{
      Response response = await _dio.get(
        '/getbookList_v2?serviceKey=${dotenv.env['BOOK_API_KEY']}&pageNo=1&numOfRows=10&type=json&isbn=$barcode',
      );
      if(response.statusCode == 200){
        var data = response.data;
        BookHeader bookHeader = BookHeader.fromJson(jsonData: data["header"]);
        BookBody bookBody = BookBody.fromJson(jsonData: data["body"]);
        return Center(

        );
      }
    }catch(e, s){
      debugPrint('$e, $s');
    }

    return Center(
      child: Text('도서 정보가 없습니다.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String barcode = arguments["barcode"] as String;


    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Icon(Icons.star),
          ),
        ],
      ),
      body: SingleChildScrollView(

      ),
    );
  }

}