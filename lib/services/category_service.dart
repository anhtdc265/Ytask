import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream lấy danh sách category theo user - Đã cập nhật orderBy createdAt DESC để nhãn mới lên đầu
  Stream<List<CategoryModel>> getCategoriesByUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Đảm bảo user có các category mặc định
  Future<void> ensureDefaultCategories(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      final defaultCategories = [
        {'name': 'Công việc', 'colorHex': 'FF64DA56'},
        {'name': 'Học tập', 'colorHex': 'FF64DA56'},
        {'name': 'Vận động', 'colorHex': 'FF64DA56'},
        {'name': 'Đi chơi', 'colorHex': 'FF64DA56'},
        {'name': 'Cá nhân', 'colorHex': 'FF64DA56'},
        {'name': 'Khác', 'colorHex': 'FF64DA56'},
      ];

      final batch = _firestore.batch();
      for (var cat in defaultCategories) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('categories')
            .doc();

        final category = CategoryModel(
          id: docRef.id,
          userId: uid,
          name: cat['name']!,
          colorHex: cat['colorHex']!,
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        batch.set(docRef, category.toMap());
      }
      await batch.commit();
    }
  }


  // Lấy danh sách category một lần để AI/local advisor hiển thị tên danh mục.
  Future<List<CategoryModel>> getCategoriesForUser(String uid) async {
    if (uid.trim().isEmpty) return <CategoryModel>[];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .get();

    return snapshot.docs
        .map((doc) => CategoryModel.fromMap({
      ...doc.data(),
      'id': doc.data()['id'] ?? doc.id,
    }))
        .toList(growable: false);
  }

  // Tạo category mới
  Future<void> createCategory(CategoryModel category) async {
    final docRef = _firestore
        .collection('users')
        .doc(category.userId)
        .collection('categories')
        .doc();

    final newCategory = category.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newCategory.toMap());
  }

  // Cập nhật category
  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection('users')
        .doc(category.userId)
        .collection('categories')
        .doc(category.id)
        .update(category.copyWith(updatedAt: DateTime.now()).toMap());
  }

  // Xóa category
  Future<void> deleteCategory(String uid, String categoryId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }
}
