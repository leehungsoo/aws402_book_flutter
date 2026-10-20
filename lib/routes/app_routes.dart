import 'package:aws402_book_flutter/screens/book_info_screen.dart';
import 'package:flutter/material.dart';

import '../screens/barcode_screen.dart';
import '../screens/home_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const home = "/home";
  static const scanner = "/scanner";
  static const bookInfo = "/bookInfo";
  static final Map<String, WidgetBuilder> routes = {
    home : (context)=>const HomeScreen(title: '홈스크린'),
    scanner : (context)=>const BarcodeScreen(title: '바코드 스캐너'),
    bookInfo : (context)=>const BookInfoScreen(title: '도서 정보'),
  };
}