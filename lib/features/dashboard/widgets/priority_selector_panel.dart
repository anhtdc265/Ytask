import 'package:flutter/material.dart';
import 'package:todo_app/models/task_model.dart';

class PrioritySelectorPanel extends StatelessWidget {
  final TaskPriority currentPriority;
  final ValueChanged<TaskPriority> onSelected;

  const PrioritySelectorPanel({
    super.key,
    required this.currentPriority,
    required this.onSelected,
  });

  String _priorityLabel(TaskPriority priority) => priority.vietnameseLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn mức độ ưu tiên',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(TaskPriority.low, const Color(0xFFA7FFEB), const Color(0xFF00BFA5)),
                _buildOption(TaskPriority.medium, const Color(0xFFFFF59D), const Color(0xFFFFD600)),
                _buildOption(TaskPriority.high, const Color(0xFFFFCDD2), const Color(0xFFFF1744)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(TaskPriority priority, Color bgColor, Color glowColor) {
    final isSelected = currentPriority == priority;

    return GestureDetector(
      onTap: () => onSelected(priority),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? glowColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          _priorityLabel(priority),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: isSelected ? glowColor.withValues(alpha: 0.9) : Colors.black54,
          ),
        ),
      ),
    );
  }
}
