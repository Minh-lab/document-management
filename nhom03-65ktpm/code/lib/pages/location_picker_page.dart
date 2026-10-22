import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../functions.dart';
import '../services/geocoding_service.dart';
import '../widgets/document_location_map.dart';

/// Kết quả trả về từ [LocationPickerPage].
///
/// `null` = người dùng hủy (không thay đổi gì).
class LocationPickerResult {
  const LocationPickerResult._({this.location, required this.deleted});

  const LocationPickerResult.saved(DocumentLocationModel location)
    : this._(location: location, deleted: false);

  const LocationPickerResult.deleted() : this._(deleted: true);

  final DocumentLocationModel? location;
  final bool deleted;
}

/// Mở màn hình chọn vị trí dưới dạng dialog (thay vì điều hướng sang trang mới).
Future<LocationPickerResult?> showLocationPickerDialog(
  BuildContext context, {
  int? documentId,
  DocumentLocationModel? existingLocation,
}) {
  final size = MediaQuery.sizeOf(context);
  final width = size.width > 752 ? 720.0 : size.width - 32;
  final height = (size.height * 0.9).clamp(280.0, 860.0);

  return showDialog<LocationPickerResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: width,
        height: height,
        child: LocationPickerPage(
          documentId: documentId,
          existingLocation: existingLocation,
          embeddedInDialog: true,
        ),
      ),
    ),
  );
}

/// Màn hình chọn / nhập vị trí vật lý của tài liệu (UC-07).
///
/// Hỗ trợ:
/// - Chọn trực tiếp trên bản đồ OpenStreetMap (chạm để đặt marker).
/// - Tìm địa chỉ, lấy vị trí GPS hiện tại.
/// - Tự điền địa chỉ từ tọa độ và vẫn cho phép nhập tay khi mất mạng.
///
/// Màn hình không ghi dữ liệu; nó trả về [LocationPickerResult] để màn hình
/// gọi (form tài liệu / chi tiết tài liệu) lưu vào `document_locations`.
class LocationPickerPage extends StatefulWidget {
  final int? documentId;
  final DocumentLocationModel? existingLocation;
  final bool embeddedInDialog;

  const LocationPickerPage({
    super.key,
    this.documentId,
    this.existingLocation,
    this.embeddedInDialog = false,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _fallbackCenter = LatLng(10.7769, 106.6919); // TP.HCM

  final _placeNameCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();

  LatLng? _marker;
  bool _isFetchingLocation = false;
  bool _isSearching = false;
  bool _isResolvingAddress = false;
  String? _errorMsg;

  int _reverseRequestId = 0;

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
      if (loc.hasCoordinates) {
        _marker = LatLng(loc.latitude!, loc.longitude!);
      }
    }
  }

