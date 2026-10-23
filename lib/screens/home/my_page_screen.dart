import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aws402_book_flutter/screens/sign/login_screen.dart';
import 'package:aws402_book_flutter/screens/sign/edit_profile_screen.dart';
import 'package:aws402_book_flutter/screens/sign/target_book_screen.dart';
import 'package:aws402_book_flutter/screens/sign/book_statistics_screen.dart';
import '../home_screen.dart';
// [형호 추가]
import 'package:aws402_book_flutter/services/reading_goal_storage.dart';
import 'package:aws402_book_flutter/models/loan_book_model.dart';
import 'package:aws402_book_flutter/services/loan_book_storage.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  User? currentUser;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // [형호 수정] 서버 주소에서 API 기본 경로를 설정
  String _resolveApiBaseUrl() {
    final configured = dotenv.env['API_BASE_URL']?.trim();
    final fallback = dotenv.env['CUSTOM_API_SERVER']?.trim() ?? '';

    final base = (configured != null && configured.isNotEmpty)
        ? configured
        : fallback;

    if (base.isEmpty) {
      throw StateError('API_BASE_URL이 .env에 설정되지 않았습니다.');
    }

    final normalized = base.replaceAll(RegExp(r'/+$'), '');
    final path = Uri.parse(normalized).path;

    // 주소에 /api가 이미 있으면 중복으로 붙이지 않는다.
    final apiBase =
    path.endsWith('/api') ? normalized : '$normalized/api';

    return '$apiBase/';
  }

  // [형호 수정] 백엔드 서버 통신용 Dio
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _resolveApiBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  int targetBookCount = 0;
  int status = 0;
  int userGrade = 0; // (0: 일반유저, 1: 관리자)
  List<LoanBook> _loanBooks = []; // [형호 추가] 로컬 도서 목록
  int readBookCount = 0; // [형호 추가] 화면에 표시할 완독 권수
  int _serverReadBookCount = 0; // [형호 추가] 서버에서 받아온 완독 권수
  String userBio = '';
  DateTime? targetEndDate;
  String displayName = '사용자';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // [형호 추가] 도서 등록·수정·반납 시 마이페이지 갱신
    LoanBookStorage.instance.changes.addListener(_refreshLoanBooks);
    _refreshLoanBooks();

    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      _initMyPageData();
    } else {
      _loadLocalData();
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

  // [형호 수정] 기존의 API 조회 흐름을 유지하면서, 화면이 종료된 후 setState()를 호출하는 문제를 방지
  Future<void> _initMyPageData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    await _fetchUserDataFromApi();
    await _loadLocalData();

    if (!mounted) return;

    setState(() => _isLoading = false);
  }

  // [형호 수정]
  Future<void> _fetchUserDataFromApi() async {
    currentUser = FirebaseAuth.instance.currentUser;
    displayName = currentUser?.displayName ?? '사용자';

    final email = currentUser?.email;
    if (email == null || email.isEmpty) return;

    try {
      final response = await _dio.get<dynamic>(
        '/user/exists',
        queryParameters: {'email': email},
      );

      final body = response.data;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['data'] is! Map) {
        debugPrint('[마이페이지 API] 사용자 정보 응답 확인 필요: $body');
        return;
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);

      final serverTarget =
          int.tryParse('${data['targetBookCount'] ?? 0}') ?? 0;
      final serverStatus =
          int.tryParse('${data['status'] ?? 0}') ?? 0;
      final serverRole =
          int.tryParse('${data['grade'] ?? 0}') ?? 0;
      final serverName = data['name']?.toString();

      if (!mounted) return;

      setState(() {
        targetBookCount = serverTarget;
        status = serverStatus;
        userGrade = serverRole;

        // 서버에서 내려온 값을 기존 화면 데이터와 결합
        _serverReadBookCount = serverStatus;
        if (serverStatus > readBookCount) {
          readBookCount = serverStatus;
        }

        if (serverName != null && serverName.trim().isNotEmpty) {
          displayName = serverName;
        }
      });
    } on DioException catch (e) {
      debugPrint(
        '[마이페이지 API 오류] '
            'HTTP: ${e.response?.statusCode}, '
            '응답: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      debugPrint('[마이페이지 API 예외] $e');
    }
  }

  // [형호 수정]
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    // 기존 버전에서 사용한 목표 저장 키
    final targetFromLegacyKey =
        prefs.getInt('target_book_count') ?? 0;

    // 현재 독서 목표 저장소
    final targetFromGoalStorage =
    await ReadingGoalStorage.instance.loadTargetBookCount();

    final localTargetBookCount = [
      targetFromLegacyKey,
      targetFromGoalStorage,
    ].reduce((a, b) => a > b ? a : b);

    // 프로필 사진
    final imagePath = prefs.getString('profile_image_path');

    File? loadedImage;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        loadedImage = file;
      }
    }

    // 한 줄 소개
    final loadedBio = prefs.getString('user_bio') ?? '';

    // 목표 마감 날짜
    final dateString = prefs.getString('target_end_date');
    final loadedDate = dateString == null
        ? null
        : DateTime.tryParse(dateString);

    // 로컬 도서 목록
    final localBooks = await LoanBookStorage.instance.loadBooks();

    final completedCount =
        localBooks.where((book) => book.isCompleted).length;

    final effectiveReadCount = [
      completedCount,
      readBookCount,
      _serverReadBookCount,
    ].reduce((a, b) => a > b ? a : b);

    if (!mounted) return;

    setState(() {
      _imageFile = loadedImage;
      userBio = loadedBio;
      targetEndDate = loadedDate;

      _loanBooks = localBooks;
      readBookCount = effectiveReadCount;

      // 서버 목표가 없을 때 로컬 목표 사용
      if (targetBookCount <= 0 && localTargetBookCount > 0) {
        targetBookCount = localTargetBookCount;
      }
    });

    debugPrint('[마이페이지 복구] 로컬 도서 수: ${localBooks.length}');
    debugPrint('[마이페이지 복구] 로컬 완독 권수: $completedCount');
    debugPrint('[마이페이지 복구] 서버 완독 권수: $_serverReadBookCount');
  }

  // [형호 수정]
  Future<void> _updateTargetBookCountApi(int newTarget) async {
    if (newTarget <= 0) {
      showToast('올바른 목표 권수를 입력해주세요.');
      return;
    }

    // 서버 연결이 실패해도 기기의 목표를 유지
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('target_book_count', newTarget);
    await ReadingGoalStorage.instance.saveTargetBookCount(newTarget);

    if (!mounted) return;

    setState(() {
      targetBookCount = newTarget;
    });

    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null || email.isEmpty) {
      showToast('목표를 기기에 저장했습니다. 로그인 정보를 확인해주세요.');
      return;
    }

    try {
      final response = await _dio.put<dynamic>(
        '/user/targetbook',
        data: {
          'email': email,
          'targetBookCount': newTarget,
          'grade': userGrade,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        showToast('목표 권수가 저장되었습니다.');
        debugPrint('[목표 저장] 서버 저장 성공: $newTarget');
      } else {
        showToast('기기에는 저장했지만 서버 저장은 실패했습니다.');
        debugPrint(
          '[목표 저장] HTTP ${response.statusCode}: ${response.data}',
        );
      }
    } on DioException catch (e) {
      showToast('기기에는 저장했지만 서버 연결에 실패했습니다.');
      debugPrint(
        '[목표 저장 API 오류] '
            'HTTP ${e.response?.statusCode}, '
            '${e.response?.data ?? e.message}',
      );
    } catch (e) {
      showToast('목표는 기기에 저장했지만 서버 처리 중 오류가 발생했습니다.');
      debugPrint('[목표 저장 예외] $e');
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

  // [형호 추가] 도서 목록이 변경되면 최신 데이터를 다시 불러옴
  Future<void> _refreshLoanBooks() async {
    final books = await LoanBookStorage.instance.loadBooks();

    if (!mounted) return;

    final completedCount =
        books.where((book) => book.isCompleted).length;

    final effectiveReadCount = [
      completedCount,
      readBookCount,
      _serverReadBookCount,
    ].reduce((a, b) => a > b ? a : b);

    setState(() {
      _loanBooks = books;
      readBookCount = effectiveReadCount;
    });
  }

  // [형호 수정] 화면이 사라질 때 도서 저장소의 변경 리스너를 해제
  @override
  void dispose() {
    LoanBookStorage.instance.changes.removeListener(_refreshLoanBooks);
    super.dispose();
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

    // [형호 수정] 등급과 진행률 계산 변경
    String currentGrade = _calculateGrade(readBookCount);
    double progress = targetBookCount > 0
        ? (readBookCount / targetBookCount).clamp(0.0, 1.0)
        : 0.0;
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
                          targetBookCount == 0
                              ? '목표를 설정해주세요.'
                              : '총 ${targetBookCount}권 중 ${readBookCount}권 달성',
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
                              status: readBookCount, // [형호 수정]
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
                            builder: (context) => BookStatisticsScreen(
                              completedBooks: _loanBooks
                                  .where((book) => book.isCompleted)
                                  .map((book) => book.toJson())
                                  .toList(), // [형호 수정] 통계 화면에 실제 완독 도서 전달
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // [형호 추가] 독서 현황 카드
              const SizedBox(height: 20),
              _buildReadingRecordsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // [형호 추가] 나의 독서 기록 카드
  Widget _buildReadingRecordsCard() {
    final readingBooks = _loanBooks
        .where((book) => book.isCurrentlyReading)
        .toList();

    final overdueBooks =
    _loanBooks.where((book) => book.isOverdue).toList();

    final dueSoonBooks =
    _loanBooks.where((book) => book.isDueSoon).toList();

    final completedBooks =
    _loanBooks.where((book) => book.isCompleted).toList();

    final returnedBooks =
    _loanBooks.where((book) => book.isReturned).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '독서 현황',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildBookRecordCategory('읽는 중인 책', readingBooks),
          _buildBookRecordCategory('반납 임박', dueSoonBooks),
          _buildBookRecordCategory('연체', overdueBooks),
          _buildBookRecordCategory('완독', completedBooks),
          _buildBookRecordCategory('반납 완료', returnedBooks),
        ],
      ),
    );
  }

  // [형호 추가] 독서 기록의 개별 분류와 도서 제목 표시
  Widget _buildBookRecordCategory(String title, List<LoanBook> books) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: 12,
        ),
        initiallyExpanded: false,
        leading: const Icon(
          Icons.menu_book_rounded,
          color: Color(0xFF8B5A2B),
          size: 21,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${books.length}권',
              style: const TextStyle(
                color: Color(0xFF8B5A2B),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
        children: [
          if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '해당하는 책이 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ...books.map(
                  (book) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.book_outlined,
                      size: 18,
                      color: Color(0xFF8B5A2B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
