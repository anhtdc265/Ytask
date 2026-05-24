import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/theme_service.dart';

class ProfileAppearanceScreen extends StatefulWidget {
  const ProfileAppearanceScreen({super.key});

  @override
  State<ProfileAppearanceScreen> createState() => _ProfileAppearanceScreenState();
}

class _ProfileAppearanceScreenState extends State<ProfileAppearanceScreen> {
  final _themeService = ThemeService();
  ThemeMode _selectedMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mode = await _themeService.getSavedThemeMode();

    if (!mounted) return;

    setState(() {
      _selectedMode = mode;
      _isLoading = false;
    });
  }

  Future<void> _selectMode(ThemeMode mode) async {
    setState(() => _selectedMode = mode);
    await _themeService.updateThemeMode(mode);
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _BackButtonCircle(
                onTap: () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Giao diện',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn cách YTask hiển thị sáng, tối hoặc theo thiết bị.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 26),
            _AppearanceOptionCard(
              selectedMode: _selectedMode,
              onChanged: _selectMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceOptionCard extends StatelessWidget {
  const _AppearanceOptionCard({
    required this.selectedMode,
    required this.onChanged,
  });

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.scheduleCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.scheduleCardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _ThemeRadioTile(
            icon: Icons.phone_android_rounded,
            title: 'Theo hệ thống',
            subtitle: 'Tự đổi sáng/tối theo thiết bị',
            value: ThemeMode.system,
            groupValue: selectedMode,
            onChanged: onChanged,
          ),
          _DividerLine(),
          _ThemeRadioTile(
            icon: Icons.light_mode_outlined,
            title: 'Sáng',
            subtitle: 'Luôn dùng giao diện sáng',
            value: ThemeMode.light,
            groupValue: selectedMode,
            onChanged: onChanged,
          ),
          _DividerLine(),
          _ThemeRadioTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tối',
            subtitle: 'Luôn dùng giao diện tối',
            value: ThemeMode.dark,
            groupValue: selectedMode,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemeRadioTile extends StatelessWidget {
  const _ThemeRadioTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;
    final isSelected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.brand, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.brand : colors.inputBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Divider(
      height: 1,
      thickness: 1,
      indent: 74,
      color: colors.inputBorder.withValues(alpha: 0.75),
    );
  }
}

class _BackButtonCircle extends StatelessWidget {
  const _BackButtonCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Material(
      color: colors.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
