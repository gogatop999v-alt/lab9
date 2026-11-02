import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';

enum SubmitStatus { idle, submitting, success, failure }

class CreatePostController extends ChangeNotifier {
  CreatePostController(this._repo);

  final PostRepository _repo;

  SubmitStatus status = SubmitStatus.idle;
  Post? created;
  AppException? error;

  /// Возвращает созданный сервером пост или null при ошибке / повторном нажатии.
  Future<Post?> submit(CreatePostRequest request) async {
    if (status == SubmitStatus.submitting) return null;
    status = SubmitStatus.submitting;
    error = null;
    notifyListeners();
    try {
      created = await _repo.createPost(request);
      status = SubmitStatus.success;
    } on AppException catch (e) {
      error = e;
      status = SubmitStatus.failure;
    }
    notifyListeners();
    return status == SubmitStatus.success ? created : null;
  }
}
