import 'dart:async';

/// Шина событий для глобальных событий авторизации.
/// Используется для уведомления UI о необходимости повторного входа.
class AuthEventBus {
  static final AuthEventBus _instance = AuthEventBus._internal();
  factory AuthEventBus() => _instance;
  AuthEventBus._internal();

  final _controller = StreamController<AuthEvent>.broadcast();

  /// Поток событий авторизации
  Stream<AuthEvent> get stream => _controller.stream;

  /// Отправить событие всем подписчикам
  void emit(AuthEvent event) {
    _controller.add(event);
  }

  /// Освободить ресурсы (вызывать при выходе из приложения)
  void dispose() {
    _controller.close();
  }
}

/// Типы событий авторизации
enum AuthEventType {
  /// Refresh token истёк — требуется повторный вход
  tokenExpired,

  /// Пользователь вышел из системы
  loggedOut,

  /// Токены были очищены (например, при деактивации аккаунта)
  tokensCleared,
}

/// Событие авторизации
class AuthEvent {
  final AuthEventType type;
  final String? message;

  AuthEvent(this.type, [this.message]);

  @override
  String toString() => 'AuthEvent(type: $type, message: $message)';
}