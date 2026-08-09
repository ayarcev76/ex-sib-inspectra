class AppConstants {
  // Базовый URL вашего бэкенда (IP компьютера в локальной сети)
  static const String baseUrl = 'http://192.168.0.112:8000';
  
  // API endpoints
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String meEndpoint = '/api/v1/auth/me';
  
  // Таймауты (в миллисекундах)
  static const int connectTimeout = 10000; // 10 секунд
  static const int receiveTimeout = 15000; // 15 секунд
  
  // Ключи для хранения токенов в защищённом хранилище
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}