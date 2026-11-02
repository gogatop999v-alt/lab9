import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/posts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 30 постов: id 1-10 -> user 1, 11-20 -> user 2, 21-30 -> user 3.
class FakePostApi implements PostApi {
  Object? errorToThrow;
  Completer<void>? gateForPage2;
  final List<int> pageCalls = [];
  final List<int?> userIdCalls = [];

  static final all = List.generate(
    30,
    (i) => Post(
        id: i + 1,
        userId: i ~/ 10 + 1,
        title: 'Post ${i + 1} title',
        body: 'Body ${i + 1}'),
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
    userIdCalls.add(userId);
    if (errorToThrow != null) throw errorToThrow!;
    if (page == 2 && gateForPage2 != null) await gateForPage2!.future;
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
  Future<List<Comment>> getComments(int postId) async => [];
  @override
  Future<Post> createPost(CreatePostRequest request) async => Post(
      id: 101,
      userId: request.userId,
      title: request.title,
      body: request.body);
  @override
  Future<List<User>> getUsers() async => [];
  @override
  Future<User> getUser(int id) async =>
      User(id: id, name: 'U$id', username: 'u$id');
}

DioException _http(int code) {
  final ro = RequestOptions(path: '/posts');
  return DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: ro, statusCode: code),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePostApi api;
  late PostRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = FakePostApi();
    repo = PostRepository(api: api, cache: PostCache(prefs));
  });

  test('репозиторий успешно загружает посты и сохраняет их в кэш', () async {
    final posts = await repo.fetchPosts(page: 1);
    expect(posts.length, 10);
    expect(posts.first.id, 1);
    expect(repo.cachedFirstPage(null, SortOrder.asc)?.length, 10);
  });

  test('HTTP 500 преобразуется в ServerErrorException', () async {
    api.errorToThrow = _http(500);
    expect(repo.fetchPosts(page: 1), throwsA(isA<ServerErrorException>()));
  });

  test('HTTP 404 -> ClientErrorException, таймаут -> RequestTimeoutException',
      () async {
    api.errorToThrow = _http(404);
    await expectLater(
        repo.fetchPosts(page: 1), throwsA(isA<ClientErrorException>()));
    api.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/posts'),
        type: DioExceptionType.receiveTimeout);
    await expectLater(
        repo.fetchPosts(page: 1), throwsA(isA<RequestTimeoutException>()));
  });

  test('некорректный JSON (TypeError) -> ParseException без падения', () async {
    api.errorToThrow = TypeError();
    expect(repo.fetchPosts(page: 1), throwsA(isA<ParseException>()));
  });

  test('фильтрация по автору и поиск по заголовку', () async {
    final c = PostsController(repo);
    await c.loadInitial();
    expect(c.visiblePosts.length, 10);

    await c.setUser(2);
    expect(api.userIdCalls.last, 2);
    expect(c.visiblePosts.length, 10);
    expect(c.visiblePosts.every((p) => p.userId == 2), isTrue);

    await c.resetFilters();
    c.setQuery('post 7 ');
    expect(c.visiblePosts.map((p) => p.id), [7]);
  });

  test('при ошибке сети кэш не удаляется', () async {
    final c = PostsController(repo);
    await c.loadInitial(); // заполняем кэш
    api.errorToThrow = _http(500);
    await c.loadInitial(); // кэш показан, сервер падает
    expect(c.status, ListStatus.success);
    expect(c.refreshError, isA<ServerErrorException>());
    expect(c.visiblePosts.length, 10);
  });

  test('защита от дублирующейся загрузки одной страницы', () async {
    final c = PostsController(repo);
    await c.loadInitial();

    api.gateForPage2 = Completer<void>();
    final f1 = c.loadMore();
    final f2 = c.loadMore(); // второй вызов должен быть проигнорирован
    api.gateForPage2!.complete();
    await Future.wait([f1, f2]);

    expect(api.pageCalls.where((p) => p == 2).length, 1);
    final ids = c.visiblePosts.map((p) => p.id).toList();
    expect(ids.length, 20);
    expect(ids.toSet().length, 20); // без дубликатов
  });

  test('после смены фильтра старые результаты не смешиваются с новыми',
      () async {
    final c = PostsController(repo);
    await c.loadInitial();
    await c.loadMore();
    expect(c.visiblePosts.length, 20);
    await c.setUser(3);
    expect(c.visiblePosts.every((p) => p.userId == 3), isTrue);
  });
}
