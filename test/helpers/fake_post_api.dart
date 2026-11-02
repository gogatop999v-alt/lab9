import 'dart:async';

import 'package:dio/dio.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/remote/post_api.dart';

/// Поддельный API для тестов (без сети).
/// 30 постов: id 1-10 -> user 1, 11-20 -> user 2, 21-30 -> user 3.
class FakePostApi implements PostApi {
  Object? errorToThrow; // ошибка для getPosts
  Object? createError; // ошибка для createPost
  Object? commentsError; // ошибка для getComments
  Completer<void>? postsGate; // «задержка» ответа getPosts
  Completer<void>? createGate; // «задержка» ответа createPost

  final List<int> pageCalls = [];
  final List<String?> orderCalls = [];
  final List<CreatePostRequest> createdRequests = [];

  static final all = List.generate(
    30,
    (i) => Post(
      id: i + 1,
      userId: i ~/ 10 + 1,
      title: 'Post ${i + 1} title',
      body: 'Body ${i + 1}',
    ),
  );

  @override
  Future<List<Post>> getPosts({
    required int page,
    required int limit,
    int? userId,
    String? sort,
    String? order,
  }) async {
    pageCalls.add(page);
    orderCalls.add(order);
    if (postsGate != null) await postsGate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    var list = all.where((p) => userId == null || p.userId == userId).toList();
    if (order == 'desc') list = list.reversed.toList();
    final start = (page - 1) * limit;
    if (start >= list.length) return [];
    final end = (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  @override
  Future<Post> getPost(int id) async => all[id - 1];

  @override
  Future<List<Post>> getPostsByUser(int userId) async =>
      all.where((p) => p.userId == userId).toList();

  @override
  Future<List<Comment>> getComments(int postId) async {
    if (commentsError != null) throw commentsError!;
    return [
      Comment(
        id: 1,
        postId: postId,
        name: 'Первый комментарий',
        email: 'a@b.com',
        body: 'Текст комментария',
      ),
    ];
  }

  @override
  Future<Post> createPost(CreatePostRequest request) async {
    if (createGate != null) await createGate!.future;
    if (createError != null) throw createError!;
    createdRequests.add(request);
    return Post(
      id: 101,
      userId: request.userId,
      title: request.title,
      body: request.body,
    );
  }

  @override
  Future<List<User>> getUsers() async => List.generate(
        3,
        (i) => User(id: i + 1, name: 'User ${i + 1}', username: 'user${i + 1}'),
      );

  @override
  Future<User> getUser(int id) async =>
      User(id: id, name: 'User $id', username: 'user$id');
}

/// Ошибка HTTP с нужным кодом.
DioException httpError(int code) {
  final ro = RequestOptions(path: '/posts');
  return DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: ro, statusCode: code),
  );
}
