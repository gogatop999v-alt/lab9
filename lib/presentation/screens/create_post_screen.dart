import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../state/create_post_controller.dart';
import '../state/posts_controller.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CreatePostController(ctx.read<PostRepository>()),
      child: const _CreateForm(),
    );
  }
}

class _CreateForm extends StatefulWidget {
  const _CreateForm();

  @override
  State<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends State<_CreateForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _userId;

  @override
  void initState() {
    super.initState();
    final posts = context.read<PostsController>();
    if (posts.users.isEmpty) posts.loadUsers();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String? _validate(String? value, int min, int max) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Обязательное поле';
    if (v.length < min || v.length > max) return 'От $min до $max символов';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<CreatePostController>();
    final posts = context.read<PostsController>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await ctrl.submit(CreatePostRequest(
      title: _title.text.trim(),
      body: _body.text.trim(),
      userId: _userId!,
    ));
    if (!mounted) return;

    if (created == null) {
      if (ctrl.error != null) {
        messenger.showSnackBar(SnackBar(content: Text(ctrl.error!.userMessage)));
      }
      return;
    }
    await posts.addLocalPost(created);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ответ сервера'),
        content: SingleChildScrollView(
          child: Text(
            const JsonEncoder.withIndent('  ').convert(created.toJson()),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<PostsController>();
    final submitting =
        context.watch<CreatePostController>().status == SubmitStatus.submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый пост')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _title,
            enabled: !submitting,
            decoration: const InputDecoration(
                labelText: 'Заголовок', border: OutlineInputBorder()),
            validator: (v) => _validate(v, 5, 100),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _body,
            enabled: !submitting,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Текст', border: OutlineInputBorder()),
            validator: (v) => _validate(v, 10, 1000),
          ),
          const SizedBox(height: 16),
          if (posts.users.isEmpty)
            Row(children: [
              if (posts.usersLoading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton(
                    onPressed: posts.loadUsers,
                    child: const Text('Загрузить авторов')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(posts.usersError?.userMessage ?? 'Загрузка авторов…'),
              ),
            ])
          else
            DropdownButtonFormField<int>(
              value: _userId,
              decoration: const InputDecoration(
                  labelText: 'Автор', border: OutlineInputBorder()),
              items: posts.users
                  .map((u) => DropdownMenuItem<int>(
                      value: u.id, child: Text('${u.id}. ${u.name}')))
                  .toList(),
              onChanged: submitting ? null : (v) => setState(() => _userId = v),
              validator: (v) => v == null ? 'Выберите автора' : null,
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Создать'),
          ),
        ]),
      ),
    );
  }
}
