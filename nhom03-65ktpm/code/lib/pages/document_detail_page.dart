import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../functions.dart';
import '../services/tag_service.dart';
import '../struct/document_model.dart';
import '../struct/tag_model.dart';
import '../utils/responsive.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/document_location_map.dart';
import '../widgets/share_dialog.dart';
import '../widgets/state_views.dart';
import 'document_form_page.dart';
import 'file_viewer_page.dart';
import 'location_picker_page.dart';
import 'tag_management_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final int documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  DocumentLocationModel? _location;
  PermissionRole? _permission;
  bool _isLoading = true;
  bool _changed = false;
  String? _error;

  bool get _canEdit =>
      _permission == PermissionRole.owner ||
      _permission == PermissionRole.editor;

  bool get _isOwner => _permission == PermissionRole.owner;

  // Quản lý Tag
  final TagService _tagService = TagService();

  List<TagModel> _allTags = [];
  List<TagModel> _documentTags = [];
  Set<int> _selectedTagIds = {};

  bool _isLoadingTags = false;
  bool _isSavingTags = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadLocation() async {
    final loc = await getDocumentLocation(widget.documentId);
    if (mounted) setState(() => _location = loc);
  }

  Future<void> _editLocation() async {
    if (!_canEdit) {
      _showLocationMessage('Bạn không có quyền chỉnh sửa vị trí tài liệu này');
      return;
    }

    final result = await showLocationPickerDialog(
      context,
      documentId: widget.documentId,
      existingLocation: _location,
    );

    // result == null nghĩa là người dùng hủy, không thay đổi dữ liệu.
    if (result == null || !mounted) return;

    try {
      if (result.deleted) {
        await deleteDocumentLocation(widget.documentId);
        if (!mounted) return;
        setState(() => _location = null);
        _showLocationMessage('Đã xóa vị trí tài liệu');
        return;
      }

      final location = result.location;
      if (location == null) return;

      final saved = await upsertDocumentLocation(
        documentId: widget.documentId,
        latitude: location.latitude,
        longitude: location.longitude,
        placeName: location.placeName,
        note: location.note,
      );
      if (!mounted) return;
      setState(() => _location = saved ?? location);
      _showLocationMessage('Đã lưu vị trí tài liệu');
    } catch (error) {
      if (!mounted) return;
      _showLocationMessage('Không lưu được vị trí: $error');
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLocationDirections(DocumentLocationModel location) async {
    if (!location.hasCoordinates) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${location.latitude},${location.longitude}',
      'travelmode': 'driving',
    });
    await _openExternalMap(uri);
  }

  Future<void> _openLocationOnMap(DocumentLocationModel location) async {
    if (!location.hasCoordinates) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location.latitude},${location.longitude}',
    });
    await _openExternalMap(uri);
  }

  Future<void> _openExternalMap(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showLocationMessage('Không thể mở ứng dụng bản đồ');
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Kiểm tra quyền trước khi tải nội dung tài liệu.
    final permission = await getUserPermission(widget.documentId);
    if (!mounted) return;
    if (permission == null) {
      setState(() {
        _permission = null;
        _document = null;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    try {
      final document = await getDocumentById(widget.documentId);

      if (!mounted) return;

      setState(() {
        _document = document;
        _permission = permission;
        _isLoading = false;
      });
      // Chỉ ghi nhận lượt xem sau khi đã xác thực quyền truy cập.
      recordDocumentView(widget.documentId); // UC-11: lượt xem + sở thích
      _loadLocation();
      // Tải danh sách tag và tag đã gán cho tài liệu.
      await _loadTags();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Tai danh sach Tag va Tag da gan cho tai lieu
  Future<void> _loadTags() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTags = true;
    });

    try {
      final results = await Future.wait([
        _tagService.getTags(),
        _tagService.getTagsForDocument(widget.documentId),
      ]);

      final allTags = results[0];
      final documentTags = results[1];

      if (!mounted) return;

      setState(() {
        _allTags = allTags;
        _documentTags = documentTags;
        _selectedTagIds = documentTags.map((tag) => tag.id).toSet();
        _isLoadingTags = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingTags = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không tải được Tag: $error')));
    }
  }

  // Lưu các Tag được chọn
  Future<void> _saveTags() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền chỉnh sửa tag của tài liệu này'),
        ),
      );
      return;
    }
    if (_isSavingTags || _isLoadingTags) return;

    setState(() {
      _isSavingTags = true;
    });

    try {
      await _tagService.setDocumentTags(
        documentId: widget.documentId,
        tagIds: _selectedTagIds.toList(),
      );

      // Cập nhật sở thích theo tag để phục vụ Recommendation (UC-11).
      try {
        await recordTagging(_selectedTagIds.toList());
      } catch (error) {
        debugPrint('⚠️ Không cập nhật được sở thích tag: $error');
      }

      await _loadTags();

      if (!mounted) return;

      _changed = true;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu Tag cho tài liệu!')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lưu Tag thất bại: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTags = false;
        });
      }
    }
  }

  Future<void> _manageTags() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TagManagementPage()));
    if (mounted) await _loadTags();
  }

  // Chinh sua tai lieu
  Future<void> _edit() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa')),
      );
      return;
    }
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền chỉnh sửa tài liệu này'),
        ),
      );
      return;
    }

    final document = _document;
    if (document == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentFormPage(document: document)),
    );

    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  // Xoa tai lieu
  Future<void> _delete() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập để xóa')));
      return;
    }
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ chủ sở hữu tài liệu mới có quyền xóa'),
        ),
      );
      return;
    }

    final document = _document;
    if (document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        title: 'Xóa tài liệu',
        content: 'Bạn có chắc chắn muốn xóa tài liệu này không?',
      ),
    );

    if (confirmed != true) return;

    try {
      await deleteDocument(document.id, storagePath: document.storagePath);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa tài liệu')));

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa tài liệu: $error')));
    }
  }

  // Chia se tai lieu
  void _share() {
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ chủ sở hữu tài liệu mới có quyền chia sẻ'),
        ),
      );
      return;
    }
    final document = _document;
    if (document == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => ShareDialog(
        documentId: document.id,
        documentTitle: document.title,
        onShareChanged: () => _load(),
      ),
    );
  }

  // Mo tep dinh kem
  Future<void> _openFile() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để xem tài liệu')),
      );
      return;
    }
    if (_permission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền xem tài liệu này')),
      );
      return;
    }

    final document = _document;
    if (document == null || !document.hasAttachment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu này không có tệp đính kèm')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FileViewerPage(document: document)),
    );
  }

  void _goBack() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text('Chi tiết tài liệu'),
        actions: [
          if (_document != null) ...[
            if (_canEdit)
              IconButton(
                tooltip: 'Chỉnh sửa',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
            if (_isOwner)
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (value) {
                  if (value == 'share') _share();
                  if (value == 'delete') _delete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share_outlined),
                      title: Text('Chia sẻ'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Xóa tài liệu',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingView(message: 'Đang tải chi tiết tài liệu...');
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Không tải được tài liệu',
        message: _error!,
        onRetry: _load,
      );
    }

    final document = _document;

    if (document == null) {
      return AppEmptyView(
        icon: Icons.folder_off_outlined,
        title: 'Tài liệu không tồn tại',
        message: 'Tài liệu có thể đã bị xóa hoặc bạn không có quyền xem.',
        actionLabel: 'Quay lai',
        onAction: _goBack,
      );
    }

    return ListView(
      padding: context.pagePadding,
      children: [
        ContentWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(context, document),
              const SizedBox(height: 16),
              _buildAttachmentCard(context, document),
              const SizedBox(height: 16),
              _buildLocationCard(context),
              const SizedBox(height: 16),
              _buildInfoCard(context, document),
              const SizedBox(height: 16),
              _buildTagsCard(context),
            ],
          ),
        ),
      ],
    );
  }

  // Hiển thị khu vực chọn Tag
  Widget _buildTagsCard(BuildContext context) {
    final visibleTags = _canEdit ? _allTags : _documentTags;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sell_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Phân loại bằng Tag',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_canEdit)
                  TextButton(
                    onPressed: _manageTags,
                    child: const Text('Quản lý'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _canEdit
                  ? 'Chọn một hoặc nhiều thẻ phù hợp với tài liệu.'
                  : 'Các thẻ đã gán cho tài liệu.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            if (_isLoadingTags)
              const Center(child: CircularProgressIndicator())
            else if (visibleTags.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _canEdit
                        ? 'Chưa có tag nào. Tạo tag để gán cho tài liệu.'
                        : 'Tài liệu chưa được gán tag.',
                  ),
                  if (_canEdit) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _manageTags,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo tag'),
                    ),
                  ],
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visibleTags.map((tag) {
                  return FilterChip(
                    label: Text(tag.name),
                    selected: _selectedTagIds.contains(tag.id),
                    onSelected: !_canEdit || _isSavingTags
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
                  );
                }).toList(),
              ),

            if (!_isLoadingTags && _documentTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Tag đã lưu: ${_documentTags.map((tag) => tag.name).join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],

            if (_canEdit) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isLoadingTags || _isSavingTags ? null : _saveTags,
                  icon: _isSavingTags
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSavingTags ? 'Đang lưu...' : 'Lưu Tag'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DocumentModel document) {
    return Card(
      child: Padding(
        padding: context.responsive(
          compact: const EdgeInsets.all(18),
          expanded: const EdgeInsets.all(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(
                  label: document.categoryName.trim().isEmpty
                      ? 'Chưa phân loại'
                      : document.categoryName,
                ),
                if (_permission == PermissionRole.viewer) ...[
                  const SizedBox(width: 8),
                  const _Badge(
                    label: 'Chỉ xem',
                    color: AppColors.textSecondary,
                    background: Color(0xFFF1F5F9),
                  ),
                ] else if (_permission == PermissionRole.editor) ...[
                  const SizedBox(width: 8),
                  const _Badge(label: 'Có thể chỉnh sửa'),
                ] else if (_permission == PermissionRole.owner) ...[
                  const SizedBox(width: 8),
                  const _Badge(
                    label: 'Chủ sở hữu',
                    color: AppColors.success,
                    background: Color(0xFFE7F6EC),
                  ),
                ],
                const Spacer(),
                if (document.hasAttachment)
                  const _Badge(
                    label: 'Có tệp đính kèm',
                    color: AppColors.success,
                    background: Color(0xFFE7F6EC),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              document.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
            ),
            const SizedBox(height: 10),
            Text(
              (document.description?.trim().isNotEmpty ?? false)
                  ? document.description!
                  : 'Chưa có mô tả cho tài liệu này.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
                fontStyle: (document.description?.trim().isNotEmpty ?? false)
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_canEdit)
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Chỉnh sửa'),
                  ),
                if (_isOwner)
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Chia sẻ'),
                  ),
                if (document.hasAttachment)
                  OutlinedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Mở tệp'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, DocumentModel document) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                document.hasAttachment
                    ? Icons.insert_drive_file_outlined
                    : Icons.file_present_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tệp đính kèm',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    document.hasAttachment
                        ? 'Mở tệp để xem nội dung chi tiết.'
                        : 'Tài liệu này chưa có tệp đính kèm.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (document.hasAttachment)
              TextButton.icon(
                onPressed: _openFile,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Mở'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final loc = _location;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Vị trí vật lý',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_canEdit)
                  TextButton.icon(
                    onPressed: _editLocation,
                    icon: const Icon(Icons.edit_location_outlined, size: 16),
                    label: Text(
                      loc == null || loc.isEmpty ? 'Thêm vị trí' : 'Sửa vị trí',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (loc == null || loc.isEmpty)
              const Text(
                'Chưa có thông tin vị trí. Nhấn "Thêm vị trí" để ghi lại nơi lưu trữ tài liệu.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else ...[
              if (loc.placeName != null && loc.placeName!.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: 'Địa điểm',
                  value: loc.placeName!,
                ),
              if (loc.note != null && loc.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Ghi chú',
                  value: loc.note!,
                ),
              ],
              if (loc.hasCoordinates) ...[
                const SizedBox(height: 12),
                DocumentLocationMap(
                  latitude: loc.latitude!,
                  longitude: loc.longitude!,
                  height: 210,
                  zoom: 17,
                  interactive: false,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.gps_fixed,
                  label: 'Tọa độ',
                  value:
                      '${loc.latitude!.toStringAsFixed(5)}, ${loc.longitude!.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openLocationDirections(loc),
                      icon: const Icon(Icons.navigation_outlined, size: 16),
                      label: const Text('Chỉ đường'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openLocationOnMap(loc),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Mở bản đồ'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, DocumentModel document) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin tài liệu',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Danh mục',
              value: document.categoryName.trim().isEmpty
                  ? 'Chưa phân loại'
                  : document.categoryName,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Ngày tạo',
              value: DateFormat('dd/MM/yyyy HH:mm').format(document.createdAt),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.update,
              label: 'Cập nhật lần cuối',
              value: DateFormat('dd/MM/yyyy HH:mm').format(document.updatedAt),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.tag,
              label: 'Mã tài liệu',
              value: '#${document.id}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.color = AppColors.primaryDark,
    this.background = AppColors.primaryLight,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
