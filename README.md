# Post Explorer (SRS 8 + SRS 9)

Flutter-приложение для просмотра, поиска и создания постов на базе [JSONPlaceholder](https://jsonplaceholder.typicode.com).
Стек: Dio, Retrofit, json_serializable, Provider (ChangeNotifier), SharedPreferences.

## Запуск
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # генерирует *.g.dart
flutter run
flutter test                                               # тесты
```

## Архитектура
```
Presentation (screens, widgets, state: PostsController, CreatePostController)
      ↓
Repository (PostRepository: кэш + преобразование ошибок в AppException)
      ↓
Remote data source (Retrofit PostApi + единый DioClient + interceptors)   Local: PostCache
      ↓
JSONPlaceholder REST API
```
UI никогда не обращается к Dio напрямую — только к контроллерам, а те к репозиторию.

| Слой | Папка | Ответственность |
|---|---|---|
| core | `lib/core` | `DioClient` (baseUrl, таймауты, LogInterceptor, ApiInterceptor), `AppException` |
| data/models | `lib/data/models` | `Post`, `Comment`, `User` (+ вложенные `Address`, `Geo`, `Company`), `json_serializable` |
| data/remote | `lib/data/remote` | Retrofit-интерфейс `PostApi` (5 обязательных + 2 доп. запроса) |
| data/local | `lib/data/local` | `PostCache` на SharedPreferences |
| data/repositories | `lib/data/repositories` | `PostRepository` |
| presentation | `lib/presentation` | экраны, виджеты, состояние |

## API-запросы (Retrofit)
GET `/posts` (`_page`, `_limit`, `userId`, `_sort`, `_order`) · GET `/posts/{id}` · GET `/posts?userId=` · GET `/posts/{id}/comments` · POST `/posts` · GET `/users` · GET `/users/{id}`

## Поведение кэша
- **Первый запуск:** кэша нет → индикатор загрузки → список с сервера → первая страница сохраняется в кэш.
- **Повторное открытие:** сразу показываются сохранённые посты с плашкой «Показаны сохранённые данные, обновляем…», параллельно идёт запрос; после ответа список и кэш обновляются, плашка исчезает.
- **Нет интернета:** кэшированный список остаётся на экране, плашка сообщает об ошибке обновления. Если кэша нет — экран ошибки с кнопкой «Повторить». Pull-to-refresh обновляет вручную.
- Кэш хранится отдельно для каждого сочетания «автор + сортировка». Созданные локально посты сохраняются и помечены «создан локально» (JSONPlaceholder их не хранит).

## Состояния UI
Loading · Success · Error · Cached (плашка) · Empty. Подгрузка страницы, загрузка списка, загрузка авторов и отправка формы имеют отдельные состояния (не один `isLoading`).

## Обработка ошибок
`AppException`: `NoConnectionException`, `RequestTimeoutException`, `ClientErrorException` (4xx), `ServerErrorException` (5xx), `ParseException`, `UnknownException`. Пользователь видит понятное сообщение, технические детали пишутся в лог (`debugPrint`).

## Пагинация, поиск, фильтры
- 10 постов на страницу, подгрузка при прокрутке, индикатор внизу, защита от повторной загрузки страницы, кнопка «Повторить» при ошибке.
- Смена фильтра/сортировки сбрасывает страницы; устаревшие ответы отбрасываются (счётчик поколений), результаты не смешиваются.
- Поиск по заголовку — **локальный, только среди загруженных постов** (это написано в интерфейсе). Фильтр по `userId` и сортировка по ID — на сервере. Кнопка «Сбросить фильтры» в AppBar.

## Тесты (11)
JSON→Post, Post→JSON, отсутствующее поле, вложенный User, успешная загрузка через репозиторий, ошибки 500/404/таймаут, ParseException, фильтрация по автору и заголовку, сохранение кэша при ошибке, защита от дублей страницы, отсутствие смешивания после смены фильтра, POST через `http_mock_adapter`.

## Зачем нужны Dio, Retrofit, json_serializable и Repository
- **Dio** — HTTP-клиент: таймауты, interceptors, логирование, единая настройка.
- **Retrofit** — декларативное описание эндпоинтов интерфейсом; код запросов генерируется, меньше ручных ошибок.
- **json_serializable** — генерирует `fromJson/toJson`, не нужно писать парсер вручную.
- **Repository** — скрывает от UI источники данных (сеть/кэш), превращает ошибки в понятные и делает код тестируемым.

## SRS 9: иконка и тесты
**Launcher Icon.** Исходники: `assets/icon/app_icon.png` и `app_icon_foreground.png` (Adaptive Icon). Настройка — в конце `pubspec.yaml` (`flutter_launcher_icons`). Генерация:
```bash
flutter pub get
dart run flutter_launcher_icons
```

**Тесты** (`flutter test`):
| Файл | Тип | Что проверяет |
|---|---|---|
| `test/unit_logic_test.dart` | Unit (21) | AppException, модели, PostCache, PostsController, CreatePostController |
| `test/widget_test.dart` | Widget (13) | экраны списка, деталей и создания поста, навигация, ошибки, кэш |
| `test/small_widgets_test.dart` | Widget (5) | PostTile, ErrorView, CachedBanner |
| `test/post_model_test.dart`, `post_repository_test.dart`, `create_post_test.dart` | Unit (SRS 8) | модели, репозиторий, POST через mock-адаптер |
| `test/helpers/fake_post_api.dart` | — | поддельный API без сети |
