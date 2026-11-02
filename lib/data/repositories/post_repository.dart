import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../local/post_cache.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../remote/post_api.dart';

enum SortOrder { asc, desc }

/// Единственная точка доступа UI к данным: сеть + кэш + преобразование ошибок.
class PostRepository {
  PostRepository({
    required PostApi api,
    required PostCache cache,
    this.pageSize = 10,
  })  : _api = api,
        _cache = cache;

  final PostApi _api;
  final PostCache _cache;
  final int pageSize;

  static String _key(int? userId, SortOrder order) =>
      'posts_${userId ?? 'all'}_${order.name}';

  List<Post>? cachedFirstPage(int? userId, SortOrder order) =>
      _cache.readPosts(_key(userId, order));

  Future<List<Post>> fetchPosts({
    required int page,
    int? userId,
    SortOrder order = SortOrder.asc,
  }) async {
    final posts = await _guard(() => _api.getPosts(
          page: page,
          limit: pageSize,
          userId: userId,
          sort: 'id',
          order: order.name,
        ));
    if (page == 1) {
      await _cache.writePosts(_key(userId, order), posts);
    }
    return posts;
  }

  Future<Post> fetchPost(int id) => _guard(() => _api.getPost(id));

  Future<List<Post>> fetchPostsByUser(int userId) =>
      _guard(() => _api.getPostsByUser(userId));

  Future<List<Comment>> fetchComments(int postId) =>
      _guard(() => _api.getComments(postId));

  Future<List<User>> fetchUsers() => _guard(() => _api.getUsers());

  Future<User> fetchUser(int id) => _guard(() => _api.getUser(id));

  Future<Post> createPost(CreatePostRequest request) =>
      _guard(() => _api.createPost(request));

  List<Post> loadLocalPosts() => _cache.readLocalPosts();

  Future<void> saveLocalPosts(List<Post> posts) =>
      _cache.writeLocalPosts(posts);

  /// Превращает любые исключения в [AppException].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      final ex = AppException.fromDio(e);
      debugPrint('[Repository] $ex');
      throw ex;
    } on TypeError catch (e) {
      debugPrint('[Repository] parse error: $e');
      throw ParseException(technical: e.toString());
    } on FormatException catch (e) {
      debugPrint('[Repository] parse error: $e');
      throw ParseException(technical: e.toString());
    } catch (e) {
      debugPrint('[Repository] unknown error: $e');
      throw UnknownException(technical: e.toString());
    }
  }
}
