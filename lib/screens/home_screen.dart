import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:aws402_book_flutter/routes/app_routes.dart';
import 'package:aws402_book_flutter/screens/home/book_screen.dart';
import 'package:aws402_book_flutter/screens/home/my_page_screen.dart';
import 'package:aws402_book_flutter/screens/home/note_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final String title;
  const HomeScreen({super.key, required this.title});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BookScreen(),     // 홈
    const NoteScreen(),     // 나의 독서 기록
    const MyPageScreen(),   // 마이페이지
  ];

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home, 'label': '홈'},
    {'icon': Icons.menu_book, 'label': '나의 독서 기록'},
    {'icon': Icons.person_outline, 'label': '마이페이지'},
  ];

  @override
  Widget build(BuildContext context) {
    final Color mainColor = const Color(0xFF1B3B6F); // 딥 네이비

    return Scaffold(
      body: _pages[_currentIndex],

      // 3. 우측 하단 동그란 버튼 (세로 줄무늬 ISBN 바코드)
      floatingActionButton: FloatingActionButton(
        backgroundColor: mainColor,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.scanner);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 3, height: 22, color: Colors.white),
            const SizedBox(width: 2),
            Container(width: 1, height: 22, color: Colors.white),
            const SizedBox(width: 3),
            Container(width: 4, height: 22, color: Colors.white),
            const SizedBox(width: 2),
            Container(width: 2, height: 22, color: Colors.white),
            const SizedBox(width: 3),
            Container(width: 1, height: 22, color: Colors.white),
            const SizedBox(width: 2),
            Container(width: 3, height: 22, color: Colors.white),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: _navItems.length,
        tabBuilder: (index, isActive) {
          final color = isActive ? mainColor : Colors.grey;
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _navItems[index]['icon'],
                size: 24.0,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                _navItems[index]['label'],
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        },
        activeIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
      ),
    );
  }
}