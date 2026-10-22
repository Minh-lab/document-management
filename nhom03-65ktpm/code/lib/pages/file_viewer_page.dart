import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../functions.dart';
import '../services/file_download_service.dart';
import '../services/file_opener.dart';
import '../struct/document_model.dart';
import '../widgets/state_views.dart';

/// Trang xem tài liệu trực tiếp trong ứng dụng (PDF, ảnh, văn bản).
class FileViewerPage extends StatefulWidget {
  const FileViewerPage({
    super.key,
    required this.document,
    this.initialUrl,
  });

  final DocumentModel document;

  /// URL đã được xác thực (signed URL) nếu nơi gọi đã chuẩn bị sẵn.
  final String? initialUrl;

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

enum _ViewerKind { pdf, image, text, unsupported }

class _FileViewerPageState extends State<FileViewerPage> {
  final _downloadService = FileDownloadService();

  bool _isLoading = true;
  String? _error;
  Uint8List? _bytes;
  String? _resolvedUrl;
  _ViewerKind _kind = _ViewerKind.unsupported;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _progress = 0;
    });

    try {
      final url = await _resolveUrl();
      if (url == null || url.isEmpty) {
        throw Exception('Tài liệu này không có tệp đính kèm');
      }
      _resolvedUrl = url;

      final kind = _detectKind(url);
      final bytes = await _downloadService.download(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _kind = kind;
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

  Future<String?> _resolveUrl() async {
    final document = widget.document;
    final storagePath = document.storagePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      final signed = await storageService.getSignedUrl(storagePath);
      if (signed != null && signed.isNotEmpty) return signed;
    }
    return widget.initialUrl ?? document.openUrl;
  }

  _ViewerKind _detectKind(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return _ViewerKind.pdf;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
        return _ViewerKind.image;
      case 'txt':
      case 'md':
      case 'csv':
      case 'json':
      case 'xml':
      case 'log':
      case 'yaml':
      case 'yml':
        return _ViewerKind.text;
      default:
        return _ViewerKind.unsupported;
    }
  }

  String get _fileName {
    final url = _resolvedUrl ?? widget.document.openUrl ?? '';
    final path = Uri.tryParse(url)?.path ?? '';
    final name = path.split('/').last;
    if (name.isNotEmpty && name.contains('.')) return name;
    return '${widget.document.title}.pdf';
  }

  Future<void> _openExternal() async {
    final bytes = _bytes;
    if (bytes != null) {
      final opened = await openFileBytes(bytes, _fileName);
      if (opened) return;
    }

    final url = _resolvedUrl ?? widget.document.openUrl;
    if (url == null || url.isEmpty) return;
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở tệp này')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kind == _ViewerKind.pdf || _kind == _ViewerKind.image
          ? const Color(0xFF263238)
          : AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              tooltip: 'Mở bằng ứng dụng khác',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternal,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _progress > 0
                  ? 'Đang tải tài liệu... ${(_progress * 100).round()}%'
                  : 'Đang tải tài liệu...',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: AppColors.background,
        child: AppErrorView(
          title: 'Không thể mở tài liệu',
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const AppEmptyView(
        icon: Icons.insert_drive_file_outlined,
        title: 'Không có nội dung',
        message: 'Tệp đính kèm trống hoặc không đọc được.',
      );
    }

    switch (_kind) {
      case _ViewerKind.pdf:
        return _PdfBytesView(bytes: bytes, sourceName: _fileName);
      case _ViewerKind.image:
        return PhotoView(
          imageProvider: MemoryImage(bytes),
          backgroundDecoration: const BoxDecoration(color: Color(0xFF263238)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          loadingBuilder: (context, event) =>
              const Center(child: CircularProgressIndicator()),
        );
      case _ViewerKind.text:
        return _TextViewer(bytes: bytes);
      case _ViewerKind.unsupported:
        return _UnsupportedView(
          fileName: _fileName,
          onOpenExternal: _openExternal,
        );
    }
  }
}

/// Xem PDF bằng pdfrx (hỗ trợ Android, iOS, Windows, macOS, Linux, Web),
/// có pinch-zoom và điều hướng trang.
class _PdfBytesView extends StatefulWidget {
  const _PdfBytesView({required this.bytes, required this.sourceName});

  final Uint8List bytes;
  final String sourceName;

  @override
  State<_PdfBytesView> createState() => _PdfBytesViewState();
}

class _PdfBytesViewState extends State<_PdfBytesView> {
  final _controller = PdfViewerController();
  int _page = 1;
  int _pagesCount = 0;
  bool _loadFailed = false;

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Container(
        color: AppColors.background,
        child: const AppErrorView(
          title: 'Không thể hiển thị PDF',
          message: 'Tệp PDF có thể bị hỏng hoặc không được hỗ trợ.',
        ),
      );
    }

    return Stack(
      children: [
        PdfViewer.data(
          widget.bytes,
          sourceName: widget.sourceName,
          controller: _controller,
          params: PdfViewerParams(
            backgroundColor: const Color(0xFF263238),
            margin: 8,
            onViewerReady: (document, controller) {
              if (mounted) {
                setState(() => _pagesCount = controller.pageCount);
              }
            },
            onPageChanged: (page) {
              if (mounted && page != null) setState(() => _page = page);
            },
            onDocumentLoadFinished: (ref, succeeded) {
              if (mounted && !succeeded) {
                setState(() => _loadFailed = true);
              }
            },
          ),
        ),
        if (_pagesCount > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_page / $_pagesCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Xem tệp văn bản thuần (txt, md, csv, json...).
class _TextViewer extends StatelessWidget {
  const _TextViewer({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = '(Không thể đọc nội dung văn bản)';
    }

    return Container(
      color: AppColors.background,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            content,
            style: const TextStyle(
              height: 1.55,
              fontSize: 14,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

/// Định dạng chưa hỗ trợ xem trực tiếp (docx, xlsx, pptx...).
class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({
    required this.fileName,
    required this.onOpenExternal,
  });

  final String fileName;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Định dạng này chưa hỗ trợ xem trực tiếp trong ứng dụng. '
                'Bạn có thể mở bằng ứng dụng khác trên thiết bị.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Mở bằng ứng dụng khác'),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 10),
                const Text(
                  'Trên web, tệp sẽ được mở trong tab mới.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
