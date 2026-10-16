import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget{
  const SearchScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('검색 페이지'),
    );
  }

}