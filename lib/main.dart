import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/dio_client.dart';
import 'data/local/post_cache.dart';
import 'data/remote/post_api.dart';
import 'data/repositories/post_repository.dart';
import 'presentation/screens/posts_list_screen.dart';
import 'presentation/state/posts_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final dioClient = DioClient(); // единственный экземпляр Dio
  final repository = PostRepository(
    api: PostApi(dioClient.dio),
    cache: PostCache(prefs),
  );
  runApp(PostExplorerApp(repository: repository));
}

class PostExplorerApp extends StatelessWidget {
  const PostExplorerApp({super.key, required this.repository});

  final PostRepository repository;

  @override
  Widget build(BuildContext context) {
    return Provider<PostRepository>.value(
      value: repository,
      child: ChangeNotifierProvider(
        create: (_) => PostsController(repository)
          ..loadInitial()
          ..loadUsers(),
        child: MaterialApp(
          title: 'Post Explorer',
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          home: const PostsListScreen(),
        ),
      ),
    );
  }
}
