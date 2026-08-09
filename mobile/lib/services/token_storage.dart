import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

/// Сервис для безопасного хранения JWT-токенов.
/// Использует зашифрованное хранилище устройства (Keychain на iOS,
/// EncryptedSharedPreferences на Android).
class TokenStorage {
  // Настройки хранилища с явным указанием параметров для Android
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Сохранить access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: token,
      aOptions: _androidOptions,
    );
  }

  /// Сохранить refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: token,
      aOptions: _androidOptions,
    );
  }

  /// Получить access token
  Future<String?> getAccessToken() async {
    return await _storage.read(
      key: AppConstants.accessTokenKey,
      aOptions: _androidOptions,
    );
  }

  /// Получить refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: AppConstants.refreshTokenKey,
      aOptions: _androidOptions,
    );
  }

  /// Удалить все токены (при выходе из системы)
  Future<void> clearTokens() async {
    await _storage.delete(
      key: AppConstants.accessTokenKey,
      aOptions: _androidOptions,
    );
    await _storage.delete(
      key: AppConstants.refreshTokenKey,
      aOptions: _androidOptions,
    );
  }

  /// Проверить, есть ли сохранённые токены (пользователь авторизован)
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }
}