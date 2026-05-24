import 'dart:convert';

/// A temporary task draft extracted by AI from a natural-language request.
///
/// This model is NOT the real TaskModel saved to Firestore.
/// It is used as a safe intermediate object before showing a preview dialog
/// and asking the user to confirm task creation.
class AiTaskDraft {
  static const String priorityLow = 'low';
  static const String priorityMedium = 'medium';
  static const String priorityHigh = 'high';
  static const String defaultPriority = priorityMedium;
  static const String defaultCategoryName = 'Công việc';

  static const List<String> allowedPriorities = <String>[
    priorityLow,
    priorityMedium,
    priorityHigh,
  ];

  static const List<String> orderedJsonFields = <String>[
    'title',
    'description',
    'priority',
    'startAt',
    'endAt',
    'reminderMinutes',
    'categoryName',
    'location',
    'missingFields',
    'confidence',
  ];

  final String title;
  final String description;

  /// Normalized values: low, medium, high.
  final String priority;

  /// Parsed from AI ISO-8601 strings, for example: 2026-05-11T20:00:00.
  final DateTime? startAt;
  final DateTime? endAt;

  /// Reminder offset in minutes before the task starts.
  /// Null means the AI did not extract a reminder.
  final int? reminderMinutes;

  /// Human-readable category name extracted by AI.
  /// It will be mapped to a real categoryId later before saving TaskModel.
  final String? categoryName;
  final String? location;

  /// Fields that AI could not confidently extract.
  /// Example: ['startAt'] when the user says "nhắc tôi học Flutter"
  /// without giving a time.
  final List<String> missingFields;

  /// AI confidence from 0.0 to 1.0.
  final double confidence;

  const AiTaskDraft({
    required this.title,
    this.description = '',
    this.priority = defaultPriority,
    this.startAt,
    this.endAt,
    this.reminderMinutes,
    this.categoryName,
    this.location,
    this.missingFields = const <String>[],
    this.confidence = 0.0,
  });

  factory AiTaskDraft.empty() {
    return const AiTaskDraft(
      title: '',
      missingFields: <String>['title'],
    );
  }

  factory AiTaskDraft.fromJsonString(String source) {
    final jsonText = _extractJsonObject(source.trim());
    final dynamic decoded;

    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw FormatException(
        'AI task draft JSON is malformed: ${e.message}',
        e.source,
        e.offset,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI task draft JSON must be an object.');
    }

    return AiTaskDraft.fromMap(decoded);
  }

  factory AiTaskDraft.fromMap(Map<String, dynamic> map) {
    final title = _parseString(map['title']) ?? '';
    final description = _parseString(map['description']) ?? '';
    final priority = _normalizePriority(map['priority']);
    final startAt = _parseDateTime(map['startAt']);
    final endAt = _parseDateTime(map['endAt']);
    final reminderMinutes = _parseReminderMinutes(map['reminderMinutes']);
    final categoryName = _parseString(map['categoryName']);
    final location = _parseString(map['location']);
    final confidence = _parseConfidence(map['confidence']);

    final missingFields = _normalizeMissingFields(
      map: map,
      title: title,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      reminderMinutes: reminderMinutes,
    );

    return AiTaskDraft(
      title: title,
      description: description,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      reminderMinutes: reminderMinutes,
      categoryName: categoryName,
      location: location,
      missingFields: missingFields,
      confidence: confidence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'reminderMinutes': reminderMinutes,
      'categoryName': effectiveCategoryName,
      'location': _cleanNullableText(location),
      'missingFields': missingFields,
      'confidence': confidence,
    };
  }

  String toJsonString() {
    return jsonEncode(toMap());
  }

