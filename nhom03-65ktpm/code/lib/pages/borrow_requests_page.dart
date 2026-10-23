import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../colors.dart';
import '../functions.dart';
import '../struct/borrow_request_model.dart';
import '../struct/document_model.dart';
import '../utils/responsive.dart';
import '../widgets/borrow_request_dialog.dart';
import '../widgets/state_views.dart';
import 'document_detail_page.dart';

class BorrowRequestsPage extends StatefulWidget {
  const BorrowRequestsPage({super.key});

  @override
  State<BorrowRequestsPage> createState() => _BorrowRequestsPageState();
}

class _BorrowRequestsPageState extends State<BorrowRequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<DocumentModel> _availableDocuments = [];
  List<BorrowRequestModel> _myRequests = [];
  List<BorrowRequestModel> _incomingRequests = [];
  bool _loading = true;
  String? _error;
  List<RealtimeChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
    _channels = supabaseService.subscribeToBorrowRequests(
      userId: currentUserId,
      onChanged: () => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    for (final channel in _channels) {
      supabaseService.unsubscribe(channel);
    }
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await expireBorrowRequests();
      final results = await Future.wait([
        getBorrowableDocuments(keyword: _searchController.text),
        getMyBorrowRequests(),
        getIncomingBorrowRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _availableDocuments = results[0] as List<DocumentModel>;
        _myRequests = results[1] as List<BorrowRequestModel>;
        _incomingRequests = results[2] as List<BorrowRequestModel>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _search(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(showLoading: false),
    );
  }

  Future<void> _requestToBorrow(DocumentModel document) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => BorrowRequestDialog(document: document),
    );
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi yêu cầu mượn tài liệu')),
    );
    await _load(showLoading: false);
  }

  Future<void> _respond(BorrowRequestModel request, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askRejectionReason();
      if (reason == null || !mounted) return;
    }
    await _runAction(
      () => respondToBorrowRequest(
        requestId: request.id,
        approve: approve,
        reason: reason,
      ),
      approve ? 'Đã duyệt yêu cầu mượn' : 'Đã từ chối yêu cầu mượn',
    );
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Lý do (không bắt buộc)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể thực hiện thao tác: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Có thể mượn'),
                Tab(text: 'Yêu cầu của tôi'),
                Tab(text: 'Chờ duyệt'),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const AppLoadingView(message: 'Đang tải yêu cầu mượn...');
    }
    if (_error != null) {
      return AppErrorView(
        title: 'Không tải được yêu cầu mượn',
        message: _error!,
        onRetry: _load,
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCatalog(),
        _buildRequestList(_myRequests, incoming: false),
        _buildRequestList(_incomingRequests, incoming: true),
      ],
    );
  }

  Widget _buildCatalog() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.pagePadding,
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Tìm tài liệu có thể mượn...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: () {
                              _searchController.clear();
                              _load(showLoading: false);
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_availableDocuments.isEmpty)
                  const _EmptyListMessage(
                    message:
                        'Chưa có tài liệu nào được chủ sở hữu cho phép mượn.',
                  )
                else
                  for (final document in _availableDocuments)
                    _buildDocumentCard(document),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (document.description?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text(
                document.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _requestToBorrow(document),
                  icon: const Icon(Icons.outbox_outlined, size: 18),
                  label: const Text('Yêu cầu mượn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList(
    List<BorrowRequestModel> requests, {
    required bool incoming,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.pagePadding,
        children: [
          ContentWidth(
            maxWidth: 900,
            child: requests.isEmpty
                ? _EmptyListMessage(
                    message: incoming
                        ? 'Không có yêu cầu nào cần xử lý.'
                        : 'Bạn chưa gửi yêu cầu mượn tài liệu nào.',
                  )
                : Column(
                    children: requests
                        .map(
                          (request) =>
                              _buildRequestCard(request, incoming: incoming),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BorrowRequestModel request, {
    required bool incoming,
  }) {
    final status = request.isOverdue
        ? BorrowRequestStatus.expired
        : request.status;
    final date = DateFormat('dd/MM/yyyy').format(request.dueAt.toLocal());
    final actions = <Widget>[];
    if (incoming && request.status == BorrowRequestStatus.pending) {
      actions.add(
        FilledButton(
          onPressed: () => _respond(request, true),
          child: const Text('Duyệt'),
        ),
      );
      actions.add(
        OutlinedButton(
          onPressed: () => _respond(request, false),
          child: const Text('Từ chối'),
        ),
      );
    } else if (!incoming && request.status == BorrowRequestStatus.pending) {
      actions.add(
        TextButton(
          onPressed: () => _runAction(
            () => cancelBorrowRequest(request.id),
            'Đã hủy yêu cầu mượn',
          ),
          child: const Text('Hủy yêu cầu'),
        ),
      );
    } else if (!incoming &&
        request.status == BorrowRequestStatus.approved &&
        !request.isOverdue) {
      actions.add(
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DocumentDetailPage(documentId: request.documentId),
              ),
            );
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Mở tài liệu'),
        ),
      );
      actions.add(
        FilledButton.tonal(
          onPressed: () => _runAction(
            () => requestBorrowReturn(request.id),
            'Đã báo trả, chờ chủ tài liệu xác nhận',
          ),
          child: const Text('Báo đã trả'),
        ),
      );
    } else if (!incoming &&
        request.status == BorrowRequestStatus.returnRequested) {
      actions.add(
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DocumentDetailPage(documentId: request.documentId),
              ),
            );
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Mở tài liệu'),
        ),
      );
    } else if (incoming &&
        request.status == BorrowRequestStatus.returnRequested) {
      actions.add(
        FilledButton(
          onPressed: () => _runAction(
            () => confirmBorrowReturn(request.id),
            'Đã xác nhận nhận lại tài liệu',
          ),
          child: const Text('Xác nhận đã nhận'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.documentTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (incoming)
              Text('Người mượn: ${request.borrowerName ?? request.borrowerId}')
            else
              Text('Chủ tài liệu: ${request.ownerName ?? request.ownerId}'),
            Text('Hạn trả: $date'),
            if (request.note?.trim().isNotEmpty ?? false)
              Text('Lời nhắn: ${request.note}'),
            if (request.rejectionReason?.trim().isNotEmpty ?? false)
              Text('Lý do từ chối: ${request.rejectionReason}'),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BorrowRequestStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.label),
      backgroundColor: status == BorrowRequestStatus.approved
          ? const Color(0xFFE7F6EC)
          : status == BorrowRequestStatus.rejected ||
                status == BorrowRequestStatus.expired
          ? const Color(0xFFFDECEA)
          : AppColors.primaryLight,
    );
  }
}

class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
