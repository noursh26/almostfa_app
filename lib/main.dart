import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const AlmostfaApp());
}

class AlmostfaApp extends StatelessWidget {
  const AlmostfaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المصطفى',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6B3C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}
