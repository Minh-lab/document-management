import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử Kiến trúc Cashew (Architecture Tests)', () {
    test('Lớp UI (pages) tuyệt đối không được gọi trực tiếp Database hoặc Drift', () {
      final pagesDir = Directory('lib/pages');
      if (!pagesDir.existsSync()) return;

      final files = pagesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (var file in files) {
        final content = file.readAsStringSync();

        // Kiểm tra UI không import database
        expect(
          content.contains('package:drift/drift.dart'),
          isFalse,
          reason:
              'File ${file.path} vi phạm kiến trúc: Import trực tiếp package drift.',
        );

        expect(
          content.contains('database/tables.dart') ||
              content.contains('database/'),
          isFalse,
          reason:
              'File ${file.path} vi phạm kiến trúc: Import trực tiếp thư mục database.',
        );
      }
    });

    test('Lớp UI (widgets) tuyệt đối không được gọi trực tiếp Database hoặc Drift', () {
      final widgetsDir = Directory('lib/widgets');
      if (!widgetsDir.existsSync()) return;

      final files = widgetsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (var file in files) {
        final content = file.readAsStringSync();

        expect(
          content.contains('package:drift/drift.dart'),
          isFalse,
          reason:
              'File ${file.path} vi phạm kiến trúc: Import trực tiếp package drift.',
        );

        expect(
          content.contains('database/tables.dart') ||
              content.contains('database/'),
          isFalse,
          reason:
              'File ${file.path} vi phạm kiến trúc: Import trực tiếp thư mục database.',
        );
      }
    });

    test('Lớp Business Logic (functions.dart) giao tiếp dữ liệu qua service, không dùng Drift', () {
      final functionsFile = File('lib/functions.dart');
      expect(
        functionsFile.existsSync(),
        isTrue,
        reason: 'Phải tồn tại file functions.dart ở thư mục gốc lib/',
      );

      final content = functionsFile.readAsStringSync();

      // Kiến trúc hiện tại: UI -> functions.dart -> Supabase/Firebase service.
      expect(
        content.contains('services/supabase_service.dart'),
        isTrue,
        reason: 'functions.dart phải gọi lớp service dữ liệu (Supabase).',
      );
      expect(
        content.contains('package:drift/drift.dart') ||
            content.contains('database/tables.dart'),
        isFalse,
        reason: 'functions.dart không còn dùng Drift/SQLite cục bộ sau khi chuyển sang Supabase.',
      );
    });
  });
}
