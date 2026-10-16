import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:aws402_book_flutter/screens/home/book_screen.dart';
import 'package:aws402_book_flutter/screens/home/my_page_screen.dart';
import 'package:aws402_book_flutter/screens/home/search_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget{
  final String title;
  const HomeScreen({super.key, required this.title});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>{

  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BookScreen(),
    const SearchScreen(),
    const MyPageScreen(),
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.search,
    Icons.manage_accounts_outlined,
  ];

  final List<String> _titles = [
    '홈',
    '도서검색',
    '마이 페이지'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   title: Text(widget.title),
      //
      //   actions: <Widget>[
      //     Padding(
      //       padding: EdgeInsets.all(20.0),
      //       child: GestureDetector(
      //         onTap: (){},
      //         child: Icon(Icons.list),
      //       ),
      //     )
      //   ],
      // ),
      body: _pages[_currentIndex],
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: _icons.length,
        tabBuilder: (index, isActive) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icons[index],
                size: isActive ? 30.0 : 25.0,
                color: isActive ? Colors.teal : Colors.grey,
              ),
              Text(
                _titles[index],
                style: TextStyle(
                  fontSize: 12.0,
                ),
              )
            ],
          );
        },
        activeIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 32,
        rightCornerRadius: 32,
      ),
    );
  }

}