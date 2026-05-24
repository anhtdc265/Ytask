import 'dart:convert';

/// Structured result returned by Gemini for the AI day-planning feature.
///
/// Keep this model separate from UI widgets so ChatbotScreen can render
/// cards/messages without parsing free-form text from the model.
class AiDayPlanResult {
  static const List<String> orderedJsonFields = <String>[
    'summary',
    'items',
    'tips',
  ];

  final String summary;
  final List<AiDayPlanItem> items;
  final List<String> tips;

  const AiDayPlanResult({
    required this.summary,
    this.items = const <AiDayPlanItem>[],
    this.tips = const <String>[],
  });

  factory AiDayPlanResult.empty({
    String summary = 'Hôm nay bạn chưa có nhiệm vụ nào cần sắp xếp.',
  }) {
    return AiDayPlanResult(summary: summary);
  }

  factory AiDayPlanResult.fromJsonString(String source) {
    final jsonText = _extractJsonObject(source.trim());
    final dynamic decoded;

    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw FormatException(
        'AI day plan JSON is malformed: ${e.message}',
        e.source,
        e.offset,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI day plan JSON must be an object.');
    }

    return AiDayPlanResult.fromMap(decoded);
  }

  factory AiDayPlanResult.fromMap(Map<String, dynamic> map) {
    final parsedItems = _parseItems(map['items'])
      ..sort((a, b) => a.suggestedOrder.compareTo(b.suggestedOrder));

    return AiDayPlanResult(
      summary: _parseString(map['summary']) ??
          'Đây là kế hoạch gợi ý cho các nhiệm vụ hôm nay.',
      items: List<AiDayPlanItem>.unmodifiable(parsedItems),
      tips: List<String>.unmodifiable(_parseStringList(map['tips'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary.trim(),
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'tips': tips.map(_cleanText).where((tip) => tip.isNotEmpty).toList(),
    };
  }

  String toJsonString() {
    return jsonEncode(toMap());
  }

  AiDayPlanResult copyWith({
    String? summary,
    List<AiDayPlanItem>? items,
    List<String>? tips,
  }) {
    return AiDayPlanResult(
      summary: summary ?? this.summary,
      items: items ?? this.items,
      tips: tips ?? this.tips,
    );
  }

  bool get hasItems => items.isNotEmpty;

  /// A readable fallback message for the current chat UI.
  /// Later, the same structured data can be rendered by a custom card widget.
  String toChatText() {
    final buffer = StringBuffer()
      ..writeln('**Kế hoạch gợi ý hôm nay**')
      ..writeln()
      ..writeln(summary.trim());

    if (items.isNotEmpty) {
      buffer.writeln();
      for (final item in items) {
        buffer
          ..writeln('${item.suggestedOrder}. ${item.title}')
          ..writeln('Lý do: ${item.reason}');

        if (item.suggestedTimeText.trim().isNotEmpty) {
          buffer.writeln('Gợi ý thời gian: ${item.suggestedTimeText}');
        }

        buffer.writeln();
      }
    }

    if (tips.isNotEmpty) {
      buffer.writeln('**Gợi ý thêm:**');
      for (final tip in tips) {
        buffer.writeln('- $tip');
      }
    }

    return buffer.toString().trim();
  }

  static List<AiDayPlanItem> _parseItems(dynamic value) {
    if (value is! List) return <AiDayPlanItem>[];

    final items = <AiDayPlanItem>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        final parsed = AiDayPlanItem.fromMap(item);
        if (parsed.taskId.isNotEmpty && parsed.title.isNotEmpty) {
          items.add(parsed);
        }
      } else if (item is Map) {
        final parsed = AiDayPlanItem.fromMap(Map<String, dynamic>.from(item));
        if (parsed.taskId.isNotEmpty && parsed.title.isNotEmpty) {
          items.add(parsed);
        }
      }
    }

    return items;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map(_parseString)
        .whereType<String>()
        .map(_cleanText)
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return _cleanText(value);
    return _cleanText(value.toString());
  }

  static String _cleanText(String value) {
    return value.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
  }

  static String _extractJsonObject(String source) {
    final fencedJsonMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(source);

    if (fencedJsonMatch != null) {
      return fencedJsonMatch.group(1)?.trim() ?? source;
    }

    final start = source.indexOf('{');
    final end = source.lastIndexOf('}');

    if (start >= 0 && end > start) {
      return source.substring(start, end + 1).trim();
    }

    return source;
  }
}

/// One recommended task inside an AI day plan.
class AiDayPlanItem {
  final String taskId;
  final String title;
  final int suggestedOrder;
  final String reason;
  final String suggestedTimeText;

  const AiDayPlanItem({
    required this.taskId,
    required this.title,
    required this.suggestedOrder,
    required this.reason,
    this.suggestedTimeText = '',
  });

  factory AiDayPlanItem.fromMap(Map<String, dynamic> map) {
    return AiDayPlanItem(
      taskId: AiDayPlanResult._parseString(map['taskId']) ?? '',
      title: AiDayPlanResult._parseString(map['title']) ?? '',
      suggestedOrder: _parsePositiveInt(
        map['suggestedOrder'],
        fallback: 999,
      ),
      reason: AiDayPlanResult._parseString(map['reason']) ??
          'Nhiệm vụ này phù hợp để thực hiện trong hôm nay.',
      suggestedTimeText:
          AiDayPlanResult._parseString(map['suggestedTimeText']) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId.trim(),
      'title': title.trim(),
      'suggestedOrder': suggestedOrder,
      'reason': reason.trim(),
      'suggestedTimeText': suggestedTimeText.trim(),
    };
  }

  AiDayPlanItem copyWith({
    String? taskId,
    String? title,
    int? suggestedOrder,
    String? reason,
    String? suggestedTimeText,
  }) {
    return AiDayPlanItem(
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      suggestedOrder: suggestedOrder ?? this.suggestedOrder,
      reason: reason ?? this.reason,
      suggestedTimeText: suggestedTimeText ?? this.suggestedTimeText,
    );
  }

  static int _parsePositiveInt(dynamic value, {required int fallback}) {
    int? parsed;

    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value.trim());
    }

    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }
}
