import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/profile_components.dart';

class ProfileHelpScreen extends StatelessWidget {
  const ProfileHelpScreen({super.key});

  static const List<_HelpTopic> _topics = [
    _HelpTopic(
      icon: Icons.add_task_rounded,
      title: 'Tạo nhiệm vụ',
      subtitle: 'Thêm tiêu đề, thời gian, nhãn và nhắc nhở.',
      detailTitle: 'Tạo nhiệm vụ mới',
      detailBody:
          'Nhấn nút + ở màn hình chính để tạo nhiệm vụ. Bạn nên nhập tiêu đề rõ ràng, chọn thời gian bắt đầu/kết thúc và thêm nhắc nhở nếu nhiệm vụ quan trọng.',
    ),
    _HelpTopic(
      icon: Icons.calendar_month_rounded,
      title: 'Quản lý lịch trình',
      subtitle: 'Xem các nhiệm vụ theo ngày trên Dashboard.',
      detailTitle: 'Quản lý lịch trình',
      detailBody:
          'Dashboard giúp bạn xem nhiệm vụ theo từng ngày. Chọn ngày trên thanh lịch để kiểm tra công việc cần làm và mở chi tiết nhiệm vụ khi cần chỉnh sửa.',
    ),
    _HelpTopic(
      icon: Icons.insights_rounded,
      title: 'Theo dõi tiến độ',
      subtitle: 'Xem trạng thái pending, in progress, completed.',
      detailTitle: 'Theo dõi tiến độ',
      detailBody:
          'Màn tiến độ tổng hợp nhiệm vụ theo trạng thái. Bạn có thể xem nhanh nhiệm vụ đang chờ, đang làm, đã hoàn thành hoặc đã hủy để kiểm soát khối lượng công việc.',
    ),
    _HelpTopic(
      icon: Icons.auto_awesome_rounded,
      title: 'Sử dụng trợ lý AI',
      subtitle: 'Hỏi AI để tìm, sắp xếp và phân tích công việc.',
      detailTitle: 'Sử dụng trợ lý AI',
      detailBody:
          'Trợ lý AI có thể hỗ trợ tìm nhiệm vụ, gợi ý cách sắp xếp công việc và phân tích tiến độ. Tính năng này đang ở giai đoạn beta nên nên dùng như công cụ hỗ trợ.',
      actionLabel: 'Mở trợ lý AI',
      routeName: '/chatbot',
    ),
    _HelpTopic(
      icon: Icons.feedback_outlined,
      title: 'Gửi phản hồi',
      subtitle: 'Góp ý lỗi, giao diện hoặc tính năng cần cải thiện.',
      detailTitle: 'Gửi phản hồi',
      detailBody:
          'Bạn có thể ghi lại lỗi gặp phải, màn hình liên quan và thao tác dẫn đến lỗi. Phần gửi phản hồi trực tiếp sẽ được kết nối ở giai đoạn sau của dự án.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Scaffold(
      backgroundColor: colors.appBackground,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ProfileBackButton(onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 32),
            Text(
              'Hướng dẫn',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Các thao tác chính trong YTask được gom gọn để bạn tra cứu nhanh khi cần.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            ProfileSection(
              title: 'Trợ giúp nhanh',
              children: [
                for (final topic in _topics)
                  ProfileActionTile(
                    icon: topic.icon,
                    title: topic.title,
                    subtitle: topic.subtitle,
                    onTap: () => _showHelpTopicSheet(context, topic),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHelpTopicSheet(BuildContext context, _HelpTopic topic) async {
    final colors = context.ytaskColors;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: colors.scheduleCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(
                        alpha: context.isDarkMode ? 0.18 : 0.13,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(topic.icon, color: colors.brand, size: 26),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    topic.detailTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    topic.detailBody,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (topic.actionLabel != null && topic.routeName != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(context, topic.routeName!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          topic.actionLabel!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Đã hiểu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HelpTopic {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detailTitle,
    required this.detailBody,
    this.actionLabel,
    this.routeName,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detailTitle;
  final String detailBody;
  final String? actionLabel;
  final String? routeName;
}
