import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../functions.dart';
import '../utils/responsive.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/share_dialog.dart';
import '../widgets/state_views.dart';
import 'document_form_page.dart';
import 'location_picker_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final int documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  DocumentLocationModel? _location;
  bool _isLoading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    recordDocumentView(widget.documentId); // UC-11: lượt xem + sở thích
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final loc = await getDocumentLocation(widget.documentId);
    if (mounted) setState(() => _location = loc);
  }

  Future<void> _editLocation() async {
    final result = await Navigator.of(context).push<DocumentLocationModel?>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          documentId: widget.documentId,
          existingLocation: _location,
        ),
      ),
    );
    // result == null means deleted, otherwise updated
    if (mounted) {
      setState(() => _location = result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Đã xóa vị trí tài liệu'
                : 'Đã lưu vị trí tài liệu',
          ),
        ),
      );
    }
  }

  /// Kiểm tra xem user có quyền xem tài liệu không
  Future<bool> _hasDocumentPermission() async {
    if (currentUserId.isEmpty) return false;
    final permission = await supabaseService.getUserPermission(
      widget.documentId,
      currentUserId,
    );
    // Owner và editor có quyền xem, viewer cũng có quyền xem
    return permission != null &&
        (permission == PermissionRole.owner ||
            permission == PermissionRole.editor ||
            permission == PermissionRole.viewer);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Kiểm tra quyền trước khi tải
    final hasPermission = await _hasDocumentPermission();
    if (!hasPermission && !mounted) return;

    try {
      final document = await getDocumentById(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = document;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa')),
      );
      return;
    }
    final permission = await supabaseService.getUserPermission(
      widget.documentId,
      currentUserId,
    );
    if (permission != PermissionRole.owner &&
        permission != PermissionRole.editor) {
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
      _load();
    }
  }

  Future<void> _delete() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập để xóa')));
      return;
    }
    final permission = await supabaseService.getUserPermission(
      widget.documentId,
      currentUserId,
    );
    if (permission != PermissionRole.owner) {
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

  void _share() {
    final document = _document;
    if (document == null) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          ShareDialog(documentId: document.id, documentTitle: document.title),
    );
  }

  Future<void> _openFile() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để xem tài liệu')),
      );
      return;
    }
    final permission = await supabaseService.getUserPermission(
      widget.documentId,
      currentUserId,
    );
    if (permission != PermissionRole.owner &&
        permission != PermissionRole.editor &&
        permission != PermissionRole.viewer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền xem tài liệu này')),
      );
      return;
    }

    final document = _document;
    final url = document?.openUrl;
    if (document == null || url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu này không có tệp đính kèm')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Không thể mở tệp này')));
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
            IconButton(
              tooltip: 'Chỉnh sửa',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
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
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
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
        actionLabel: 'Quay lại',
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
            ],
          ),
        ),
      ],
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
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Chỉnh sửa'),
                ),
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
              if (loc.shelf != null && loc.shelf!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.shelves,
                  label: 'Kệ / Ngăn',
                  value: loc.shelf!,
                ),
              ],
              if (loc.note != null && loc.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Ghi chú',
                  value: loc.note!,
                ),
              ],
              if (loc.hasCoordinates) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.gps_fixed,
                  label: 'Tọa độ',
                  value:
                      '${loc.latitude!.toStringAsFixed(5)}, ${loc.longitude!.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Không thể mở ứng dụng bản đồ'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Chỉ đường'),
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
