import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

/// Провайдер аутентификации.
/// Управляет состоянием авторизации и биометрической аутентификации.
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final BiometricService _biometricService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isOnline = true; // Предполагаем, что сеть есть по умолчанию
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  AuthProvider(this._authService, this._biometricService);

  // Геттеры для UI
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isOnline => _isOnline;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Инициализация при запуске приложения.
  /// Ключевое изменение: сначала загружаем локальные данные,
  /// потом (если есть сеть) пытаемся обновить с сервера.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Проверяем доступность биометрии
      _isBiometricAvailable = await _biometricService.isBiometricAvailable();
      _isBiometricEnabled = await _biometricService.isBiometricEnabled();

      // 2. Проверяем, есть ли сохранённые токены
      final hasTokens = await _authService.isAuthenticated();

      if (hasTokens) {
        // 3. Сначала загружаем кэшированный профиль (работает без интернета!)
        _currentUser = await _authService.getLocalUserProfile();
        
        if (_currentUser != null) {
          // Считаем пользователя авторизованным на основе локальных данных
          _isAuthenticated = true;
          print('✅ [AuthProvider] Пользователь авторизован по локальным данным');
        } else {
          // Кэша нет — пробуем получить с сервера
          print('⚠️ [AuthProvider] Локальный кэш пуст, пробуем сервер...');
          _currentUser = await _authService.getCurrentUser();
          _isAuthenticated = _currentUser != null;
        }

        // 4. Если сеть есть — обновляем данные пользователя в фоне
        // (не блокируем UI, даже если запрос упадёт)
        if (_isAuthenticated) {
          _refreshUserInBackground();
        }
      } else {
        // Токенов нет — пользователь не авторизован
        _isAuthenticated = false;
        _currentUser = null;
        print('⚠️ [AuthProvider] Токены не найдены, пользователь не авторизован');
      }
    } catch (e) {
      print('❌ [AuthProvider] Ошибка инициализации: $e');
      // Даже при ошибке пытаемся загрузить локальные данные
      _currentUser = await _authService.getLocalUserProfile();
      _isAuthenticated = _currentUser != null;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Фоновое обновление данных пользователя (не блокирует UI).
  void _refreshUserInBackground() {
    // Запускаем async-операцию без await
    _authService.getCurrentUser().then((user) {
      if (user != null) {
        _currentUser = user;
        _isOnline = true;
        notifyListeners();
        print('✅ [AuthProvider] Данные пользователя обновлены с сервера');
      } else {
        _isOnline = false;
        notifyListeners();
        print('️ [AuthProvider] Не удалось обновить данные (возможно, нет сети)');
      }
    }).catchError((e) {
      _isOnline = false;
      notifyListeners();
      print('❌ [AuthProvider] Ошибка фонового обновления: $e');
    });
  }

  /// Вход в систему по email и паролю.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(email, password);

    _isLoading = false;

    if (result['success'] == true) {
      _isAuthenticated = true;
      _currentUser = result['user'];
      _isOnline = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['error'] ?? 'Неизвестная ошибка';
      notifyListeners();
      return false;
    }
  }

  /// Включить биометрическую авторизацию.
  Future<void> enableBiometric(String email, String password) async {
    await _biometricService.saveCredentials(email, password);
    _isBiometricEnabled = true;
    notifyListeners();
    print('✅ [AuthProvider] Биометрическая авторизация включена');
  }

  /// Включить биометрию с подтверждением пользователя.
  Future<bool> enableBiometricWithConfirmation(String email, String password) async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Подтвердите биометрию для включения быстрого входа в будущем',
    );

    if (!authenticated) {
      print('⚠️ [AuthProvider] Пользователь отменил или не прошёл биометрию');
      return false;
    }

    await enableBiometric(email, password);
    return true;
  }

  /// Отключить биометрическую авторизацию.
  Future<void> disableBiometric() async {
    await _biometricService.clearSavedCredentials();
    _isBiometricEnabled = false;
    notifyListeners();
    print('✅ [AuthProvider] Биометрическая авторизация отключена');
  }

  /// Попытка автоматического входа по биометрии.
  Future<bool> tryAutoLogin() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credentials = await _biometricService.tryAutoLogin();
      
      if (credentials == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final email = credentials['email']!;
      final password = credentials['password']!;

      final result = await _authService.login(email, password);

      _isLoading = false;

      if (result['success'] == true) {
        _isAuthenticated = true;
        _currentUser = result['user'];
        _isOnline = true;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Ошибка авто-входа';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Ошибка биометрической авторизации: $e';
      notifyListeners();
      return false;
    }
  }

  /// Выход из системы.
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Очистить сообщение об ошибке.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Получить данные текущего пользователя с сервера.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      _currentUser = user;
      _isOnline = true;
      notifyListeners();
    } else {
      _isOnline = false;
      notifyListeners();
    }
    return user;
  }
}