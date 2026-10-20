import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../functions.dart';
import '../colors.dart';

class DocumentFormPage extends StatefulWidget {
  final DocumentModel? document;

  const DocumentFormPage({Key? key, this.document}) : super(key: key);

  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.document != null) {
      _titleController.text = widget.document!.title;
      _descriptionController.text = widget.document!.description ?? '';
      _selectedCategoryId = widget.document!.categoryId;
    }
  }

  Future<void> _loadCategories() async {
    final categories = await getCategories();
    setState(() {
      _categories = categories;
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    });
  }

  Future<void> _pickFile() async {
    final List<PlatformFile> files = await FilePickerPlatform.instance.pickFiles();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFile = files.single;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      if (widget.document == null) {
        await addDocument(
          title: _titleController.text,
          description: _descriptionController.text,
          file: _selectedFile,
          categoryId: _selectedCategoryId!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm tài liệu thành công')),
        );
      } else {
        await updateDocument(
          id: widget.document!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          file: _selectedFile,
          categoryId: _selectedCategoryId!,
          existingFileUrl: widget.document!.fileUrl,
          existingStoragePath: widget.document!.storagePath,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật tài liệu thành công')),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  String _getFileDisplayName() {
    if (_selectedFile != null) {
      return _selectedFile!.name;
    }
    if (widget.document?.fileUrl != null || widget.document?.filePath != null) {
      return 'Đã có file đính kèm';
    }
    return 'Chưa chọn file';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document == null ? 'Thêm tài liệu' : 'Sửa tài liệu'),
        backgroundColor: AppColors.primary,
      ),
      body: _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        if (value.length > 255) {
                          return 'Tiêu đề không được vượt quá 255 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả (tuỳ chọn)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn danh mục';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // File upload section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getFileDisplayName(),
                                style: TextStyle(
                                  color: _selectedFile != null || widget.document?.hasAttachment == true
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedFile != null)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: _removeFile,
                                tooltip: 'Xóa file đã chọn',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_selectedFile != null ? 'Thay đổi file' : 'Chọn file'),
                        ),
                        if (_isUploading) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đang tải lên: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveDocument,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Lưu',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}