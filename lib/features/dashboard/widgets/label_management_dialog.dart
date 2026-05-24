import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/services/category_service.dart';

class LabelManagementDialog extends StatefulWidget {
  final String uid;
  final String initialCategoryId;
  final Function(CategoryModel) onSelected;

  const LabelManagementDialog({
    super.key,
    required this.uid,
    required this.initialCategoryId,
    required this.onSelected,
  });

  @override
  State<LabelManagementDialog> createState() => _LabelManagementDialogState();
}

class _LabelManagementDialogState extends State<LabelManagementDialog> {
  static const int _maxLabelLength = 30;

  final TextEditingController _newLabelController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  late String selectedId;
  List<CategoryModel> _currentCategories = [];
  String? _labelError;
  bool _isAddingLabel = false;

  @override
  void initState() {
    super.initState();
    selectedId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    super.dispose();
  }

  String _normalizeLabelName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isDuplicateLabel(String name) {
    final normalizedName = name.toLowerCase();
    return _currentCategories.any(
          (category) => _normalizeLabelName(category.name).toLowerCase() == normalizedName,
    );
  }

  void _showSnackMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addNewLabel() async {
    if (_isAddingLabel) return;

    final name = _normalizeLabelName(_newLabelController.text);

    if (name.isEmpty) {
      setState(() => _labelError = 'Vui lòng nhập tên nhãn');
      return;
    }

    if (name.length > _maxLabelLength) {
      setState(() => _labelError = 'Tên nhãn tối đa $_maxLabelLength ký tự');
      return;
    }

    if (_isDuplicateLabel(name)) {
      setState(() => _labelError = 'Nhãn này đã tồn tại');
      return;
    }

    setState(() {
      _labelError = null;
      _isAddingLabel = true;
    });

    final newCat = CategoryModel(
      id: '',
      userId: widget.uid,
      name: name,
      colorHex: 'FF64DA56',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _categoryService.createCategory(newCat);
      if (!mounted) return;
      _newLabelController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showSnackMessage('Lỗi thêm nhãn: $e');
    } finally {
      if (mounted) {
        setState(() => _isAddingLabel = false);
      }
    }
  }

  void _deleteLabel(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text("Bạn có chắc muốn xóa nhãn '${cat.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _categoryService.deleteCategory(widget.uid, cat.id);
                if (!mounted) return;
                if (selectedId == cat.id) {
                  setState(() => selectedId = '');
                }
              } catch (e) {
                _showSnackMessage('Lỗi xóa nhãn: $e');
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thêm nhãn',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newLabelController,
                maxLength: _maxLabelLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Nhập tên nhãn mới...',
                  helperText: 'Tối đa $_maxLabelLength ký tự',
                  counterText: '',
                  errorText: _labelError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    tooltip: 'Thêm nhãn',
                    icon: _isAddingLabel
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.add_circle, color: Color(0xFF64DA56)),
                    onPressed: _isAddingLabel ? null : _addNewLabel,
                  ),
                ),
                onChanged: (_) {
                  if (_labelError != null) {
                    setState(() => _labelError = null);
                  }
                },
                onSubmitted: (_) => _addNewLabel(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<CategoryModel>>(
                  stream: _categoryService.getCategoriesByUser(widget.uid),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    final sortedCategories = [...categories];
                    sortedCategories.sort((a, b) {
                      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });

                    _currentCategories = sortedCategories;

                    if (selectedId.isEmpty && sortedCategories.isNotEmpty) {
                      selectedId = sortedCategories.first.id;
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && sortedCategories.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedCategories.map((cat) {
                          final isSelected = cat.id == selectedId;
                          return GestureDetector(
                            onTap: () => setState(() => selectedId = cat.id),
                            child: Chip(
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              backgroundColor: isSelected
                                  ? const Color(0xFF64DA56)
                                  : isDark
                                  ? const Color(0xFF2F3A30)
                                  : const Color(0xFFD8EFD6),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF898C89),
                                fontWeight: FontWeight.bold,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.grey),
                              onDeleted: () => _deleteLabel(cat),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide.none,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFA69C9C)),
                        backgroundColor: const Color(0xFF1D1B20).withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF767070))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentCategories.isNotEmpty) {
                          final cat = _currentCategories.firstWhere(
                                (c) => c.id == selectedId,
                            orElse: () => _currentCategories.first,
                          );
                          widget.onSelected(cat);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64DA56),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lưu', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
