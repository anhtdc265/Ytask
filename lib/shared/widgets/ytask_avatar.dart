import 'package:flutter/material.dart';

class YTaskAvatarOption {
  final String id;
  final String label;
  final String emoji;
  final Color backgroundColor;
  final Color foregroundColor;

  const YTaskAvatarOption({
    required this.id,
    required this.label,
    required this.emoji,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

const List<YTaskAvatarOption> yTaskAvatarOptions = [
  YTaskAvatarOption(
    id: 'frog',
    label: 'Ếch năng suất',
    emoji: '🐸',
    backgroundColor: Color(0xFFD9FBD3),
    foregroundColor: Color(0xFF1F9D3A),
  ),
  YTaskAvatarOption(
    id: 'robot',
    label: 'Robot AI',
    emoji: '🤖',
    backgroundColor: Color(0xFFE3F2FF),
    foregroundColor: Color(0xFF2274A5),
  ),
  YTaskAvatarOption(
    id: 'cat',
    label: 'Mèo tập trung',
    emoji: '🐱',
    backgroundColor: Color(0xFFFFF1C7),
    foregroundColor: Color(0xFFB87900),
  ),
  YTaskAvatarOption(
    id: 'fox',
    label: 'Cáo nhanh nhẹn',
    emoji: '🦊',
    backgroundColor: Color(0xFFFFE2D6),
    foregroundColor: Color(0xFFE35D28),
  ),
  YTaskAvatarOption(
    id: 'panda',
    label: 'Gấu bình tĩnh',
    emoji: '🐼',
    backgroundColor: Color(0xFFEDEDF2),
    foregroundColor: Color(0xFF3A3A45),
  ),
  YTaskAvatarOption(
    id: 'tiger',
    label: 'Hổ quyết tâm',
    emoji: '🐯',
    backgroundColor: Color(0xFFFFE7B8),
    foregroundColor: Color(0xFFC47700),
  ),
];

YTaskAvatarOption getYTaskAvatarOption(String? avatarId) {
  if (avatarId == null || avatarId.trim().isEmpty) {
    return yTaskAvatarOptions.first;
  }

  return yTaskAvatarOptions.firstWhere(
    (option) => option.id == avatarId,
    orElse: () => yTaskAvatarOptions.first,
  );
}

class YTaskAvatar extends StatelessWidget {
  final String? avatarId;
  final double size;
  final bool showBorder;
  final bool showShadow;

  const YTaskAvatar({
    super.key,
    required this.avatarId,
    this.size = 96,
    this.showBorder = true,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final option = getYTaskAvatarOption(avatarId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: option.backgroundColor,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: Colors.white.withAlpha(230),
                width: 4,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        option.emoji,
        style: TextStyle(
          fontSize: size * 0.46,
          height: 1,
        ),
      ),
    );
  }
}