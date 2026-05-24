import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:todo_app/models/ai_day_plan_result.dart';
import 'package:todo_app/models/ai_day_plan_task_summary.dart';
import 'package:todo_app/models/ai_task_draft.dart';

class ChatbotService {
  static const String _modelName = 'gemini-2.5-flash-lite';

  static const String _fallbackErrorMessage =
      'Hiện tại trợ lý AI chưa phản hồi được, bạn thử lại sau nhé.';

  static const String _quotaLimitMessage =
      'Trợ lý đang bận một chút. Bạn hãy thử lại sau một lát nhé.';

  static const String _emptyMessage = 'Bạn hãy nhập nội dung cần hỏi nhé.';

  static const String _emptyResponseMessage =
      'Mình chưa nhận được phản hồi phù hợp. Bạn thử hỏi lại ngắn gọn hơn nhé.';

  static const String _systemPrompt = '''
Bạn là trợ lý AI của ứng dụng YTask - ứng dụng quản lý công việc cá nhân.

VAI TRÒ:
- Hỗ trợ người dùng hiểu cách dùng YTask.
- Gợi ý cách sắp xếp công việc cá nhân.
- Hướng dẫn tạo nhiệm vụ, xem tiến độ, xử lý nhiệm vụ quá hạn.
- Trả lời như một trợ lý trong app, thân thiện, rõ ràng, không lan man.

BỐI CẢNH ỨNG DỤNG YTASK:
- YTask là ứng dụng quản lý công việc cá nhân.
- Người dùng có thể đăng ký, đăng nhập tài khoản.
- Dữ liệu nhiệm vụ được lưu theo tài khoản người dùng.
- Dashboard là màn hình chính để xem lịch, danh sách nhiệm vụ và tạo nhiệm vụ.
- Người dùng tạo nhiệm vụ bằng nút dấu cộng (+) ở Dashboard.
- Progress là màn hình theo dõi tiến độ công việc.
- Chatbot là màn hình người dùng đang nói chuyện với bạn.
- Profile là màn hình tài khoản/cá nhân.
- Nhiệm vụ có thể có tiêu đề, mô tả, thời gian bắt đầu, thời gian kết thúc, nhãn, độ ưu tiên, vị trí và nhắc nhở.
- Trạng thái nhiệm vụ gồm:
  + pending: chưa làm / đang chờ
  + inProgress: đang làm
  + completed: đã hoàn thành
  + cancelled: đã hủy
- Nhiệm vụ quá hạn là nhiệm vụ đã qua thời gian kết thúc nhưng chưa hoàn thành.

LUẬT TRẢ LỜI:
- Luôn trả lời bằng tiếng Việt.
- Nếu người dùng không yêu cầu giải thích chi tiết, trả lời trong 3-6 dòng.
- Nếu cần liệt kê, chỉ dùng tối đa 3-5 ý chính.
- Hạn chế markdown; chỉ dùng in đậm hoặc danh sách khi thật sự cần.
- Không trả lời quá dài trên màn hình mobile.
- Không dùng giọng quá trang trọng; hãy thân thiện và dễ hiểu.

GIỚI HẠN HIỆN TẠI:
- Bạn được phép hỗ trợ hỏi đáp và hướng dẫn dùng YTask.
- Với yêu cầu tạo nhiệm vụ, app có luồng riêng để AI tạo bản nháp nhiệm vụ và người dùng xác nhận trước khi lưu.
- Bạn không được tự khẳng định đã tạo/lưu nhiệm vụ nếu app chưa có bước xác nhận của người dùng.
- Bạn chưa được tự lưu thay đổi vào dữ liệu của người dùng.
- Bạn chưa được tự lưu lịch sử chat.
- Bạn chưa được đọc danh sách nhiệm vụ thật của người dùng.
- Nếu người dùng hỏi “hôm nay tôi có việc gì?”, “task của tôi đâu?”, hoặc hỏi dữ liệu cá nhân hiện tại, hãy nói rằng hiện tại bạn chưa được cấp quyền xem trực tiếp dữ liệu nhiệm vụ, rồi hướng dẫn họ xem ở Dashboard hoặc Progress.

QUY TẮC CHỐNG BỊA:
- Không bịa danh sách nhiệm vụ của người dùng.
- Không bịa rằng đã lưu dữ liệu.
- Không bịa rằng đã gửi thông báo nhắc nhở.
- Không khẳng định thao tác đã hoàn thành nếu app chưa thực hiện thao tác đó.
- Nếu không chắc, hãy nói rõ giới hạn hiện tại.

MỤC TIÊU ĐỒ ÁN:
- Chatbot cần hoạt động ổn định để demo.
- Trọng tâm là hỗ trợ người dùng dùng app YTask hiệu quả hơn.
- Luồng tạo bản nháp nhiệm vụ bằng ngôn ngữ tự nhiên phải luôn có bước preview/xác nhận trước khi lưu.
''';

