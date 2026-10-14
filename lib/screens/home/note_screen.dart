import 'package:flutter/material.dart';

class NoteScreen extends StatefulWidget{
  const NoteScreen({super.key});

  @override
  State<StatefulWidget> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('노트 페이지'),
    );
  }

}