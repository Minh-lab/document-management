import 'package:supabase_flutter/supabase_flutter.dart';

import '../struct/tag_model.dart';

class TagService {
  final SupabaseClient _client = Supabase.instance.client;

  // Lay danh sach Tag
  Future<List<TagModel>> getTags() async {
    final data = await _client
        .from('tags')
        .select('id, name, color')
        .order('name');

    return (data as List)
        .map((item) => TagModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Them Tag moi
  Future<TagModel> createTag({required String name, String? color}) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Tên Tag không được để trống.');
    }

    try {
      final data = await _client
          .from('tags')
          .insert({'name': normalizedName, 'color': color})
          .select('id, name, color')
          .single();

      return TagModel.fromJson(Map<String, dynamic>.from(data));
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;

      final existing = await _client
          .from('tags')
          .select('id, name, color')
          .eq('name', normalizedName)
          .single();
      return TagModel.fromJson(Map<String, dynamic>.from(existing));
    }
  }

  // Sua ten va mau Tag
  Future<TagModel> updateTag({
    required int id,
    required String name,
    String? color,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Tên Tag không được để trống.');
    }

    final data = await _client
        .from('tags')
        .update({'name': normalizedName, 'color': color})
        .eq('id', id)
        .select('id, name, color')
        .single();

    return TagModel.fromJson(Map<String, dynamic>.from(data));
  }

  // Xoa Tag va cac lien ket voi tai lieu
  Future<void> deleteTag(int id) async {
    // Xoa cac lien ket truoc de tranh loi khoa ngoai
    await _client.from('document_tags').delete().eq('tag_id', id);

    // Xoa Tag
    await _client.from('tags').delete().eq('id', id);
  }

  // Lay Tag cua mot tai lieu
  Future<List<TagModel>> getTagsForDocument(int documentId) async {
    final links = await _client
        .from('document_tags')
        .select('tag_id')
        .eq('document_id', documentId);

    final tagIds = (links as List)
        .map((item) => (item['tag_id'] as num).toInt())
        .toList();

    if (tagIds.isEmpty) {
      return [];
    }

    final tags = await _client
        .from('tags')
        .select('id, name, color')
        .filter('id', 'in', '(${tagIds.join(',')})')
        .order('name');

    return (tags as List)
        .map((item) => TagModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Lay ID cac tai lieu co Tag duoc chon
  Future<List<int>> getDocumentIdsForTag(int tagId) async {
    return getDocumentIdsForTags([tagId]);
  }

  // Search tag names and return documents linked to any matching tag.
  Future<List<int>> searchDocumentIdsByTagName(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final matchingTags = await _client
        .from('tags')
        .select('id')
        .ilike('name', '%$normalizedQuery%');
    final tagIds = (matchingTags as List)
        .map((item) => (item['id'] as num).toInt())
        .toList();

    return getDocumentIdsForTags(tagIds);
  }

  Future<List<int>> getDocumentIdsForTags(Iterable<int> tagIds) async {
    final uniqueTagIds = tagIds.toSet().toList();
    if (uniqueTagIds.isEmpty) return [];

    final data = await _client
        .from('document_tags')
        .select('document_id')
        .filter('tag_id', 'in', '(${uniqueTagIds.join(',')})');

    return (data as List)
        .map((item) => (item['document_id'] as num).toInt())
        .toList();
  }

  // Gan danh sach Tag cho tai lieu
  Future<void> setDocumentTags({
    required int documentId,
    required List<int> tagIds,
  }) async {
    final uniqueTagIds = tagIds.toSet().toList();
    final currentLinks = await _client
        .from('document_tags')
        .select('tag_id')
        .eq('document_id', documentId);
    final currentTagIds = (currentLinks as List)
        .map((item) => (item['tag_id'] as num).toInt())
        .toSet();

    final tagsToAdd = uniqueTagIds
        .where((tagId) => !currentTagIds.contains(tagId))
        .toList();
    if (tagsToAdd.isNotEmpty) {
      await _client
          .from('document_tags')
          .insert(
            tagsToAdd.map((tagId) {
              return {'document_id': documentId, 'tag_id': tagId};
            }).toList(),
          );
    }

    final tagsToRemove = currentTagIds
        .difference(uniqueTagIds.toSet())
        .toList();
    if (tagsToRemove.isNotEmpty) {
      await _client
          .from('document_tags')
          .delete()
          .eq('document_id', documentId)
          .filter('tag_id', 'in', '(${tagsToRemove.join(',')})');
    }
  }
}
