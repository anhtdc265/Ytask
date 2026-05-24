import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:todo_app/models/chat_message.dart';

/// Service lưu và đọc lịch sử chatbot theo từng tài khoản người dùng.
///
/// Firestore path:
/// users/{uid}/chat_messages/{messageId}
class ChatHistoryService {
  ChatHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _deleteBatchSize = 300;

  static const String defaultWelcomeMessage =
      'Xin chào, tôi là trợ lý AI của YTask. Bạn có thể hỏi tôi cách tạo nhiệm vụ, xem tiến độ, xử lý nhiệm vụ quá hạn hoặc sắp xếp công việc hôm nay.';

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid) {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'uid không được để trống');
    }

    return _firestore
        .collection('users')
        .doc(safeUid)
        .collection('chat_messages');
  }

  /// Theo dõi lịch sử chat của một user theo thời gian tăng dần.
  Stream<List<ChatMessage>> watchMessages(String uid) {
    return _messagesRef(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList(growable: false);
    });
  }

  /// Thêm một tin nhắn vào lịch sử chat của user.
  Future<void> addMessage(String uid, ChatMessage message) async {
    final hasText = message.text.trim().isNotEmpty;
    final hasDayPlan = message.dayPlan != null;

    if (!hasText && !hasDayPlan) {
      return;
    }

    await _messagesRef(uid).add(message.toMap());
  }

  /// Xóa toàn bộ lịch sử chat của user hiện tại.
  ///
  /// Firestore batch chỉ nên xử lý một lượng document vừa phải, nên hàm này
  /// xóa theo từng lô để an toàn nếu lịch sử chat dài.
  Future<void> clearMessages(String uid) async {
    final collection = _messagesRef(uid);

    while (true) {
      final snapshot = await collection.limit(_deleteBatchSize).get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  /// Tạo tin nhắn chào mừng nếu user chưa có lịch sử chat.
  Future<void> addWelcomeMessageIfEmpty(String uid) async {
    final collection = _messagesRef(uid);
    final snapshot = await collection.limit(1).get();

    if (snapshot.docs.isNotEmpty) {
      return;
    }

    await collection.add(ChatMessage.ai(defaultWelcomeMessage).toMap());
  }
}
