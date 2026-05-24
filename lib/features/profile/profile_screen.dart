import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'profile_account_screen.dart';
import 'profile_help_screen.dart';
import 'profile_notification_screen.dart';
import 'widgets/profile_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _themeService = ThemeService();

  UserModel? _user;
  bool _isLoading = true;
  String _notificationSubtitle = 'Cài đặt nhắc nhở và quyền thông báo';
  String _appearanceSubtitle = 'Theo hệ thống';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);

    final user = await _authService.getUserProfile();
    final themeMode = await _themeService.getSavedThemeMode();

    if (!mounted) return;

    setState(() {
      _user = user;
      _notificationSubtitle = 'Cài đặt nhắc nhở và quyền thông báo';
      _appearanceSubtitle = _themeService.labelOf(themeMode);
      _isLoading = false;
    });
  }

  Future<void> _openAccountScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileAccountScreen()),
    );

    if (result == true) {
      await _loadAllData();
    }
  }

  Future<void> _openNotificationScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileNotificationScreen()),
    );

    await _loadAllData();
  }

  Future<void> _openThemeModeSheet() async {
    final currentMode = await _themeService.getSavedThemeMode();

    if (!mounted) return;

    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => ThemeOptionBottomSheet(currentMode: currentMode),
    );

    if (!mounted || selectedMode == null) return;

    await _themeService.updateThemeMode(selectedMode);

    if (!mounted) return;

    setState(() => _appearanceSubtitle = _themeService.labelOf(selectedMode));
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Scaffold(
      backgroundColor: colors.appBackground,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.brand))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ProfileBackButton(
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfileHeader(
                    user: _user,
                    onTap: _openAccountScreen,
                  ),
                  const SizedBox(height: 26),
                  ProfileSection(
                    title: 'Tài khoản',
                    children: [
                      ProfileMenuTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Tài khoản & bảo mật',
                        subtitle: 'Thông tin cá nhân, email và mật khẩu',
                        onTap: _openAccountScreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ProfileSection(
                    title: 'Cài đặt',
                    children: [
                      ProfileMenuTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Thông báo',
                        subtitle: _notificationSubtitle,
                        onTap: _openNotificationScreen,
                      ),
                      ProfileMenuTile(
                        icon: Icons.palette_outlined,
                        title: 'Giao diện',
                        subtitle: _appearanceSubtitle,
                        onTap: _openThemeModeSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ProfileSection(
                    title: 'Hỗ trợ',
                    children: [
                      ProfileMenuTile(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Trợ lý AI',
                        subtitle: 'Beta · Hỏi AI về sắp xếp, tìm và phân tích công việc',
                        onTap: () => Navigator.pushNamed(context, '/chatbot'),
                      ),
                      ProfileMenuTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Hướng dẫn',
                        subtitle: 'Cách dùng YTask và các mẹo thao tác nhanh',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileHelpScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ProfileLogoutButton(onTap: _handleLogout),
                ],
              ),
      ),
    );
  }
}
