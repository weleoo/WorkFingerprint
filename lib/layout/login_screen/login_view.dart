import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:workfingerprint/layout/admin_screen/admin_view.dart';
import 'package:workfingerprint/layout/home_screen/home.dart';
import 'package:workfingerprint/register_screen/register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isObscure = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // شلنا الـ Container والـ MediaQuery اللي كانوا بيثبتوا الارتفاع عشان الـ Scroll يشتغل بحرية
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Hero(
                tag: 'logo',
                child: Image.asset('assets/images/logo.png', height: 120),
              ),
              const SizedBox(height: 50),

              // حقل البريد الإلكتروني
              _buildTextField(
                hint: "البريد الإلكتروني",
                icon: Icons.email_outlined,
                controller: emailController,
              ),

              const SizedBox(height: 20),

              // حقل الباسورد
              _buildPasswordField(),

              const SizedBox(height: 40),

              // زرار تسجيل الدخول المطور
              _buildLoginButton(context),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterView()));
                },
                child: Text(
                  "ليس لديك حساب؟ سجل الآن",
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),

              // استبدلنا الـ Spacer بـ SizedBox كبير عشان نمنع الـ Overflow
              // وفي نفس الوقت نحافظ على المسافة بين الفورم وبيانات المطور
              const SizedBox(height: 60),

              // بيانات المطور (وليد عادل)
              Column(
                children: [
                  Text(
                    "Developed by Waleed Adel",
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "01019857504",
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- باقي الـ Widgets زي ما هي بالظبط بدون أي تغيير في الديزاين ---

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.blue.shade600]),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () async {
          String email = emailController.text.trim();
          String password = passwordController.text.trim();

          if (email.isEmpty || password.isEmpty) {
            _showSnackBar("برجاء إدخال كافة البيانات");
            return;
          }

          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            const String adminEmail = "cairo@company.admin";

            if (email.toLowerCase() == adminEmail.toLowerCase()) {
              _showSnackBar("مرحباً بك أيها المدير");
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardView()),
                );
              }
            } else {
              _showSnackBar("تم تسجيل الدخول بنجاح");
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EngineerFormView()),
                );
              }
            }
          } on FirebaseAuthException catch (e) {
            _showSnackBar("خطأ: البريد أو كلمة المرور غير صحيحة");
          } catch (e) {
            _showSnackBar("حدث خطأ غير متوقع");
          }
        },
        child: const Text(
          "تسجيل الدخول",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.blue.shade50, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: passwordController,
        obscureText: isObscure,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: "كلمة المرور",
          prefixIcon: IconButton(
            icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.blue.shade300),
            onPressed: () => setState(() => isObscure = !isObscure),
          ),
          suffixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade300),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.blue.shade100)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, required IconData icon, required TextEditingController controller}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.blue.shade50, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: Icon(icon, color: Colors.blue.shade300),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.blue.shade100)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}