import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../colors.dart';

/// Bản đồ OpenStreetMap hiển thị vị trí tài liệu.
///
/// - [interactive] = true: người dùng có thể kéo/phóng và chạm để chọn vị trí.
/// - [interactive] = false: chỉ hiển thị marker (dùng ở trang chi tiết).
class DocumentLocationMap extends StatelessWidget {
  const DocumentLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 220,
    this.zoom = 16,
    this.interactive = true,
    this.onTap,
    this.mapController,
    this.showMarker = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final bool interactive;
  final bool showMarker;
  final ValueChanged<LatLng>? onTap;
  final MapController? mapController;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              // Bản đồ tĩnh cần khởi tạo lại khi tọa độ thay đổi; bản đồ
              // tương tác giữ nguyên camera để người dùng không bị "nhảy".
              key: interactive
                  ? null
                  : ValueKey('doc_location_map_$latitude-$longitude-$zoom'),
              mapController: mapController,
              options: MapOptions(
                initialCenter: point,
                initialZoom: zoom,
                minZoom: 3,
                maxZoom: 19,
                backgroundColor: const Color(0xFFE8EEF5),
                interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
                onTap: interactive && onTap != null
                    ? (_, tappedPoint) => onTap!(tappedPoint)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.code',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    if (showMarker)
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 44,
                          color: AppColors.error,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            if (!interactive)
              Positioned(
                right: 8,
                top: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.place,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
