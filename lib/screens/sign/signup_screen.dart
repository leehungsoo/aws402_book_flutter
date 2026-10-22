import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// 공통 토스트 메시지 함수
void showToast(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: const Color(0xFF1FC1C3),
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 폼 유효성 검사 키
  final _formKey = GlobalKey<FormState>();

  // 입력값 저장 변수들
  String password = '';
  String confirmPassword = '';
  String name = '';
  String emailId = '';
  String emailDomain = 'naver.com';
  int targetBookCount = 10; // 초기값 10

  final Dio _dio = Dio(); // 서버 통신용 Dio 인스턴스

  // 입력창 테두리 스타일 생성기
  OutlineInputBorder _buildInputBorder(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // 백엔드 서버 DB(tb_users)에 회원 정보 및 토큰 저장 요청
  Future<bool> registerUserToBackend(String email, String pwd, String userName, int targetCount, String? firebaseToken, String? fcmToken) async {
    try {
      // 애뮬레이터
      // const url = 'http://10.0.2.2:8080/api/signup';
      // 실제기기
      const url = '/api/signup';

      final response = await _dio.post(
        url,
        data: {
          'name': userName,
          'email': email,
          'password': pwd,
          'target_book_count': targetCount,
          'grade': 0,
          'token': fcmToken,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('백엔드 DB 저장 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('백엔드 API 통신 에러: $e');
      return false;
    }
  }

  // Firebase 회원가입 및 이메일 인증 처리 + 백엔드 연동
  void signUp() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (password != confirmPassword) {
      showToast('비밀번호가 일치하지 않습니다.');
      return;
    }

    String fullEmail = '$emailId@$emailDomain';

    try {
      // Firebase Authentication 계정 생성
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: fullEmail, password: password);

      if (userCredential.user != null) {
        // 파이어베이스 유저 이름 업데이트 및 인증 메일 발송
        await userCredential.user?.updateDisplayName(name);
        await userCredential.user?.sendEmailVerification();

        // 파이어베이스 ID 토큰 (인증용)
        String? firebaseToken = await userCredential.user?.getIdToken();

        // 기기의 FCM 푸시 알림 토큰 획득
        String? fcmToken = await FirebaseMessaging.instance.getToken();

        // 백엔드 DB(tb_users)에 유저 정보 및 토큰 전송
        bool isBackendSaved = await registerUserToBackend(fullEmail, password, name, targetBookCount, firebaseToken, fcmToken);

        if (!isBackendSaved) {
          showToast('파이어베이스 가입은 완료되었으나 서버 DB 저장에 실패했습니다.');
        }

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF9F5),
              title: const Text('회원가입 완료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: const Text(
                '입력하신 이메일로 인증 메일이 발송되었습니다. \n\n'
                    '이메일 인증을 완료하신 후\n'
                    '로그인 해주세요!',
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('확인', style: TextStyle(color: Color(0xFF1FC1C3), fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      }
      // 가입 시 에러처리
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        showToast('비밀번호는 6자 이상이어야 합니다.');
      } else if (e.code == 'email-already-in-use') {
        showToast('이미 사용 중인 이메일(아이디)입니다.');
      } else if (e.code == 'invalid-email') {
        showToast('올바른 이메일 형식이 아닙니다.');
      } else {
        showToast('회원 가입 중 오류가 발생했습니다: ${e.message}');
      }
    } catch (e) {
      debugPrint('오류 발생 : ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1FC1C3);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
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
                    const Text(
                      '회원가입',
                      style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      '회원님의 가입을 진심으로 환영합니다!',
                      style: TextStyle(fontSize: 13.0, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 28.0),

                    // 이메일 아이디 & 도메인 선택 영역
                    const Text('로그인 이메일 (아이디)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: '이메일 아이디',
                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: _buildInputBorder(Colors.grey[300]!),
                              focusedBorder: _buildInputBorder(primaryColor, width: 2.0),
                            ),
                            onChanged: (value) => emailId = value,
                            validator: (value) => (value == null || value.isEmpty) ? '이메일을 입력해주세요.' : null,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text('@', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<String>(
                            value: emailDomain,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: _buildInputBorder(Colors.grey[300]!),
                              focusedBorder: _buildInputBorder(primaryColor, width: 2.0),
                            ),
                            items: ['naver.com', 'gmail.com', 'daum.net', 'nate.com']
                                .map((domain) => DropdownMenuItem(value: domain, child: Text(domain, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                emailDomain = value ?? 'naver.com';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // 비밀번호 입력 필드
                    const Text('비밀번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '비밀번호 입력 (6자 이상)',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: _buildInputBorder(Colors.grey[300]!),
                        focusedBorder: _buildInputBorder(primaryColor, width: 2.0),
                      ),
                      onSaved: (value) => password = value ?? '',
                      validator: (value) {
                        if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
                        if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // 비밀번호 확인 필드
                    const Text('비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '비밀번호 재입력',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: _buildInputBorder(Colors.grey[300]!),
                        focusedBorder: _buildInputBorder(primaryColor, width: 2.0),
                      ),
                      onSaved: (value) => confirmPassword = value ?? '',
                      validator: (value) {
                        if (value == null || value.isEmpty) return '비밀번호를 다시 입력해주세요.';
                        if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // 이름 또는 별명 입력 필드
                    const Text('이름 또는 별명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: '이름 또는 별명을 입력해주세요',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: _buildInputBorder(Colors.grey[300]!),
                        focusedBorder: _buildInputBorder(primaryColor, width: 2.0),
                      ),
                      onSaved: (value) => name = value ?? '',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름 또는 별명을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32.0),

                    // 하단 버튼 영역 (가입하기 / 뒤로가기)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              child: const Text('가입하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[600],
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              child: const Text('뒤로가기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}