import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:workfingerprint/layout/admin_screen/admin_view.dart'; // صفحة المدير
import 'package:workfingerprint/layout/home_screen/home.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';
 // صفحة المهندس

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    // 1. استنى ثانيتين للوجو
    await Future.delayed(const Duration(seconds: 2));

    // 2. اسأل الفايربيز فيه حد مسجل؟
    User? user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user != null) {
      // 3. هنا بقى "الزتونة".. هنشوف إيميل المستخدم اللي مسجل حالياً
      const String adminEmail = "cairo@company.admin";
      String? currentUserEmail = user.email?.toLowerCase();

      if (currentUserEmail == adminEmail.toLowerCase()) {
        // لو الإيميل هو إيميل المدير.. افتحله صفحة المدير فوراً
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardView()),
        );
      } else {
        // لو أي إيميل تاني.. افتحله صفحة المهندسين (سكرين 4)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EngineerFormView()),

        );
      }
    } else {
      // لو مفيش حد مسجل أصلاً.. واديه للوجين
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Hero(
          tag: 'logo',
          child: Image.asset("assets/images/logo.png", width: 250),
        ),
      ),
    );
  }
}