import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';
import '../services/tag_service.dart';
import '../struct/tag_model.dart';
import '../utils/responsive.dart';
import '../widgets/document_location_map.dart';
import '../widgets/state_views.dart';
import 'location_picker_page.dart';
import 'tag_management_page.dart';

class DocumentFormPage extends StatefulWidget {
  const DocumentFormPage({super.key, this.document});

  final DocumentModel? document;

  bool get isEditing => document != null;

  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagService = TagService();

  List<CategoryModel> _categories = [];
  List<TagModel> _tags = [];
  final Set<int> _selectedTagIds = {};
  int? _selectedCategoryId;
  PlatformFile? _selectedFile;
  DocumentLocationModel? _location;
  bool _locationChanged = false;
  bool _isLoadingLocation = false;
  bool _isLoadingCategories = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    if (document != null) {
      _titleController.text = document.title;
      _descriptionController.text = document.description ?? '';
      _selectedCategoryId = document.categoryId;
    }
    _loadCategories();
    if (document != null) {
      _checkEditPermission(document.id);
      _loadLocation(document.id);
    }
  }

  Future<void> _loadLocation(int documentId) async {
    setState(() => _isLoadingLocation = true);
    final location = await getDocumentLocation(documentId);
    if (!mounted) return;
    setState(() {
      _location = location;
      _isLoadingLocation = false;
    });
  }

  /// Kiểm tra quyền chỉnh sửa khi mở form sửa tài liệu
  Future<void> _checkEditPermission(int documentId) async {
    if (currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa')),
      );
      Navigator.of(context).pop();
      return;
    }
    final permission = await getUserPermission(documentId);
    if (permission != PermissionRole.owner &&
        permission != PermissionRole.editor) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền chỉnh sửa tài liệu này'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _loadError = null;
    });

    try {
      final categories = await getCategories();
      final tags = await _tagService.getTags();
      final document = widget.document;
      final documentTags = document == null
          ? <TagModel>[]
          : await _tagService.getTagsForDocument(document.id);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _tags = tags;
        _selectedTagIds
          ..clear()
          ..addAll(documentTags.map((tag) => tag.id));
        _isLoadingCategories = false;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _manageTags() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TagManagementPage()));
    if (!mounted) return;

    try {
      final tags = await _tagService.getTags();
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _selectedTagIds.removeWhere((id) => !tags.any((tag) => tag.id == id));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách tag: $error')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles();
      if (files.isNotEmpty && mounted) {
        setState(() => _selectedFile = files.single);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể chọn tệp: $error')));
    }
  }

  Future<void> _pickLocation() async {
    final result = await showLocationPickerDialog(
      context,
      existingLocation: _location,
    );
    if (result == null || !mounted) return;
    setState(() {
      _location = result.deleted ? null : result.location;
      _locationChanged = true;
    });
  }

  Future<void> _persistLocation(int documentId) async {
    final location = _location;
    if (location == null || location.isEmpty) {
      await deleteDocumentLocation(documentId);
      return;
    }
    await upsertDocumentLocation(
      documentId: documentId,
      latitude: location.latitude,
      longitude: location.longitude,
      placeName: location.placeName,
      note: location.note,
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      setState(() => _saveError = 'Vui lòng chọn danh mục cho tài liệu.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      late final DocumentModel savedDocument;
      if (widget.document == null) {
        savedDocument = await addDocument(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          file: _selectedFile,
          categoryId: _selectedCategoryId!,
        );
        if (_location != null && !_location!.isEmpty) {
          await _persistLocation(savedDocument.id);
        }
      } else {
        savedDocument = await updateDocument(
          id: widget.document!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          file: _selectedFile,
          categoryId: _selectedCategoryId!,
          existingFileUrl: widget.document!.fileUrl,
          existingStoragePath: widget.document!.storagePath,
        );
        if (_locationChanged) {
          await _persistLocation(widget.document!.id);
        }
      }
      await _tagService.setDocumentTags(
        documentId: savedDocument.id,
        tagIds: _selectedTagIds.toList(),
      );
      // Cập nhật sở thích theo tag cho Recommendation (UC-11).
      await recordTagging(_selectedTagIds.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Đã cập nhật tài liệu thành công'
                : 'Đã thêm tài liệu thành công',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lưu tài liệu thất bại: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      onPressed: _isSaving ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(
        _isSaving
            ? 'Đang lưu...'
            : (widget.isEditing ? 'Lưu thay đổi' : 'Lưu tài liệu'),
      ),
    );
  }

  Widget _buildLocationSection() {
    final location = _location;
    final hasLocation = location != null && !location.isEmpty;

    return _SectionCard(
      title: 'Vị trí tài liệu',
      subtitle: 'Chọn vị trí trên bản đồ để lưu tọa độ, địa chỉ và chỉ đường sau này.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (location != null && location.hasCoordinates) ...[
            DocumentLocationMap(
              latitude: location.latitude!,
              longitude: location.longitude!,
              height: 160,
              zoom: 16,
              interactive: false,
            ),
            const SizedBox(height: 10),
            Text(
              location.summaryText,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation
                        ? Icons.place_outlined
                        : Icons.add_location_alt_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasLocation ? location.summaryText : 'Chưa chọn vị trí. Bạn có thể chọn trên bản đồ hoặc bỏ trống.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickLocation,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(
                  hasLocation ? 'Thay đổi vị trí' : 'Chọn vị trí trên bản đồ',
                ),
              ),
              if (hasLocation)
                TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                          _location = null;
                          _locationChanged = true;
                        }),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xóa vị trí'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa tài liệu' : 'Thêm tài liệu'),
      ),
      body: _buildBody(context),
      bottomNavigationBar: context.isCompact && !_isLoadingCategories
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _buildSaveButton(),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoadingCategories) {
      return const AppLoadingView(message: 'Đang tải danh mục...');
    }

    if (_loadError != null) {
      return AppErrorView(
        title: 'Không tải được dữ liệu biểu mẫu',
        message: _loadError!,
        onRetry: _loadCategories,
      );
    }

    final basicInfo = _SectionCard(
      title: 'Thông tin cơ bản',
      subtitle:
          'Tiêu đề là bắt buộc, mô tả giúp bạn tìm lại tài liệu nhanh hơn.',
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề *',
              hintText: 'Ví dụ: Bài giảng Giải tích tuần 5',
            ),
            validator: (value) {
              final title = value?.trim() ?? '';
              if (title.isEmpty) return 'Vui lòng nhập tiêu đề';
              if (title.length > 255) {
                return 'Tiêu đề không được vượt quá 255 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            enabled: !_isSaving,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              hintText: 'Tóm tắt nội dung hoặc ghi chú cho tài liệu...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );

    final classification = _SectionCard(
      title: 'Phân loại & tệp đính kèm',
      subtitle: 'Chọn danh mục và tệp cần lưu kèm tài liệu.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Danh mục *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _selectedCategoryId = value),
            validator: (value) =>
                value == null ? 'Vui lòng chọn danh mục' : null,
          ),
          const SizedBox(height: 18),
          _FilePickerField(
            fileName: _selectedFile?.name,
            hasExistingFile: widget.document?.hasAttachment ?? false,
            enabled: !_isSaving,
            onPick: _pickFile,
            onRemove: _selectedFile == null
                ? null
                : () => setState(() => _selectedFile = null),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 16),
            _InlineError(message: _saveError!),
          ],
          if (!context.isCompact) ...[
            const SizedBox(height: 22),
            _buildSaveButton(),
          ],
          if (_isSaving && _selectedFile != null) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            const Text(
              'Đang tải tệp lên Storage, vui lòng không đóng màn hình.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );

    final tagsSection = _SectionCard(
      title: 'Tag',
      subtitle: 'Chọn một hoặc nhiều tag để phân loại tài liệu.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tags.isEmpty)
            const Text('Chưa có tag nào.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _tags)
                  FilterChip(
                    label: Text(tag.name),
                    selected: _selectedTagIds.contains(tag.id),
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            });
                          },
                  ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isSaving ? null : _manageTags,
            icon: const Icon(Icons.sell_outlined),
            label: const Text('Tạo hoặc quản lý tag'),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: ContentWidth(
        maxWidth: 1000,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (context.isExpanded)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: basicInfo),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          classification,
                          const SizedBox(height: 16),
                          _buildLocationSection(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                basicInfo,
                const SizedBox(height: 16),
                classification,
                const SizedBox(height: 16),
                _buildLocationSection(),
              ],
              const SizedBox(height: 16),
              tagsSection,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _FilePickerField extends StatelessWidget {
  const _FilePickerField({
    required this.fileName,
    required this.hasExistingFile,
    required this.enabled,
    required this.onPick,
    this.onRemove,
  });

  final String? fileName;
  final bool hasExistingFile;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null || hasExistingFile;
    final label =
        fileName ?? (hasExistingFile ? 'Đã có tệp đính kèm' : 'Chưa chọn tệp');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hasFile
                    ? Icons.insert_drive_file_outlined
                    : Icons.cloud_upload_outlined,
                color: hasFile ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasFile
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Bỏ tệp đã chọn',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.error,
                  ),
                  onPressed: enabled ? onRemove : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(hasFile ? 'Thay đổi tệp' : 'Chọn tệp'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
