import 'package:flutter/material.dart';

class RewardScreen extends StatefulWidget{
  const RewardScreen({super.key});

  @override
  State<StatefulWidget> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("업적 페이지"),
    );
  }

}