  AiTaskDraft copyWith({
    String? title,
    String? description,
    String? priority,
    DateTime? startAt,
    DateTime? endAt,
    int? reminderMinutes,
    String? categoryName,
    String? location,
    List<String>? missingFields,
    double? confidence,
    bool clearStartAt = false,
    bool clearEndAt = false,
    bool clearReminderMinutes = false,
    bool clearCategoryName = false,
    bool clearLocation = false,
  }) {
    return AiTaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority != null ? _normalizePriority(priority) : this.priority,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      reminderMinutes:
          clearReminderMinutes ? null : (reminderMinutes ?? this.reminderMinutes),
      categoryName: clearCategoryName ? null : (categoryName ?? this.categoryName),
      location: clearLocation ? null : (location ?? this.location),
      missingFields: missingFields ?? this.missingFields,
      confidence: confidence != null ? _clampConfidence(confidence) : this.confidence,
    );
  }

  bool get hasTitle => title.trim().isNotEmpty;

  bool get hasMissingFields => missingFields.isNotEmpty;

  bool get hasStartTime => startAt != null;

  bool get hasEndTime => endAt != null;

  bool get hasReminder => reminderMinutes != null && reminderMinutes! > 0;

  /// Reminder before start time requires a known startAt.
  bool get needsStartTimeForReminder => hasReminder && startAt == null;

  bool get isNotTaskCreationIntent => missingFields.contains('intent');

  String get effectiveCategoryName {
    final value = categoryName?.trim();
    if (value == null || value.isEmpty) {
      return defaultCategoryName;
    }
    return value;
  }

  /// Validation used before showing or saving the draft.
  /// This does not replace final validation in the service that maps draft -> TaskModel.
  List<String> validateForPreview() {
    final errors = <String>[];

    if (isNotTaskCreationIntent) {
      errors.add('intent');
    }

    if (!hasTitle) {
      errors.add('title');
    }

    if (!_isAllowedPriority(priority)) {
      errors.add('priority');
    }

    if (needsStartTimeForReminder) {
      errors.add('startAt');
    }

    if (startAt != null && endAt != null && endAt!.isBefore(startAt!)) {
      errors.add('endAt');
    }

    errors.addAll(
      missingFields
          .map((field) => _normalizeMissingFieldName(field))
          .whereType<String>()
          .where((field) => field.isNotEmpty),
    );

    return errors.toSet().toList(growable: false);
  }

  bool get canCreateSafely => validateForPreview().isEmpty;


  bool get hasInvalidOrMissingPriority {
    return validateForPreview().contains('priority');
  }

  bool get hasInvalidStartTime {
    return validateForPreview().contains('startAt');
  }

  bool get hasInvalidEndTime {
    return validateForPreview().contains('endAt');
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static String? _cleanNullableText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = _parseString(value);
    if (text == null) return null;

    // For AI task drafts, date-only values are not enough because reminder and
    // scheduling logic need an exact time. The prompt asks the model to return
    // null when the user gives only a vague day without hour/minute.
    final hasTimePart = RegExp(r'(T|\s)\d{1,2}:\d{2}').hasMatch(text);
    if (!hasTimePart) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static int? _parseReminderMinutes(dynamic value) {
    if (value == null) return null;

    int? parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else {
      final text = _parseString(value);
      parsed = text == null ? null : int.tryParse(text);
    }

    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const <String>[];

    if (value is List) {
      return value
          .map(_parseString)
          .whereType<String>()
          .map(_normalizeMissingFieldName)
          .whereType<String>()
          .toSet()
          .toList(growable: false);
    }

    final singleValue = _normalizeMissingFieldName(_parseString(value));
    if (singleValue == null) return const <String>[];

    return <String>[singleValue];
  }

  static double _parseConfidence(dynamic value) {
    if (value == null) return 0.0;

    double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else {
      final text = _parseString(value);
      parsed = text == null ? null : double.tryParse(text);
    }

    return _clampConfidence(parsed ?? 0.0);
  }

  static double _clampConfidence(double value) {
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }

  static String _normalizePriority(dynamic value) {
    final raw = _parseString(value)?.toLowerCase() ?? defaultPriority;

    switch (raw) {
      case priorityLow:
      case 'thấp':
      case 'thap':
        return priorityLow;
      case priorityHigh:
      case 'cao':
        return priorityHigh;
      case priorityMedium:
      case 'trung bình':
      case 'trung binh':
      case 'vừa':
      case 'vua':
      case 'normal':
      case 'default':
        return priorityMedium;
      default:
        return defaultPriority;
    }
  }

  static bool _isStrictPriorityToken(dynamic value) {
    final raw = _parseString(value)?.toLowerCase();
    if (raw == null) return false;

    return _isAllowedPriority(raw);
  }

  static bool _isAllowedPriority(String value) {
    return allowedPriorities.contains(value);
  }

  static List<String> _normalizeMissingFields({
    required Map<String, dynamic> map,
    required String title,
    required String priority,
    required DateTime? startAt,
    required DateTime? endAt,
    required int? reminderMinutes,
  }) {
    final fields = <String>{
      ..._parseStringList(map['missingFields']),
    };

    if (title.trim().isEmpty && !fields.contains('intent')) {
      fields.add('title');
    }

    if (!_isStrictPriorityToken(map['priority'])) {
      fields.add('priority');
    }

    final rawStartAt = _parseString(map['startAt']);
    if (rawStartAt != null && startAt == null) {
      fields.add('startAt');
    }

    final rawEndAt = _parseString(map['endAt']);
    if (rawEndAt != null && endAt == null) {
      fields.add('endAt');
    }

    if (reminderMinutes != null && startAt == null) {
      fields.add('startAt');
    }

    return fields.toList(growable: false);
  }

  static String? _normalizeMissingFieldName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;

    switch (text) {
      case 'title':
      case 'priority':
      case 'startAt':
      case 'endAt':
      case 'reminderMinutes':
      case 'categoryName':
      case 'location':
      case 'intent':
        return text;
      default:
        return text;
    }
  }

  /// Allows parsing responses that accidentally include Markdown fences
  /// around a JSON object.
  static String _extractJsonObject(String source) {
    final withoutFence = source
        .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    if (withoutFence.startsWith('{') && withoutFence.endsWith('}')) {
      return withoutFence;
    }

    final start = withoutFence.indexOf('{');
    final end = withoutFence.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found in AI response.');
    }

    return withoutFence.substring(start, end + 1);
  }

  @override
  String toString() {
    return 'AiTaskDraft(${toJsonString()})';
  }
}
