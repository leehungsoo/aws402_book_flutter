import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TargetBookScreen extends StatefulWidget {
  final int initialTarget;
  final int status;
  final DateTime? initialDate;

  const TargetBookScreen({
    super.key,
    this.initialTarget = 0,
    this.status = 0,
    this.initialDate,
  });

  @override
  State<TargetBookScreen> createState() => _TargetBookScreenState();
}

class _TargetBookScreenState extends State<TargetBookScreen> {
  late final TextEditingController _targetController;
  DateTime? selectedDate;

  final Dio _dio = Dio(
      BaseOptions(
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 3),
          baseUrl: dotenv.env['API_BASE_URL']??''
      )
  );
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  int currentStatus = 0;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.status;
    _targetController = TextEditingController(
      text: widget.initialTarget > 0 ? widget.initialTarget.toString() : '',
    );
    selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _targetController.dispose();
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

  String _getReadingTitle(int count) {
    if (count >= 3000) return '💠 세계수';
    if (count >= 1000) return '🌲 숲';
    if (count >= 500) return '🌳 나무';
    if (count >= 200) return '🌿 줄기';
    if (count >= 100) return '🌿 새싹';
    return '🌱 씨앗';
  }

  int _calculateReadingLevel(int count) {
    if (count >= 3000) return 5;
    if (count >= 1000) return 4;
    if (count >= 500) return 3;
    if (count >= 200) return 2;
    if (count >= 100) return 1;
    return 0;
  }

  // [추가] 백엔드 서버로 목표 권수를 전송하여 DB에 반영하는 함수
  Future<bool> _updateTargetOnServer(int targetBookCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('target_book_count', targetBookCount);

      if (currentUser?.email == null) return true;

      // const url = 'http://10.0.2.2:8080/api/targetbook';
      const url = '/user/targetbook';
      final response = await _dio.put(
        url,
        data: {
          'email': currentUser!.email,
          'targetBookCount': targetBookCount,
          'grade': _calculateReadingLevel(currentStatus),
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('백엔드 목표 권수 업데이트 에러: $e');
      return false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5A2B),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
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
          '독서 목표 설정',
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
            // [복원 완료] 나의 독서 현황 및 칭호 카드
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
                    '나의 독서 현황',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 현재까지 읽은 총 권수: ${currentStatus}권',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• 현재 나의 독서 칭호: ${_getReadingTitle(currentStatus)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 등급 기준표 카드
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
                    '📖 등급 기준표',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildGradeRow('💠 세계수', '3000권 이상'),
                  _buildGradeRow('🌲 숲', '1000권 이상'),
                  _buildGradeRow('🌳 나무', '500권 이상'),
                  _buildGradeRow('🌿 줄기', '200권 이상'),
                  _buildGradeRow('🌿 새싹', '100권 이상'),
                  _buildGradeRow('🌱 씨앗', '0권 이상'),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                    '목표 권수 및 기간 설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '목표 권수',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '목표 권수를 입력하세요',
                      suffixText: '권',
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '목표 달성 마감 날짜',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? '날짜를 선택해주세요'
                                : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: selectedDate == null
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                      int? parsedTarget = int.tryParse(_targetController.text);
                      if (parsedTarget != null && parsedTarget > 0) {
                        setState(() => _isLoading = true);

                        //서버 API로 목표치 업데이트 전송
                        await _updateTargetOnServer(parsedTarget);

                        setState(() => _isLoading = false);

                        _showToast('목표와 기간이 성공적으로 설정되었습니다!');

                        if (!mounted) return;

                        Navigator.pop(context, {
                          'target': parsedTarget,
                          'endDate': selectedDate,
                        });
                      } else {
                        _showToast('올바른 숫자를 입력해주세요.');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Center(
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
                        '목표 저장하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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

  Widget _buildGradeRow(String grade, String condition) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(grade, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(condition, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}