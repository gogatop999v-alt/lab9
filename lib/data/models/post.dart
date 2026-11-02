import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable()
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isLocal = false,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  /// true, если пост создан локально (сервер JSONPlaceholder его не хранит).
  @JsonKey(defaultValue: false)
  final bool isLocal;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({bool? isLocal}) => Post(
        id: id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal ?? this.isLocal,
      );
}

/// Тело POST /posts.
@JsonSerializable()
class CreatePostRequest {
  const CreatePostRequest({
    required this.title,
    required this.body,
    required this.userId,
  });

  final String title;
  final String body;
  final int userId;

  factory CreatePostRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePostRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePostRequestToJson(this);
}
