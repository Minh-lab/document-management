import 'package:flutter/material.dart';

import '../services/tag_service.dart';
import '../struct/tag_model.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  final TagService _service = TagService();
  List<TagModel> _tags = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getTags();
      if (!mounted) return;
      setState(() {
        _tags = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editTag({TagModel? tag}) async {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final colorController = TextEditingController(
      text: tag?.color ?? '#2196F3',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? 'Thêm Tag' : 'Sửa Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên Tag',
                hintText: 'Ví dụ: Flutter',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(
                labelText: 'Mã màu',
                hintText: '#2196F3',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == true) {
      var color = colorController.text.trim();
      if (color.isNotEmpty && !color.startsWith('#')) {
        color = '#$color';
      }

      try {
        if (tag == null) {
          await _service.createTag(
            name: nameController.text.trim(),
            color: color.isEmpty ? null : color,
          );
        } else {
          await _service.updateTag(
            id: tag.id,
            name: nameController.text.trim(),
            color: color.isEmpty ? null : color,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tag == null ? 'Đã thêm Tag' : 'Đã sửa Tag')),
          );
          await _loadTags();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }

    nameController.dispose();
    colorController.dispose();
  }

  Future<void> _deleteTag(TagModel tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa Tag'),
        content: Text('Bạn muốn xóa "${tag.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteTag(tag.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa Tag')));
      await _loadTags();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không xóa được Tag: $e')));
      }
    }
  }

  Color _tagColor(TagModel tag) {
    final value = tag.color?.trim().replaceFirst('#', '');
    if (value == null || (value.length != 6 && value.length != 8)) {
      return Colors.blue;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return Colors.blue;
    return Color(value.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tag')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lỗi tải Tag: $_error'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loadTags,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : _tags.isEmpty
          ? const Center(child: Text('Chưa có Tag nào'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _tagColor(tag),
                      child: const Icon(
                        Icons.sell_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(tag.name),
                    subtitle: Text(
                      'ID: ${tag.id} | Màu: ${tag.color ?? "Mặc định"}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTag(tag: tag);
                        } else if (value == 'delete') {
                          _deleteTag(tag);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTag(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm Tag'),
      ),
    );
  }
}
