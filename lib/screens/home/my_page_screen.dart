import 'package:flutter/material.dart';

class MyPageScreen extends StatefulWidget{
  const MyPageScreen({super.key});

  @override
  State<StatefulWidget> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('마이 페이지'),
    );
  }

}