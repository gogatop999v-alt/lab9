import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_post_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePostApi api;
  late PostRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = FakePostApi();
    repo = PostRepository(api: api, cache: PostCache(prefs));
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(PostExplorerApp(repository: repo));
    await tester.pumpAndSettle();
  }

  Future<void> openCreateScreen(WidgetTester tester) async {
    await openApp(tester);
    await tester.tap(find.text('Новый пост'));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester,
      {String title = 'Мой новый пост',
      String body = 'Текст нового поста для проверки'}) async {
    await tester.enterText(find.byType(TextFormField).at(0), title);
    await tester.enterText(find.byType(TextFormField).at(1), body);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. User 1').last);
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------------ экран списка
  testWidgets('1. Главный экран: заголовок, кнопки, поиск и список постов',
      (tester) async {
    await openApp(tester);

    expect(find.text('Post Explorer'), findsOneWidget); // заголовок AppBar
    expect(find.text('Новый пост'), findsOneWidget); // кнопка FAB
    expect(find.byType(TextField), findsOneWidget); // поиск
    expect(find.text('Все авторы'), findsOneWidget); // фильтр по автору
    expect(find.byTooltip('Сбросить фильтры'), findsOneWidget);
    expect(find.text('Post 1 title'), findsOneWidget); // посты загрузились
  });

  testWidgets('2. Пока идёт загрузка виден индикатор, потом список',
      (tester) async {
    api.postsGate = Completer<void>();
    await tester.pumpWidget(PostExplorerApp(repository: repo));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Post 1 title'), findsNothing);

    api.postsGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Post 1 title'), findsOneWidget);
  });

  testWidgets('3. Ошибка сервера: сообщение и кнопка «Повторить» работает',
      (tester) async {
    api.errorToThrow = httpError(500);
    await openApp(tester);
    expect(find.text('Сервер временно недоступен (код 500). Попробуйте позже.'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);

    api.errorToThrow = null; // «сервер починили»
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Post 1 title'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('4. Поиск оставляет подходящие посты, а сброс возвращает всё',
      (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'post 7');
    await tester.pump();
    expect(find.text('Post 7 title'), findsOneWidget);
    expect(find.text('Post 1 title'), findsNothing);

    await tester.tap(find.byTooltip('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Post 1 title'), findsOneWidget);
    expect(find.text('post 7'), findsNothing); // поле поиска очищено
  });

  testWidgets('5. Поиск без результатов показывает подсказку',
      (tester) async {
    await openApp(tester);
    await tester.enterText(find.byType(TextField), 'zzz-нет-такого');
    await tester.pump();
    expect(find.text('Ничего не найдено среди загруженных постов'),
        findsOneWidget);
  });

  testWidgets('6. Без сети показываются сохранённые данные и плашка',
      (tester) async {
    await repo.fetchPosts(page: 1); // заполняем кэш
    api.errorToThrow = httpError(500); // а сервер «упал»
    await openApp(tester);

    expect(find.textContaining('Показаны сохранённые данные'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Post 1 title'), findsOneWidget);
  });

  // ----------------------------------------------------- экран деталей
  testWidgets('7. Переход на экран поста: автор и комментарии', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Post 1 title'));
    await tester.pumpAndSettle();

    expect(find.text('Пост #1'), findsOneWidget);
    expect(find.text('Автор: User 1 (email неизвестен)'), findsOneWidget);
    expect(find.text('Комментарии'), findsOneWidget);
    expect(find.text('Первый комментарий'), findsOneWidget);

    await tester.pageBack(); // назад к списку
    await tester.pumpAndSettle();
    expect(find.text('Post Explorer'), findsOneWidget);
  });

  testWidgets('8. Ошибка комментариев: «Повторить» подгружает их',
      (tester) async {
    api.commentsError = httpError(500);
    await openApp(tester);
    await tester.tap(find.text('Post 1 title'));
    await tester.pumpAndSettle();
    expect(find.text('Первый комментарий'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);

    api.commentsError = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Первый комментарий'), findsOneWidget);
  });

  // ----------------------------------------------------- экран создания
  testWidgets('9. Переход на экран создания поста и его элементы',
      (tester) async {
    await openCreateScreen(tester);

    expect(find.widgetWithText(AppBar, 'Новый пост'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Создать'), findsOneWidget);
  });

  testWidgets('10. Пустая форма: ошибки валидации, запрос не отправлен',
      (tester) async {
    await openCreateScreen(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Обязательное поле'), findsNWidgets(2));
    expect(find.text('Выберите автора'), findsOneWidget);
    expect(api.createdRequests, isEmpty);
  });

  testWidgets('11. Слишком короткий заголовок отклоняется', (tester) async {
    await openCreateScreen(tester);
    await fillForm(tester, title: 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();

    expect(find.text('От 5 до 100 символов'), findsOneWidget);
    expect(api.createdRequests, isEmpty);
  });

  testWidgets('12. Успешное создание: диалог ответа и пост в списке',
      (tester) async {
    await openCreateScreen(tester);
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Ответ сервера'), findsOneWidget);
    expect(find.textContaining('"id": 101'), findsOneWidget);
    expect(api.createdRequests.single.userId, 1);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Post Explorer'), findsOneWidget); // вернулись к списку
    expect(find.text('Мой новый пост'), findsOneWidget);
    expect(find.text('создан локально'), findsOneWidget);
  });

  testWidgets('13. Ошибка сервера при создании: SnackBar, экран не закрыт',
      (tester) async {
    api.createError = httpError(500);
    await openCreateScreen(tester);
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Сервер временно недоступен (код 500). Попробуйте позже.'),
        findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Новый пост'), findsOneWidget);
    expect(find.text('Ответ сервера'), findsNothing);
  });
}
