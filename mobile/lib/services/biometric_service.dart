import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Сервис биометрической аутентификации.
/// Отвечает за:
/// 1. Проверку доступности биометрии на устройстве
/// 2. Запрос аутентификации (отпечаток / Face ID)
/// 3. Сохранение/чтение зашифрованных учётных данных для авто-входа
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Ключи для хранения учётных данных
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Проверить, поддерживает ли устройство биометрию
  /// и настроена ли она (есть хотя бы один отпечаток/лицо).
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      print('❌ [BiometricService] Ошибка проверки биометрии: $e');
      return false;
    }
  }

  /// Получить список доступных типов биометрии на устройстве.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('❌ [BiometricService] Ошибка получения типов биометрии: $e');
      return [];
    }
  }

  /// Запросить биометрическую аутентификацию.
  /// Возвращает true, если пользователь успешно прошёл проверку.
  Future<bool> authenticate({
    String reason = 'Подтвердите свою личность для входа в систему',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('️ [BiometricService] Биометрия недоступна на этом устройстве');
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Биометрическая аутентификация',
            cancelButton: 'Отмена',
            biometricHint: 'Приложите палец к сканеру',
            biometricNotRecognized: 'Отпечаток не распознан',
            biometricSuccess: 'Аутентификация успешна',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true, // Только биометрия, без PIN/паттерна
          stickyAuth: true,    // Не прерывать при сворачивании приложения
        ),
      );

      return authenticated;
    } catch (e) {
      print('❌ [BiometricService] Ошибка аутентификации: $e');
      return false;
    }
  }

  /// Сохранить учётные данные для авто-входа по биометрии.
  /// Вызывается после успешного логина, если пользователь включил биометрию.
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _savedEmailKey, value: email);
    await _storage.write(key: _savedPasswordKey, value: password);
    await _storage.write(key: _biometricEnabledKey, value: 'true');
    print('✅ [BiometricService] Учётные данные сохранены');
  }

  /// Проверить, включена ли биометрическая авторизация.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Получить сохранённый email (если биометрия включена).
  Future<String?> getSavedEmail() async {
    return await _storage.read(key: _savedEmailKey);
  }

  /// Получить сохранённый пароль (если биометрия включена).
  Future<String?> getSavedPassword() async {
    return await _storage.read(key: _savedPasswordKey);
  }

  /// Проверить, есть ли сохранённые учётные данные.
  Future<bool> hasSavedCredentials() async {
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    return email != null && password != null;
  }

  /// Удалить сохранённые учётные данные (при выходе или отключении биометрии).
  Future<void> clearSavedCredentials() async {
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
    await _storage.delete(key: _biometricEnabledKey);
    print('✅ [BiometricService] Учётные данные удалены');
  }

  /// Полный флоу авто-входа по биометрии.
  /// 1. Проверяет, есть ли сохранённые данные
  /// 2. Запрашивает биометрию
  /// 3. Возвращает email и пароль для автоматического логина
  /// Возвращает null, если что-то пошло не так.
  Future<Map<String, String>?> tryAutoLogin() async {
    if (!await hasSavedCredentials()) {
      return null;
    }

    final authenticated = await authenticate();
    if (!authenticated) {
      return null;
    }

    final email = await getSavedEmail();
    final password = await getSavedPassword();

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }

    return null;
  }
}