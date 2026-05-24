import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo_app/models/ai_day_plan_result.dart';

enum MessageType {
  user,
  ai,
}

extension MessageTypeX on MessageType {
  String get value {
    switch (this) {
      case MessageType.user:
        return 'user';
      case MessageType.ai:
        return 'ai';
    }
  }
}

class ChatMessage {
  final String text;
  final MessageType type;
  final DateTime createdAt;

  /// Structured AI day-plan data.
  ///
  /// Keep this optional so old chat messages can still be rendered as plain
  /// Markdown, while day-planning answers can be rendered as a dedicated card.
  final AiDayPlanResult? dayPlan;

  const ChatMessage({
    required this.text,
    required this.type,
    required this.createdAt,
    this.dayPlan,
  });

  factory ChatMessage.user(String text) {
    return ChatMessage(
      text: text,
      type: MessageType.user,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.ai(
      String text, {
        AiDayPlanResult? dayPlan,
      }) {
    return ChatMessage(
      text: text,
      type: MessageType.ai,
      createdAt: DateTime.now(),
      dayPlan: dayPlan,
    );
  }

  factory ChatMessage.aiDayPlan(AiDayPlanResult plan) {
    return ChatMessage.ai(
      plan.toChatText(),
      dayPlan: plan,
    );
  }

  /// Convert this chat message to a Firestore-safe map.
  ///
  /// `createdAt` is stored as a Firestore Timestamp so later services can
  /// order chat history by time with `orderBy('createdAt')`.
  Map<String, dynamic> toMap() {
    return {
      'text': text.trim(),
      'type': type.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'dayPlan': dayPlan?.toMap(),
    };
  }

  /// Restore a chat message from Firestore/local map data.
  ///
  /// Supports both normal messages and AI day-plan messages. It is also tolerant
  /// of old/legacy data where `createdAt` might be a String, DateTime, int, or
  /// missing.
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: _parseString(map['text']),
      type: _parseMessageType(map['type']),
      createdAt: _parseDateTime(map['createdAt']),
      dayPlan: _parseDayPlan(map['dayPlan']),
    );
  }

  ChatMessage copyWith({
    String? text,
    MessageType? type,
    DateTime? createdAt,
    AiDayPlanResult? dayPlan,
    bool clearDayPlan = false,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      dayPlan: clearDayPlan ? null : dayPlan ?? this.dayPlan,
    );
  }

  bool get isUser => type == MessageType.user;

  bool get isAi => type == MessageType.ai;

  bool get hasDayPlan => dayPlan != null;

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static MessageType _parseMessageType(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'user':
        return MessageType.user;
      case 'ai':
      case 'assistant':
      case 'bot':
        return MessageType.ai;
      default:
        return MessageType.ai;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }

  static AiDayPlanResult? _parseDayPlan(dynamic value) {
    if (value == null) return null;

    try {
      if (value is AiDayPlanResult) return value;
      if (value is Map<String, dynamic>) return AiDayPlanResult.fromMap(value);
      if (value is Map) {
        return AiDayPlanResult.fromMap(Map<String, dynamic>.from(value));
      }
      if (value is String && value.trim().isNotEmpty) {
        return AiDayPlanResult.fromJsonString(value);
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
