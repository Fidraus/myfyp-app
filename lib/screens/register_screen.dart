import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('${ApiConfig.baseUrl}/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
          'password_confirmation': _confirmController.text,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showSnack('Registration successful! Please login.');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      } else {
        String msg = 'Registration failed. Please try again.';
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) {
            msg = body['message'];
          } else if (body['errors'] != null) {
            final errors = body['errors'] as Map<String, dynamic>;
            msg = (errors.values.first as List).first.toString();
          }
        } catch (_) {
          msg = 'Error ${response.statusCode}: ${response.body}';
        }
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Connection error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    }
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

              Text('Create Account', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Register with your Gmail', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 36),

              _label('Full Name'),
              _field(controller: _nameController, hint: 'Ahmad bin Ali', icon: Icons.person_outline),
              const SizedBox(height: 16),

              _label('Email'),
              _field(
                controller: _emailController,
                hint: 'example@gmail.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _label('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Confirm Password'),
              _field(controller: _confirmController, hint: '••••••••', icon: Icons.lock_outline, obscure: true),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('Register Now', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text('Login', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: caps,
      obscureText: obscure,
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