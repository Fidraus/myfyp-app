import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_service.dart';
import '../config/api_config.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'guest_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse('${ApiConfig.baseUrl}/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'] ?? data;
        await SessionService.saveSession(
          userId: (user['id'] as num?)?.toInt() ?? 1,
          name: user['name'] ?? 'User',
          email: user['email'] ?? '',
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        }
      } else {
        String msg = 'Invalid Email or Password';
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Connection error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              Text('Welcome Back', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Sign in with your Gmail', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 40),

              _label('Email'),
              _field(
                controller: _emailController,
                hint: 'example@gmail.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              _label('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: GoogleFonts.poppins(fontSize: 14),
                onSubmitted: (_) => _handleLogin(),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('Login', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Register', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuestHomeScreen())),
                  child: Text('Continue as Guest', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: caps,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: _inputDecoration(hint: hint, icon: icon),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
    );
  }
}