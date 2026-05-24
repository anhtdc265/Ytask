import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:todo_app/services/task_service.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUp(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(name);

      final newUser = UserModel(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        avatarUrl: 'frog',
      );

      await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());

      return userCredential;
    } catch (e) {
      print('Lỗi đăng ký: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _syncAuthEmailToFirestore(userCredential.user);

      final uid = userCredential.user?.uid;

      if (uid != null) {
        try {
          await TaskService().syncPendingRemindersForUser(uid);
        } catch (e) {
          debugPrint('YTask: lỗi sync reminder sau đăng nhập: $e');
        }
      }

      return userCredential;
    } catch (e) {
      print('Lỗi đăng nhập: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      await user.reload();
      final freshUser = _auth.currentUser;

      await _syncAuthEmailToFirestore(freshUser);

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Lỗi lấy Profile: $e');
      return null;
    }
  }

  Future<void> updateUserName(String newName) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'Không tìm thấy người dùng hiện tại.',
        );
      }

      final trimmedName = newName.trim();

      await user.updateDisplayName(trimmedName);

      await _firestore.collection('users').doc(user.uid).update({
        'name': trimmedName,
      });
    } catch (e) {
      print('Lỗi cập nhật tên: $e');
      rethrow;
    }
  }

  Future<void> updateUserAvatar(String avatarUrl) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'Không tìm thấy người dùng hiện tại.',
        );
      }

      final safeAvatar = avatarUrl.trim().isEmpty ? 'frog' : avatarUrl.trim();

      await _firestore.collection('users').doc(user.uid).update({
        'avatarUrl': safeAvatar,
      });

      // Chỉ update photoURL nếu sau này avatarUrl là link ảnh thật.
      // Với avatar mẫu dạng ID như "frog", "robot" thì chỉ lưu Firestore.
      if (safeAvatar.startsWith('http://') || safeAvatar.startsWith('https://')) {
        await user.updatePhotoURL(safeAvatar);
      }
    } catch (e) {
      print('Lỗi cập nhật avatar: $e');
      rethrow;
    }
  }

  User _requireCurrentUser() {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Không tìm thấy người dùng hiện tại.',
      );
    }

    return user;
  }

  Future<void> _syncAuthEmailToFirestore(User? user) async {
    if (user == null) return;

    final authEmail = user.email?.trim();
    if (authEmail == null || authEmail.isEmpty) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'id': user.uid,
        'name': user.displayName ?? 'Người dùng',
        'email': authEmail,
        'avatarUrl': user.photoURL,
      }, SetOptions(merge: true));
      return;
    }

    final data = doc.data();
    final firestoreEmail = (data?['email'] as String?)?.trim();
    final pendingEmail = (data?['pendingEmail'] as String?)?.trim();

    final updates = <String, dynamic>{};

    if (firestoreEmail != authEmail) {
      updates['email'] = authEmail;
    }

    if (pendingEmail != null && pendingEmail == authEmail) {
      updates['pendingEmail'] = FieldValue.delete();
      updates['pendingEmailRequestedAt'] = FieldValue.delete();
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> reauthenticateWithPassword({
    required String currentPassword,
  }) async {
    final user = _requireCurrentUser();
    final email = user.email;

    if (email == null || email.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Tài khoản hiện tại không có email.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updateUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireCurrentUser();

    await reauthenticateWithPassword(
      currentPassword: currentPassword,
    );

    await user.updatePassword(newPassword);
  }

  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _requireCurrentUser();
    final trimmedEmail = newEmail.trim();

    await reauthenticateWithPassword(
      currentPassword: currentPassword,
    );

    await user.verifyBeforeUpdateEmail(trimmedEmail);

    await _firestore.collection('users').doc(user.uid).set(
      {
        'pendingEmail': trimmedEmail,
        'pendingEmailRequestedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> syncUserProfileFromAuth() async {
    final oldUser = currentUser;
    if (oldUser == null) return;

    await oldUser.reload();

    final user = currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data();

    final pendingEmail = data?['pendingEmail'] as String?;

    final updates = <String, dynamic>{};

    if (user.email != null && user.email!.trim().isNotEmpty) {
      updates['email'] = user.email;
    }

    if (pendingEmail != null && user.email == pendingEmail) {
      updates['pendingEmail'] = FieldValue.delete();
      updates['pendingEmailRequestedAt'] = FieldValue.delete();
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    try {
      await NotificationService.instance.cancelAll();
    } catch (e) {
      print('Lỗi hủy notifications khi signOut: $e');
    }
    await _auth.signOut();
  }
}

String mapAuthErrorToMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }

  final code = error.code.replaceFirst('auth/', '').trim();

  switch (code) {
    case 'no-current-user':
      return 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
    case 'missing-email':
      return 'Tài khoản hiện tại không có email để xác thực.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Mật khẩu hiện tại không đúng.';
    case 'weak-password':
      return 'Mật khẩu mới quá yếu. Vui lòng dùng ít nhất 6 ký tự.';
    case 'email-already-in-use':
      return 'Email này đã được sử dụng.';
    case 'invalid-email':
      return 'Email không hợp lệ.';
    case 'requires-recent-login':
      return 'Phiên đăng nhập đã cũ. Vui lòng đăng nhập lại rồi thử lại.';
    case 'too-many-requests':
      return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
    case 'operation-not-allowed':
      return 'Chức năng này chưa được bật trong Firebase Authentication.';
    case 'user-disabled':
      return 'Tài khoản đã bị vô hiệu hóa.';
    case 'user-not-found':
      return 'Không tìm thấy tài khoản.';
    default:
      return error.message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}