import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:todo_app/core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  static const Color primaryGreen = Color(0xFF63D64E);

  Future<void> _handleRegister() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu xác nhận không khớp!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đăng ký thành công!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final yColors = AppTheme.colors(context);
    final topSectionHeight = size.height * 0.25;
    const double frogSize = 140;

    return Scaffold(
      backgroundColor: yColors.authBackground,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height),
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: topSectionHeight,
                      width: double.infinity,
                      color: yColors.authBackground,
                    ),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight: size.height - topSectionHeight,
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      decoration: BoxDecoration(
                        color: yColors.authPanel,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: yColors.brand,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Về đăng nhập",
                                  style: TextStyle(
                                    color: yColors.brand,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Đăng ký",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: yColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _AuthTextField(hintText: "Họ và tên:", icon: Icons.person_outline, controller: _nameController),
                          const SizedBox(height: 14),
                          _AuthTextField(hintText: "Email:", icon: Icons.mail_outline, controller: _emailController),
                          const SizedBox(height: 14),
                          _AuthTextField(hintText: "Mật khẩu:", icon: Icons.lock_outline, obscureText: true, controller: _passwordController),
                          const SizedBox(height: 14),
                          _AuthTextField(hintText: "Xác nhận mật khẩu", icon: Icons.lock_outline, obscureText: true, controller: _confirmPasswordController),
                          const SizedBox(height: 28),
                          _isLoading 
                            ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                            : _PrimaryAuthButton(text: "ĐĂNG KÝ", onPressed: _handleRegister),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: topSectionHeight - (frogSize / 2),
                  right: 30,
                  child: Image.asset(
                    'assets/images/frog.png',
                    width: frogSize, height: frogSize,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.bug_report, size: frogSize, color: primaryGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;

  const _AuthTextField({
    required this.hintText,
    required this.icon,
    required this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        cursorColor: yColors.brand,
        style: TextStyle(
          color: yColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: yColors.inputHint,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            icon,
            color: yColors.inputHint,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryAuthButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: yColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
