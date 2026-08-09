class ApiConstants {
  // ⚠️ ВАЖНО: Для Android эмулятора используйте 10.0.2.2 вместо localhost
  // Для физического устройства используйте IP вашего компьютера в локальной сети
  static const String baseUrl = 'http://192.168.0.112:8000/api/v1';
  
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh';
  static const String getMe = '/users/me';
  
  // Таймауты
  static const int connectTimeout = 15000; // 15 секунд
  static const int receiveTimeout = 15000;
}