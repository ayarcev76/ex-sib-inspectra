import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Сервис аутентификации.
/// Отвечает за логику входа, выхода и работы с текущим пользователем.
class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  
  // Ключ для хранения профиля пользователя локально
  static const String _userProfileKey = 'cached_user_profile';
  
  // Настройки хранилища для Android
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  AuthService(this._apiClient, this._tokenStorage);

  /// Вход в систему по email и паролю.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final formData = FormData.fromMap({
        'username': email.trim(),
        'password': password,
      });

      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Сохраняем токены
        await _tokenStorage.saveAccessToken(data['access_token']);
        await _tokenStorage.saveRefreshToken(data['refresh_token']);

        // Если бэкенд вернул объект user — сохраняем его локально
        if (data['user'] != null) {
          await _saveUserProfileLocally(data['user']);
          return {
            'success': true,
            'user': data['user'],
          };
        }
        
        // Если user не пришел — запрашиваем через /me и сохраняем
        final user = await getCurrentUser();
        if (user != null) {
          await _saveUserProfileLocally(user);
          return {
            'success': true,
            'user': user,
          };
        }

        return {
          'success': false,
          'error': 'Не удалось получить данные пользователя',
        };
      } else {
        return {
          'success': false,
          'error': 'Неверный статус ответа: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;

        if (statusCode == 401) {
          return {
            'success': false,
            'error': 'Неверный email или пароль',
          };
        } else if (statusCode == 400) {
          final detail = responseData is Map
              ? responseData['detail'] ?? 'Некорректные данные'
              : 'Некорректные данные';
          return {
            'success': false,
            'error': detail.toString(),
          };
        } else {
          return {
            'success': false,
            'error': 'Ошибка сервера: $statusCode',
          };
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'error': 'Превышено время ожидания соединения',
        };
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'error': 'Сервер слишком долго отвечает',
        };
      } else if (e.type == DioExceptionType.connectionError) {
        return {
          'success': false,
          'error': 'Нет связи с сервером. Проверьте подключение к сети.',
        };
      } else {
        return {
          'success': false,
          'error': 'Ошибка сети: ${e.message ?? "неизвестная ошибка"}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Неизвестная ошибка: $e',
      };
    }
  }

  /// Выход из системы.
  Future<void> logout() async {
    await _tokenStorage.clearTokens();
    await _clearLocalUserProfile();
  }

  /// Получить информацию о текущем пользователе с сервера.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/api/v1/auth/me');
      if (response.statusCode == 200) {
        final user = response.data;
        // Кэшируем локально при успешном запросе
        await _saveUserProfileLocally(user);
        return user;
      }
      return null;
    } catch (e) {
      print('❌ [AuthService] Ошибка получения данных пользователя: $e');
      return null;
    }
  }

  /// Проверить, авторизован ли пользователь (есть ли сохранённый токен).
  Future<bool> isAuthenticated() async {
    return await _tokenStorage.hasTokens();
  }

  // ==========================================
  // Локальное кэширование профиля пользователя
  // ==========================================

  /// Сохранить профиль пользователя локально (в зашифрованном хранилище).
  Future<void> _saveUserProfileLocally(Map<String, dynamic> user) async {
    try {
      final storage = const FlutterSecureStorage(
        aOptions: _androidOptions,
      );
      await storage.write(
        key: _userProfileKey,
        value: jsonEncode(user),
        aOptions: _androidOptions,
      );
      print('✅ [AuthService] Профиль пользователя сохранён локально');
    } catch (e) {
      print('❌ [AuthService] Ошибка сохранения профиля: $e');
    }
  }

  /// Загрузить профиль пользователя из локального кэша.
  /// Работает БЕЗ интернета!
  Future<Map<String, dynamic>?> getLocalUserProfile() async {
    try {
      final storage = const FlutterSecureStorage(
        aOptions: _androidOptions,
      );
      final cachedJson = await storage.read(
        key: _userProfileKey,
        aOptions: _androidOptions,
      );
      
      if (cachedJson == null || cachedJson.isEmpty) {
        return null;
      }

      final user = jsonDecode(cachedJson) as Map<String, dynamic>;
      print('✅ [AuthService] Профиль пользователя загружен из кэша');
      return user;
    } catch (e) {
      print('❌ [AuthService] Ошибка загрузки кэшированного профиля: $e');
      return null;
    }
  }

  /// Очистить локальный кэш профиля.
  Future<void> _clearLocalUserProfile() async {
    try {
      final storage = const FlutterSecureStorage(
        aOptions: _androidOptions,
      );
      await storage.delete(
        key: _userProfileKey,
        aOptions: _androidOptions,
      );
      print('✅ [AuthService] Локальный кэш профиля очищен');
    } catch (e) {
      print('❌ [AuthService] Ошибка очистки кэша профиля: $e');
    }
  }
}