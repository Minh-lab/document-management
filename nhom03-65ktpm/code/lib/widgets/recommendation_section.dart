import 'package:flutter/material.dart';

import '../colors.dart';
import '../struct/recommendation_model.dart';
import '../utils/responsive.dart';

/// Khối "Gợi ý cho bạn" ở trang chủ (UC-11). Không có gợi ý thì ẩn hẳn (ngoại lệ 11b).
class RecommendationSection extends StatelessWidget {
  const RecommendationSection({super.key, required this.items, this.onTap});

  final List<RecommendationModel> items;
  final ValueChanged<RecommendationModel>? onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = context.responsive<double>(compact: 240, medium: 260, expanded: 280);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Gợi ý cho bạn',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: cardWidth,
              child: _RecommendationCard(item: items[i], onTap: onTap),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item, this.onTap});

  final RecommendationModel item;
  final ValueChanged<RecommendationModel>? onTap;

  @override
  Widget build(BuildContext context) {
    final doc = item.document;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${doc.categoryName} · ${doc.ownerName.isEmpty ? 'người khác' : doc.ownerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
