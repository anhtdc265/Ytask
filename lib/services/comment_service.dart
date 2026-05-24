import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo_app/models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy Stream danh sách bình luận của một Task (Subcollection)
  Stream<List<CommentModel>> getCommentsByTask(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommentModel.fromMap(doc.data());
      }).toList();
    });
  }

  /// Thêm bình luận mới vào subcollection
  Future<void> addComment(CommentModel comment) async {
    await _firestore
        .collection('tasks')
        .doc(comment.taskId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  /// Xóa bình luận khỏi subcollection
  Future<void> deleteComment(String taskId, String commentId) async {
    await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
}
