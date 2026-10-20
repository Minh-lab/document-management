import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';
import 'colors.dart';
import 'functions.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize services (auth, seed categories)
  // Bọc trong try/catch để lỗi đồng bộ auth không làm app bị trắng màn hình.
  try {
    await initializeServices();
  } catch (e, stack) {
    debugPrint('⚠️ initializeServices failed: $e\n$stack');
  }

  runApp(const CashewApp());
}

class CashewApp extends StatelessWidget {
  const CashewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Tài liệu Học tập',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomePage(),
    );
  }
}
