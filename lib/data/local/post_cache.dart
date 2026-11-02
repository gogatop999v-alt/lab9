import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';

/// Простой кэш на SharedPreferences: первая страница для каждого
/// сочетания «фильтр + сортировка» и список локально созданных постов.
class PostCache {
  PostCache(this._prefs);

  final SharedPreferences _prefs;
  static const _localKey = 'local_posts';

  List<Post>? readPosts(String key) => _read('cache_$key');

  Future<void> writePosts(String key, List<Post> posts) =>
      _write('cache_$key', posts);

  List<Post> readLocalPosts() => _read(_localKey) ?? [];

  Future<void> writeLocalPosts(List<Post> posts) => _write(_localKey, posts);

  List<Post>? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null; // повреждённый кэш не должен ронять приложение
    }
  }

  Future<void> _write(String key, List<Post> posts) =>
      _prefs.setString(key, jsonEncode(posts.map((p) => p.toJson()).toList()));
}
