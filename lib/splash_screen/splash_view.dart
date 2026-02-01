import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:workfingerprint/layout/admin_screen/admin_view.dart';
import 'package:workfingerprint/layout/home_screen/home.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';

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
    // 1. انتظار ثانيتين للوجو
    await Future.delayed(const Duration(seconds: 2));

    // 2. التحقق من وجود مستخدم مسجل في Firebase Auth
    User? user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user != null) {
      try {
        // 3. التحقق من الرتبة (Role) من Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (context.mounted) {
          if (userDoc.exists) {
            String role = userDoc.get('role') ?? "engineer";

            // لو الرتبة أدمن، يروح للوحة الإدارة
            if (role.toLowerCase().contains("admin")) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboardView()),
              );
              return; // الخروج من الدالة بعد التوجيه
            }
          }

          // في حال كان مستخدم عادي (مهندس) أو المستند غير موجود حالياً
          // بنوديه لصفحة المهندسين طالما مسجل دخول في Auth
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EngineerFormView()),
          );
        }
      } catch (e) {
        // في حالة وجود خطأ في جلب البيانات (زي ضعف النت)
        // بنوديه لصفحة المهندسين طالما الـ Auth شغال
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EngineerFormView()),
          );
        }
      }
    } else {
      // لو مفيش مستخدم مسجل أصلاً
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
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