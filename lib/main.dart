import 'package:aws402_book_flutter/routes/app_routes.dart';
import 'package:aws402_book_flutter/screens/home_screen.dart';
import 'package:aws402_book_flutter/util/device_info.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

// [형호 수정]
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 환경변수 로드
  await dotenv.load(fileName: ".env");

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 기존 플랫폼 확인 코드는 필요할 때 사용
  // await DeviceInfo.checkPlatform();

  // Firebase 초기화가 완료된 후 앱 실행
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '바로북',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