  static const String _taskDraftSystemPrompt = '''
Bạn là bộ trích xuất bản nháp nhiệm vụ của ứng dụng YTask.

NHIỆM VỤ DUY NHẤT:
- Đọc câu tiếng Việt tự nhiên của người dùng.
- Trích xuất thông tin nhiệm vụ thành đúng 1 JSON object.
- Không trò chuyện, không giải thích, không markdown, không bọc ```json.
- Không tự tạo TaskModel thật.
- Không tự lưu dữ liệu.
- Không khẳng định đã lưu dữ liệu.

SCHEMA JSON BẮT BUỘC:
{
  "title": string,
  "description": string,
  "priority": "low" | "medium" | "high",
  "startAt": string | null,
  "endAt": string | null,
  "reminderMinutes": number | null,
  "categoryName": string | null,
  "location": string | null,
  "missingFields": string[],
  "confidence": number
}

QUY TẮC FIELD:
- title: bắt buộc nếu câu là yêu cầu tạo nhiệm vụ. Tên ngắn gọn, bỏ các cụm như "tạo nhiệm vụ", "nhắc tôi", "thêm task".
- description: nếu người dùng có mô tả thêm thì điền, nếu không có thì để "".
- priority: chỉ trả low, medium hoặc high. Nếu không nói rõ thì dùng medium.
- startAt và endAt: dùng ISO-8601 local time dạng yyyy-MM-ddTHH:mm:ss. Nếu thiếu ngày hoặc thiếu giờ cụ thể thì dùng null.
- reminderMinutes: số phút nhắc trước giờ bắt đầu. Nếu không có nhắc trước thì null.
- categoryName: nếu không rõ thì dùng "Công việc". Không được để chuỗi rỗng.
- location: địa điểm nếu người dùng nói rõ, nếu không thì null.
- missingFields: liệt kê field còn thiếu quan trọng. Ví dụ có reminderMinutes nhưng startAt null thì thêm "startAt". Nếu thiếu title thì thêm "title". Nếu câu không phải yêu cầu tạo nhiệm vụ thì thêm "intent".
- confidence: số từ 0.0 đến 1.0 thể hiện độ chắc chắn.

QUY TẮC NGÀY GIỜ:
- Luôn dựa vào thời điểm hiện tại được app cung cấp trong prompt.
- "hôm nay" là ngày hiện tại.
- "ngày mai", "mai", "tối mai", "sáng mai" là ngày kế tiếp.
- "tối" nếu có giờ như 8h tối thì hiểu là 20:00.
- "sáng" nếu có giờ như 6h sáng thì hiểu là 06:00.
- Nếu chỉ nói "chiều mai" mà không có giờ cụ thể thì startAt null và missingFields thêm "startAt".
- Nếu chỉ có ngày mà không có giờ cụ thể thì startAt null và missingFields thêm "startAt".
- Nếu không có endAt thì endAt null.

ĐẦU RA:
- Chỉ trả về JSON object hợp lệ theo schema.
- Không thêm bất kỳ chữ nào ngoài JSON.
''';


