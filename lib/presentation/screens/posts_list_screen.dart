import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/post_repository.dart';
import '../state/posts_controller.dart';
import '../widgets/post_tile.dart';
import '../widgets/state_views.dart';
import 'create_post_screen.dart';
import 'post_details_screen.dart';

class PostsListScreen extends StatefulWidget {
  const PostsListScreen({super.key});

  @override
  State<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends State<PostsListScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients) return;
    final c = context.read<PostsController>();
    if (c.query.isNotEmpty) return; // при поиске не подгружаем автоматически
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels < 200) c.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostsController>();
    // если список короче экрана — докачиваем следующую страницу
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Explorer'),
        actions: [
          IconButton(
            tooltip: 'Сбросить фильтры',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () {
              _search.clear();
              c.resetFilters();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Новый пост'),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen())),
      ),
      body: Column(children: [
        _Filters(controller: c, search: _search),
        if (c.status == ListStatus.success && c.showCachedBanner)
          CachedBanner(
            text: c.refreshError != null
                ? '${c.refreshError!.userMessage} Показаны сохранённые данные.'
                : 'Показаны сохранённые данные, обновляем…',
          ),
        Expanded(child: _body(c)),
      ]),
    );
  }

  Widget _body(PostsController c) {
    switch (c.status) {
      case ListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ListStatus.error:
        return ErrorView(
            message: c.error!.userMessage, onRetry: c.loadInitial);
      case ListStatus.success:
        final posts = c.visiblePosts;
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Text(c.query.isNotEmpty
                          ? 'Ничего не найдено среди загруженных постов'
                          : 'Постов нет'),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: posts.length + 1,
                  itemBuilder: (context, i) {
                    if (i < posts.length) {
                      final p = posts[i];
                      return PostTile(
                        post: p,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => PostDetailsScreen(post: p)),
                        ),
                      );
                    }
                    return _footer(c);
                  },
                ),
        );
    }
  }

  Widget _footer(PostsController c) {
    if (c.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (c.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(c.loadMoreError!.userMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: c.retryLoadMore, child: const Text('Повторить')),
        ]),
      );
    }
    if (!c.hasMore && c.query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Это все посты')),
      );
    }
    return const SizedBox(height: 72);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.search});

  final PostsController controller;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(children: [
        TextField(
          controller: search,
          onChanged: c.setQuery,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Поиск по заголовку',
            helperText:
                'Поиск только среди загруженных постов (${c.loadedCount}), не по всему набору',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: c.userId,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Все авторы')),
                ...c.users.map((u) => DropdownMenuItem<int?>(
                    value: u.id, child: Text('${u.id}. ${u.name}'))),
              ],
              onChanged: c.setUser,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: c.toggleOrder,
            icon: Icon(c.order == SortOrder.asc
                ? Icons.arrow_upward
                : Icons.arrow_downward),
            label: const Text('ID'),
          ),
        ]),
      ]),
    );
  }
}
