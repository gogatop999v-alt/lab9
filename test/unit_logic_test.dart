import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/create_post_controller.dart';
import 'package:post_explorer/presentation/state/posts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_post_api.dart';

DioException _dio(DioExceptionType type, {Object? error}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      error: error,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakePostApi api;
  late PostRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = FakePostApi();
    repo = PostRepository(api: api, cache: PostCache(prefs));
  });

  // ---------------------------------------------------------------- ошибки
  group('AppException.fromDio', () {
    test('таймаут соединения -> RequestTimeoutException', () {
      final e = AppException.fromDio(_dio(DioExceptionType.connectionTimeout));
      expect(e, isA<RequestTimeoutException>());
    });

    test('ошибка соединения -> NoConnectionException с понятным текстом', () {
      final e = AppException.fromDio(_dio(DioExceptionType.connectionError));
      expect(e, isA<NoConnectionException>());
      expect(e.userMessage, contains('Нет подключения'));
    });

    test('404 -> "Данные не найдены.", 403 -> сообщение с кодом', () {
      final ro = RequestOptions(path: '/x');
      DioException http(int c) => DioException(
            requestOptions: ro,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: ro, statusCode: c),
          );
      final e404 = AppException.fromDio(http(404)) as ClientErrorException;
      final e403 = AppException.fromDio(http(403)) as ClientErrorException;
      expect(e404.statusCode, 404);
      expect(e404.userMessage, 'Данные не найдены.');
      expect(e403.userMessage, 'Не удалось выполнить запрос (код 403).');
    });

    test('503 -> ServerErrorException, код есть в сообщении', () {
      final e = AppException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: RequestOptions(path: '/x'), statusCode: 503),
      ));
      expect(e, isA<ServerErrorException>());
      expect(e.userMessage, contains('503'));
    });

    test('FormatException внутри DioException -> ParseException', () {
      final e = AppException.fromDio(
          _dio(DioExceptionType.unknown, error: const FormatException('bad')));
      expect(e, isA<ParseException>());
    });

    test('toString содержит технические детали', () {
      const e = UnknownException(technical: 'secret details');
      expect(e.toString(), contains('secret details'));
      expect(e.userMessage, isNot(contains('secret')));
    });
  });

  // ---------------------------------------------------------------- модели
  group('Модели', () {
    test('Post.copyWith меняет только isLocal', () {
      const p = Post(id: 1, userId: 2, title: 'T', body: 'B');
      final local = p.copyWith(isLocal: true);
      expect(local.isLocal, isTrue);
      expect([local.id, local.userId, local.title, local.body],
          [1, 2, 'T', 'B']);
      expect(p.isLocal, isFalse); // исходный объект не изменился
    });

    test('CreatePostRequest.toJson содержит три поля', () {
      const r = CreatePostRequest(title: 'Hello', body: 'World', userId: 4);
      expect(r.toJson(), {'title': 'Hello', 'body': 'World', 'userId': 4});
    });

    test('Comment: JSON туда и обратно', () {
      final json = {
        'id': 3,
        'postId': 9,
        'name': 'n',
        'email': 'e@e.com',
        'body': 'b'
      };
      expect(Comment.fromJson(json).toJson(), json);
    });
  });

  // ------------------------------------------------------------------ кэш
  group('PostCache', () {
    test('записанные посты читаются обратно', () async {
      final cache = PostCache(prefs);
      await cache.writePosts('k', FakePostApi.all.take(3).toList());
      final read = cache.readPosts('k');
      expect(read?.map((p) => p.id), [1, 2, 3]);
    });

    test('отсутствующий ключ -> null, локальные посты -> пустой список', () {
      final cache = PostCache(prefs);
      expect(cache.readPosts('нет'), isNull);
      expect(cache.readLocalPosts(), isEmpty);
    });

    test('повреждённый кэш не роняет приложение (некорректные данные)',
        () async {
      await prefs.setString('cache_broken', 'это не JSON');
      expect(PostCache(prefs).readPosts('broken'), isNull);
    });
  });

  // ------------------------------------------------------ PostsController
  group('PostsController', () {
    test('toggleOrder переключает сортировку и запрашивает desc', () async {
      final c = PostsController(repo);
      await c.loadInitial();
      await c.toggleOrder();
      expect(c.order, SortOrder.desc);
      expect(api.orderCalls.last, 'desc');
      expect(c.visiblePosts.first.id, 30);
    });

    test('после последней страницы hasMore = false, дублей нет', () async {
      final c = PostsController(repo);
      await c.loadInitial();
      for (var i = 0; i < 4; i++) {
        await c.loadMore();
      }
      expect(c.loadedCount, 30);
      expect(c.hasMore, isFalse);
    });

    test('ошибка подгрузки сохраняется, retryLoadMore её исправляет',
        () async {
      final c = PostsController(repo);
      await c.loadInitial();
      api.errorToThrow = httpError(500);
      await c.loadMore();
      expect(c.loadMoreError, isA<ServerErrorException>());
      expect(c.loadedCount, 10); // уже загруженное не пропало

      api.errorToThrow = null;
      await c.retryLoadMore();
      expect(c.loadMoreError, isNull);
      expect(c.loadedCount, 20);
    });

    test('resetFilters сбрасывает автора, сортировку и поиск', () async {
      final c = PostsController(repo);
      await c.loadInitial();
      await c.setUser(2);
      await c.toggleOrder();
      c.setQuery('abc');
      await c.resetFilters();
      expect(c.userId, isNull);
      expect(c.order, SortOrder.asc);
      expect(c.query, isEmpty);
    });

    test('addLocalPost: пост первый в списке, помечен isLocal и сохранён',
        () async {
      final c = PostsController(repo);
      await c.loadInitial();
      await c.addLocalPost(
          const Post(id: 101, userId: 1, title: 'Мой пост', body: 'Текст'));
      expect(c.visiblePosts.first.id, 101);
      expect(c.visiblePosts.first.isLocal, isTrue);

      // новый контроллер (как после перезапуска приложения) видит этот пост
      final restored = PostsController(repo);
      expect(restored.visiblePosts.single.title, 'Мой пост');
    });

    test('поиск по пустой/несуществующей строке', () async {
      final c = PostsController(repo);
      await c.loadInitial();
      c.setQuery('   ');
      expect(c.visiblePosts.length, 10); // пробелы игнорируются
      c.setQuery('zzz-нет-такого');
      expect(c.visiblePosts, isEmpty);
    });
  });

  // ------------------------------------------------ CreatePostController
  group('CreatePostController', () {
    const request =
        CreatePostRequest(title: 'Hello world', body: 'Body text 123', userId: 1);

    test('успешная отправка -> success и созданный пост', () async {
      final c = CreatePostController(repo);
      final post = await c.submit(request);
      expect(c.status, SubmitStatus.success);
      expect(post?.id, 101);
      expect(api.createdRequests.single.userId, 1);
    });

    test('ошибка сервера -> failure, null и сообщение об ошибке', () async {
      api.createError = httpError(500);
      final c = CreatePostController(repo);
      final post = await c.submit(request);
      expect(post, isNull);
      expect(c.status, SubmitStatus.failure);
      expect(c.error, isA<ServerErrorException>());
    });

    test('повторное нажатие во время отправки игнорируется', () async {
      api.createGate = Completer<void>();
      final c = CreatePostController(repo);
      final f1 = c.submit(request);
      final second = await c.submit(request); // сразу, пока первая не завершилась
      expect(second, isNull);
      api.createGate!.complete();
      await f1;
      expect(api.createdRequests.length, 1);
    });
  });
}
