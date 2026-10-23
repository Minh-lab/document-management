// Kiểm thử UC-11 – Gợi ý tài liệu (Hạnh):
//   • thuật toán chấm điểm (utils/recommendation_scorer.dart)
//   • khối "Gợi ý cho bạn" (widgets/recommendation_section.dart)

import 'package:code/struct/recommendation_model.dart';
import 'package:code/theme.dart';
import 'package:code/utils/recommendation_scorer.dart';
import 'package:code/widgets/recommendation_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 22);

RecommendationCandidate doc(int id, List<String> tags, {int ageDays = 0, int views = 0}) =>
    RecommendationCandidate(
      id: id,
      title: 'Tài liệu $id',
      categoryName: 'Bài giảng',
      ownerName: 'Đạt',
      createdAt: now.subtract(Duration(days: ageDays)),
      tags: tags,
      viewCount: views,
    );

void main() {
  group('Thành phần điểm (0–1)', () {
    test('tagScore là độ tương đồng cosine', () {
      expect(tagSimilarity({'giai-tich': 1}, ['giai-tich']), closeTo(1, 1e-9));
      expect(tagSimilarity({'giai-tich': 1}, ['giai-tich', 'dai-so']), closeTo(0.7071, 1e-4));
      expect(tagSimilarity({'giai-tich': 1}, ['flutter']), 0);
      expect(tagSimilarity({}, ['flutter']), 0);
    });

    test('recencyScore giảm một nửa sau mỗi 30 ngày', () {
      expect(recencyScore(now, now), closeTo(1, 1e-9));
      expect(recencyScore(now.subtract(const Duration(days: 30)), now), closeTo(0.5, 1e-9));
      expect(recencyScore(now.subtract(const Duration(days: 60)), now), closeTo(0.25, 1e-9));
    });

    test('viewScore chuẩn hóa theo tài liệu xem nhiều nhất', () {
      expect(viewScore(5, 10), 0.5);
      expect(viewScore(0, 0), 0);
    });
  });

  group('Xếp hạng', () {
    test('score = 0.5×tag + 0.3×độ mới + 0.2×lượt xem', () {
      final r = rankRecommendations(
        interests: {'giai-tich': 3},
        candidates: [doc(1, ['giai-tich'], ageDays: 30, views: 4), doc(2, [], views: 8)],
        now: now,
      );
      final first = r.firstWhere((x) => x.document.id == 1);
      expect(first.score, closeTo(0.5 * 1 + 0.3 * 0.5 + 0.2 * 0.5, 1e-9));
    });

    test('tài liệu trùng sở thích xếp trên tài liệu mới nhưng không liên quan', () {
      final r = rankRecommendations(
        interests: {'giai-tich': 3},
        candidates: [doc(1, ['flutter']), doc(2, ['giai-tich'], ageDays: 60)],
        now: now,
      );
      expect(r.map((x) => x.document.id), [2, 1]);
      expect(r.first.reason, 'Vì bạn quan tâm #giai-tich');
      expect(r.last.reason, 'Tài liệu mới');
    });

    test('tối đa 5 gợi ý; không có ứng viên thì trả rỗng (khối gợi ý bị ẩn)', () {
      final many = [for (var i = 0; i < 8; i++) doc(i, ['java'])];
      expect(rankRecommendations(interests: {'java': 1}, candidates: many, now: now), hasLength(5));
      expect(rankRecommendations(interests: {'java': 1}, candidates: [], now: now), isEmpty);
    });

    test('gợi ý thay đổi khi sở thích thay đổi', () {
      final candidates = [doc(1, ['giai-tich']), doc(2, ['flutter'])];
      final a = rankRecommendations(interests: {'giai-tich': 2}, candidates: candidates, now: now);
      final b = rankRecommendations(interests: {'flutter': 2}, candidates: candidates, now: now);
      expect(a.first.document.id, 1);
      expect(b.first.document.id, 2);
    });

    test('cold start: chưa có sở thích thì dùng tag phổ biến', () {
      final r = rankRecommendations(
        interests: {},
        candidates: [doc(1, ['java']), doc(2, ['java']), doc(3, ['flutter'])],
        now: now,
      );
      expect(r.last.document.id, 3);
      expect(r.first.reason, 'Tag phổ biến: #java');
    });

    test('200 tài liệu được chấm điểm dưới 300ms', () {
      final many = [for (var i = 0; i < 200; i++) doc(i, ['tag${i % 10}', 'tag${i % 7}'], ageDays: i, views: i % 13)];
      final sw = Stopwatch()..start();
      rankRecommendations(interests: {'tag1': 3, 'tag2': 1}, candidates: many, now: now);
      expect(sw.elapsedMilliseconds, lessThan(300));
    });
  });

  group('Khối "Gợi ý cho bạn"', () {
    Future<void> pump(WidgetTester tester, List<RecommendationModel> items) => tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: Scaffold(body: RecommendationSection(items: items))),
        );

    testWidgets('hiển thị tiêu đề, tài liệu và lý do gợi ý', (tester) async {
      final items = rankRecommendations(
        interests: {'giai-tich': 2},
        candidates: [doc(1, ['giai-tich'])],
        now: now,
      );
      await pump(tester, items);
      expect(find.text('Gợi ý cho bạn'), findsOneWidget);
      expect(find.text('Tài liệu 1'), findsOneWidget);
      expect(find.text('Vì bạn quan tâm #giai-tich'), findsOneWidget);
    });

    testWidgets('không có gợi ý thì ẩn hẳn khối', (tester) async {
      await pump(tester, const []);
      expect(find.text('Gợi ý cho bạn'), findsNothing);
    });
  });
}
