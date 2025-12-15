import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapspend/pages/welcome_page.dart';
import 'package:snapspend/pages/expenses_summary_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final ocrService = OcrService();
  // await ocrService.llamaService.checkModelExists();

  // final result = await ocrService.llamaService.generateText(
  //   prompt:
  //       'Extract receipt information from the following Thai text and output ONLY valid JSON with English keys.Receipt OCR text:หชําระเงินสําเร็จ | <18 ต.ค. 68 19:45 น. +น.ส. วริษฐา มธ.กสิกรไทยXXX-X-X0997-xธรรมรักษ์ พรหมเผ่านาย ธรรมรักษ์ พรหมเผ่า202510186620028เลขที่รายการ:015291194532AQRO078/8จํานวน:81.00 บาทค่าธรรมเนียม:0.00 บาท สแกนตรวจสอบสลิป',
  //   // 'who are you?',
  //   onStatusUpdate: (s) => print(s),
  //   onTextUpdate: (t) => print('Generated: $t'),
  //   maxTokens: 512,
  // );

  // print('Final result: $result');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appBackground = Color(0xFF0A1A2F);
    return MaterialApp(
      title: 'Llama FFI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: appBackground,
        canvasColor: appBackground,
        useMaterial3: true,
      ),
      home: const _AppStartRouter(),
    );
  }
}

class _AppStartRouter extends StatelessWidget {
  const _AppStartRouter();

  Future<bool> _isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;
    return !complete;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstRun(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1A2F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
            ),
          );
        }

        final isFirstRun = snapshot.data!;
        return isFirstRun ? const WelcomePage() : const ExpensesSummaryPage();
      },
    );
  }
}
