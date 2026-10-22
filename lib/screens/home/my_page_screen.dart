import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aws402_book_flutter/screens/sign/login_screen.dart';
import 'package:aws402_book_flutter/screens/sign/edit_profile_screen.dart';
import 'package:aws402_book_flutter/screens/sign/target_book_screen.dart';
import 'package:aws402_book_flutter/screens/sign/book_statistics_screen.dart';
import '../home_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  User? currentUser;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();

  int targetBookCount = 0;
  int status = 0;
  int userGrade = 0; // (0: 일반유저, 1: 관리자)
  String userBio = '';
  DateTime? targetEndDate;
  String displayName = '사용자';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _initMyPageData();
    }
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: const Color(0xFFFAF9F5),
      borderRadius: BorderRadius.circular(16.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Future<void> _initMyPageData() async {
    setState(() => _isLoading = true);
    await _fetchUserDataFromApi();
    await _loadLocalData();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUserDataFromApi() async {
    currentUser = FirebaseAuth.instance.currentUser;
    displayName = currentUser?.displayName ?? '사용자';

    if (currentUser != null && currentUser!.email != null) {
      try {
        final response = await _dio.get(
          // 'http://10.0.2.2:8080/api/mypage/${currentUser!.email}',
          'api/mypage/${currentUser!.email}',
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          setState(() {
            targetBookCount = data['targetBookCount'] ?? 0;
            status = data['status'] ?? 0;
            displayName = data['name'] ?? displayName;
            userGrade = data['grade'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('API 데이터 조회 실패: $e');
      }
    }
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? imagePath = prefs.getString('profile_image_path');
    File? loadedImage;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) loadedImage = file;
    }

    final String loadedBio = prefs.getString('user_bio') ?? '';
    final String? dateString = prefs.getString('target_end_date');
    DateTime? loadedDate = dateString != null ? DateTime.tryParse(dateString) : null;

    setState(() {
      _imageFile = loadedImage;
      userBio = loadedBio;
      targetEndDate = loadedDate;
    });
  }

  Future<void> _updateTargetBookCountApi(int newTarget) async {
    if (currentUser == null || currentUser!.email == null) return;

    try {
      final response = await _dio.put(
        'http://10.0.2.2:8080/api/targetbook',
        data: {
          'email': currentUser!.email,
          'targetBookCount': newTarget,
          'grade': userGrade,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => targetBookCount = newTarget);
        showToast('목표 권수가 저장되었습니다.');
      } else {
        showToast('목표 권수 저장 실패');
      }
    } catch (e) {
      showToast('서버 통신 에러');
      debugPrint('Dio PUT 에러: $e');
    }
  }

  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF8B5A2B),
      textColor: Colors.white,
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final File selectedFile = File(pickedFile.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', selectedFile.path);

        setState(() => _imageFile = selectedFile);
        showToast('프로필 사진이 변경되었습니다.');
      }
    } catch (e) {
      showToast('이미지 불러오기 실패');
    }
  }

  String _calculateGrade(int count) {
    if (count >= 3000) return '💠 세계수';
    if (count >= 1000) return '🌲 숲';
    if (count >= 500) return '🌳 나무';
    if (count >= 200) return '🌿 줄기';
    if (count >= 100) return '🌿 새싹';
    return '🌱 씨앗';
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    showToast('로그아웃 되었습니다.');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen(title: 'BaroBook')),
          (route) => false,
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF9F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text('계정 관리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFFFAF9F5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('로그아웃', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      content: const Text('정말 로그아웃 하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('아니오', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _signOut();
                          },
                          child: const Text('네', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F0E6);
    const cardColor = Color(0xFFFAF9F5);
    const primaryColor = Color(0xFF8B5A2B);

    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('마이페이지', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: cardColor,
          elevation: 0,
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 70, color: primaryColor),
              const SizedBox(height: 16),
              const Text(
                '로그인이 필요한 서비스입니다.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final bool? loginSuccess = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen(title: 'BaroBook')),
                  );

                  if (loginSuccess == true && mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen(title: 'BaroBook')),
                          (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('로그인하러 가기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    String currentGrade = _calculateGrade(status);
    double progress = targetBookCount > 0 ? (status / targetBookCount).clamp(0.0, 1.0) : 0.0;
    int percentage = (progress * 100).toInt();

    String dateText = targetEndDate != null
        ? '${targetEndDate!.year}-${targetEndDate!.month.toString().padLeft(2, '0')}-${targetEndDate!.day.toString().padLeft(2, '0')}'
        : '';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor, width: 2.5),
                              color: Colors.grey[200],
                              image: _imageFile != null
                                  ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _imageFile == null
                                ? const Icon(Icons.person_rounded, size: 60, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        if (userGrade == 1) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: '관리자 계정',
                            child: Icon(
                              Icons.stars_rounded,
                              color: Color(0xFFFFB800),
                              size: 24,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userBio.isEmpty ? '등록된 한 줄 소개가 없습니다.' : userBio,
                      style: TextStyle(
                        fontSize: 13,
                        color: userBio.isEmpty ? Colors.grey[400] : Colors.grey[700],
                        fontStyle: userBio.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        // [수정완료] '완독' 글자 지우고 등급명만 깔끔하게 출력
                        '현재 등급: $currentGrade',
                        style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _buildCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('전체 독서 진행률', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          targetBookCount == 0
                              ? ''
                              : dateText.isNotEmpty
                              ? '목표: ${targetBookCount}권 (~$dateText)'
                              : '목표: ${targetBookCount}권',
                          style: const TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          // [수정완료] '목표미설정' 문구 제거 및 깔끔한 표현으로 통일
                          targetBookCount == 0 ? '목표를 설정해주세요.' : '총 ${targetBookCount}권 중 ${status}권 달성',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '$percentage%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: _buildCardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHorizontalMenuButton(
                      icon: Icons.person_outline,
                      title: '내 정보 수정',
                      onTap: () async {
                        final Map<String, dynamic>? updatedProfile = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              currentName: displayName,
                              currentBio: userBio,
                              currentGrade: userGrade,
                            ),
                          ),
                        );
                        if (updatedProfile != null) await _initMyPageData();
                      },
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: Colors.grey[300]),
                    _buildHorizontalMenuButton(
                      icon: Icons.flag_outlined,
                      title: '목표 설정',
                      onTap: () async {
                        final Map<String, dynamic>? result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TargetBookScreen(
                              initialTarget: targetBookCount,
                              status: status,
                              initialDate: targetEndDate,
                            ),
                          ),
                        );

                        if (result != null) {
                          final int newTarget = result['target'] ?? 0;
                          final DateTime? endDate = result['endDate'];

                          // 서버로 목표 권수 업데이트 전송
                          await _updateTargetBookCountApi(newTarget);

                          if (endDate != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('target_end_date', endDate.toIso8601String());
                            setState(() => targetEndDate = endDate);
                          }
                        }
                        // 설정 완료 후 화면 최신화
                        await _initMyPageData();
                      },
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: Colors.grey[300]),
                    _buildHorizontalMenuButton(
                      icon: Icons.bar_chart_rounded,
                      title: '읽은 책 통계',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookStatisticsScreen(
                              completedBooks: [],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalMenuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF8B5A2B)),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}