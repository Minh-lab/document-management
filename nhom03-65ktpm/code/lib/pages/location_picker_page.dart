import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../functions.dart';

/// Màn hình chọn / nhập vị trí vật lý của tài liệu (UC-07).
///
/// Hỗ trợ hai luồng:
/// - 7a: Nhập tên địa điểm / kệ / ghi chú bằng tay (luôn khả dụng).
/// - GPS / ghi tọa độ (tùy chọn – chỉ hoạt động nếu thiết bị có vị trí).
///
/// Trả về [DocumentLocationModel?] khi pop.
class LocationPickerPage extends StatefulWidget {
  final int documentId;
  final DocumentLocationModel? existingLocation;

  const LocationPickerPage({
    super.key,
    required this.documentId,
    this.existingLocation,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _placeNameCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool _isSaving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final loc = widget.existingLocation;
    if (loc != null) {
      _placeNameCtrl.text = loc.placeName ?? '';
      _shelfCtrl.text = loc.shelf ?? '';
      _noteCtrl.text = loc.note ?? '';
      if (loc.latitude != null) _latCtrl.text = loc.latitude!.toString();
      if (loc.longitude != null) _lngCtrl.text = loc.longitude!.toString();
    }
  }

  @override
  void dispose() {
    _placeNameCtrl.dispose();
    _shelfCtrl.dispose();
    _noteCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  bool _validateCoords() {
    final latText = _latCtrl.text.trim();
    final lngText = _lngCtrl.text.trim();
    if (latText.isEmpty && lngText.isEmpty) return true; // không nhập vẫn OK
    final lat = _parseDouble(latText);
    final lng = _parseDouble(lngText);
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_validateCoords()) {
      setState(() => _errorMsg = 'Tọa độ không hợp lệ. Vĩ độ: -90 → 90, Kinh độ: -180 → 180');
      return;
    }

    final hasAnyData = _placeNameCtrl.text.trim().isNotEmpty ||
        _shelfCtrl.text.trim().isNotEmpty ||
        _noteCtrl.text.trim().isNotEmpty ||
        _latCtrl.text.trim().isNotEmpty;

    if (!hasAnyData) {
      setState(() => _errorMsg = 'Vui lòng nhập ít nhất một thông tin vị trí.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final saved = await upsertDocumentLocation(
        documentId: widget.documentId,
        latitude: _parseDouble(_latCtrl.text),
        longitude: _parseDouble(_lngCtrl.text),
        placeName: _placeNameCtrl.text.trim().isEmpty ? null : _placeNameCtrl.text.trim(),
        shelf: _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMsg = 'Lưu vị trí thất bại: $e';
      });
    }
  }

  Future<void> _clearLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa vị trí'),
        content: const Text('Bạn có chắc muốn xóa thông tin vị trí của tài liệu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await deleteDocumentLocation(widget.documentId);
    if (!mounted) return;
    Navigator.of(context).pop(null); // null = đã xóa
  }

  Future<void> _openMapNavigation() async {
    final lat = _parseDouble(_latCtrl.text);
    final lng = _parseDouble(_lngCtrl.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có tọa độ để chỉ đường')),
      );
      return;
    }
    final label = Uri.encodeComponent(_placeNameCtrl.text.trim().isEmpty
        ? 'Vị trí tài liệu'
        : _placeNameCtrl.text.trim());
    // Mở Google Maps (Web + Android)
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng bản đồ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = widget.existingLocation != null &&
        !widget.existingLocation!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vị trí tài liệu'),
        actions: [
          if (hasExisting)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa vị trí',
              onPressed: _isSaving ? null : _clearLocation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Thông tin mô tả (luôn khả dụng – 7a) ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mô tả vị trí',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _placeNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên địa điểm / phòng / khu vực',
                        hintText: 'Ví dụ: Thư viện tầng 3, Phòng A201',
                        prefixIcon: Icon(Icons.place_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shelfCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kệ / ngăn / vị trí cụ thể',
                        hintText: 'Ví dụ: Kệ B, ngăn 3, ô 15',
                        prefixIcon: Icon(Icons.shelves),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú thêm',
                        hintText: 'Ví dụ: Bìa màu xanh, cạnh cửa sổ',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- Tọa độ GPS (tùy chọn) ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tọa độ GPS',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Text(
                            'Tùy chọn',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhập tọa độ thủ công để hỗ trợ chỉ đường.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Vĩ độ (Latitude)',
                              hintText: '10.7769',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Kinh độ (Longitude)',
                              hintText: '106.6919',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _openMapNavigation,
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Xem trên bản đồ'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vị trí'),
              ),
            ),

            const SizedBox(height: 16),

            // Hướng dẫn fallback 7b
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu không có GPS, bạn vẫn có thể lưu bằng cách mô tả vị trí bằng văn bản ở trên. '
                      'Tọa độ chỉ cần thiết nếu muốn dùng tính năng chỉ đường trên bản đồ.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
