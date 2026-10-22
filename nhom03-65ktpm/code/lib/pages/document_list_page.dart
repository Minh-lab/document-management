import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../functions.dart';
import '../services/tag_service.dart';
import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../struct/tag_model.dart';
import '../utils/responsive.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/document_grid.dart';
import '../widgets/share_dialog.dart';
import 'document_detail_page.dart';
import 'document_form_page.dart';
import 'tag_management_page.dart';

class DocumentListPage extends StatefulWidget {
  const DocumentListPage({super.key});

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  final TextEditingController _searchController = TextEditingController();
  final TagService _tagService = TagService();

  Timer? _debounce;
  RealtimeChannel? _realtimeChannel;

  List<DocumentModel> _documents = [];
  List<CategoryModel> _categories = [];
  List<TagModel> _tags = [];

  int? _selectedCategoryId;
  final Set<int> _selectedTagIds = {};

  bool _isLoading = true;
  String? _error;

  bool get _hasFilter =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _selectedTagIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    _debounce?.cancel();

    final channel = _realtimeChannel;
    if (channel != null) {
      supabaseService.unsubscribe(channel);
    }

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Tai danh muc
      final categories = await getCategories();

      final keyword = _searchController.text.trim();

      // Search document titles and tag names, then merge the matches.
      final titleMatches = await getDocuments(
        keyword: keyword,
        categoryId: _selectedCategoryId,
      );

      final tags = await _tagService.getTags();
      var loadedDocuments = titleMatches;

      if (keyword.isNotEmpty) {
        final matchingDocumentIds = await _tagService
            .searchDocumentIdsByTagName(keyword);
        if (matchingDocumentIds.isNotEmpty) {
          final tagMatches = await getDocuments(
            categoryId: _selectedCategoryId,
            documentIds: matchingDocumentIds.toSet(),
          );
          final documentsById = {
            for (final document in [...titleMatches, ...tagMatches])
              document.id: document,
          };
          loadedDocuments = documentsById.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      }

      // A document matches when it has at least one selected tag.
      if (_selectedTagIds.isNotEmpty) {
        final documentIds = await _tagService.getDocumentIdsForTags(
          _selectedTagIds,
        );
        loadedDocuments = loadedDocuments
            .where((document) => documentIds.contains(document.id))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _documents = loadedDocuments;
        _tags = tags;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint('LOI TAI DU LIEU: $error');
      debugPrint('$stackTrace');

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
      onDocumentsChanged: (_) {
        _load(showLoading: false);
      },
    );
  }

  void _onSearchChanged(String _) {
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(showLoading: false),
    );
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });

    _load();
  }

  void _toggleTag(int tagId) {
    setState(() {
      if (!_selectedTagIds.add(tagId)) {
        _selectedTagIds.remove(tagId);
      }
    });

    _load();
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _selectedCategoryId = null;
      _selectedTagIds.clear();
    });

    _load();
  }

  Future<void> _openDetail(DocumentModel document) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(documentId: document.id),
      ),
    );

    if (changed != false && mounted) {
      _load(showLoading: false);
    }
  }

  Future<void> _openForm([DocumentModel? document]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentFormPage(document: document)),
    );

    if (changed != false && mounted) {
      _load(showLoading: false);
    }
  }

  Future<void> _openTagManagement() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TagManagementPage()));
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _deleteDocument(DocumentModel document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Xóa tài liệu',
        content:
            'Bạn có chắc chắn muốn xóa tài liệu "${document.title}" không?',
      ),
    );

    if (confirmed != true) return;

    try {
      await deleteDocument(document.id, storagePath: document.storagePath);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa tài liệu')));

      _load(showLoading: false);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm tài liệu'),
      ),
      body: Column(
        children: [
          Padding(
            padding: context.pagePadding,
            child: ContentWidth(
              maxWidth: 1200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _hasFilter ? _clearFilters : null,
                  ),

                  // Loc theo danh muc
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Lọc theo danh mục',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'Tất cả',
                            selected: _selectedCategoryId == null,
                            onSelected: () => _selectCategory(null),
                          ),
                          for (final category in _categories) ...[
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: category.name,
                              selected: _selectedCategoryId == category.id,
                              onSelected: () {
                                _selectCategory(
                                  _selectedCategoryId == category.id
                                      ? null
                                      : category.id,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lọc theo Tag',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openTagManagement,
                        icon: const Icon(Icons.sell_outlined, size: 18),
                        label: const Text('Quản lý tag'),
                      ),
                    ],
                  ),

                  // Loc theo Tag
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in _tags) ...[
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text('#${tag.name}'),
                              selected: _selectedTagIds.contains(tag.id),
                              onSelected: (_) => _toggleTag(tag.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Không thể tải danh sách tài liệu',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _hasFilter
                    ? 'Không tìm thấy tài liệu phù hợp'
                    : 'Chưa có tài liệu',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _hasFilter
                    ? 'Thử thay đổi từ khóa, danh mục hoặc Tag.'
                    : 'Nhấn Thêm tài liệu để bắt đầu.',
                textAlign: TextAlign.center,
              ),
              if (_hasFilter) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Xóa bộ lọc'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ContentWidth(
        maxWidth: 1200,
        child: DocumentGrid(
          documents: _documents,
          padding: context.pagePadding.add(const EdgeInsets.only(bottom: 88)),
          physics: const AlwaysScrollableScrollPhysics(),
          onTap: _openDetail,
          onEdit: (document) => _openForm(document),
          onDelete: _deleteDocument,
          onShare: _openShareDialog,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm theo tiêu đề hoặc tên tag...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa tìm kiếm',
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  onClear?.call();
                },
              ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
