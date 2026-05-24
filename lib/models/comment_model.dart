import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String taskId;
  final String userId;
  final String userDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    this.userDisplayName = 'Người dùng',
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      userId: map['userId'] ?? '',
      userDisplayName: map['userDisplayName'] ?? 'Người dùng',
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      content: map['content'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  CommentModel copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? userDisplayName,
    String? authorAvatarUrl,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
