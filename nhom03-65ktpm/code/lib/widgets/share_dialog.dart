import 'package:flutter/material.dart';

import '../functions.dart';
import '../struct/user_model.dart';
import '../struct/permission_model.dart';
import '../colors.dart';

class ShareDialog extends StatefulWidget {
  final int documentId;
  final String documentTitle;
  final List<PermissionModel> existingShares;
  final Function()? onShareChanged;

  const ShareDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.existingShares = const [],
    this.onShareChanged,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  /// Chủ sở hữu không phải là vai trò có thể cấp qua hộp thoại chia sẻ.
  static const List<PermissionRole> _assignableRoles = [
    PermissionRole.viewer,
    PermissionRole.editor,
  ];

  final _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  List<PermissionModel> _currentShares = [];
  bool _isSearching = false;
  bool _isLoading = false;
  bool _isLoadingShares = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentShares = _visibleShares(widget.existingShares);
    _loadShares();
  }

  /// Bản ghi owner thuộc về tài liệu, không hiển thị như một lượt chia sẻ.
  List<PermissionModel> _visibleShares(List<PermissionModel> shares) {
    return shares
        .where((permission) => permission.role != PermissionRole.owner)
        .toList();
  }

  /// Tải danh sách người đã được chia sẻ tài liệu (không chặn việc mở dialog)
  Future<void> _loadShares() async {
    setState(() => _isLoadingShares = true);
    try {
      final shares = await getDocumentShares(widget.documentId);
      if (mounted) {
        setState(() {
          // Bản ghi owner thuộc về tài liệu, không hiển thị như một lượt chia sẻ.
          _currentShares = _visibleShares(shares);
          _isLoadingShares = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingShares = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await searchUsers(query);
      // Lọc bỏ những user đã được chia sẻ
      final sharedUserIds = _currentShares.map((p) => p.userId).toSet();
      final filtered = results
          .where((u) => !sharedUserIds.contains(u.id))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addShare(UserModel user, PermissionRole role) async {
    if (role == PermissionRole.owner) return;
    if (user.id == currentUserId) {
      setState(() {
        _error = 'Không thể chia sẻ tài liệu cho chính mình.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await shareDocument(
        documentId: widget.documentId,
        userId: user.id,
        role: role,
      );

      // Reload shares
      final shares = await getDocumentShares(widget.documentId);
      if (mounted) {
        setState(() {
          _currentShares = _visibleShares(shares);
          _searchResults = [];
          _searchController.clear();
          _isLoading = false;
        });
        widget.onShareChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateShare(
    PermissionModel permission,
    PermissionRole newRole,
  ) async {
    if (newRole == PermissionRole.owner) return;

    setState(() => _isLoading = true);

    try {
      await updateShare(
        documentId: widget.documentId,
        userId: permission.userId,
        role: newRole,
      );

      final shares = await getDocumentShares(widget.documentId);
      if (mounted) {
        setState(() {
          _currentShares = _visibleShares(shares);
          _isLoading = false;
        });
        widget.onShareChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeShare(String userId) async {
    setState(() => _isLoading = true);

    try {
      await removeShare(widget.documentId, userId);

      final shares = await getDocumentShares(widget.documentId);
      if (mounted) {
        setState(() {
          _currentShares = _visibleShares(shares);
          _isLoading = false;
        });
        widget.onShareChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chia sẻ: ${widget.documentTitle}'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm user bằng email hoặc tên...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchUsers,
              onSubmitted: _searchUsers,
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],

            // Search results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Kết quả tìm kiếm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return _buildAddUserTile(user);
                  },
                ),
              ),
            ],

            // Current shares
            if (_isLoadingShares && _currentShares.isEmpty) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ] else if (_currentShares.isNotEmpty) ...[
              if (_searchResults.isNotEmpty) const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Đã chia sẻ:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentShares.length} người',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _currentShares.length,
                  itemBuilder: (context, index) {
                    return _buildShareTile(_currentShares[index]);
                  },
                ),
              ),
            ] else if (!_isSearching && _searchResults.isEmpty) ...[
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Chưa chia sẻ cho ai. Tìm user để chia sẻ.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildAddUserTile(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(user.displayNameOrEmail[0].toUpperCase())
            : null,
      ),
      title: Text(user.displayNameOrEmail),
      subtitle: Text(user.email ?? ''),
      trailing: PopupMenuButton<PermissionRole>(
        onSelected: (role) => _addShare(user, role),
        itemBuilder: (context) => _assignableRoles.map((role) {
          return PopupMenuItem(value: role, child: Text(role.label));
        }).toList(),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Chia sẻ', style: TextStyle(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildShareTile(PermissionModel permission) {
    final user =
        permission.user ??
        UserModel(
          id: permission.userId,
          displayName: permission.userId.substring(0, 8),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(user.displayNameOrEmail[0].toUpperCase())
            : null,
      ),
      title: Text(user.displayNameOrEmail),
      subtitle: Text(user.email ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<PermissionRole>(
            value: permission.role,
            underline: const SizedBox(),
            items: _assignableRoles.map((role) {
              return DropdownMenuItem(value: role, child: Text(role.label));
            }).toList(),
            onChanged: (role) {
              if (role != null && role != permission.role) {
                _updateShare(permission, role);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _removeShare(permission.userId),
            tooltip: 'Xóa chia sẻ',
          ),
        ],
      ),
    );
  }
}
