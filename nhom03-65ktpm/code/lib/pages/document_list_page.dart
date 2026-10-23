import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../functions.dart';
import '../services/tag_service.dart';
import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../struct/permission_model.dart';
import '../struct/tag_model.dart';
import '../utils/responsive.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/document_grid.dart';
import '../widgets/share_dialog.dart';
import '../widgets/state_views.dart';
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
  List<DocumentModel> _documents = [];
  List<DocumentModel> _sharedDocuments = [];
  Map<int, PermissionRole> _sharedRoles = {};
  Set<int> _sharedTagDocumentIds = {};
  List<CategoryModel> _categories = [];
  List<TagModel> _tags = [];
  int? _selectedCategoryId;
  final Set<int> _selectedTagIds = {};
  bool _showShared = false;
  bool _isLoading = true;
  bool _isLoadingShared = false;
  String? _error;
  String? _sharedError;
  RealtimeChannel? _realtimeChannel;

  bool get _hasFilter =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _selectedTagIds.isNotEmpty;

  /// Tài liệu được chia sẻ sau khi áp dụng tìm kiếm/lọc phía client.
  List<DocumentModel> get _filteredSharedDocuments {
    final keyword = _searchController.text.trim().toLowerCase();
    return _sharedDocuments.where((document) {
      final matchesKeyword =
          keyword.isEmpty ||
          document.title.toLowerCase().contains(keyword) ||
          (document.description ?? '').toLowerCase().contains(keyword);
      final matchesCategory =
          _selectedCategoryId == null ||
          document.categoryId == _selectedCategoryId;
      final matchesTags =
          _selectedTagIds.isEmpty ||
          _sharedTagDocumentIds.contains(document.id);
      return matchesKeyword && matchesCategory && matchesTags;
    }).toList();
  }

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

  Future<void> _loadShared({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingShared = true;
        _sharedError = null;
      });
    }

    try {
      final results = await Future.wait([
        getSharedWithMe(),
        getSharedDocumentRoles(),
      ]);
      final documents = results[0] as List<DocumentModel>;
      final roles = results[1] as Map<int, PermissionRole>;
      final tagDocumentIds = _selectedTagIds.isEmpty
          ? <int>{}
          : await _tagService.getDocumentIdsForTags(_selectedTagIds);
      if (!mounted) return;
      setState(() {
        _sharedDocuments = documents;
        _sharedRoles = roles;
        _sharedTagDocumentIds = tagDocumentIds.toSet();
        _isLoadingShared = false;
        _sharedError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingShared = false;
        _sharedError = error.toString().replaceFirst('Exception: ', '');
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
    if (_showShared) return;
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

    if (!_showShared) _load();
  }

  void _toggleTag(int tagId) {
    setState(() {
      if (!_selectedTagIds.add(tagId)) {
        _selectedTagIds.remove(tagId);
      }
    });

    if (_showShared) {
      _loadShared(showLoading: false);
    } else {
      _load();
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategoryId = null;
      _selectedTagIds.clear();
    });
    if (!_showShared) _load();
  }

  Future<void> _openDetail(DocumentModel document) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(documentId: document.id),
      ),
    );
    if (changed != false) {
      if (_showShared) {
        _loadShared(showLoading: false);
      } else {
        _load(showLoading: false);
      }
    }
  }

  void _switchTab(bool showShared) {
    if (_showShared == showShared) return;
    setState(() => _showShared = showShared);
    if (showShared) _loadShared();
  }

  Future<void> _openForm([DocumentModel? document]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentFormPage(document: document)),
    );
    if (changed == false) return;
    if (_showShared) {
      _loadShared(showLoading: false);
    } else {
      _load(showLoading: false);
    }
  }

  Future<void> _openTagManagement() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TagManagementPage()));
    if (!mounted) return;
    if (_showShared) {
      await _loadShared(showLoading: false);
    } else {
      await _load(showLoading: false);
    }
  }

  Future<void> _deleteDocument(DocumentModel document) async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập để xóa')));
      return;
    }
    final permission = await getUserPermission(document.id);
    if (permission != PermissionRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ chủ sở hữu tài liệu mới có quyền xóa'),
        ),
      );
      return;
    }

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

  Future<void> _openShareDialog(DocumentModel document) async {
    final permission = await getUserPermission(document.id);
    if (!mounted) return;
    if (permission != PermissionRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ chủ sở hữu tài liệu mới có quyền chia sẻ'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => ShareDialog(
        documentId: document.id,
        documentTitle: document.title,
        onShareChanged: () => _load(showLoading: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _showShared
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
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
                  _buildTabSelector(),
                  const SizedBox(height: 12),
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

  Widget _buildTabSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.folder_outlined, size: 18),
            label: Text('Của tôi'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.people_outline, size: 18),
            label: Text('Được chia sẻ'),
          ),
        ],
        selected: {_showShared},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _switchTab(selection.first),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_showShared) {
      if (_isLoadingShared && _sharedDocuments.isEmpty) {
        return const AppLoadingView(
          message: 'Đang tải tài liệu được chia sẻ...',
        );
      }
      return RefreshIndicator(
        onRefresh: () => _loadShared(showLoading: false),
        child: _buildSharedContent(context),
      );
    }

    if (_isLoading) {
      return const AppLoadingView(message: 'Đang tải tài liệu...');
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: _buildContent(context),
    );
  }

  Widget _buildSharedContent(BuildContext context) {
    if (_sharedError != null) {
      return AppErrorView(
        title: 'Không tải được tài liệu được chia sẻ',
        message: _sharedError!,
        onRetry: _loadShared,
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    final documents = _filteredSharedDocuments;
    if (documents.isEmpty) {
      return AppEmptyView(
        icon: _hasFilter ? Icons.search_off : Icons.people_outline,
        title: _hasFilter
            ? 'Không tìm thấy tài liệu được chia sẻ phù hợp'
            : 'Chưa có tài liệu được chia sẻ',
        message: _hasFilter ? 'Thử từ khóa khác hoặc bỏ bộ lọc hiện tại.' : 'Khi chủ tài liệu chia sẻ quyền xem hoặc chỉnh sửa, tài liệu sẽ xuất hiện tại đây.',
        actionLabel: _hasFilter ? 'Xóa bộ lọc' : null,
        onAction: _hasFilter ? _clearFilters : null,
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    return ContentWidth(
      maxWidth: 1200,
      child: DocumentGrid(
        documents: documents,
        padding: context.pagePadding.add(const EdgeInsets.only(bottom: 24)),
        physics: const AlwaysScrollableScrollPhysics(),
        onTap: _openDetail,
        onEdit: (document) {
          final role = _sharedRoles[document.id];
          if (role == PermissionRole.editor) {
            _openForm(document);
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_error != null) {
      return AppErrorView(
        title: 'Không tải được danh sách',
        message: _error!,
        onRetry: _load,
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    if (_documents.isEmpty) {
      return AppEmptyView(
        icon: _hasFilter ? Icons.search_off : Icons.folder_open,
        title: _hasFilter
            ? 'Không tìm thấy tài liệu phù hợp'
            : 'Bạn chưa có tài liệu nào',
        message: _hasFilter
            ? 'Thử từ khóa khác hoặc bỏ bộ lọc hiện tại.'
            : 'Nhấn "Thêm" để tạo tài liệu đầu tiên của bạn.',
        actionLabel: _hasFilter ? 'Xóa bộ lọc' : 'Thêm tài liệu',
        onAction: _hasFilter ? _clearFilters : () => _openForm(),
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    return ContentWidth(
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
