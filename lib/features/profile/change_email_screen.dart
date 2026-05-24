import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ChangeEmailScreen extends StatefulWidget {
  final String currentEmail;

  const ChangeEmailScreen({
    super.key,
    required this.currentEmail,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  static const Color _primaryGreen = Color(0xFF64DA56);

  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _currentEmailController;
  final _newEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _currentEmailController = TextEditingController(
      text: widget.currentEmail,
    );
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _authService.requestEmailChange(
        currentPassword: _currentPasswordController.text.trim(),
        newEmail: _newEmailController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Kiểm tra email mới'),
            content: Text(
              'Đã gửi email xác minh tới ${_newEmailController.text.trim()}.\n\n'
              'Vui lòng mở email mới và bấm link xác nhận. '
              'Sau đó hãy đăng nhập lại YTask bằng email mới.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          );
        },
      );

      await _authService.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapAuthErrorToMessage(e))),
      );

      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : const Color(0xFF2E2B3A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _BackButtonCircle(
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 28),
              Text(
                'Đổi email',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email mới cần được xác minh trước khi thay đổi chính thức.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              _YTaskTextField(
                controller: _currentEmailController,
                label: 'Email hiện tại',
                readOnly: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _YTaskTextField(
                controller: _newEmailController,
                label: 'Email mới',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Vui lòng nhập email mới';
                  }

                  if (!_isValidEmail(text)) {
                    return 'Email không hợp lệ';
                  }

                  if (text.toLowerCase() ==
                      widget.currentEmail.trim().toLowerCase()) {
                    return 'Email mới phải khác email hiện tại';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),
              _YTaskTextField(
                controller: _currentPasswordController,
                label: 'Mật khẩu hiện tại',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập mật khẩu hiện tại';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 34),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'GỬI EMAIL XÁC MINH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButtonCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButtonCircle({
    required this.onTap,
  });

  static const Color _primaryGreen = Color(0xFF64DA56);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: _primaryGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _YTaskTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _YTaskTextField({
    required this.controller,
    required this.label,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? const Color(0xFF252725) : Colors.white,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF64DA56),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }
}