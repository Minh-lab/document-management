import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../functions.dart';
import '../colors.dart';
import '../widgets/document_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_component.dart';
import '../widgets/share_dialog.dart';
import 'document_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  List<DocumentModel> _documents = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      // Sync user profile first
      await syncCurrentUser();
      
      await Future.wait([
        _loadCategories(),
        _loadDocuments(),
      ]);
      if (mounted) {
        setState(() {
          _error = null;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading data: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      rethrow;
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await getDocuments(
        keyword: _searchController.text,
        categoryId: _selectedCategoryId,
      );
      if (mounted) {
        setState(() {
          _documents = docs;
        });
      }
    } catch (e) {
      debugPrint('Error loading documents: $e');
      rethrow;
    }
  }

  void _setupRealtime() {
    _realtimeChannel = supabaseService.subscribeToDocuments(
      userId: currentUserId,
      onDocumentsChanged: (documents) {
        if (mounted) {
          setState(() {
            _documents = documents;
          });
        }
      },
    );
  }

  Future<void> _deleteDocument(int id, String? storagePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDialog(
        title: 'Xóa tài liệu',
        content: 'Bạn có chắc chắn muốn xóa tài liệu này không?',
      ),
    );

    if (confirm == true) {
      await deleteDocument(id, storagePath: storagePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tài liệu')),
        );
      }
    }
  }

  Future<void> _openDocument(DocumentModel doc) async {
    final url = doc.openUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu này không có file đính kèm')),
      );
      return;
    }
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở file này')),
        );
      }
    }
  }

  void _navigateToForm([DocumentModel? document]) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentFormPage(document: document),
      ),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  void _showShareDialog(DocumentModel document) {
    // Mở dialog ngay lập tức để UI hiện ra khi bấm nút chia sẻ.
    // Danh sách người đã chia sẻ sẽ được tải bên trong dialog.
    showDialog(
      context: context,
      builder: (context) => ShareDialog(
        documentId: document.id,
        documentTitle: document.title,
        onShareChanged: () {
          // Reload documents to update any UI indicators
          _loadDocuments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tài liệu Học tập'),
        backgroundColor: AppColors.primary,
        actions: [
          StreamBuilder<firebase_auth.User?>(
            stream: authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final user = snapshot.data!;
                return PopupMenuButton<String>(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundImage: user.photoURL != null 
                        ? NetworkImage(user.photoURL!) 
                        : null,
                    child: user.photoURL == null 
                        ? Text(user.displayName?.isNotEmpty == true 
                            ? user.displayName![0].toUpperCase() 
                            : user.email?[0].toUpperCase() ?? 'U')
                        : null,
                  ),
                  onSelected: (value) async {
                    if (value == 'signout') {
                      await signOut();
                    } else if (value == 'profile') {
                      // TODO: Show profile dialog
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoURL != null 
                              ? NetworkImage(user.photoURL!) 
                              : null,
                          child: user.photoURL == null 
                              ? Text(user.displayName?.isNotEmpty == true 
                                  ? user.displayName![0].toUpperCase() 
                                  : user.email?[0].toUpperCase() ?? 'U')
                              : null,
                        ),
                        title: Text(user.displayName ?? 'Người dùng'),
                        subtitle: Text(user.email ?? ''),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'signout',
                      child: const ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Đăng xuất'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: () async {
                    await signInWithGoogle();
                  },
                  icon: const Icon(Icons.login, color: Colors.white, size: 20),
                  label: const Text('Đăng nhập Google', style: TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tài liệu...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (_) => _loadDocuments(),
            ),
          ),
          if (_categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _selectedCategoryId == null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryId = null;
                          });
                          _loadDocuments();
                        }
                      },
                    ),
                  ),
                  ..._categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: _selectedCategoryId == category.id,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryId = selected ? category.id : null;
                          });
                          _loadDocuments();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Lỗi tải dữ liệu',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _initData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _documents.isEmpty
                        ? const EmptyComponent(message: 'Không tìm thấy tài liệu nào')
                        : ListView.builder(
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              final doc = _documents[index];
                              return DocumentCard(
                                document: doc,
                                onEdit: () => _navigateToForm(doc),
                                onDelete: () => _deleteDocument(doc.id, doc.storagePath),
                                onTap: () => _openDocument(doc),
                                onShare: () => _showShareDialog(doc),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}