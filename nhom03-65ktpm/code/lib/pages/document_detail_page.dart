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
import '../widgets/share_dialog.dart';
import '../widgets/state_views.dart';
import 'document_form_page.dart';
import 'tag_management_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final int documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  bool _isLoading = true;
  bool _changed = false;
  String? _error;

  // Quan ly Tag
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

  // Tai thong tin tai lieu
  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final document = await getDocumentById(widget.documentId);

      if (!mounted) return;

      setState(() {
        _document = document;
        _isLoading = false;
      });

      // Tai cac Tag sau khi tai tai lieu thanh cong
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
          .showSnackBar(SnackBar(content: Text('Khong tai duoc Tag: $error')));
    }
  }

  // Luu cac Tag duoc chon
  Future<void> _saveTags() async {
    if (_isSavingTags || _isLoadingTags) return;

    setState(() {
      _isSavingTags = true;
    });

    try {
      await _tagService.setDocumentTags(
        documentId: widget.documentId,
        tagIds: _selectedTagIds.toList(),
      );

      await _loadTags();

      if (!mounted) return;

      _changed = true;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Da luu Tag cho tai lieu!')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Luu Tag that bai: $error')));
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
    final document = _document;
    if (document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        title: 'Xoa tai lieu',
        content: 'Ban co chac chan muon xoa tai lieu nay khong?',
      ),
    );

    if (confirmed != true) return;

    try {
      await deleteDocument(document.id, storagePath: document.storagePath);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Da xoa tai lieu')));

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong the xoa tai lieu: $error')));
    }
  }

  // Chia se tai lieu
  void _share() {
    final document = _document;
    if (document == null) return;

    showDialog<void>(
      context: context,
      builder: (_) =>
          ShareDialog(documentId: document.id, documentTitle: document.title),
    );
  }

  // Mo tep dinh kem
  Future<void> _openFile() async {
    final document = _document;
    final url = document?.openUrl;

    if (document == null || url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tai lieu nay khong co tep dinh kem')),
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
        .showSnackBar(const SnackBar(content: Text('Khong the mo tep nay')));
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
        title: const Text('Chi tiet tai lieu'),
        actions: [
          if (_document != null) ...[
            IconButton(
              tooltip: 'Chinh sua',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            PopupMenuButton<String>(
              tooltip: 'Tuy chon',
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
                    title: Text('Chia se'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text(
                      'Xoa tai lieu',
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
      return const AppLoadingView(message: 'Dang tai chi tiet tai lieu...');
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Khong tai duoc tai lieu',
        message: _error!,
        onRetry: _load,
      );
    }

    final document = _document;

    if (document == null) {
      return AppEmptyView(
        icon: Icons.folder_off_outlined,
        title: 'Tai lieu khong ton tai',
        message: 'Tai lieu co the da bi xoa hoac ban khong co quyen xem.',
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
              _buildInfoCard(context, document),
              const SizedBox(height: 16),
              _buildTagsCard(context),
            ],
          ),
        ),
      ],
    );
  }

  // The hien khu vuc chon Tag
  Widget _buildTagsCard(BuildContext context) {
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
                  'Phan loai bang Tag',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _manageTags,
                  child: const Text('Quản lý'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Chon mot hoac nhieu the phu hop voi tai lieu.'),
            const SizedBox(height: 12),

            if (_isLoadingTags)
              const Center(child: CircularProgressIndicator())
            else if (_allTags.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chưa có tag nào. Tạo tag để gán cho tài liệu.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _manageTags,
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo tag'),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTags.map((tag) {
                  return FilterChip(
                    label: Text(tag.name),
                    selected: _selectedTagIds.contains(tag.id),
                    onSelected: _isSavingTags
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
                'Tag da luu: ${_documentTags.map((tag) => tag.name).join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],

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
                label: Text(_isSavingTags ? 'Dang luu...' : 'Luu Tag'),
              ),
            ),
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
                      ? 'Chua phan loai'
                      : document.categoryName,
                ),
                const Spacer(),
                if (document.hasAttachment)
                  const _Badge(
                    label: 'Co tep dinh kem',
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
                  : 'Chua co mo ta cho tai lieu nay.',
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
                  label: const Text('Chinh sua'),
                ),
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Chia se'),
                ),
                if (document.hasAttachment)
                  OutlinedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Mo tep'),
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
                    'Tep dinh kem',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    document.hasAttachment
                        ? 'Mo tep de xem noi dung chi tiet.'
                        : 'Tai lieu nay chua co tep dinh kem.',
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
                label: const Text('Mo'),
              ),
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
              'Thong tin tai lieu',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Danh muc',
              value: document.categoryName.trim().isEmpty
                  ? 'Chua phan loai'
                  : document.categoryName,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Ngay tao',
              value: DateFormat('dd/MM/yyyy HH:mm').format(document.createdAt),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.update,
              label: 'Cap nhat lan cuoi',
              value: DateFormat('dd/MM/yyyy HH:mm').format(document.updatedAt),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.tag,
              label: 'Ma tai lieu',
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
