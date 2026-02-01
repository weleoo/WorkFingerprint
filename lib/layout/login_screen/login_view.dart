import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool isLoading = false;

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
              _buildTextField(
                hint: "البريد الإلكتروني",
                icon: Icons.email_outlined,
                controller: emailController,
              ),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 40),
              isLoading
                  ? const CircularProgressIndicator()
                  : _buildLoginButton(context),
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
              const SizedBox(height: 60),
              Column(
                children: [
                  Text(
                    "Developed By Waleed Adel",
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

          setState(() => isLoading = true);

          try {
            // 1. تسجيل الدخول عبر Firebase Auth
            UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );


            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

            if (userDoc.exists && userDoc.data() != null) {
              // استخراج الرول (إذا لم يوجد نعتبره مهندس بشكل افتراضي)
              Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
              String role = userData['role']?.toString() ?? "engineer";

              if (context.mounted) {
                // 3. التوجيه بناءً على الرتبة
                if (role.toLowerCase().contains("admin")) {
                  _showSnackBar("مرحباً بك في لوحة الإدارة");
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardView()),
                  );
                } else {
                  _showSnackBar("تم تسجيل الدخول بنجاح");
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const EngineerFormView()),
                  );
                }
              }
            } else {
              // حالة وجود حساب في Auth ولكن لا يوجد له بيانات في Firestore
              _showSnackBar("خطأ: بيانات المستخدم غير مكتملة في قاعدة البيانات");
            }
          } on FirebaseAuthException catch (e) {
            if (e.code == 'user-not-found') {
              _showSnackBar("هذا البريد غير مسجل");
            } else if (e.code == 'wrong-password') {
              _showSnackBar("كلمة المرور غير صحيحة");
            } else {
              _showSnackBar("خطأ: البريد أو كلمة المرور غير صحيحة");
            }
          } catch (e) {
            _showSnackBar("حدث خطأ غير متوقع أثناء الدخول");
          } finally {
            if (mounted) setState(() => isLoading = false);
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