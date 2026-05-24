import 'package:flutter/material.dart';

import 'package:todo_app/models/ai_day_plan_result.dart';

/// A compact, demo-friendly card for the AI day-planning feature.
///
/// The card consumes structured [AiDayPlanResult] data, so the UI does not need
/// to parse free-form AI text. A future task can pass [onViewTask] to open
/// DetailTaskScreen from each suggested item.
class AiDayPlanCard extends StatelessWidget {
  const AiDayPlanCard({
    super.key,
    required this.plan,
    this.onViewTask,
  });

  final AiDayPlanResult plan;
  final ValueChanged<String>? onViewTask;

  static const Color _ytaskGreen = Color(0xFF64DA56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A211A) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F261F);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF6F766F);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : _ytaskGreen.withOpacity(0.20);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, primaryText, secondaryText),
          const SizedBox(height: 12),
          Text(
            plan.summary.trim().isEmpty
                ? 'Đây là kế hoạch gợi ý cho hôm nay.'
                : plan.summary.trim(),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.38,
              fontWeight: FontWeight.w700,
              color: secondaryText,
            ),
          ),
          if (plan.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...plan.items.map(
              (item) => _DayPlanItemTile(
                item: item,
                onViewTask: onViewTask,
              ),
            ),
          ],
          if (plan.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTips(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _ytaskGreen.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: _ytaskGreen,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kế hoạch hôm nay',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'AI gợi ý thứ tự làm việc',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF4F574F);
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF2F8F1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: _ytaskGreen,
              ),
              const SizedBox(width: 7),
              Text(
                'Gợi ý thêm',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...plan.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• ${tip.trim()}',
                style: TextStyle(
                  fontSize: 13.2,
                  height: 1.32,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPlanItemTile extends StatelessWidget {
  const _DayPlanItemTile({
    required this.item,
    this.onViewTask,
  });

  final AiDayPlanItem item;
  final ValueChanged<String>? onViewTask;

  static const Color _ytaskGreen = Color(0xFF64DA56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF202520);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF697069);
    final itemBackground = isDark
        ? Colors.white.withOpacity(0.045)
        : const Color(0xFFF7FBF6);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.035),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderBadge(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.6,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                          color: primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityBadge(context),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.reason.trim().isEmpty
                      ? 'Phù hợp để thực hiện trong hôm nay.'
                      : item.reason.trim(),
                  style: TextStyle(
                    fontSize: 13.2,
                    height: 1.34,
                    fontWeight: FontWeight.w600,
                    color: secondaryText,
                  ),
                ),
                if (item.suggestedTimeText.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildTimeHint(context, item.suggestedTimeText.trim()),
                ],
                if (onViewTask != null && item.taskId.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => onViewTask?.call(item.taskId.trim()),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: _ytaskGreen,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Xem task',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBadge() {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _ytaskGreen,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: _ytaskGreen.withOpacity(0.26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        item.suggestedOrder.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _ytaskGreen.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Ưu tiên #${item.suggestedOrder}',
        style: const TextStyle(
          color: Color(0xFF329226),
          fontSize: 11.4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTimeHint(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white60 : const Color(0xFF7A817A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.7,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