  @override
  void dispose() {
    _placeNameCtrl.dispose();
    _shelfCtrl.dispose();
    _noteCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  bool _validateCoords() {
    final latText = _latCtrl.text.trim();
    final lngText = _lngCtrl.text.trim();
    if (latText.isEmpty && lngText.isEmpty) return true; // không nhập vẫn OK
    final lat = _parseDouble(latText);
    final lng = _parseDouble(lngText);
    return _isValidCoordinate(lat, lng);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Cập nhật marker khi người dùng sửa trực tiếp ô vĩ độ / kinh độ.
  void _syncMarkerFromFields() {
    final lat = _parseDouble(_latCtrl.text);
    final lng = _parseDouble(_lngCtrl.text);
    if (_isValidCoordinate(lat, lng)) {
      setState(() => _marker = LatLng(lat!, lng!));
    } else if (_latCtrl.text.trim().isEmpty && _lngCtrl.text.trim().isEmpty) {
      setState(() => _marker = null);
    }
  }

  Future<void> _resolveAddress(LatLng point) async {
    final requestId = ++_reverseRequestId;
    setState(() => _isResolvingAddress = true);

    final address = await geocodingService.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );

    if (!mounted || requestId != _reverseRequestId) return;
    setState(() => _isResolvingAddress = false);

    if (address == null) {
      _showMessage('Không lấy được địa chỉ từ bản đồ. Bạn có thể nhập tay.');
      return;
    }
    setState(() => _placeNameCtrl.text = address);
  }

  void _selectPoint(LatLng point, {String? address, bool recenter = true}) {
    setState(() {
      _marker = point;
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
      if (address != null) _placeNameCtrl.text = address;
    });

    if (recenter) {
      try {
        _mapController.move(point, 17);
      } catch (_) {
        // Bản đồ chưa sẵn sàng (ví dụ đang mở màn hình) – bỏ qua.
      }
    }

    if (address == null) {
      _resolveAddress(point);
    }
  }

  Future<void> _searchAddress() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      _showMessage('Vui lòng nhập địa chỉ cần tìm.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    final results = await geocodingService.searchAddress(keyword);
    if (!mounted) return;
    setState(() => _isSearching = false);

    if (results.isEmpty) {
      _showMessage(
        'Không tìm thấy địa chỉ phù hợp. Hãy chạm trực tiếp trên bản đồ.',
      );
      return;
    }

    final selected = await showModalBottomSheet<GeocodingPlace>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Chọn địa chỉ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final place = results[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(place.displayName),
                    onTap: () => Navigator.of(sheetContext).pop(place),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    _selectPoint(
      LatLng(selected.latitude, selected.longitude),
      address: selected.displayName,
    );
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Dịch vụ định vị GPS chưa bật.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Quyền truy cập vị trí bị từ chối.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Quyền truy cập vị trí bị từ chối vĩnh viễn.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      _selectPoint(
        LatLng(position.latitude, position.longitude),
        recenter: true,
      );
    } catch (error) {
      _showMessage('Không lấy được vị trí hiện tại: $error');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _openDirections() async {
    final lat = _parseDouble(_latCtrl.text);
    final lng = _parseDouble(_lngCtrl.text);
    if (!_isValidCoordinate(lat, lng)) {
      _showMessage('Chưa có tọa độ để chỉ đường.');
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
      'travelmode': 'driving',
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showMessage('Không thể mở ứng dụng bản đồ.');
  }

  void _save() {
    if (!_validateCoords()) {
      setState(() {
        _errorMsg = 'Tọa độ không hợp lệ. Vĩ độ: -90 → 90, Kinh độ: -180 → 180';
      });
      return;
    }

    final hasAnyData =
        _placeNameCtrl.text.trim().isNotEmpty ||
        _shelfCtrl.text.trim().isNotEmpty ||
        _noteCtrl.text.trim().isNotEmpty ||
        _latCtrl.text.trim().isNotEmpty;

    if (!hasAnyData) {
      setState(
        () => _errorMsg = 'Vui lòng chọn vị trí trên bản đồ hoặc nhập ít nhất một thông tin vị trí.',
      );
      return;
    }

    final location = DocumentLocationModel(
      id: widget.existingLocation?.id,
      documentId: widget.documentId ?? widget.existingLocation?.documentId ?? 0,
      latitude: _parseDouble(_latCtrl.text),
      longitude: _parseDouble(_lngCtrl.text),
      placeName: _placeNameCtrl.text.trim().isEmpty
          ? null
          : _placeNameCtrl.text.trim(),
      shelf: _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(LocationPickerResult.saved(location));
  }

  Future<void> _clearLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa vị trí'),
        content: const Text(
          'Bạn có chắc muốn xóa thông tin vị trí của tài liệu này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(const LocationPickerResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting =
        widget.existingLocation != null && !widget.existingLocation!.isEmpty;
    final marker = _marker;
    final mapCenter = marker ?? _fallbackCenter;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Bản đồ chọn vị trí ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chọn vị trí trên bản đồ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chạm vào bản đồ để đặt marker, hoặc tìm địa chỉ / dùng GPS.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: InputDecoration(
                      labelText: 'Tìm địa chỉ',
                      hintText: 'Ví dụ: Thư viện trường Đại học Bách Khoa',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Tìm',
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _isSearching ? null : _searchAddress,
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DocumentLocationMap(
                    latitude: mapCenter.latitude,
                    longitude: mapCenter.longitude,
                    height: 280,
                    zoom: marker == null ? 13 : 17,
                    mapController: _mapController,
                    showMarker: marker != null,
                    onTap: (point) => _selectPoint(point, recenter: false),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          marker == null
                              ? 'Chưa chọn điểm nào trên bản đồ.'
                              : 'Đã chọn: ${_latCtrl.text}, ${_lngCtrl.text}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_isResolvingAddress)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isFetchingLocation
                            ? null
                            : _fetchCurrentLocation,
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_outlined, size: 18),
                        label: const Text('Vị trí hiện tại'),
                      ),
                      if (marker != null)
                        TextButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.navigation_outlined, size: 18),
                          label: const Text('Chỉ đường'),
                        ),
                      if (marker != null)
                        TextButton.icon(
                          onPressed: () {
                            _reverseRequestId++;
                            setState(() {
                              _marker = null;
                              _latCtrl.clear();
                              _lngCtrl.clear();
                              _isResolvingAddress = false;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Bỏ chọn điểm'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Thông tin mô tả (luôn khả dụng – 7a) ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Địa chỉ & mô tả vị trí',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _placeNameCtrl,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ / tên địa điểm',
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

          // --- Tọa độ (vẫn cho nhập tay khi mất mạng) ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tọa độ',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tự động điền khi chọn trên bản đồ. Có thể nhập tay nếu cần.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          onChanged: (_) => _syncMarkerFromFields(),
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
                            decimal: true,
                            signed: true,
                          ),
                          onChanged: (_) => _syncMarkerFromFields(),
                          decoration: const InputDecoration(
                            labelText: 'Kinh độ (Longitude)',
                            hintText: '106.6919',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
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
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu vị trí'),
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
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nếu không có mạng hoặc không có GPS, bạn vẫn có thể lưu bằng cách '
                    'mô tả vị trí bằng văn bản. Tọa độ chỉ cần thiết nếu muốn dùng '
                    'tính năng chỉ đường trên bản đồ.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embeddedInDialog) {
      return Column(
        children: [
          _buildDialogHeader(context, hasExisting),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vị trí tài liệu'),
        actions: [
          if (hasExisting)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Xóa vị trí',
              onPressed: _clearLocation,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildDialogHeader(BuildContext context, bool hasExisting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Vị trí tài liệu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (hasExisting)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Xóa vị trí',
              onPressed: _clearLocation,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
