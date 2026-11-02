// GENERATED CODE - DO NOT MODIFY BY HAND
// (написано вручную по образцу json_serializable / retrofit_generator,
//  при запуске build_runner будет перезаписано автоматически)

part of 'post_api.dart';

class _PostApi implements PostApi {
  _PostApi(this._dio, {this.baseUrl});

  final Dio _dio;
  final String? baseUrl;

  String _url(String path) => baseUrl == null ? path : '$baseUrl$path';

  List<Post> _posts(List<dynamic>? data) =>
      data!.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();

  @override
  Future<List<Post>> getPosts({
    required int page,
    required int limit,
    int? userId,
    String? sort,
    String? order,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      _url('/posts'),
      queryParameters: <String, dynamic>{
        '_page': page,
        '_limit': limit,
        if (userId != null) 'userId': userId,
        if (sort != null) '_sort': sort,
        if (order != null) '_order': order,
      },
    );
    return _posts(response.data);
  }

  @override
  Future<Post> getPost(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(_url('/posts/$id'));
    return Post.fromJson(response.data!);
  }

  @override
  Future<List<Post>> getPostsByUser(int userId) async {
    final response = await _dio.get<List<dynamic>>(
      _url('/posts'),
      queryParameters: <String, dynamic>{'userId': userId},
    );
    return _posts(response.data);
  }

  @override
  Future<List<Comment>> getComments(int postId) async {
    final response =
        await _dio.get<List<dynamic>>(_url('/posts/$postId/comments'));
    return response.data!
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Post> createPost(CreatePostRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _url('/posts'),
      data: request.toJson(),
    );
    return Post.fromJson(response.data!);
  }

  @override
  Future<List<User>> getUsers() async {
    final response = await _dio.get<List<dynamic>>(_url('/users'));
    return response.data!
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<User> getUser(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(_url('/users/$id'));
    return User.fromJson(response.data!);
  }
}
