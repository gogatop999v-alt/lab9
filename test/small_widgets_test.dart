import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/presentation/widgets/post_tile.dart';
import 'package:post_explorer/presentation/widgets/state_views.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PostTile', () {
    const local = Post(
        id: 3,
        userId: 2,
        title: 'Заголовок поста',
        body: 'Первая строка\nВторая строка',
        isLocal: true);

    testWidgets('показывает номер, заголовок, текст в одну строку и автора',
        (tester) async {
      await tester.pumpWidget(_wrap(PostTile(post: local, onTap: () {})));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Заголовок поста'), findsOneWidget);
      expect(find.text('Первая строка Вторая строка'), findsOneWidget);
      expect(find.text('Автор #2'), findsOneWidget);
    });

    testWidgets('метка «создан локально» только у локальных постов',
        (tester) async {
      await tester.pumpWidget(_wrap(PostTile(post: local, onTap: () {})));
      expect(find.text('создан локально'), findsOneWidget);

      await tester.pumpWidget(_wrap(PostTile(
          post: local.copyWith(isLocal: false), onTap: () {})));
      expect(find.text('создан локально'), findsNothing);
    });

    testWidgets('нажатие вызывает onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(PostTile(post: local, onTap: () => taps++)));
      await tester.tap(find.byType(ListTile));
      expect(taps, 1);
    });
  });

  group('ErrorView / CachedBanner', () {
    testWidgets('ErrorView: сообщение, иконка и кнопка «Повторить»',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(
          _wrap(ErrorView(message: 'Ошибка!', onRetry: () => retries++)));
      expect(find.text('Ошибка!'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      expect(retries, 2);
    });

    testWidgets('CachedBanner: текст и иконка', (tester) async {
      await tester.pumpWidget(_wrap(const CachedBanner(text: 'Из кэша')));
      expect(find.text('Из кэша'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
