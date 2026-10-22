// Thuật toán gợi ý tài liệu (UC-11) – hàm thuần, không gọi mạng nên kiểm thử được.
//
//   score = 0.5 × tagScore + 0.3 × recencyScore + 0.2 × viewScore   (mỗi thành phần 0–1)
//
//   tagScore     : độ tương đồng cosine giữa sở thích (tag → trọng số) và tập tag của tài liệu
//   recencyScore : 0.5 ^ (số ngày tuổi / 30) – tài liệu 30 ngày tuổi được 0.5
//   viewScore    : lượt xem / lượt xem lớn nhất trong các ứng viên
//
// Người dùng mới (chưa có sở thích – cold start): dùng độ phổ biến của tag thay cho sở thích.

import 'dart:math';

import '../struct/recommendation_model.dart';

const double tagFactor = 0.5;
const double recencyFactor = 0.3;
const double viewFactor = 0.2;
const double recencyHalfLifeDays = 30;

/// Độ tương đồng cosine giữa vector sở thích và tập tag của tài liệu (0–1).
double tagSimilarity(Map<String, double> interests, List<String> tags) {
  if (interests.isEmpty || tags.isEmpty) return 0;
  final norm = sqrt(interests.values.fold<double>(0, (sum, w) => sum + w * w));
  if (norm == 0) return 0;
  final dot = tags.fold<double>(0, (sum, t) => sum + (interests[t] ?? 0));
  return (dot / (norm * sqrt(tags.length))).clamp(0.0, 1.0);
}

/// Độ mới: 1 với tài liệu vừa tạo, 0.5 sau 30 ngày, 0.25 sau 60 ngày.
double recencyScore(DateTime createdAt, DateTime now) {
  final days = max(0, now.difference(createdAt).inHours) / 24;
  return pow(0.5, days / recencyHalfLifeDays).toDouble();
}

/// Lượt xem chuẩn hóa theo tài liệu được xem nhiều nhất (0–1).
double viewScore(int views, int maxViews) => maxViews <= 0 ? 0 : views / maxViews;

/// Cold start: trọng số của tag = số tài liệu ứng viên mang tag đó.
Map<String, double> popularTagWeights(List<RecommendationCandidate> candidates) {
  final weights = <String, double>{};
  for (final c in candidates) {
    for (final t in c.tags) {
      weights[t] = (weights[t] ?? 0) + 1;
    }
  }
  return weights;
}

/// Chấm điểm, xếp hạng và lấy tối đa [limit] gợi ý.
List<RecommendationModel> rankRecommendations({
  required Map<String, double> interests,
  required List<RecommendationCandidate> candidates,
  DateTime? now,
  int limit = 5,
}) {
  if (candidates.isEmpty) return const [];
  final coldStart = interests.isEmpty;
  final weights = coldStart ? popularTagWeights(candidates) : interests;
  final clock = now ?? DateTime.now();
  final maxViews = candidates.fold<int>(0, (m, c) => max(m, c.viewCount));

  final result = [
    for (final c in candidates)
      _score(c, weights, coldStart, recencyScore(c.createdAt, clock), viewScore(c.viewCount, maxViews)),
  ];
  result.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.document.createdAt.compareTo(a.document.createdAt);
  });
  return result.take(limit).toList();
}

RecommendationModel _score(
  RecommendationCandidate c,
  Map<String, double> weights,
  bool coldStart,
  double recency,
  double views,
) {
  final tag = tagSimilarity(weights, c.tags);
  return RecommendationModel(
    document: c,
    score: tagFactor * tag + recencyFactor * recency + viewFactor * views,
    tagScore: tag,
    recencyScore: recency,
    viewScore: views,
    reason: _reason(c, weights, coldStart, views),
  );
}

/// Lý do hiển thị: ưu tiên tag trùng có trọng số cao nhất.
String _reason(RecommendationCandidate c, Map<String, double> weights, bool coldStart, double views) {
  final matched = c.tags.where((t) => (weights[t] ?? 0) > 0).toList()
    ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
  if (matched.isNotEmpty) {
    final top = matched.take(2).map((t) => '#$t').join(', ');
    return coldStart ? 'Tag phổ biến: $top' : 'Vì bạn quan tâm $top';
  }
  if (views >= 0.5) return 'Được xem nhiều';
  return 'Tài liệu mới';
}
