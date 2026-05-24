import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:todo_app/models/ai_day_plan_result.dart';
import 'package:todo_app/models/ai_task_draft.dart';
import 'package:todo_app/models/chat_message.dart';
import 'package:todo_app/services/ai_task_service.dart';
import 'package:todo_app/services/chatbot_service.dart';
import 'package:todo_app/services/ai_day_plan_service.dart';
import 'package:todo_app/services/chat_history_service.dart';
import 'package:todo_app/features/chatbot/widgets/ai_day_plan_card.dart';
import 'package:todo_app/shared/widgets/custom_bottom_nav.dart';
import 'package:todo_app/features/chatbot/local_ytask_reply.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const Color _ytaskGreen = Color(0xFF64DA56);
  static const Color _lightBackground = Color(0xFFF6FAF5);
  static const Color _darkBackground = Color(0xFF101510);
  static const Color _darkCard = Color(0xFF1A211A);

  static const int _cooldownDuration = 3;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiTaskService _aiTaskService = AiTaskService();
  final AiDayPlanService _aiDayPlanService = AiDayPlanService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  final ChatbotService _chatbotService = ChatbotService();
  final Random _localReplyRandom = Random();

  List<ChatMessage> _messages = <ChatMessage>[];
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  String? _currentUid;

  final List<String> _quickPrompts = const <String>[
    'YTask dùng để làm gì?',
    'Tạo task bằng AI như nào?',
    'Làm sao để xem nhiệm vụ quá hạn?',
    'Gợi ý tôi cách sắp xếp công việc hôm nay',
  ];

  bool _isLoading = false;
  bool _isCoolingDown = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  bool get _canSend {
    return _messageController.text.trim().isNotEmpty &&
        !_isLoading &&
        !_isCoolingDown;
  }

  bool get _canUseQuickPrompt {
    return !_isLoading && !_isCoolingDown;
  }

  @override
  void initState() {
    super.initState();
    _initChatHistory();
  }

  Future<void> _initChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = <ChatMessage>[
          ChatMessage.ai(
            'Bạn cần đăng nhập để sử dụng trợ lý AI của YTask.',
          ),
        ];
      });
      return;
    }

    _currentUid = user.uid;

    try {
      await _chatHistoryService.addWelcomeMessageIfEmpty(user.uid);
    } catch (e) {
      debugPrint('YTask chat welcome message error: $e');
    }

    await _messagesSubscription?.cancel();
    _messagesSubscription = _chatHistoryService.watchMessages(user.uid).listen(
          (messages) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = <ChatMessage>[
            ChatMessage.ai(
              'Mình chưa thể tải lịch sử chat. Lý do: $error',
            ),
          ];
        });
      },
    );
  }

  Future<void> _saveChatMessage(ChatMessage message) async {
    final uid = _currentUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      _appendLocalMessage(message);
      return;
    }

    _currentUid = uid;

    try {
      await _chatHistoryService.addMessage(uid, message);
    } catch (e) {
      debugPrint('YTask save chat message error: $e');
      _appendLocalMessage(message);
    }
  }

  void _appendLocalMessage(ChatMessage message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages = <ChatMessage>[..._messages, message];
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage([String? quickMessage]) async {
    final text = (quickMessage ?? _messageController.text).trim();

    if (text.isEmpty || _isLoading || _isCoolingDown) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _messageController.clear();
      _isLoading = true;
    });

    await _saveChatMessage(ChatMessage.user(text));
    _scrollToBottom();

    AiTaskDraft? taskDraft;
    AiDayPlanResult? dayPlanResult;
    String aiReply;

    try {
      final isCreateTaskIntent = _isCreateTaskIntent(text);
      final isMultipleTaskRequest = _isMultipleTaskRequest(text);
      final isTodayPlanIntent = _isTodayPlanIntent(text);

      // Lệnh thao tác phải được ưu tiên trước local FAQ.
      // Nếu để LocalYTaskReplyService chạy trước, câu như
      // "Tạo nhiệm vụ học Flutter lúc 8h tối" rất dễ bị trả lời thành
      // hướng dẫn "vào Dashboard bấm +" thay vì mở bản nháp AI.
      if (isCreateTaskIntent && isMultipleTaskRequest) {
        await _waitLikeAiThinking(
          minMilliseconds: 1000,
          maxMilliseconds: 2500,
        );

        if (!mounted) {
          return;
        }

        aiReply =
        'Hiện tại mình chỉ hỗ trợ tạo **1 nhiệm vụ mỗi lần** để tránh lưu sai dữ liệu. '
            'Bạn hãy gửi từng nhiệm vụ riêng, ví dụ: “Tạo nhiệm vụ học Flutter lúc 8 giờ tối nay”.';
      } else if (isCreateTaskIntent) {
        await _waitLikeAiThinking(
          minMilliseconds: 1000,
          maxMilliseconds: 2500,
        );

        if (!mounted) {
          return;
        }

        taskDraft = await _chatbotService.extractTaskDraft(text);

        if (!mounted) {
          return;
        }

        if (taskDraft == null) {
          aiReply =
          'Mình chưa chắc đây là yêu cầu tạo nhiệm vụ. Bạn hãy nói rõ hơn, ví dụ: '
              '“Tạo nhiệm vụ học Flutter lúc 8 giờ tối nay”.';
        } else {
          aiReply = _buildTaskDraftPreviewMessage(taskDraft);
        }
      } else if (isTodayPlanIntent) {
        await _waitLikeAiThinking(
          minMilliseconds: 1800,
          maxMilliseconds: 4000,
        );

        if (!mounted) {
          return;
        }

        dayPlanResult = await _generateTodayPlan(text);
        aiReply = dayPlanResult.toChatText();

        if (!mounted) {
          return;
        }
      } else {
        final localReply = LocalYTaskReplyService.getReply(text);

        if (localReply != null) {
          await _waitLikeAiThinking(
            minMilliseconds: 1000,
            maxMilliseconds: 3000,
          );

          if (!mounted) {
            return;
          }

          aiReply = localReply;
        } else {
          await _waitLikeAiThinking(
            minMilliseconds: 1000,
            maxMilliseconds: 3000,
          );

          if (!mounted) {
            return;
          }

          aiReply = _buildLocalFallbackReply(text);
        }
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      aiReply = ChatbotService.friendlyErrorMessage(e);
      taskDraft = null;
      dayPlanResult = null;
    }

    await _saveChatMessage(
      dayPlanResult == null
          ? ChatMessage.ai(aiReply)
          : ChatMessage.aiDayPlan(dayPlanResult),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    _startCooldown();
    _scrollToBottom();

    if (taskDraft != null) {
      _showTaskDraftPreview(taskDraft);
    }
  }

  Future<void> _waitLikeAiThinking({
    int minMilliseconds = 1000,
    int maxMilliseconds = 4000,
  }) async {
    final safeMaxMilliseconds =
    maxMilliseconds < minMilliseconds ? minMilliseconds : maxMilliseconds;
    final delayMilliseconds = minMilliseconds +
        _localReplyRandom.nextInt(safeMaxMilliseconds - minMilliseconds + 1);

    await Future<void>.delayed(Duration(milliseconds: delayMilliseconds));
  }

  String _buildLocalFallbackReply(String text) {
    final normalized = _normalizeVietnamese(text);

    if (normalized.contains('ytask')) {
      return 'YTask là ứng dụng quản lý công việc cá nhân. App giúp bạn tạo nhiệm vụ, đặt thời gian, theo dõi tiến độ, xử lý việc quá hạn và sắp xếp công việc theo ưu tiên.';
    }

    if (normalized.contains('tro ly') ||
        normalized.contains('ai') ||
        normalized.contains('chatbot')) {
      return 'Mình là trợ lý AI trong YTask. Mình có thể hướng dẫn cách dùng app, gợi ý sắp xếp công việc và tạo bản nháp nhiệm vụ từ câu chat tự nhiên để bạn xác nhận trước khi lưu.';
    }

    return 'Mình chưa hiểu rõ câu hỏi này. Bạn có thể hỏi ngắn gọn hơn, ví dụ: “YTask dùng để làm gì?”, “Hôm nay tôi nên làm gì trước?” hoặc “Task nào gần deadline nhất?”.';
  }

  bool _isCreateTaskIntent(String text) {
    final normalized = _normalizeVietnamese(text).toLowerCase();

    // Các câu hỏi kiểu “cách tạo task”, “tạo được không”,
    // “hướng dẫn tạo nhiệm vụ” chỉ là hỏi đáp, không phải lệnh tạo task.
    if (_isTaskCreationHelpQuestion(normalized)) {
      return false;
    }

    final createPatterns = <RegExp>[
      RegExp(r'\btao\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bthem\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bcan tao\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\btao cho\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bthem cho\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bnhac\b.*\b(toi|minh|em|tui|tao)\b'),
      RegExp(r'\b(len lich|dat lich|ghi nho giup toi|ghi nho giup minh|ghi nho cho toi)\b'),

      // Câu đặt lịch/nhắc hẹn tự nhiên. Ví dụ:
      // "Đến hẹn xem phim ngày mai", "Hẹn đi họp lúc 8h".
      // Cho đi qua luồng AI draft để app hỏi/bổ sung thời gian,
      // không rơi vào fallback giới thiệu trợ lý.
      RegExp(
        r'\b(den hen|toi hen|sap den hen|hen)\b.*\b(hom nay|ngay mai|mai|toi nay|sang mai|chieu mai|toi mai|\d{1,2}\s*(h|gio|:))\b',
      ),
    ];

    return createPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  bool _isTodayPlanIntent(String text) {
    final normalized = _normalizeVietnamese(text);

    // Do not treat app-help questions as task consultation.
    if (_isTaskCreationHelpQuestion(normalized)) {
      return false;
    }

    final todayPlanPatterns = <RegExp>[
      // Câu ngắn người dùng hay gõ: có dấu/không dấu/viết tắt đều đã normalize.
      RegExp(r'\b(hom nay|ngay hom nay)\b.*\b(cong viec|nhiem vu|task|viec|ke hoach|lich|lam gi|nen|uu tien|deadline|qua han)\b'),
      RegExp(r'\b(cong viec|nhiem vu|task|viec|ke hoach|lich)\b.*\b(hom nay|ngay hom nay)\b'),
      RegExp(r'\b(hom nay co gi|hom nay lam gi|hom nay nen lam gi)\b'),
      RegExp(r'\b(xem|kiem tra|check)\b.*\b(hom nay|lich|ke hoach|cong viec|nhiem vu|task)\b'),

      // Nhóm 1: kế hoạch hôm nay / nên làm gì trước.
      RegExp(r'\b(ke hoach|lich lam viec|lich trinh)\b.*\b(hom nay|on chua|hop ly|qua tai)\b'),
      RegExp(r'\bnen\b.*\b(lam gi|viec nao|task nao|nhiem vu nao|cong viec nao)\b.*\b(truoc|dau tien)\b'),
      RegExp(r'\bnen lam gi truoc\b'),
      RegExp(r'\bbat dau\b.*\b(task nao|viec nao|nhiem vu nao|cong viec nao)\b'),

      // Nhóm 2-3: ưu tiên, deadline, gấp, quá hạn.
      RegExp(r'\b(task nao|nhiem vu nao|viec nao|cong viec nao)\b.*\b(uu tien|quan trong|gap|deadline|han|tre|qua han|lam truoc|xu ly)\b'),
      RegExp(r'\b(uu tien|priority|high|deadline|gan han|den han|het han|qua han|tre han|can xu ly gap|gap nhat)\b'),
      RegExp(r'\btruoc 12\b|\b12 gio\b|\btruoc buoi toi\b|\btoi nay\b'),

      // Nhóm 4-7: chia thời gian, quá tải, ít thời gian, Eisenhower.
      RegExp(r'\b(chia lich|chia thoi gian|khung gio|time blocking|buoi sang|buoi chieu|buoi toi)\b'),
      RegExp(r'\b(15 phut|30 phut|1 tieng|2 tieng|it thoi gian|ban ca ngay|chi con|chi ranh)\b'),
      RegExp(r'\b(qua nhieu viec|nang qua|qua tai|om qua nhieu|thuc te khong|bo bot|doi task|de sang ngay mai)\b'),
      RegExp(r'\b(khan cap|quan trong nhung|gap nhung|eisenhower|viec lon|viec nho|co the de sau)\b'),

      // Nhóm 8-9: chia nhỏ / điều chỉnh kế hoạch.
      RegExp(r'\b(chia nho|checklist|bat dau tu dau|cac buoc|buoc nao|phan nao truoc)\b'),
      RegExp(r'\b(dieu chinh|toi uu|xep lai|sap xep lai|doi thu tu|them task moi|huy task nay|hoan thanh task nay)\b'),

      // Nhóm 10: trạng thái task.
      RegExp(r'\b(pending|inprogress|in progress|dang cho|dang lam do|chua bat dau|da hoan thanh|bi huy|da huy|trang thai)\b'),
      RegExp(r'\b(con bao nhieu|bao nhieu)\b.*\b(task|nhiem vu|viec|cong viec)\b'),

      // Nhóm 11: category/danh mục.
      RegExp(r'\b(category|danh muc|nhan|hoc tap|viec hoc|cong viec|ca nhan)\b.*\b(hom nay|quan trong|uu tien|deadline|gan han|gom|truoc|co gi)\b'),

      // Nhóm 12: câu tự nhiên/đời thường.
      RegExp(r'\b(nguoi anh em|cuu toi|do ap luc|dang luoi|tap trung vao dau|xem lich hom nay|hoi roi|dang roi)\b'),
      RegExp(r'\bgio\b.*\b(toi|minh|em|tui)\b.*\bnen lam gi\b'),
    ];

    return todayPlanPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  Future<AiDayPlanResult> _generateTodayPlan(String userMessage) async {
    return _aiDayPlanService.generateTodayPlan(userMessage: userMessage);
  }

  bool _isTaskCreationHelpQuestion(String normalized) {
    final helpPatterns = <RegExp>[
      RegExp(r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b\s*(bang|voi)\s*\b(ai|ytask ai|tro ly|chatbot|ngon ngu tu nhien|cau chat)\b'),
      RegExp(r'\b(ai|ytask ai|tro ly|chatbot)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|duoc khong|co duoc khong|bang cach nao)\b'),
      RegExp(r'\bhuong dan\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bcach\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\blam sao\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\blam the nao\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bchi\b.*\btoi\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\btao duoc\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bco tao duoc\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bco the tao\b.*\b(nhiem vu|task|cong viec)\b.*\bkhong\b'),
      RegExp(r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\bduoc khong\b'),
      RegExp(r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\bkhong\b$'),
    ];

    return helpPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  bool _isMultipleTaskRequest(String text) {
    final normalized = _normalizeVietnamese(text).toLowerCase();

    final patterns = <RegExp>[
      RegExp(r'\b(2|3|4|5|hai|ba|bon|nam)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bnhiem vu\s*1\b.*\bnhiem vu\s*2\b'),
      RegExp(r'\btask\s*1\b.*\btask\s*2\b'),
    ];

    return patterns.any((pattern) => pattern.hasMatch(normalized));
  }

  String _normalizeVietnamese(String input) {
    var text = input.toLowerCase();

    text = text
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    text = ' $text ';

    final replacements = <RegExp, String>{
      RegExp(r'\b(hnay|hum nay|homnay|hn)\b'): ' hom nay ',
      RegExp(r'\b(cv)\b'): ' cong viec ',
      RegExp(r'\b(nv|nvu)\b'): ' nhiem vu ',
      RegExp(r'\b(tk|tsk)\b'): ' task ',
      RegExp(r'\b(dl|ddl|deadlinee|dealline|dead line)\b'): ' deadline ',
      RegExp(r'\b(pri|prio)\b'): ' priority ',
      RegExp(r'\b(han chot|thoi han|het han)\b'): ' deadline ',
      RegExp(r'\b(done|xong roi|da xong)\b'): ' hoan thanh ',
      RegExp(r'\b(cancel|canceled|cancelled)\b'): ' huy ',
      RegExp(r'\b(oke|okay|okela|okie|oki|ok)\b'): ' oke ',
      RegExp(r'\b(app nay|ung dung nay)\b'): ' ytask ',
      RegExp(r'\b(assistant|bot|tro ly)\b'): ' tro ly ',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    text = text.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
          (match) => '${match.group(1)}${match.group(1)}',
    );

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildTaskDraftPreviewMessage(AiTaskDraft draft) {
    final validationErrors = draft.validateForPreview();
    final hasErrors = validationErrors.isNotEmpty;

    final buffer = StringBuffer()
      ..writeln(
        hasErrors
            ? '**AI đã hiểu một phần nhiệm vụ, nhưng còn thiếu thông tin:**'
            : '**AI đã tạo bản nháp nhiệm vụ:**',
      )
      ..writeln('- Tên: ${draft.title.trim()}')
      ..writeln('- Danh mục: ${draft.effectiveCategoryName}')
      ..writeln('- Ưu tiên: ${_formatPriority(draft.priority)}')
      ..writeln('- Bắt đầu: ${_formatDateTime(draft.startAt)}')
      ..writeln('- Kết thúc: ${_formatDateTime(draft.endAt)}')
      ..writeln('- Nhắc trước: ${_formatReminder(draft.reminderMinutes)}');

    final location = draft.location?.trim();
    if (location != null && location.isNotEmpty) {
      buffer.writeln('- Vị trí: $location');
    }

    if (hasErrors) {
      buffer
        ..writeln()
        ..writeln(
          'Cần bổ sung: ${validationErrors.map(_formatMissingField).join(', ')}.',
        )
        ..writeln('Mình chưa lưu nhiệm vụ này vào dữ liệu của bạn.');
    } else {
      buffer
        ..writeln()
        ..writeln(
          'Bản nháp này **chưa được lưu**. App đã mở màn xác nhận để bạn kiểm tra trước khi lưu.',
        );
    }

    return buffer.toString().trim();
  }

  void _showTaskDraftPreview(AiTaskDraft draft) {
    if (!mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final canCreate = _canCreateDraftFromPreview(draft);
        final description = draft.description.trim();
        final missingStartAt = draft.startAt == null ||
            draft.missingFields.map((field) => field.trim()).contains('startAt');
        final location = draft.location?.trim();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.36 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _ytaskGreen.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: _ytaskGreen,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI đã tạo bản nháp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kiểm tra trước khi lưu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF7B807B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Tên',
                      value: draft.title.trim().isEmpty
                          ? 'Chưa có'
                          : draft.title.trim(),
                    ),
                    if (description.isNotEmpty)
                      _buildDraftPreviewRow(
                        sheetContext,
                        label: 'Mô tả',
                        value: description,
                      ),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Danh mục',
                      value: draft.effectiveCategoryName,
                    ),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Ưu tiên',
                      value: _formatPriority(draft.priority),
                    ),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Bắt đầu',
                      value: _formatDateTime(draft.startAt),
                    ),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Kết thúc',
                      value: _formatDateTime(draft.endAt),
                    ),
                    _buildDraftPreviewRow(
                      sheetContext,
                      label: 'Nhắc trước',
                      value: _formatReminder(draft.reminderMinutes),
                    ),
                    if (location != null && location.isNotEmpty)
                      _buildDraftPreviewRow(
                        sheetContext,
                        label: 'Vị trí',
                        value: location,
                      ),
                    if (draft.confidence > 0) ...[
                      const SizedBox(height: 4),
                      _buildDraftPreviewRow(
                        sheetContext,
                        label: 'Độ tin cậy',
                        value: '${(draft.confidence * 100).round()}%',
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (missingStartAt)
                      _buildDraftWarning(
                        sheetContext,
                        draft.needsStartTimeForReminder
                            ? 'AI chưa xác định được thời gian bắt đầu. Vì nhiệm vụ có nhắc trước, bạn cần bổ sung thời gian trước khi tạo nhiệm vụ.'
                            : 'AI chưa xác định được thời gian bắt đầu. Bạn có thể bổ sung thời gian ở bước sau nếu app cho phép task không có giờ.',
                      ),
                    if (_hasEndBeforeStart(draft))
                      _buildDraftWarning(
                        sheetContext,
                        'Thời gian kết thúc đang sớm hơn thời gian bắt đầu. Bạn cần sửa lại trước khi tạo nhiệm vụ.',
                      ),
                    if (_hasStartAtInPast(draft))
                      _buildDraftWarning(
                        sheetContext,
                        'Thời gian bắt đầu đã qua. Bạn hãy chọn thời gian bắt đầu muộn hơn trước khi tạo nhiệm vụ.',
                      ),
                    if (_hasReminderAtInPast(draft))
                      _buildDraftWarning(
                        sheetContext,
                        'Thời điểm nhắc nhở đã qua. Bạn hãy chọn thời gian bắt đầu muộn hơn hoặc bỏ nhắc nhở.',
                      ),
                    if (!draft.hasTitle)
                      _buildDraftWarning(
                        sheetContext,
                        'AI chưa xác định được tên nhiệm vụ. Bạn hãy nhập rõ tên nhiệm vụ trước khi tạo.',
                      ),
                    if (draft.missingFields.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Thông tin AI còn thiếu: ${draft.missingFields.map(_formatMissingField).join(', ')}.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF7B807B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (canCreate)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDraftCancelButton(
                              sheetContext,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDraftCreateButton(
                              sheetContext,
                              draft: draft,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildDraftCancelButton(
                              sheetContext,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDraftEditButton(
                              sheetContext,
                              draft: draft,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildDraftCancelButton(
      BuildContext sheetContext, {
        required bool isDark,
      }) {
    return OutlinedButton(
      onPressed: () => Navigator.of(sheetContext).pop(),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(
          color: isDark ? Colors.white24 : Colors.black.withOpacity(0.12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        'Hủy',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white70 : const Color(0xFF4D534D),
        ),
      ),
    );
  }

  Widget _buildDraftCreateButton(
      BuildContext sheetContext, {
        required AiTaskDraft draft,
      }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(sheetContext).pop();
        _createTaskFromDraft(draft);
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _ytaskGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Text(
        'Tạo nhiệm vụ',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildDraftEditButton(
      BuildContext sheetContext, {
        required AiTaskDraft draft,
      }) {
    return ElevatedButton.icon(
      onPressed: () => _openDraftEditSheet(sheetContext, draft),
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: const Text(
        'Chỉnh sửa',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _ytaskGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _openDraftEditSheet(
      BuildContext sheetContext,
      AiTaskDraft draft,
      ) async {
    Navigator.of(sheetContext).pop();

    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (!mounted) {
      return;
    }

    final editedDraft = await showModalBottomSheet<AiTaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (editContext) {
        return _AiTaskDraftEditSheet(
          initialDraft: draft,
          ytaskGreen: _ytaskGreen,
          darkCard: _darkCard,
        );
      },
    );

    if (!mounted || editedDraft == null) {
      return;
    }

    await _saveChatMessage(
      ChatMessage.ai(
        _buildTaskDraftPreviewMessage(editedDraft),
      ),
    );

    _scrollToBottom();
    _showTaskDraftPreview(editedDraft);
  }

  Future<void> _createTaskFromDraft(AiTaskDraft draft) async {
    if (!mounted) {
      return;
    }

    final blockingReason = _getDraftBlockingReason(draft);
    if (blockingReason != null) {
      await _saveChatMessage(ChatMessage.ai(blockingReason));
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockingReason)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final taskId = await _aiTaskService.createTaskFromDraft(draft);

      if (!mounted) {
        return;
      }

      await _saveChatMessage(
        ChatMessage.ai(
          'Đã tạo nhiệm vụ **${draft.title.trim()}** thành công. Bạn có thể xem nhiệm vụ này ở Dashboard hoặc lịch công việc.',
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo nhiệm vụ: ${draft.title.trim()}'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );

      debugPrint('YTask AI created taskId=$taskId');
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _saveChatMessage(
        ChatMessage.ai(
          ChatbotService.friendlyErrorMessage(e),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChatbotService.friendlyErrorMessage(e))),
      );
    }
  }

  Widget _buildDraftPreviewRow(
      BuildContext context, {
        required String label,
        required String value,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlaceholder = value == 'Chưa có' || value == 'Không có';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : const Color(0xFF7B807B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: isPlaceholder ? FontWeight.w700 : FontWeight.w800,
                color: isPlaceholder
                    ? isDark
                    ? Colors.white38
                    : const Color(0xFF9AA09A)
                    : isDark
                    ? Colors.white
                    : const Color(0xFF202124),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftWarning(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE562).withOpacity(isDark ? 0.18 : 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7B900).withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB88900),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF554500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canCreateDraftFromPreview(AiTaskDraft draft) {
    return _getDraftBlockingReason(draft) == null;
  }

  String? _getDraftBlockingReason(AiTaskDraft draft) {
    final validationErrors = draft.validateForPreview();

    if (validationErrors.contains('intent')) {
      return 'AI chưa xác định đây là yêu cầu tạo nhiệm vụ. Bạn hãy nhập rõ hơn trước khi tạo.';
    }

    if (!draft.hasTitle || validationErrors.contains('title')) {
      return 'AI chưa xác định được tên nhiệm vụ. Bạn hãy nhập rõ tên nhiệm vụ trước khi tạo.';
    }

    if (validationErrors.contains('priority')) {
      return 'Độ ưu tiên AI trả về chưa hợp lệ. Chỉ chấp nhận low, medium hoặc high.';
    }

    if (draft.needsStartTimeForReminder) {
      return 'AI chưa xác định được thời gian bắt đầu. Vì nhiệm vụ có nhắc trước, bạn cần bổ sung thời gian trước khi tạo nhiệm vụ.';
    }

    if (validationErrors.contains('startAt')) {
      return 'Thời gian bắt đầu AI trả về chưa hợp lệ hoặc còn thiếu. Bạn cần bổ sung thời gian trước khi tạo nhiệm vụ.';
    }

    if (validationErrors.contains('endAt')) {
      return _hasEndBeforeStart(draft)
          ? 'Thời gian kết thúc đang sớm hơn thời gian bắt đầu. Bạn cần sửa lại trước khi tạo nhiệm vụ.'
          : 'Thời gian kết thúc AI trả về chưa hợp lệ. Bạn cần sửa lại trước khi tạo nhiệm vụ.';
    }

    final unresolvedFields = validationErrors
        .where((field) => field != 'intent')
        .where((field) => field != 'title')
        .where((field) => field != 'priority')
        .where((field) => field != 'startAt')
        .where((field) => field != 'endAt')
        .toList(growable: false);

    if (unresolvedFields.isNotEmpty) {
      return 'AI còn thiếu thông tin: ${unresolvedFields.map(_formatMissingField).join(', ')}. Bạn cần bổ sung trước khi tạo nhiệm vụ.';
    }

    if (_hasEndBeforeStart(draft)) {
      return 'Thời gian kết thúc đang sớm hơn thời gian bắt đầu. Bạn cần sửa lại trước khi tạo nhiệm vụ.';
    }

    if (_hasStartAtInPast(draft)) {
      return 'Thời gian bắt đầu đã qua. Bạn hãy chọn thời gian bắt đầu muộn hơn trước khi tạo nhiệm vụ.';
    }

    if (_hasReminderAtInPast(draft)) {
      return 'Thời điểm nhắc nhở đã qua. Bạn hãy chọn thời gian bắt đầu muộn hơn hoặc bỏ nhắc nhở.';
    }

    return null;
  }

  bool _hasStartAtInPast(AiTaskDraft draft) {
    final startAt = draft.startAt;
    if (startAt == null) {
      return false;
    }

    return !startAt.toLocal().isAfter(DateTime.now());
  }

  bool _hasReminderAtInPast(AiTaskDraft draft) {
    final reminderAt = _calculateReminderAt(draft);
    if (reminderAt == null) {
      return false;
    }

    return !reminderAt.toLocal().isAfter(DateTime.now());
  }

  DateTime? _calculateReminderAt(AiTaskDraft draft) {
    final startAt = draft.startAt;
    final reminderMinutes = draft.reminderMinutes;

    if (startAt == null || reminderMinutes == null || reminderMinutes <= 0) {
      return null;
    }

    return startAt.subtract(Duration(minutes: reminderMinutes));
  }

  bool _hasEndBeforeStart(AiTaskDraft draft) {
    final startAt = draft.startAt;
    final endAt = draft.endAt;

    return startAt != null && endAt != null && endAt.isBefore(startAt);
  }

  String _formatPriority(String priority) {
    switch (priority) {
      case AiTaskDraft.priorityHigh:
        return 'Cao';
      case AiTaskDraft.priorityLow:
        return 'Thấp';
      case AiTaskDraft.priorityMedium:
      default:
        return 'Trung bình';
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có';
    }

    final local = value.toLocal();
    final day = _twoDigits(local.day);
    final month = _twoDigits(local.month);
    final year = local.year.toString();
    final hour = _twoDigits(local.hour);
    final minute = _twoDigits(local.minute);

    return '$hour:$minute, $day/$month/$year';
  }

  String _formatReminder(int? reminderMinutes) {
    if (reminderMinutes == null || reminderMinutes <= 0) {
      return 'Không có';
    }

    return '$reminderMinutes phút';
  }

  String _formatMissingField(String field) {
    switch (field) {
      case 'title':
        return 'tên nhiệm vụ';
      case 'priority':
        return 'độ ưu tiên';
      case 'startAt':
        return 'thời gian bắt đầu';
      case 'endAt':
        return 'thời gian kết thúc';
      case 'intent':
        return 'ý định tạo nhiệm vụ';
      default:
        return field;
    }
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  Future<void> _confirmClearChatHistory() async {
    final uid = _currentUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để xóa lịch sử chat.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa lịch sử chat?'),
          content: const Text(
            'Bạn có chắc muốn xóa lịch sử chat không? Hành động này chỉ xóa lịch sử chatbot của tài khoản hiện tại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      await _chatHistoryService.clearMessages(uid);
      await _chatHistoryService.addWelcomeMessageIfEmpty(uid);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa lịch sử chat.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa lịch sử chat: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();

    setState(() {
      _isCoolingDown = true;
      _cooldownSeconds = _cooldownDuration;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isCoolingDown = false;
          _cooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        _cooldownSeconds--;
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _darkBackground : _lightBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        foregroundColor: isDark ? Colors.white : const Color(0xFF202124),
        title: const Text(
          'YTask AI Assistant',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Xóa lịch sử chat',
            onPressed: _isLoading ? null : _confirmClearChatHistory,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  itemCount: _messages.length + (_isLoading ? 2 : 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildIntroCard(context);
                    }

                    final messageIndex = index - 1;

                    if (_isLoading && messageIndex == _messages.length) {
                      return _buildLoadingBubble(context);
                    }

                    final message = _messages[messageIndex];
                    return _buildMessageBubble(context, message);
                  },
                ),
              ),
              _buildBottomComposer(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _ytaskGreen.withOpacity(isDark ? 0.24 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.24 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _ytaskGreen.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _ytaskGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý công việc của bạn',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Hỏi tôi cách sắp xếp công việc, xem tiến độ hoặc dùng YTask hiệu quả hơn.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.32,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF7B807B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkBackground : _lightBackground,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickPromptBar(context),
          _buildCooldownNotice(context),
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildQuickPromptBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _canUseQuickPrompt ? () => _handleSendMessage(prompt) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: _canUseQuickPrompt
                    ? _ytaskGreen.withOpacity(isDark ? 0.16 : 0.13)
                    : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _canUseQuickPrompt
                      ? _ytaskGreen.withOpacity(0.34)
                      : Colors.grey.withOpacity(0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: _canUseQuickPrompt ? _ytaskGreen : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _canUseQuickPrompt
                          ? isDark
                          ? Colors.white
                          : const Color(0xFF1F3D22)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCooldownNotice(BuildContext context) {
    if (!_isCoolingDown) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 15,
            color: isDark ? Colors.white54 : const Color(0xFF7B807B),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Bạn đợi vài giây rồi gửi tiếp nhé. Còn $_cooldownSeconds giây.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF7B807B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              enabled: !_isLoading,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSend) {
                  _handleSendMessage();
                }
              },
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF202124),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _isCoolingDown
                    ? 'Đợi $_cooldownSeconds giây...'
                    : 'Hỏi trợ lý AI...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF9AA09A),
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: isDark ? _darkCard : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.045),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(
                    color: _ytaskGreen.withOpacity(0.75),
                    width: 1.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _canSend ? _ytaskGreen : const Color(0xFFC9CEC9),
              shape: BoxShape.circle,
              boxShadow: _canSend
                  ? [
                BoxShadow(
                  color: _ytaskGreen.withOpacity(0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
                  : [],
            ),
            child: IconButton(
              onPressed: _canSend ? () => _handleSendMessage() : null,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    if (!isUser && message.dayPlan != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.92,
          ),
          child: AiDayPlanCard(plan: message.dayPlan!),
        ),
      );
    }

    final Color bubbleColor = isUser
        ? _ytaskGreen
        : isDark
        ? _darkCard
        : Colors.white;

    final Color textColor = isUser
        ? Colors.white
        : isDark
        ? Colors.white
        : const Color(0xFF252A25);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 7),
            bottomRight: Radius.circular(isUser ? 7 : 22),
          ),
          border: isUser
              ? null
              : Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.055),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isUser
            ? Text(
          message.text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.38,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        )
            : MarkdownBody(
          data: message.text,
          selectable: false,
          softLineBreak: true,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14.5,
              height: 1.38,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            strong: TextStyle(
              fontSize: 14.5,
              height: 1.38,
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            listBullet: TextStyle(
              fontSize: 14.5,
              height: 1.38,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(7),
            bottomRight: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.055),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _ytaskGreen.withOpacity(0.95),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI đang suy nghĩ...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF6E756E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _AiTaskDraftEditSheet extends StatefulWidget {
  const _AiTaskDraftEditSheet({
    required this.initialDraft,
    required this.ytaskGreen,
    required this.darkCard,
  });

  final AiTaskDraft initialDraft;
  final Color ytaskGreen;
  final Color darkCard;

  @override
  State<_AiTaskDraftEditSheet> createState() => _AiTaskDraftEditSheetState();
}

class _AiTaskDraftEditSheetState extends State<_AiTaskDraftEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _locationController;
  late final TextEditingController _reminderController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _priority;
  DateTime? _startAt;
  DateTime? _endAt;
  String? _editError;

  @override
  void initState() {
    super.initState();

    final draft = widget.initialDraft;
    _titleController = TextEditingController(text: draft.title.trim());
    _descriptionController = TextEditingController(text: draft.description.trim());
    _categoryController = TextEditingController(text: draft.effectiveCategoryName);
    _locationController = TextEditingController(text: draft.location?.trim() ?? '');
    _reminderController = TextEditingController(
      text: draft.reminderMinutes == null ? '' : draft.reminderMinutes.toString(),
    );
    _priority = AiTaskDraft.allowedPriorities.contains(draft.priority)
        ? draft.priority
        : AiTaskDraft.defaultPriority;
    _startAt = draft.startAt;
    _endAt = draft.endAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? widget.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.36 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.ytaskGreen.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: widget.ytaskGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chỉnh sửa bản nháp AI',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Các thay đổi ở đây vẫn chỉ là bản nháp, chưa lưu vào dữ liệu của bạn.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF7B807B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Tên nhiệm vụ *',
                    hint: 'Ví dụ: Học Flutter',
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bạn cần nhập tên nhiệm vụ.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Mô tả',
                    hint: 'Không bắt buộc',
                    isDark: isDark,
                    minLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Ưu tiên',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white70 : const Color(0xFF4D534D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPriorityChip(
                        label: 'Thấp',
                        value: AiTaskDraft.priorityLow,
                        isDark: isDark,
                      ),
                      _buildPriorityChip(
                        label: 'Trung bình',
                        value: AiTaskDraft.priorityMedium,
                        isDark: isDark,
                      ),
                      _buildPriorityChip(
                        label: 'Cao',
                        value: AiTaskDraft.priorityHigh,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          label: 'Bắt đầu',
                          value: _startAt,
                          isDark: isDark,
                          onTap: () => _pickDateTime(isStart: true),
                          onClear: _startAt == null
                              ? null
                              : () => setState(() {
                            _startAt = null;
                            _editError = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDateButton(
                          label: 'Kết thúc',
                          value: _endAt,
                          isDark: isDark,
                          onTap: () => _pickDateTime(isStart: false),
                          onClear: _endAt == null
                              ? null
                              : () => setState(() {
                            _endAt = null;
                            _editError = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _reminderController,
                    label: 'Nhắc trước phút',
                    hint: 'Ví dụ: 15',
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return null;
                      }

                      final parsed = int.tryParse(text);
                      if (parsed == null || parsed <= 0) {
                        return 'Số phút nhắc trước phải lớn hơn 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _categoryController,
                    label: 'Danh mục',
                    hint: AiTaskDraft.defaultCategoryName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _locationController,
                    label: 'Vị trí',
                    hint: 'Không bắt buộc',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  if (_editError != null) ...[
                    _buildEditError(isDark: isDark, message: _editError!),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black.withOpacity(0.12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Hủy',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : const Color(0xFF4D534D),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitEditedDraft,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: widget.ytaskGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Xem lại',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    int minLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: minLines > 1 ? 4 : 1,
      cursorColor: widget.ytaskGreen,
      validator: validator,
      onChanged: (_) {
        if (_editError != null) {
          setState(() => _editError = null);
        }
      },
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF202124),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF7B807B),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : const Color(0xFFB0B7B0),
          fontWeight: FontWeight.w600,
        ),
        errorStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F8F4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE5ECE4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: widget.ytaskGreen, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildEditError({
    required bool isDark,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE562).withOpacity(isDark ? 0.16 : 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7B900).withOpacity(0.36),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB88900),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : const Color(0xFF554500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final selected = _priority == value;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() {
        _priority = value;
        _editError = null;
      }),
      selectedColor: widget.ytaskGreen,
      backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F8F4),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : isDark
            ? Colors.white70
            : const Color(0xFF4D534D),
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected
            ? widget.ytaskGreen
            : isDark
            ? Colors.white12
            : const Color(0xFFE5ECE4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? value,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F8F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE5ECE4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : const Color(0xFF7B807B),
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : const Color(0xFF7B807B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatDateTime(value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.2,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: value == null
                    ? isDark
                    ? Colors.white38
                    : const Color(0xFFB0B7B0)
                    : isDark
                    ? Colors.white
                    : const Color(0xFF202124),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart
        ? (_startAt ?? now)
        : (_endAt ?? _startAt?.add(const Duration(hours: 1)) ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _editError = null;
      if (isStart) {
        _startAt = selected;
        if (_endAt != null && _endAt!.isBefore(selected)) {
          _endAt = selected.add(const Duration(hours: 1));
        }
      } else {
        _endAt = selected;
      }
    });
  }

  void _submitEditedDraft() {
    FocusScope.of(context).unfocus();

    setState(() => _editError = null);

    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) {
      return;
    }

    final reminderText = _reminderController.text.trim();
    final reminderMinutes = reminderText.isEmpty ? null : int.parse(reminderText);

    if (reminderMinutes != null && _startAt == null) {
      setState(() {
        _editError = 'Nhiệm vụ có nhắc trước nên bạn cần chọn thời gian bắt đầu.';
      });
      return;
    }

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      setState(() {
        _editError = 'Thời gian kết thúc không được sớm hơn thời gian bắt đầu.';
      });
      return;
    }

    final normalizedPriority = AiTaskDraft.allowedPriorities.contains(_priority)
        ? _priority
        : AiTaskDraft.defaultPriority;

    final categoryName = _categoryController.text.trim().isEmpty
        ? AiTaskDraft.defaultCategoryName
        : _categoryController.text.trim();
    final location = _locationController.text.trim().isEmpty
        ? null
        : _locationController.text.trim();

    final editedDraft = AiTaskDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: normalizedPriority,
      startAt: _startAt,
      endAt: _endAt,
      reminderMinutes: reminderMinutes,
      categoryName: categoryName,
      location: location,
      missingFields: const <String>[],
      confidence: widget.initialDraft.confidence,
    );

    Navigator.of(context).pop(editedDraft);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có';
    }

    final local = value.toLocal();
    final day = _twoDigits(local.day);
    final month = _twoDigits(local.month);
    final hour = _twoDigits(local.hour);
    final minute = _twoDigits(local.minute);

    return '$hour:$minute, $day/$month/${local.year}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
