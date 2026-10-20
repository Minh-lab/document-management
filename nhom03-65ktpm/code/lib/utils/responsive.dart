import 'package:flutter/widgets.dart';

/// Breakpoint theo kế hoạch giao diện:
/// compact < 600, medium 600–1024, expanded >= 1024.
enum ScreenSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get windowSize => MediaQuery.sizeOf(this);
  double get screenWidth => windowSize.width;

  ScreenSize get screenSize {
    final width = screenWidth;
    if (width < 600) return ScreenSize.compact;
    if (width < 1024) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;

  /// Chọn giá trị theo breakpoint, medium mặc định bằng compact,
  /// expanded mặc định bằng medium.
  T responsive<T>({required T compact, T? medium, T? expanded}) {
    switch (screenSize) {
      case ScreenSize.compact:
        return compact;
      case ScreenSize.medium:
        return medium ?? compact;
      case ScreenSize.expanded:
        return expanded ?? medium ?? compact;
    }
  }

  EdgeInsets get pagePadding => responsive(
    compact: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    medium: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    expanded: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  );

  /// Số cột lưới tài liệu: 1 / 2 / 3 / 4.
  int get documentGridColumns {
    final width = screenWidth;
    if (width >= 1500) return 4;
    if (width >= 1024) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}

/// Giới hạn chiều rộng nội dung trên màn hình lớn (Web/tablet).
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
