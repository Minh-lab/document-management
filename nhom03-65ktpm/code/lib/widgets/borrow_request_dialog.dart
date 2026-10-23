import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../functions.dart';
import '../struct/document_model.dart';

class BorrowRequestDialog extends StatefulWidget {
  const BorrowRequestDialog({super.key, required this.document});

  final DocumentModel document;

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  final _noteController = TextEditingController();
  late DateTime _dueAt;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dueAt = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _chooseDueDate() async {
    final now = DateTime.now();
    final dueAt = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year, now.month, now.day + 364),
      helpText: 'Chọn ngày dự kiến trả',
    );
    if (dueAt != null) setState(() => _dueAt = dueAt);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await createBorrowRequest(
        documentId: widget.document.id,
        note: _noteController.text.trim(),
        dueAt: DateTime(_dueAt.year, _dueAt.month, _dueAt.day, 23, 59),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yêu cầu mượn tài liệu'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.document.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Lời nhắn (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _chooseDueDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                'Dự kiến trả: ${DateFormat('dd/MM/yyyy').format(_dueAt)}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}
