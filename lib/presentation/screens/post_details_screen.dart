import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/state_views.dart';

class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late final PostRepository _repo;
  late Future<Post> _postF;
  late Future<User> _authorF;
  late Future<List<Comment>> _commentsF;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PostRepository>();
    _load();
  }

  void _load() {
    final p = widget.post;
    // Локальный пост на сервере не существует (GET /posts/101 вернёт 404).
    _postF = p.isLocal ? Future.value(p) : _repo.fetchPost(p.id);
    _authorF = _repo.fetchUser(p.userId);
    _commentsF = p.isLocal ? Future.value(<Comment>[]) : _repo.fetchComments(p.id);
  }

  String _msg(Object? e) =>
      e is AppException ? e.userMessage : 'Что-то пошло не так.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Пост #${widget.post.id}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FutureBuilder<Post>(
          future: _postF,
          initialData: widget.post, // сразу показываем то, что есть в списке
          builder: (context, s) {
            final p = s.data ?? widget.post;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(p.body),
              if (p.isLocal)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Chip(label: Text('создан локально — сервер его не хранит')),
                ),
              if (s.hasError)
                Text('Не удалось обновить: ${_msg(s.error)}',
                    style: TextStyle(color: theme.colorScheme.error)),
            ]);
          },
        ),
        const Divider(height: 32),
        FutureBuilder<User>(
          future: _authorF,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (s.hasError) return Text('Автор #${widget.post.userId}');
            final u = s.data!;
            final city = u.address?.city;
            final company = u.company?.name;
            return Text(
              'Автор: ${u.name} (${u.email ?? 'email неизвестен'})'
              '${city != null ? '\nГород: $city' : ''}'
              '${company != null ? '\nКомпания: $company' : ''}',
            );
          },
        ),
        const Divider(height: 32),
        Text('Комментарии', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<Comment>>(
          future: _commentsF,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return SizedBox(
                height: 240,
                child: ErrorView(
                    message: _msg(s.error),
                    onRetry: () => setState(_load)),
              );
            }
            final list = s.data!;
            if (list.isEmpty) return const Text('Комментариев нет');
            return Column(
              children: list
                  .map((c) => Card(
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Text('${c.email}\n${c.body}'),
                          isThreeLine: true,
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ]),
    );
  }
}
