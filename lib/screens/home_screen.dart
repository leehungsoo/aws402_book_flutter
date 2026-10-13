import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:aws402_book_flutter/screens/home/book_screen.dart';
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
    const Center(child: Icon(Icons.woman),),
    const Center(child: Icon(Icons.wallet),),
    const Center(child: Icon(Icons.beach_access),),

  ];

  final List<IconData> _icons = [
    Icons.menu_book,
    Icons.light,
    Icons.grade,
    Icons.manage_accounts_outlined,
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
          return Icon(
            _icons[index],
            size: isActive ? 40.0 : 28.0,
            color: isActive ? Colors.teal : Colors.grey,
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
      // bottomNavigationBar: NavigationBar (
      //   selectedIndex: _currentIndex,
      //   onDestinationSelected: (index) {
      //     setState(() => _currentIndex = index);
      //   },
      //   destinations: [
      //     NavigationDestination(
      //       icon: Icon(Icons.man),
      //       label: '',
      //     ),
      //     NavigationDestination(
      //       icon: Icon(Icons.woman),
      //       label: '',
      //     ),
      //     NavigationDestination(
      //       icon: Icon(Icons.wallet),
      //       label: '',
      //     ),
      //     NavigationDestination(
      //       icon: Icon(Icons.beach_access),
      //       label: '',
      //     ),
      //   ],
      // ),
    );
  }

}