  static const String _dayPlanSystemPrompt = '''
Bạn là trợ lý lập kế hoạch trong ngày của YTask.

NHIỆM VỤ:
- Dựa trên danh sách task hôm nay do app cung cấp.
- Sắp xếp thứ tự nên làm trong ngày.
- Ưu tiên task có priority high, gần đến hạn, đang pending/inProgress.
- Task có thời gian kết thúc gần hơn thường nên làm trước.
- Task chưa có thời gian rõ ràng có thể xếp sau, trừ khi priority high.
- Không bịa thêm task mới.
- Không dùng taskId ngoài danh sách app cung cấp.
- Không tự nhận đã lưu dữ liệu, tạo task, sửa task hoặc gửi thông báo.
- Trả về JSON đúng schema.
- Trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu.

SCHEMA JSON BẮT BUỘC:
{
  "summary": string,
  "items": [
    {
      "taskId": string,
      "title": string,
      "suggestedOrder": number,
      "reason": string,
      "suggestedTimeText": string
    }
  ],
  "tips": string[]
}

QUY TẮC ĐẦU RA:
- Chỉ trả về 1 JSON object hợp lệ.
- Không thêm markdown, không bọc ```json.
- items chỉ được chứa các task có trong danh sách app cung cấp.
- taskId phải giữ nguyên chính xác theo danh sách app cung cấp.
- title phải giữ gần đúng với title app cung cấp, không tự đặt tên mới.
- suggestedOrder bắt đầu từ 1 và tăng dần.
- reason nêu lý do ngắn gọn: ưu tiên cao, gần đến hạn, đang thực hiện, có nhắc nhở, hoặc chưa có thời gian rõ ràng.
- suggestedTimeText là gợi ý ngắn như "Nên làm đầu tiên", "Làm sau nhiệm vụ ưu tiên cao", hoặc "Có thể xếp vào cuối ngày".
''';


  static final Schema _taskDraftResponseSchema = Schema.object(
    properties: {
      'title': Schema.string(
        description: 'Tên nhiệm vụ ngắn gọn. Dùng chuỗi rỗng nếu chưa xác định được.',
      ),
      'description': Schema.string(
        description: 'Mô tả thêm cho nhiệm vụ. Dùng chuỗi rỗng nếu không có.',
      ),
      'priority': Schema.enumString(
        enumValues: AiTaskDraft.allowedPriorities,
        description: 'Độ ưu tiên, chỉ gồm low, medium hoặc high.',
      ),
      'startAt': Schema.string(
        nullable: true,
        description: 'Thời gian bắt đầu dạng yyyy-MM-ddTHH:mm:ss, hoặc null nếu thiếu ngày/giờ cụ thể.',
      ),
      'endAt': Schema.string(
        nullable: true,
        description: 'Thời gian kết thúc dạng yyyy-MM-ddTHH:mm:ss, hoặc null nếu không có.',
      ),
      'reminderMinutes': Schema.integer(
        nullable: true,
        description: 'Số phút nhắc trước giờ bắt đầu, hoặc null nếu không có nhắc nhở.',
      ),
      'categoryName': Schema.string(
        nullable: true,
        description: 'Tên danh mục dự đoán. Nếu không rõ thì dùng Công việc.',
      ),
      'location': Schema.string(
        nullable: true,
        description: 'Địa điểm nếu người dùng nói rõ, hoặc null.',
      ),
      'missingFields': Schema.array(
        items: Schema.string(),
        description: 'Các field còn thiếu, ví dụ title, startAt, endAt, priority, intent.',
      ),
      'confidence': Schema.number(
        description: 'Độ chắc chắn từ 0.0 đến 1.0.',
      ),
    },
    propertyOrdering: AiTaskDraft.orderedJsonFields,
  );


  static final Schema _dayPlanResponseSchema = Schema.object(
    properties: {
      'summary': Schema.string(
        description: 'Tóm tắt ngắn gọn kế hoạch làm việc hôm nay bằng tiếng Việt.',
      ),
      'items': Schema.array(
        items: Schema.object(
          properties: {
            'taskId': Schema.string(
              description: 'ID task, phải lấy đúng từ danh sách app cung cấp.',
            ),
            'title': Schema.string(
              description: 'Tên nhiệm vụ, giữ gần đúng với title app cung cấp.',
            ),
            'suggestedOrder': Schema.integer(
              description: 'Thứ tự nên làm, bắt đầu từ 1.',
            ),
            'reason': Schema.string(
              description: 'Lý do đề xuất ngắn gọn bằng tiếng Việt.',
            ),
            'suggestedTimeText': Schema.string(
              description: 'Gợi ý thời điểm làm ngắn gọn bằng tiếng Việt.',
            ),
          },
          propertyOrdering: <String>[
            'taskId',
            'title',
            'suggestedOrder',
            'reason',
            'suggestedTimeText',
          ],
        ),
        description: 'Danh sách task được sắp xếp theo thứ tự nên làm trong ngày.',
      ),
      'tips': Schema.array(
        items: Schema.string(),
        description: 'Một vài lời khuyên ngắn để hoàn thành kế hoạch trong ngày.',
      ),
    },
    propertyOrdering: AiDayPlanResult.orderedJsonFields,
  );

