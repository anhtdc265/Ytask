import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:todo_app/features/dashboard/detail_task_screen.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/models/category_model.dart';

class TaskDetailLoaderScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailLoaderScreen({
    super.key,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('tasks').doc(taskId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF64DA56),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const _MissingTaskScreen();
        }

        final data = snapshot.data!.data();

        if (data == null || data['isDeleted'] == true) {
          return const _MissingTaskScreen();
        }

        final task = TaskModel.fromMap({
          ...data,
          'id': data['id'] ?? snapshot.data!.id,
        });

        // Vì DetailTaskScreen yêu cầu initialCategory, cần fetch thêm Category
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(task.userId)
              .collection('categories')
              .doc(task.categoryId)
              .get(),
          builder: (context, catSnapshot) {
            if (catSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF64DA56),
                  ),
                ),
              );
            }

            CategoryModel category;
            if (catSnapshot.hasData && catSnapshot.data!.exists) {
              category = CategoryModel.fromMap(catSnapshot.data!.data()!);
            } else {
              category = CategoryModel(
                id: task.categoryId,
                userId: task.userId,
                name: 'Nhãn',
                colorHex: 'FF64DA56',
              );
            }

            return DetailTaskScreen(
              task: task,
              initialCategory: category,
            );
          },
        );
      },
    );
  }
}

class _MissingTaskScreen extends StatelessWidget {
  const _MissingTaskScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF64DA56),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFF64DA56).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: Color(0xFF64DA56),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Nhiệm vụ không còn tồn tại',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF2E2B3A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhiệm vụ này có thể đã bị xóa hoặc không còn khả dụng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
