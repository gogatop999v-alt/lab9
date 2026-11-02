import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late DioAdapter adapter;
  late PostRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
    adapter = DioAdapter(dio: dio);
    repo = PostRepository(api: PostApi(dio), cache: PostCache(prefs));
  });

  const request = CreatePostRequest(
      title: 'Hello world', body: 'Body of the new post', userId: 1);

  test('POST /posts через Retrofit + mock-адаптер Dio', () async {
    adapter.onPost(
      '/posts',
      (server) => server.reply(201, {
        'id': 101,
        'title': 'Hello world',
        'body': 'Body of the new post',
        'userId': 1,
      }),
      data: Matchers.any,
    );
    final post = await repo.createPost(request);
    expect(post.id, 101);
    expect(post.title, 'Hello world');
  });

  test('POST /posts: ошибка 500 -> ServerErrorException', () async {
    adapter.onPost(
      '/posts',
      (server) => server.reply(500, {'error': 'boom'}),
      data: Matchers.any,
    );
    expect(repo.createPost(request), throwsA(isA<ServerErrorException>()));
  });
}
