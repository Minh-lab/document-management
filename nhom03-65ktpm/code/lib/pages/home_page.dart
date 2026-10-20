import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../colors.dart';
import '../functions.dart';
import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../utils/responsive.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/document_grid.dart';
import '../widgets/share_dialog.dart';
import '../widgets/state_views.dart';
import 'document_detail_page.dart';
import 'document_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onViewAllDocuments});

  final VoidCallback onViewAllDocuments;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DocumentModel> _documents = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) supabaseService.unsubscribe(channel);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _documents.isEmpty;
      _error = null;
    });

    try {
      final results = await Future.wait([getCategories(), getDocuments()]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _documents = results[1] as List<DocumentModel>;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _setupRealtime() {
    _realtimeChannel = supabaseService.subscribeToDocuments(
      userId: currentUserId,
      onDocumentsChanged: (documents) {
        if (!mounted) return;
        setState(() {
          _documents = documents;
          _isLoading = false;
          _error = null;
        });
      },
    );
  }

  Future<void> _openDetail(DocumentModel document) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(documentId: document.id),
      ),
    );
    if (changed != false) _load();
  }

  Future<void> _openForm([DocumentModel? document]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentFormPage(document: document)),
    );
    if (changed != false) _load();
  }

  Future<void> _deleteDocument(DocumentModel document) async {
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
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa tài liệu: $error')));
    }
  }

  void _openShareDialog(DocumentModel document) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          ShareDialog(documentId: document.id, documentTitle: document.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingView(message: 'Đang tải trang chủ...');
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Không tải được trang chủ',
        message: _error!,
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.pagePadding,
        children: [
          ContentWidth(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _StatsRow(
                  documents: _documents,
                  categories: _categories.length,
                ),
                const SizedBox(height: 28),
                _buildRecentSection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = currentFirebaseUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email;
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (email != null && email.contains('@'))
        ? email.split('@').first
        : 'bạn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $name 👋',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hôm nay, ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (context.isExpanded)
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm tài liệu'),
              ),
          ],
        ),
        if (!context.isExpanded) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm tài liệu'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tài liệu gần đây',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (_documents.isNotEmpty)
              TextButton(
                onPressed: widget.onViewAllDocuments,
                child: const Text('Xem tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_documents.isEmpty)
          SizedBox(
            height: 260,
            child: AppEmptyView(
              icon: Icons.folder_open,
              title: 'Chưa có tài liệu nào',
              message: 'Thêm tài liệu đầu tiên để bắt đầu quản lý việc học.',
              actionLabel: 'Thêm tài liệu',
              onAction: () => _openForm(),
            ),
          )
        else
          DocumentGrid(
            documents: _documents,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            maxItems: context.isCompact ? 4 : 6,
            onTap: _openDetail,
            onEdit: (document) => _openForm(document),
            onDelete: _deleteDocument,
            onShare: _openShareDialog,
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.documents, required this.categories});

  final List<DocumentModel> documents;
  final int categories;

  @override
  Widget build(BuildContext context) {
    final withAttachment = documents.where((d) => d.hasAttachment).length;

    final cards = [
      _StatCard(
        icon: Icons.folder_copy_outlined,
        label: 'Tài liệu',
        value: '${documents.length}',
        color: AppColors.primary,
      ),
      _StatCard(
        icon: Icons.category_outlined,
        label: 'Danh mục',
        value: '$categories',
        color: AppColors.success,
      ),
      _StatCard(
        icon: Icons.attach_file,
        label: 'Có tệp đính kèm',
        value: '$withAttachment',
        color: AppColors.warning,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1)
            SizedBox(width: context.isCompact ? 10 : 14),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final iconBox = Container(
      width: compact ? 32 : 42,
      height: compact ? 32 : 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Icon(icon, color: color, size: compact ? 17 : 21),
    );

    final valueText = Text(
      value,
      style: TextStyle(
        fontSize: compact ? 18 : 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );

    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 10.5 : 12,
        color: AppColors.textSecondary,
      ),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconBox,
                  const SizedBox(height: 8),
                  valueText,
                  const SizedBox(height: 1),
                  labelText,
                ],
              )
            : Row(
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        valueText,
                        const SizedBox(height: 1),
                        labelText,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
