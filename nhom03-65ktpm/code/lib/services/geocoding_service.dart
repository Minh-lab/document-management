import 'dart:convert';

import 'package:http/http.dart' as http;

/// Kết quả tìm kiếm địa chỉ (dùng cho chọn vị trí trên bản đồ).
class GeocodingPlace {
  const GeocodingPlace({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final double latitude;
  final double longitude;
  final String displayName;
}

/// Dịch vụ địa chỉ ngoài (Nominatim / OpenStreetMap).
///
/// Không cần API key. Nếu thiết bị mất mạng hoặc dịch vụ không phản hồi,
/// các hàm trả về `null` / danh sách rỗng để màn hình vẫn hoạt động với
/// tọa độ nhập tay.
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const Duration _timeout = Duration(seconds: 8);
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    // Nominatim yêu cầu User-Agent mô tả ứng dụng.
    'User-Agent': 'CashewStudyDocuments/1.0 (student project)',
  };

  /// Lấy địa chỉ hiển thị từ tọa độ (reverse geocoding).
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/reverse').replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'accept-language': 'vi',
          'zoom': '18',
        },
      );
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final displayName = data['display_name'] as String?;
      if (displayName == null || displayName.trim().isEmpty) return null;
      return displayName.trim();
    } catch (_) {
      return null;
    }
  }

  /// Tìm tọa độ từ chuỗi địa chỉ (forward geocoding).
  Future<List<GeocodingPlace>> searchAddress(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return const [];

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'format': 'jsonv2',
          'q': keyword,
          'accept-language': 'vi',
          'limit': '5',
        },
      );
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body);
      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final lat = double.tryParse('${item['lat']}');
            final lon = double.tryParse('${item['lon']}');
            final name = item['display_name'] as String?;
            if (lat == null || lon == null || name == null) return null;
            return GeocodingPlace(
              latitude: lat,
              longitude: lon,
              displayName: name,
            );
          })
          .whereType<GeocodingPlace>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

final GeocodingService geocodingService = GeocodingService();
