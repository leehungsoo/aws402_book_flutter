// [형호 추가] StreamSubscription<User?> 자료형 사용
import 'dart:async';
// [형호 추가] Firebase 로그인 상태 및 이메일 인증 여부를 확인하는 데 사용
import 'package:firebase_auth/firebase_auth.dart';
// [형호 추가] 로그인 버튼을 눌렀을 때 로그인 화면을 열기 위해 사용
import 'package:aws402_book_flutter/screens/sign/login_screen.dart';
// [형호 추가] 회원가입 버튼을 눌렀을 때 회원가입 화면을 열기 위해 사용
import 'package:aws402_book_flutter/screens/sign/signup_screen.dart';
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
  bool _authChecked = false; // [형호 추가] Firebase에서 최초 인증 상태를 확인했는지 여부
  bool _isAuthenticated = false; // [형호 추가] 현재 사용자가 로그인했고 이메일 인증도 완료했는지 여부

  late final StreamSubscription<User?> _authSubscription; // [형호 추가] Firebase 인증 상태 변경을 감지하는 구독 객체

  final List<Widget> _pages = [
    const BookScreen(), // 홈
    const NoteScreen(), // 나의 독서 기록
    const MyPageScreen(), // 마이페이지
  ];

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home, 'label': '홈'},
    {'icon': Icons.menu_book, 'label': '나의 독서 기록'},
    {'icon': Icons.person_outline, 'label': '마이페이지'},
  ];

  // [형호 추가] 인증 상태 감시
  @override
  void initState() {
    super.initState();

    // Firebase 인증 상태를 감지
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      setState(() {
        _authChecked = true;
        _isAuthenticated = user != null && user.emailVerified;
      });
    });
  }

  // [형호 추가] 인증 구독 정리
  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // [형호 추가] 로그인 화면 열기(로그인 성공 여부는 Firebase 인증 상태 구독을 통해 화면에 반영)
  Future<void> _openLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(title: 'BaroBook')),
    );
  }

  // [형호 추가] 회원가입 화면 열기
  Future<void> _openSignUp() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  // [형호 추가] 로그인하지 않은 사용자에게 보여 줄 화면
  Widget _buildLoginRequiredScreen() {
    const primaryColor = Color(0xFF8B5A2B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: primaryColor),
                const SizedBox(height: 20),
                const Text(
                  '로그인이 필요한 서비스입니다.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  '회원가입 후 로그인하면 홈과 나의 독서 기록을 이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _openLogin();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _openSignUp();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('회원가입'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [형호 추가] Firebase 인증 상태를 아직 확인하지 못했을 때
    if (!_authChecked) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // [형호 추가] 로그인하지 않았거나 이메일 인증이 완료되지 않았을 때
    if (!_isAuthenticated) {
      return _buildLoginRequiredScreen();
    }

    // 로그인된 사용자에게만 기존 앱을 표시한다.
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
              Icon(_navItems[index]['icon'], size: 24.0, color: color),
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
