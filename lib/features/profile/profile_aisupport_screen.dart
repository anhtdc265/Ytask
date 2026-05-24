import 'package:flutter/material.dart';

class ProfileAISupportScreen extends StatelessWidget {
  const ProfileAISupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF63D64E);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              Text("Trợ lý AI", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome, size: 60, color: primaryGreen),
                    const SizedBox(height: 16),
                    Text(
                      "Chào mừng đến với Trợ lý AI!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Đây là khu vực trợ lý AI hỗ trợ bạn quản lý công việc thông minh hơn. Chức năng sẽ được cập nhật hoàn thiện trong giai đoạn tiếp theo của dự án.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
