import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';

enum ListStatus { loading, success, error }

/// Состояние списка постов. Загрузка списка, подгрузка страницы и загрузка
/// авторов описаны отдельными полями, а не одним флагом isLoading.
class PostsController extends ChangeNotifier {
  PostsController(PostRepository repo)
      : _repo = repo,
        _localPosts = repo.loadLocalPosts();

  final PostRepository _repo;

  ListStatus status = ListStatus.loading;
  AppException? error; // фатальная ошибка (нет данных вообще)
  AppException? refreshError; // не удалось обновить, но есть кэш
  bool isFromCache = false;

  bool isLoadingMore = false;
  AppException? loadMoreError;
  bool hasMore = true;

  int? userId;
  SortOrder order = SortOrder.asc;
  String query = '';

  List<User> users = [];
  bool usersLoading = false;
  AppException? usersError;

  List<Post> _posts = [];
  List<Post> _localPosts;
  int _page = 1;
  int _generation = 0; // защита от «устаревших» ответов после смены фильтра

  int get loadedCount => _posts.length;
  bool get showCachedBanner => isFromCache || refreshError != null;

  /// Локальные посты + загруженные, с учётом фильтра по автору и поиска.
  List<Post> get visiblePosts {
    final q = query.trim().toLowerCase();
    final all = [
      ..._localPosts.where((p) => userId == null || p.userId == userId),
      ..._posts,
    ];
    if (q.isEmpty) return all;
    return all.where((p) => p.title.toLowerCase().contains(q)).toList();
  }

  /// Первая загрузка / смена фильтра: сначала кэш, затем сервер.
  Future<void> loadInitial() => _loadFirstPage(showCache: true);

  /// Pull-to-refresh: текущий список остаётся на экране.
  Future<void> refresh() => _loadFirstPage(showCache: false);

  Future<void> _loadFirstPage({required bool showCache}) async {
    final gen = ++_generation;
    _page = 1;
    hasMore = true;
    isLoadingMore = false;
    loadMoreError = null;
    refreshError = null;
    error = null;

    if (showCache) {
      final cached = _repo.cachedFirstPage(userId, order);
      if (cached != null && cached.isNotEmpty) {
        _posts = cached;
        isFromCache = true;
        status = ListStatus.success;
      } else {
        _posts = [];
        isFromCache = false;
        status = ListStatus.loading;
      }
      notifyListeners();
    }

    try {
      final fresh =
          await _repo.fetchPosts(page: 1, userId: userId, order: order);
      if (gen != _generation) return;
      _posts = fresh;
      isFromCache = false;
      hasMore = fresh.length >= _repo.pageSize;
      status = ListStatus.success;
    } on AppException catch (e) {
      if (gen != _generation) return;
      if (_posts.isNotEmpty) {
        refreshError = e; // последний успешный результат не удаляем
      } else {
        error = e;
        status = ListStatus.error;
      }
    }
    notifyListeners();
  }

  /// Подгрузка следующей страницы (с защитой от дублей).
  Future<void> loadMore() async {
    if (isLoadingMore ||
        !hasMore ||
        loadMoreError != null ||
        status != ListStatus.success ||
        isFromCache) {
      return;
    }
    final gen = _generation;
    final nextPage = _page + 1;
    isLoadingMore = true;
    notifyListeners();
    try {
      final items =
          await _repo.fetchPosts(page: nextPage, userId: userId, order: order);
      if (gen != _generation) return;
      final ids = _posts.map((p) => p.id).toSet();
      _posts = [..._posts, ...items.where((p) => !ids.contains(p.id))];
      _page = nextPage;
      hasMore = items.length >= _repo.pageSize;
    } on AppException catch (e) {
      if (gen != _generation) return;
      loadMoreError = e;
    }
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> retryLoadMore() {
    loadMoreError = null;
    return loadMore();
  }

  // ---- фильтры ----
  Future<void> setUser(int? id) {
    userId = id;
    return loadInitial();
  }

  Future<void> toggleOrder() {
    order = order == SortOrder.asc ? SortOrder.desc : SortOrder.asc;
    return loadInitial();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> resetFilters() {
    userId = null;
    order = SortOrder.asc;
    query = '';
    return loadInitial();
  }

  // ---- авторы ----
  Future<void> loadUsers() async {
    if (usersLoading) return;
    usersLoading = true;
    usersError = null;
    notifyListeners();
    try {
      users = await _repo.fetchUsers();
    } on AppException catch (e) {
      usersError = e;
    }
    usersLoading = false;
    notifyListeners();
  }

  // ---- локально созданные посты ----
  Future<void> addLocalPost(Post serverPost) async {
    _localPosts = [serverPost.copyWith(isLocal: true), ..._localPosts];
    notifyListeners();
    await _repo.saveLocalPosts(_localPosts);
  }
}
