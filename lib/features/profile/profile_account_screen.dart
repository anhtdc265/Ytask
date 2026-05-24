import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/ytask_avatar.dart';
import 'change_password_screen.dart';
import 'change_email_screen.dart';
import 'widgets/profile_components.dart';

class ProfileAccountScreen extends StatefulWidget {
  const ProfileAccountScreen({super.key});

  @override
  State<ProfileAccountScreen> createState() => _ProfileAccountScreenState();
}

class _ProfileAccountScreenState extends State<ProfileAccountScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  String _currentEmail = '';

  bool _isLoading = false;
  bool _didChange = false;
  UserModel? _user;
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = await _authService.getUserProfile();

    if (!mounted) return;

    if (user != null) {
      setState(() {
        _user = user;
        _nameController.text = user.name;
        _currentEmail = user.email;
        _selectedAvatarId = user.avatarUrl ?? 'frog';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _closeScreen() {
    Navigator.pop(context, _didChange);
  }

  Future<void> _handleSaveName() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên không được để trống.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updateUserName(newName);

      if (!mounted) return;

      _didChange = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật tên thành công!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật tên: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openChangePasswordScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu đã được cập nhật.')),
      );
    }
  }

  Future<void> _openChangeEmailScreen() async {
    final currentEmail = _currentEmail.trim();

    if (currentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy email hiện tại.')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeEmailScreen(
          currentEmail: currentEmail,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      _didChange = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng kiểm tra email mới để xác minh thay đổi.'),
        ),
      );
    }
  }

  Future<void> _openAvatarPicker() async {
    final pickedAvatar = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bottomSafe = MediaQuery.of(context).padding.bottom;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.42,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.58, 0.88],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242623) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.28)
                                    : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Chọn avatar',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2E2B3A),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      24 + bottomSafe,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 116,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final option = yTaskAvatarOptions[index];
                          final isSelected = option.id == _selectedAvatarId;

                          return InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.pop(context, option.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF5F1F8),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF64DA56)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  YTaskAvatar(
                                    avatarId: option.id,
                                    size: 58,
                                    showBorder: false,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: yTaskAvatarOptions.length,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (pickedAvatar == null || pickedAvatar == _selectedAvatarId) return;

    setState(() => _isLoading = true);

    try {
      await _authService.updateUserAvatar(pickedAvatar);

      if (!mounted) return;

      setState(() {
        _selectedAvatarId = pickedAvatar;
        _didChange = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật avatar thành công!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật avatar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF63D64E);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading && _user == null
            ? const Center(
          child: CircularProgressIndicator(color: primaryGreen),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _closeScreen,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    YTaskAvatar(
                      avatarId: _selectedAvatarId,
                      size: 120,
                      showShadow: true,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _openAvatarPicker,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildFieldLabel('Họ và tên:', textColor),
              _buildTextField(_nameController, isDark),
              const SizedBox(height: 18),
              ProfileSection(
                title: 'Bảo mật tài khoản',
                children: [
                  ProfileSecurityTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'Email đăng nhập',
                    subtitle: _currentEmail.isEmpty
                        ? 'Chưa có email đăng nhập'
                        : _currentEmail,
                    trailingLabel: 'Đổi',
                    onTap: _isLoading ? null : _openChangeEmailScreen,
                  ),
                  ProfileSecurityTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Đổi mật khẩu',
                    subtitle: 'Yêu cầu nhập mật khẩu hiện tại',
                    onTap: _isLoading ? null : _openChangePasswordScreen,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSaveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(
                    'LƯU THAY ĐỔI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildFieldLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      bool isDark, {
        bool readOnly = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
