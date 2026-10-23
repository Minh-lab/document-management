import 'package:flutter_test/flutter_test.dart';
import 'package:code/struct/borrow_request_model.dart';

void main() {
  group('BorrowRequestModel', () {
    test('parses request participants and the database status', () {
      final request = BorrowRequestModel.fromJson({
        'id': 4,
        'document_id': 9,
        'documents': {'title': 'Bài giảng'},
        'borrower_id': 'borrower-1',
        'owner_id': 'owner-1',
        'borrower': {'display_name': 'Bạn mượn'},
        'owner': {'display_name': 'Chủ tài liệu'},
        'status': 'return_requested',
        'due_at': '2026-11-01T00:00:00.000Z',
        'created_at': '2026-10-20T00:00:00.000Z',
      });

      expect(request.documentTitle, 'Bài giảng');
      expect(request.borrowerName, 'Bạn mượn');
      expect(request.ownerName, 'Chủ tài liệu');
      expect(request.status, BorrowRequestStatus.returnRequested);
    });

    test('rejects unknown database statuses', () {
      expect(
        () => BorrowRequestStatus.fromValue('invalid'),
        throwsFormatException,
      );
    });
  });
}
