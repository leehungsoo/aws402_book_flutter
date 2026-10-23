import 'package:aws402_book_flutter/screens/home/book_screen.dart';
import 'package:aws402_book_flutter/screens/sign/signup_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.title});

  final String title;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 3),
      baseUrl: dotenv.env['API_BASE_URL']??''
    )
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF1FC1C3),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Dio 이용. 백엔드 서버에 로그인 정보, 인증 토큰, FCM 토큰 전송
  Future<Map<String, dynamic>?> _fetchUserInfo(
      String email,
      String password,
      String? firebaseToken,
      String? fcmToken,
      ) async {
    try {
      final response = await _dio.post(
        // 애뮬레이터
        // 'http://10.0.2.2:8080/api/login',
        // 실제기기
        '/user/exists',
        data: {
          'email': email,
          'password':password,
          // 'token': firebaseToken,
          // 'fcmToken': fcmToken,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        _fetchFcmToken(response.data['data']['idx'], fcmToken!);
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('백엔드 유저 정보 조회 오류: $e');
    }
    return null;
  }
  Future<void> _fetchFcmToken(int idx, String fcmToken) async {
    print('idx : $idx');
    print('fcmToken : $fcmToken');
    await _dio.put('/user/token',
        data: {
          'idx':idx,
          'token': fcmToken,
        });
  }
  void _signIn() async {
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // 파이어베이스 인증 로그인
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 이메일 인증 여부 확인
      if (userCredential.user != null && userCredential.user!.emailVerified) {
        // 로그인 성공 직후 파이어베이스 ID 토큰 가져오기 (인증용)
        String? firebaseToken = await userCredential.user?.getIdToken();
        print(' 파이어베이스 ID 토큰 확인 : $firebaseToken');
        // 기기의 최신 FCM 푸시 알림 토큰 가져오기
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        print(' fcm 토큰 확인 : $fcmToken');
        // 백엔드 연동 데이터 체크 및 두 토큰 모두 전송
        await _fetchUserInfo(email, password, firebaseToken, fcmToken);

        if (!mounted) return;

        _showToast('로그인 성공!');

         Navigator.pop(context, true);

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const BookScreen()),
        // );
      } else {
        _showToast('사용자 Email 인증을 확인해주세요.');
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String msg = '이메일 또는 비밀번호가 올바르지 않습니다.';
      if (e.code == 'invalid-email') {
        msg = '유효하지 않은 이메일 형식입니다.';
      }
      _showToast(msg);
    } catch (e) {
      _showToast('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1FC1C3);
    const brandBrownColor = Color(0xFF8B5A2B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40.0),
                const Text(
                  'BaroBook',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: brandBrownColor,
                    fontSize: 34.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 30.0),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F5),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: '이메일 (아이디)',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: primaryColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14.0,
                              horizontal: 16.0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2.0,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.0,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? '이메일을 입력하세요'
                              : null,
                        ),
                        const SizedBox(height: 12.0),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '비밀번호',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: primaryColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14.0,
                              horizontal: 16.0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2.0,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.0,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? '비밀번호를 입력하세요'
                              : null,
                        ),
                        const SizedBox(height: 20.0),
                        SizedBox(
                          height: 50.0,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              if (_formKey.currentState?.validate() ??
                                  false) {
                                _signIn();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandBrownColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text(
                              '로그인',
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: '계정이 없으신가요? ',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13.0,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: '회원가입하기',
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}