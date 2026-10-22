import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final int currentGrade;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    this.currentGrade = 0,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _passwordController;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Dio _dio = Dio();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF8B5A2B),
      textColor: Colors.white,
    );
  }

  // 백엔드 API 서버 (tb_users) 정보 수정 요청
  Future<bool> _updateProfileToBackend({
    required String name,
    required String password,
  }) async {
    if (currentUser?.email == null) return false;

    try {
      // 애뮬레이터
      // const url = 'http://10.0.2.2:8080/api/editprofile';
      // 실제기기
      const url = '/api/editprofile';

      final Map<String, dynamic> requestData = {
        'email': currentUser!.email,
        'name': name,
        'grade': widget.currentGrade,
      };

      // 비밀번호 변경란을 작성한 경우에만 서버 전송 항목에 포함
      if (password.isNotEmpty) {
        requestData['password'] = password;
      }

      final response = await _dio.put(
        url,
        data: requestData,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('백엔드 프로필 수정 에러: $e');
      return false;
    }
  }

  Future<void> _saveProfile() async {
    final String newName = _nameController.text.trim();
    final String newBio = _bioController.text.trim();
    final String newPassword = _passwordController.text.trim();

    if (newName.isEmpty) {
      _showToast('이름(별명)을 입력해주세요.');
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      _showToast('비밀번호는 6자리 이상이어야 합니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 파이어베이스 Auth 정보 업데이트 (이름 & 비밀번호)
      if (currentUser != null) {
        if (newName != currentUser!.displayName) {
          await currentUser!.updateDisplayName(newName);
        }
        if (newPassword.isNotEmpty) {
          await currentUser!.updatePassword(newPassword);
        }
      }

      // 2. 백엔드 서버 DB (tb_users) 정보 업데이트 요청 (grade 포함)
      bool isBackendUpdated = await _updateProfileToBackend(
        name: newName,
        password: newPassword,
      );

      if (!isBackendUpdated) {
        _showToast('서버 데이터 업데이트에 실패했습니다.');
      }

      // 3. 로컬 저장소(SharedPreferences)에 한줄소개 기록
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_bio', newBio);

      if (!mounted) return;

      _showToast('내 정보가 성공적으로 수정되었습니다!');

      // 마이페이지로 변경된 이름과 한 줄 소개 전달
      Navigator.pop(context, {
        'name': newName,
        'user_bio': newBio,
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showToast('비밀번호 변경을 위해 다시 로그인해 주세요.');
      } else {
        _showToast('인증 정보 수정 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showToast('정보 수정 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F0E6);
    const cardColor = Color(0xFFFAF9F5);
    const primaryColor = Color(0xFF8B5A2B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          '내 정보 수정',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내 계정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 이름 (별명) 수정
                  const Text('이름 (별명)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 한 줄 소개 입력 및 수정
                  const Text('한 줄 소개', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bioController,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: '한 줄 소개를 입력해보세요',
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 변경
                  const Text('새 비밀번호 변경', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '변경할 경우에만 입력해주세요 (6자리 이상)',
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 저장 버튼
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(50),
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
                      '수정사항 저장하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}