import 'package:flutter/material.dart';
import '../struct/document_model.dart';
import '../colors.dart';
import 'package:intl/intl.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback? onShare;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          document.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Danh mục: ${document.categoryName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (document.description != null && document.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                document.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(document.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onShare != null)
              IconButton(
                icon: const Icon(Icons.share, color: AppColors.info),
                onPressed: onShare,
                tooltip: 'Chia sẻ',
              ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
