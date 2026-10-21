import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../services/book_api.dart';
import '../routes/app_routes.dart';

// 날짜: 2026-10-20
// 수정자: 구정민
// 내용: 도서 정보를 확인하거나 직접 입력해 등록하는 화면을 추가한다.
class BookRegisterScreen extends StatefulWidget {
  const BookRegisterScreen({super.key});

  // 내용: 도서 등록 폼의 입력값과 저장 상태를 관리할 State 객체를 생성한다.
  @override
  State<BookRegisterScreen> createState() => _BookRegisterState();
}


// 내용: 필수 입력값, 읽기 전용 여부, 날짜·가격 표시 및 표지 이미지 상태를 관리한다.
class _BookRegisterState extends State<BookRegisterScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};


  // 내용: 도서 가격을 천 단위 쉼표 형식으로 표시한다.
  final numberFormat = NumberFormat.decimalPattern('ko_KR');


  // 내용: 도서 제목·소개·ISBN·출판 날짜·저자·출판사를 필수 입력 항목으로 지정한다.
  static const requiredKeys = {
    'title',
    'contents',
    'isbn',
    'datetime',
    'authors',
    'publisher',
  };
  bool initialized = false, readonly = false, saving = false;
  XFile? selectedImage;
  final names = <String, String>{
    'title': '도서 제목',
    'contents': '도서 소개',
    'url': '도서 상세 URL',
    'isbn': 'ISBN',
    'datetime': '출판 날짜',
    'authors': '저자 리스트',
    'publisher': '출판사',
    'translators': '번역자 리스트',
    'price': '정가',
    'sale_price': '판매가',
    'thumbnail': '표지 이미지 URL',
  };

  // 내용: 전달받은 도서 정보를 입력란에 채우고 날짜와 가격을 표시 형식에 맞게 변환한다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {};
    readonly = args['readonly'] == true;
    final book = (args['book'] as Map<String, dynamic>?) ?? {};
    for (final key in names.keys) {
      dynamic value = book[key];
      if (value is List) value = value.join(', ');
      String text = '${value ?? ''}';
      if (key == 'datetime' && text.isNotEmpty) {
        final parsed = DateTime.tryParse(text);

        // 내용: 출판 날짜를 YYYY-MM-DD 형식으로 표시한다.
        if (parsed != null) text = DateFormat('yyyy-MM-dd').format(parsed);
      }
      if ((key == 'price' || key == 'sale_price') && text.isNotEmpty) {
        final amount = int.tryParse(text.replaceAll(',', ''));
        if (amount != null) text = numberFormat.format(amount);
      }
      fields[key] = TextEditingController(text: text);
    }
  }


  // 내용: 도서 정보 입력에 사용한 컨트롤러를 해제한다.
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }


  // 내용: 직접 등록 시 갤러리에서 책 표지 이미지를 선택하도록 한다.
  Future<void> pickImage() async {
    if (readonly) return;
    try {

      // 내용: 도서 표지 이미지를 선택할 수 있도록 이미지 선택 기능을 연결한다.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => selectedImage = file);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
    }
  }


  // 내용: 출판 날짜를 날짜 선택기로 입력하고 YYYY-MM-DD 형식으로 표시한다.
  Future<void> pickDate() async {
    if (readonly) return;
    final current =
        DateTime.tryParse(fields['datetime']!.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1400),
      lastDate: DateTime(2100),
    );
    if (date != null)
      fields['datetime']!.text = DateFormat('yyyy-MM-dd').format(date);
  }


  // 내용: field 메서드에서 해당 화면 또는 데이터의 처리 로직을 구현한다.
  Widget field(String key) {
    if (key == 'thumbnail' && !readonly) return const SizedBox.shrink();
    final price = key == 'price' || key == 'sale_price';
    final date = key == 'datetime';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: fields[key],
        readOnly: readonly || date,
        onTap: date && !readonly ? pickDate : null,
        maxLines: key == 'contents' ? 4 : 1,
        keyboardType: price ? TextInputType.number : TextInputType.text,
        inputFormatters: price && !readonly
            ? [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsSeparatorFormatter(),
              ]
            : null,
        decoration: InputDecoration(
          label: requiredKeys.contains(key)
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: names[key]),
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(names[key]!),
          suffixIcon: date ? const Icon(Icons.calendar_month) : null,
          filled: true,
          fillColor: const Color(0xFFFAF9F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),

        // 내용: 필수 입력란이 비어 있을 때 등록을 막고 오류 문구를 표시한다.
        validator: (value) {
          if (requiredKeys.contains(key) &&
              (value == null || value.trim().isEmpty))
            return '필수 입력 항목입니다.';
          if (price &&
              value != null &&
              value.isNotEmpty &&
              int.tryParse(value.replaceAll(',', '')) == null)
            return '숫자로 입력하세요.';
          return null;
        },
      ),
    );
  }


  // 내용: 필수 6개 항목과 ISBN 중복 여부를 확인한 후 표지 이미지를 업로드하고 도서를 저장한다.
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final data = <String, dynamic>{
        for (final key in names.keys) key: fields[key]!.text.trim(),
      };
      for (final key in ['price', 'sale_price']) {
        data[key] =
            int.tryParse((data[key] as String).replaceAll(',', '')) ?? 0;
      }

      // 내용: 도서 조회 또는 등록을 위해 서버 API를 호출하도록 연결한다.
      if (await BookApi.exists(data['isbn'] as String)) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('이미 등록된 책입니다.')));
        return;
      }
      if (!readonly && selectedImage != null) {
        data['thumbnail'] = await BookApi.uploadCover(selectedImage!.path);
      }
      await BookApi.save(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('도서 등록이 완료되었습니다.')));

      // 내용: 도서 검색·등록 화면으로 이동할 수 있도록 라우팅을 연결한다.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.statusCode == 409
                  ? '이미 등록된 책입니다.'
                  : '저장 오류: ${e.message}',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 오류: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  // 내용: 필수 입력 표시와 유효성 검사를 포함한 도서 등록 폼을 구성한다.
  @override
  Widget build(BuildContext context) {
    final thumbnail = fields['thumbnail']!.text;
    Widget preview;
    if (selectedImage != null) {
      preview = Image.file(
        File(selectedImage!.path),
        height: 180,
        fit: BoxFit.contain,
      );
    } else if (thumbnail.isNotEmpty) {
      preview = Image.network(
        thumbnail,
        height: 180,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image, size: 75),
      );
    } else {
      preview = const SizedBox(
        height: 180,
        child: Icon(Icons.add_photo_alternate_outlined, size: 80),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        title: const Text('책 등록하기'),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '저장 중' : '✓ 저장'),
          ),
        ],
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InkWell(
              onTap: readonly ? null : pickImage,
              child: Column(
                children: [
                  Center(child: preview),
                  if (!readonly)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('표지를 눌러 갤러리에서 이미지 선택'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '기본 정보',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '* 필수 입력',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            for (final key in names.keys) field(key),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : save,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}


// 내용: _ThousandsSeparatorFormatter 클래스를 추가하거나 변경하여 관련 기능을 구현한다.
class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = NumberFormat.decimalPattern('ko_KR')
        .format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