  late final GenerativeModel _model =
  FirebaseAI.googleAI(auth: FirebaseAuth.instance).generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_systemPrompt),
    generationConfig: GenerationConfig(
      candidateCount: 1,
      maxOutputTokens: 360,
      temperature: 0.35,
      topP: 0.8,
      topK: 40,
    ),
  );

  late final GenerativeModel _taskDraftModel =
  FirebaseAI.googleAI(auth: FirebaseAuth.instance).generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_taskDraftSystemPrompt),
    generationConfig: GenerationConfig(
      candidateCount: 1,
      maxOutputTokens: 420,
      temperature: 0.1,
      topP: 0.8,
      topK: 40,
      responseMimeType: 'application/json',
      responseSchema: _taskDraftResponseSchema,
    ),
  );


  late final GenerativeModel _dayPlanModel =
  FirebaseAI.googleAI(auth: FirebaseAuth.instance).generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_dayPlanSystemPrompt),
    generationConfig: GenerationConfig(
      candidateCount: 1,
      maxOutputTokens: 900,
      temperature: 0.2,
      topP: 0.8,
      topK: 40,
      responseMimeType: 'application/json',
      responseSchema: _dayPlanResponseSchema,
    ),
  );

  Future<String> sendMessage(String userMessage) async {
    final message = userMessage.trim();

    if (message.isEmpty) {
      return _emptyMessage;
    }

    try {
      final response = await _model.generateContent([
        Content.text(_buildUserPrompt(message)),
      ]);

      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        return _emptyResponseMessage;
      }

      return text;
    } catch (e, stackTrace) {
      debugPrint('ChatbotService error: $e');
      debugPrintStack(stackTrace: stackTrace);

      return friendlyErrorMessage(e);
    }
  }

  static bool isQuotaError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('resource_exhausted') ||
        text.contains('quota') ||
        text.contains('rate limit') ||
        text.contains('rate-limits') ||
        text.contains('generate_content_free_tier_requests') ||
        text.contains('retry in');
  }

  static String friendlyErrorMessage(Object error) {
    if (isQuotaError(error)) {
      return _quotaLimitMessage;
    }

    return _fallbackErrorMessage;
  }

  Future<AiTaskDraft?> extractTaskDraft(String userMessage) async {
    final message = userMessage.trim();

    if (message.isEmpty) {
      return null;
    }

    try {
      final response = await _taskDraftModel.generateContent([
        Content.text(_buildTaskDraftPrompt(message)),
      ]);

      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        return _buildLocalFallbackTaskDraft(message);
      }

      final draft = _sanitizeDraftAfterAiResponse(
        AiTaskDraft.fromJsonString(text),
        message,
      );
      final validationErrors = draft.validateForPreview();

      if (draft.isNotTaskCreationIntent) {
        debugPrint(
          'ChatbotService extractTaskDraft ignored non-create intent. raw=$text',
        );
        return null;
      }

      if (validationErrors.isNotEmpty) {
        debugPrint(
          'ChatbotService extractTaskDraft validation warnings: '
              '${validationErrors.join(', ')} | raw=$text',
        );
      }

      // Return the draft even when validation has warnings so the UI can show
      // a preview and tell the user exactly which fields must be fixed.
      return draft;
    } catch (e, stackTrace) {
      debugPrint('ChatbotService extractTaskDraft error: $e');
      debugPrintStack(stackTrace: stackTrace);

      // If Firebase AI is temporarily unavailable or the model returns malformed
      // JSON, still create a conservative local draft. This keeps the important
      // safety flow alive: preview first, user confirms later, never auto-save.
      return _buildLocalFallbackTaskDraft(message);
    }
  }

  Future<AiDayPlanResult?> generateTodayPlan({
    required List<AiDayPlanTaskSummary> tasks,
  }) async {
    final safeTasks = tasks
        .where((task) => task.id.trim().isNotEmpty && task.title.trim().isNotEmpty)
        .toList(growable: false);

    if (safeTasks.isEmpty) {
      return AiDayPlanResult.empty();
    }

    try {
      final response = await _dayPlanModel.generateContent([
        Content.text(_buildDayPlanPrompt(safeTasks)),
      ]);

      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        debugPrint('ChatbotService generateTodayPlan empty response.');
        return null;
      }

      final result = AiDayPlanResult.fromJsonString(text);
      return _sanitizeDayPlanResult(result, safeTasks);
    } catch (e, stackTrace) {
      debugPrint('ChatbotService generateTodayPlan error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }


  String _buildUserPrompt(String message) {
    final now = DateTime.now().toLocal().toIso8601String();

    return '''
Thời điểm hiện tại của thiết bị: $now

Câu hỏi của người dùng:
$message

Hãy trả lời theo đúng vai trò trợ lý YTask và tuân thủ toàn bộ giới hạn trong system instruction.
''';
  }

  String _buildTaskDraftPrompt(String message) {
    final now = DateTime.now().toLocal();
    final nowIso = now.toIso8601String();
    final timezoneName = now.timeZoneName;
    final timezoneOffset = now.timeZoneOffset;

    return '''
Thời điểm hiện tại của thiết bị: $nowIso
Múi giờ thiết bị: $timezoneName
Độ lệch múi giờ: $timezoneOffset

Câu người dùng:
$message

Hãy trích xuất thành đúng 1 JSON object theo schema đã yêu cầu.
''';
  }


  String _buildDayPlanPrompt(List<AiDayPlanTaskSummary> tasks) {
    final now = DateTime.now().toLocal();
    final nowIso = now.toIso8601String();
    final timezoneName = now.timeZoneName;
    final timezoneOffset = now.timeZoneOffset;
    final taskLines = tasks.map((task) => task.toPromptLine()).join('\n');

    return '''
Thời điểm hiện tại của thiết bị: $nowIso
Múi giờ thiết bị: $timezoneName
Độ lệch múi giờ: $timezoneOffset

Danh sách task hôm nay của người dùng hiện tại:
$taskLines

Hãy lập kế hoạch trong ngày dựa duy nhất trên danh sách task trên.
Trả về đúng 1 JSON object theo schema đã yêu cầu.
''';
  }

  AiDayPlanResult _sanitizeDayPlanResult(
      AiDayPlanResult result,
      List<AiDayPlanTaskSummary> sourceTasks,
      ) {
    final sourceById = <String, AiDayPlanTaskSummary>{
      for (final task in sourceTasks) task.id: task,
    };

    final seenIds = <String>{};
    final sanitizedItems = <AiDayPlanItem>[];

    for (final item in result.items) {
      final sourceTask = sourceById[item.taskId];
      if (sourceTask == null || seenIds.contains(item.taskId)) {
        continue;
      }

      final lacksTime = sourceTask.startAt == null && sourceTask.endAt == null;
      final aiTimeText = item.suggestedTimeText.trim();
      final shouldForceMissingTimeNote = lacksTime &&
          !aiTimeText.toLowerCase().contains('chưa có thời gian');
      final safeSuggestedTimeText = shouldForceMissingTimeNote
          ? 'Chưa có thời gian rõ ràng, có thể xếp vào cuối ngày.'
          : aiTimeText;

      seenIds.add(item.taskId);
      sanitizedItems.add(
        item.copyWith(
          title: sourceTask.title,
          suggestedOrder: sanitizedItems.length + 1,
          suggestedTimeText: safeSuggestedTimeText,
        ),
      );
    }

    final missingTasks = sourceTasks.where((task) => !seenIds.contains(task.id));
    for (final task in missingTasks) {
      sanitizedItems.add(
        AiDayPlanItem(
          taskId: task.id,
          title: task.title,
          suggestedOrder: sanitizedItems.length + 1,
          reason: 'Nhiệm vụ này có trong danh sách hôm nay nhưng AI chưa xếp hạng rõ ràng.',
          suggestedTimeText: task.startAt == null && task.endAt == null
              ? 'Chưa có thời gian rõ ràng, có thể xếp sau.'
              : 'Có thể làm sau các nhiệm vụ ưu tiên hơn.',
        ),
      );
    }

    return result.copyWith(
      summary: result.summary.trim().isEmpty
          ? 'Đây là kế hoạch gợi ý cho các nhiệm vụ hôm nay.'
          : result.summary.trim(),
      items: List<AiDayPlanItem>.unmodifiable(sanitizedItems),
      tips: result.tips,
    );
  }


  AiTaskDraft? _buildLocalFallbackTaskDraft(String message) {
    final normalized = _normalizeVietnamese(message);
    final title = _extractFallbackTitle(message);
    final priorityResult = _extractFallbackPriority(normalized);
    final startAt = _extractFallbackStartAt(normalized);
    final reminderMinutes = _extractFallbackReminderMinutes(normalized);
    final missingFields = <String>{};

    if (title.trim().isEmpty) {
      missingFields.add('title');
    }

    if (priorityResult.isInvalidExplicitPriority) {
      missingFields.add('priority');
    }

    if (reminderMinutes != null && startAt == null) {
      missingFields.add('startAt');
    }

    // Nếu người dùng chỉ nói ngày mơ hồ như "ngày mai" nhưng không nói giờ,
    // không nên cho lưu ngay. UI sẽ hiện bản nháp và yêu cầu bổ sung thời gian.
    if (_hasDateHintWithoutClock(normalized)) {
      missingFields.add('startAt');
    }

    final draft = _sanitizeDraftAfterAiResponse(
      AiTaskDraft(
        title: title,
        description: '',
        priority: priorityResult.priority,
        startAt: startAt,
        endAt: null,
        reminderMinutes: reminderMinutes,
        categoryName: AiTaskDraft.defaultCategoryName,
        location: null,
        missingFields: missingFields.toList(growable: false),
        confidence: title.trim().isEmpty ? 0.2 : 0.45,
      ),
      message,
    );

    debugPrint(
      'ChatbotService using local fallback task draft: ${draft.toJsonString()}',
    );

    return draft;
  }

  AiTaskDraft _sanitizeDraftAfterAiResponse(
      AiTaskDraft draft,
      String originalMessage,
      ) {
    final normalizedMessage = _normalizeVietnamese(originalMessage);
    final missingFields = draft.missingFields.toSet();

    final cleanedTitle = _cleanDraftTitle(draft.title);
    final titleLooksLikeOnlyTime = _looksLikeOnlyDateOrTime(cleanedTitle);
    final title = titleLooksLikeOnlyTime ? '' : cleanedTitle;

    if (title.trim().isEmpty) {
      missingFields.add('title');
    } else {
      missingFields.remove('title');
    }

    final hasRangeExpression = _hasTimeRangeExpression(normalizedMessage);
    final hasDateHintWithoutClock = _hasDateHintWithoutClock(normalizedMessage);
    final startAt = draft.startAt ?? _extractFallbackStartAt(normalizedMessage);
    DateTime? endAt = draft.endAt;

    if (hasDateHintWithoutClock && startAt == null) {
      missingFields.add('startAt');
    }

    if (hasRangeExpression && endAt == null) {
      endAt = _extractFallbackEndAt(
        normalizedMessage,
        referenceStartAt: startAt,
      );
    }

    if (hasRangeExpression && endAt == null) {
      missingFields.add('endAt');
    }

    if (endAt != null) {
      missingFields.remove('endAt');
    }

    return draft.copyWith(
      title: title,
      startAt: startAt,
      endAt: endAt,
      categoryName: draft.effectiveCategoryName,
      missingFields: missingFields.toList(growable: false),
    );
  }

  String _cleanDraftTitle(String rawTitle) {
    var title = rawTitle.trim();

    title = title.replaceFirst(
      RegExp(
        r'^\s*(tạo|tao|thêm|them)\s+(nhiệm\s*vụ|nhiem\s*vu|task|công\s*việc|cong\s*viec)\s*',
        caseSensitive: false,
      ),
      '',
    );

    title = title.replaceFirst(
      RegExp(
        r'^\s*(nhắc|nhac)\s+(tôi|toi|mình|minh|em|tui|tao)\s*',
        caseSensitive: false,
      ),
      '',
    );

    title = title.replaceFirst(
      RegExp(
        r'^\s*(đến\s*hẹn|den\s*hen|tới\s*hẹn|toi\s*hen|sắp\s*đến\s*hẹn|sap\s*den\s*hen|hẹn|hen)\s*',
        caseSensitive: false,
      ),
      '',
    );

    final separator = RegExp(
      r'\s+(từ|tu|lúc|luc|vào|vao|đến|den|ngày|ngay|hôm\s*nay|hom\s*nay|ngày\s*mai|ngay\s*mai|mai|ưu\s*tiên|uu\s*tien|nhắc|nhac|ở|o)\b',
      caseSensitive: false,
    ).firstMatch(title);

    if (separator != null) {
      title = title.substring(0, separator.start);
    }

    return title
        .replaceAll(RegExp(r'''^["“”'\s]+|["“”'\s]+$'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _looksLikeOnlyDateOrTime(String title) {
    final normalized = _normalizeVietnamese(title);
    if (normalized.isEmpty) {
      return true;
    }

    if (RegExp(
      r'^(luc|vao|tu|den)?\s*\d{1,2}(h|:)?(\d{1,2})?\s*(sang|chieu|toi|dem)?\s*(hom nay|ngay mai|mai)?$',
    ).hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'^(hom nay|ngay mai|mai|toi nay|sang nay|chieu nay|toi mai|sang mai|chieu mai)$',
    ).hasMatch(normalized)) {
      return true;
    }

    final stripped = normalized
        .replaceAll(
      RegExp(r'\b(luc|vao|tu|den|ngay|hom|nay|mai|sang|chieu|toi|dem)\b'),
      ' ',
    )
        .replaceAll(RegExp(r'[0-9h/:\s]'), '');

    return stripped.isEmpty;
  }

  bool _hasDateHintWithoutClock(String normalized) {
    final hasDateHint = RegExp(
      r'\b(hom nay|ngay mai|mai|toi nay|sang mai|chieu mai|toi mai)\b',
    ).hasMatch(normalized) ||
        RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b').hasMatch(normalized);

    final hasClock = RegExp(
      r'\b\d{1,2}\s*(h|gio|:)\s*\d{0,2}\b',
    ).hasMatch(normalized);

    return hasDateHint && !hasClock;
  }

  bool _hasTimeRangeExpression(String normalized) {
    return RegExp(
      r'\b(tu|bat dau)\b.*\b(den|ket thuc|xong luc)\b',
    ).hasMatch(normalized);
  }

  DateTime? _extractFallbackEndAt(
      String normalized, {
        DateTime? referenceStartAt,
      }) {
    final match = RegExp(
      r'\b(den|ket thuc|xong luc)\s+(\d{1,2})\s*(?:h|gio|:)?\s*(\d{1,2})?\s*(sang|chieu|toi|dem)?',
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    var hour = int.tryParse(match.group(2) ?? '');
    final minute = int.tryParse(match.group(3) ?? '0') ?? 0;
    final dayPart = match.group(4);

    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    if ((dayPart == 'toi' || dayPart == 'dem' || dayPart == 'chieu') &&
        hour > 0 &&
        hour < 12) {
      hour += 12;
    }

    if (referenceStartAt != null) {
      final start = referenceStartAt.toLocal();
      return DateTime(start.year, start.month, start.day, hour, minute);
    }

    final now = DateTime.now().toLocal();
    final explicitDate = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
    ).firstMatch(normalized);

    if (explicitDate != null) {
      final day = int.tryParse(explicitDate.group(1) ?? '');
      final month = int.tryParse(explicitDate.group(2) ?? '');
      var year = int.tryParse(explicitDate.group(3) ?? '${now.year}') ?? now.year;

      if (year < 100) {
        year += 2000;
      }

      if (day == null || month == null) {
        return null;
      }

      return DateTime(year, month, day, hour, minute);
    }

    if (RegExp(r'\b(ngay mai|mai)\b').hasMatch(normalized)) {
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _extractFallbackTitle(String message) {
    var title = message.trim();

    title = title.replaceFirst(
      RegExp(
        r'^\s*(tạo|tao|thêm|them)\s+(nhiệm\s*vụ|nhiem\s*vu|task|công\s*việc|cong\s*viec)\s*',
        caseSensitive: false,
      ),
      '',
    );

    title = title.replaceFirst(
      RegExp(
        r'^\s*(nhắc|nhac)\s+(tôi|toi|mình|minh|em|tui|tao)\s*',
        caseSensitive: false,
      ),
      '',
    );

    title = title.replaceFirst(
      RegExp(
        r'^\s*(đến\s*hẹn|den\s*hen|tới\s*hẹn|toi\s*hen|sắp\s*đến\s*hẹn|sap\s*den\s*hen|hẹn|hen)\s*',
        caseSensitive: false,
      ),
      '',
    );

    final firstHardSeparator = RegExp(r'[,;.]').firstMatch(title);
    if (firstHardSeparator != null) {
      title = title.substring(0, firstHardSeparator.start);
    }

    final firstSoftSeparator = RegExp(
      r'\s+(lúc|luc|vào|vao|ngày|ngay|hôm\s*nay|hom\s*nay|ngày\s*mai|ngay\s*mai|mai|ưu\s*tiên|uu\s*tien|nhắc|nhac|ở|o)\b',
      caseSensitive: false,
    ).firstMatch(title);

    if (firstSoftSeparator != null) {
      title = title.substring(0, firstSoftSeparator.start);
    }

    return title
        .replaceAll(RegExp(r'''^["“”'\s]+|["“”'\s]+$'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  _FallbackPriorityResult _extractFallbackPriority(String normalized) {
    final priorityMatch = RegExp(
      r'\b(uu\s*tien|priority)\s+([a-z0-9]+(?:\s+[a-z0-9]+)?)',
    ).firstMatch(normalized);

    if (priorityMatch == null) {
      return const _FallbackPriorityResult(AiTaskDraft.defaultPriority);
    }

    final raw = priorityMatch.group(2)?.trim() ?? '';

    if (raw.startsWith('cao') || raw.startsWith('high')) {
      return const _FallbackPriorityResult(AiTaskDraft.priorityHigh);
    }

    if (raw.startsWith('thap') || raw.startsWith('low')) {
      return const _FallbackPriorityResult(AiTaskDraft.priorityLow);
    }

    if (raw.startsWith('trung binh') ||
        raw.startsWith('medium') ||
        raw.startsWith('vua')) {
      return const _FallbackPriorityResult(AiTaskDraft.priorityMedium);
    }

    return const _FallbackPriorityResult(
      AiTaskDraft.defaultPriority,
      isInvalidExplicitPriority: true,
    );
  }

  DateTime? _extractFallbackStartAt(String normalized) {
    final timeMatch = RegExp(
      r'\b(\d{1,2})\s*(?:h|gio|:)\s*(\d{1,2})?\b',
    ).firstMatch(normalized);

    if (timeMatch == null) {
      return null;
    }

    var hour = int.tryParse(timeMatch.group(1) ?? '');
    final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    final isEvening = RegExp(r'\b(toi|dem)\b').hasMatch(normalized);
    final isAfternoon = RegExp(r'\b(chieu)\b').hasMatch(normalized);

    if ((isEvening || isAfternoon) && hour > 0 && hour < 12) {
      hour += 12;
    }

    final now = DateTime.now().toLocal();
    DateTime date;

    final explicitDate = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
    ).firstMatch(normalized);

    if (explicitDate != null) {
      final day = int.tryParse(explicitDate.group(1) ?? '');
      final month = int.tryParse(explicitDate.group(2) ?? '');
      var year = int.tryParse(explicitDate.group(3) ?? '${now.year}') ?? now.year;

      if (year < 100) {
        year += 2000;
      }

      if (day == null || month == null) {
        return null;
      }

      date = DateTime(year, month, day, hour, minute);
    } else if (RegExp(r'\b(ngay mai|mai)\b').hasMatch(normalized)) {
      final tomorrow = now.add(const Duration(days: 1));
      date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    } else {
      date = DateTime(now.year, now.month, now.day, hour, minute);

      // If the user gave only a clock time and that time has already passed
      // today, choose tomorrow instead of creating an already-expired draft.
      if (!date.isAfter(now) &&
          !RegExp(r'\b(hom nay|toi nay|sang nay|chieu nay)\b').hasMatch(normalized)) {
        final tomorrow = now.add(const Duration(days: 1));
        date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
      }
    }

    return date;
  }

  int? _extractFallbackReminderMinutes(String normalized) {
    final match = RegExp(
      r'\b(nhac|bao)\s+truoc\s+(\d{1,4})\s*(phut|p|gio|tieng|h)\b',
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final amount = int.tryParse(match.group(2) ?? '');
    final unit = match.group(3) ?? 'phut';

    if (amount == null || amount <= 0) {
      return null;
    }

    if (unit == 'gio' || unit == 'tieng' || unit == 'h') {
      return amount * 60;
    }

    return amount;
  }

  String _normalizeVietnamese(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9/:\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _FallbackPriorityResult {
  final String priority;
  final bool isInvalidExplicitPriority;

  const _FallbackPriorityResult(
      this.priority, {
        this.isInvalidExplicitPriority = false,
      });
}
