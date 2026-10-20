import 'package:flutter/material.dart';

import '../struct/document_model.dart';
import '../utils/responsive.dart';
import 'document_card.dart';

/// Lưới thẻ tài liệu thích ứng: 1 cột (mobile) → 4 cột (web rộng).
class DocumentGrid extends StatelessWidget {
  const DocumentGrid({
    super.key,
    required this.documents,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.maxItems,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
  });

  final List<DocumentModel> documents;
  final void Function(DocumentModel document) onTap;
  final void Function(DocumentModel document)? onEdit;
  final void Function(DocumentModel document)? onDelete;
  final void Function(DocumentModel document)? onShare;
  final int? maxItems;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final items = maxItems == null
        ? documents
        : documents.take(maxItems!).toList();
    final columns = context.documentGridColumns;

    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 190,
      ),
      itemBuilder: (context, index) {
        final document = items[index];
        return DocumentCard(
          document: document,
          onTap: () => onTap(document),
          onEdit: onEdit == null ? null : () => onEdit!(document),
          onDelete: onDelete == null ? null : () => onDelete!(document),
          onShare: onShare == null ? null : () => onShare!(document),
        );
      },
    );
  }
}
