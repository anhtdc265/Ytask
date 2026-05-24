import 'package:flutter/material.dart';
import 'package:todo_app/core/theme/app_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
  });

  static const Color primaryGreen = Color(0xFF63D64E);

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case 1:
        Navigator.of(context).pushNamed('/progress');
        break;
      case 2:
        Navigator.of(context).pushNamed('/chatbot');
        break;
      case 3:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return BottomAppBar(
      height: 70,
      color: yColors.bottomNav,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _NavIcon(
            icon: Icons.calendar_month_outlined,
            isSelected: currentIndex == 0,
            onTap: () => _handleTap(context, 0),
          ),
          _NavIcon(
            icon: Icons.analytics_outlined,
            isSelected: currentIndex == 1,
            onTap: () => _handleTap(context, 1),
          ),
          _NavIcon(
            icon: Icons.auto_awesome_outlined,
            isSelected: currentIndex == 2,
            onTap: () => _handleTap(context, 2),
          ),
          _NavIcon(
            icon: Icons.person_outline,
            isSelected: currentIndex == 3,
            onTap: () => _handleTap(context, 3),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return Expanded(
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 28,
          color: isSelected ? yColors.brand : yColors.textMuted,
        ),
      ),
    );
  }
}
