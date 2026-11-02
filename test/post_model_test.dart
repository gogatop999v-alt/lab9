import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';

void main() {
  test('JSON -> Post', () {
    final post = Post.fromJson({
      'userId': 1,
      'id': 5,
      'title': 'Заголовок',
      'body': 'Текст',
    });
    expect(post.id, 5);
    expect(post.userId, 1);
    expect(post.title, 'Заголовок');
    expect(post.isLocal, isFalse);
  });

  test('Post -> JSON', () {
    const post = Post(id: 7, userId: 2, title: 'T', body: 'B', isLocal: true);
    expect(post.toJson(), {
      'id': 7,
      'userId': 2,
      'title': 'T',
      'body': 'B',
      'isLocal': true,
    });
  });

  test('отсутствие обязательного поля даёт TypeError (ловится репозиторием)', () {
    expect(() => Post.fromJson({'id': 1, 'userId': 1, 'body': 'x'}),
        throwsA(isA<TypeError>()));
  });

  test('User: вложенные модели и nullable-поля', () {
    final user = User.fromJson({
      'id': 1,
      'name': 'Leanne',
      'username': 'Bret',
      'address': {
        'city': 'Gwenborough',
        'geo': {'lat': '-37.3', 'lng': '81.1'}
      },
    });
    expect(user.address?.city, 'Gwenborough');
    expect(user.address?.geo?.lat, '-37.3');
    expect(user.company, isNull);
    expect(user.email, isNull);
  });
}
