import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử Kiến trúc Cashew (Architecture Tests)', () {
    test('Lớp UI (pages) tuyệt đối không được gọi trực tiếp Database hoặc Drift', () {
      final pagesDir = Directory('lib/pages');
      if (!pagesDir.existsSync()) return;

      final files = pagesDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (var file in files) {
        final content = file.readAsStringSync();
        
        // Kiểm tra UI không import database
        expect(
          content.contains('package:drift/drift.dart'), 
          isFalse,
          reason: 'File ${file.path} vi phạm kiến trúc: Import trực tiếp package drift.',
        );
        
        expect(
          content.contains('database/tables.dart') || content.contains('database/'), 
          isFalse,
          reason: 'File ${file.path} vi phạm kiến trúc: Import trực tiếp thư mục database.',
        );
      }
    });

    test('Lớp UI (widgets) tuyệt đối không được gọi trực tiếp Database hoặc Drift', () {
      final widgetsDir = Directory('lib/widgets');
      if (!widgetsDir.existsSync()) return;

      final files = widgetsDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (var file in files) {
        final content = file.readAsStringSync();
        
        expect(
          content.contains('package:drift/drift.dart'), 
          isFalse,
          reason: 'File ${file.path} vi phạm kiến trúc: Import trực tiếp package drift.',
        );
        
        expect(
          content.contains('database/tables.dart') || content.contains('database/'), 
          isFalse,
          reason: 'File ${file.path} vi phạm kiến trúc: Import trực tiếp thư mục database.',
        );
      }
    });

    test('Lớp Business Logic (functions.dart) phải được tách biệt và giao tiếp với Database', () {
      final functionsFile = File('lib/functions.dart');
      expect(functionsFile.existsSync(), isTrue, reason: 'Phải tồn tại file functions.dart ở thư mục gốc lib/');
      
      final content = functionsFile.readAsStringSync();
      // functions.dart PHẢI có giao tiếp với database
      expect(
        content.contains('database/tables.dart') || content.contains('package:drift/drift.dart'), 
        isTrue,
        reason: 'functions.dart phải là nơi chứa logic tương tác với database.',
      );
    });
  });
}
