import 'dart:async';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../core/constants.dart';
import 'token_storage.dart';
import 'auth_event_bus.dart';

/// HTTP-клиент приложения на базе Dio.
/// Автоматически добавляет JWT-токен в заголовки всех запросов
/// и обновляет access token через refresh token при получении 401.
class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final AuthEventBus _authEventBus = AuthEventBus();

  // Флаг для предотвращения race condition при одновременном обновлении токена
  bool _isRefreshing = false;

  // Очередь запросов, ожидающих обновления токена
  final List<Completer<bool>> _refreshQueue = [];

  ApiClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Интерсептор 1: добавляет Bearer-токен к каждому запросу
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          _logError(error);
          return handler.next(error);
        },
      ),
    );

    // Интерсептор 2: автообновление токена при 401 (QueuedInterceptorsWrapper)
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Проверяем, что это 401 ошибка и запрос не к эндпоинту refresh
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/refresh')) {

            try {
              // Пытаемся обновить токен
              final success = await _refreshToken();

              if (success) {
                // Повторяем оригинальный запрос с новым токеном
                final opts = error.requestOptions;
                final newToken = await _tokenStorage.getAccessToken();
                opts.headers['Authorization'] = 'Bearer $newToken';

                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } else {
                // 🔥 Refresh не удался — очищаем токены
                // и отправляем событие для автоматического logout
                print('❌ [ApiClient] Refresh token истёк или невалиден');
                await _tokenStorage.clearTokens();

                // ✅ Отправляем событие для UI
                _authEventBus.emit(AuthEvent(
                  AuthEventType.tokenExpired,
                  'Сессия истекла. Пожалуйста, войдите снова.',
                ));

                return handler.next(error);
              }
            } catch (e) {
              print('❌ [ApiClient] Ошибка при обновлении токена: $e');
              return handler.next(error);
            }
          }

          // Не 401 или запрос к refresh — пропускаем дальше
          return handler.next(error);
        },
      ),
    );

    // Красивый логгер запросов/ответов (только для режима разработки)
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 120,
      ),
    );
  }

  /// Получить внутренний Dio-клиент (для специфичных запросов)
  Dio get dio => _dio;

  /// Получить шину событий авторизации (для подписки в main.dart)
  AuthEventBus get authEventBus => _authEventBus;

  // ==========================================
  // БАЗОВЫЕ HTTP-МЕТОДЫ
  // ==========================================

  /// GET-запрос
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  /// POST-запрос
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  /// PUT-запрос
  Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    return await _dio.put(path, data: data);
  }

  /// DELETE-запрос
  Future<Response> delete(
    String path, {
    dynamic data,
  }) async {
    return await _dio.delete(path, data: data);
  }

  // ==========================================
  // ЗАГРУЗКА ФОТО (MULTIPART)
  // ==========================================

  /// Загрузка фотографии нарушения на сервер через multipart/form-data.
  ///
  /// Использует специальный эндпоинт для мобильного приложения, который
  /// находит нарушение по `inspectionClientId` и `violationOrder`.
  ///
  /// Возвращает `server_id` загруженного фото.
  Future<String> uploadPhoto({
    required String inspectionClientId,
    required int violationOrder,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'image/jpeg',
    double? gpsLatitude,
    double? gpsLongitude,
    DateTime? takenAt,
  }) async {
    try {
      // Парсим MIME-тип для корректного Content-Type файла
      final mediaType = _parseMediaType(mimeType);

      // Создаём FormData для multipart-запроса
      final formData = FormData.fromMap({
        'inspection_client_id': inspectionClientId,
        'violation_order': violationOrder,
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: filename,
          contentType: mediaType,
        ),
        // GPS-координаты (если есть)
        if (gpsLatitude != null) 'gps_latitude': gpsLatitude.toString(),
        if (gpsLongitude != null) 'gps_longitude': gpsLongitude.toString(),
        // Время съёмки (если есть)
        if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      });

      print('📤 [ApiClient] Загрузка фото: $filename (${fileBytes.length} bytes)');
      print('   → Инспекция: $inspectionClientId, нарушение #$violationOrder');

      // Отправляем на специальный эндпоинт для мобильного приложения
      final response = await _dio.post(
        '/api/v1/photos/mobile',
        data: formData,
        options: Options(
          // Для multipart Content-Type устанавливается автоматически
          contentType: 'multipart/form-data',
          // Увеличиваем таймауты для больших файлов (до 10 МБ)
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        // Прогресс загрузки (для будущего UI)
        onSendProgress: (sent, total) {
          if (total > 0) {
            final percent = (sent / total * 100).toStringAsFixed(0);
            print('   ⏳ Прогресс: $percent%');
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final serverPhotoId = data['id'] as String;
        print('✅ [ApiClient] Фото загружено: $serverPhotoId');
        return serverPhotoId;
      } else {
        throw PhotoUploadException(
          'Сервер вернул статус ${response.statusCode}',
          statusCode: response.statusCode,
          responseData: response.data,
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorData = e.response?.data;

      // Обработка специфичных ошибок
      if (statusCode == 404) {
        throw PhotoUploadException(
          'Нарушение не найдено на сервере. Проверьте синхронизацию инспекций.',
          statusCode: statusCode,
          responseData: errorData,
        );
      } else if (statusCode == 413) {
        throw PhotoUploadException(
          'Файл слишком большой (максимум 10 МБ)',
          statusCode: statusCode,
        );
      } else if (statusCode == 415) {
        throw PhotoUploadException(
          'Неподдерживаемый формат файла (только JPG, PNG)',
          statusCode: statusCode,
        );
      }

      throw PhotoUploadException(
        'Ошибка сети при загрузке фото: ${e.message}',
        statusCode: statusCode,
        responseData: errorData,
      );
    }
  }

  /// Парсинг MIME-типа в MediaType для Dio.
  MediaType _parseMediaType(String mimeType) {
    try {
      return MediaType.parse(mimeType);
    } catch (_) {
      // Fallback на image/jpeg, если парсинг не удался
      return MediaType('image', 'jpeg');
    }
  }

  // ==========================================
  // ОБНОВЛЕНИЕ ТОКЕНА
  // ==========================================

  /// Обновить access token через refresh token.
  /// Возвращает true при успехе, false при неудаче.
  ///
  /// 🔥 ИСПРАВЛЕНО: refresh_token теперь отправляется как FormData,
  /// а не как JSON body. Backend ожидает form-data или query параметр.
  Future<bool> _refreshToken() async {
    // Если уже идёт обновление — добавляем в очередь и ждём
    if (_isRefreshing) {
      final completer = Completer<bool>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        print('⚠️ [ApiClient] Refresh token не найден');
        return false;
      }

      print('🔄 [ApiClient] Обновление access token...');

      // Создаём отдельный Dio-клиент для запроса refresh,
      // чтобы не вызывать интерсепторы основного клиента
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      ));

      // ✅ ИСПРАВЛЕНО: используем FormData вместо JSON body
      // Backend ожидает refresh_token как form-data параметр
      final formData = FormData.fromMap({
        'refresh_token': refreshToken,
      });

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Сохраняем новые токены
        await _tokenStorage.saveAccessToken(data['access_token']);
        await _tokenStorage.saveRefreshToken(data['refresh_token']);

        print('✅ [ApiClient] Access token успешно обновлён');
        return true;
      } else {
        print('❌ [ApiClient] Ошибка refresh: статус ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ [ApiClient] Ошибка сети при refresh: ${e.message}');
      return false;
    } catch (e) {
      print('❌ [ApiClient] Ошибка при refresh: $e');
      return false;
    } finally {
      _isRefreshing = false;
      // Уведомляем все ожидающие запросы о результате
      _notifyRefreshQueue(true);
    }
  }

  /// Уведомить все запросы из очереди о завершении обновления токена.
  void _notifyRefreshQueue(bool success) {
    for (final completer in _refreshQueue) {
      if (!completer.isCompleted) {
        completer.complete(success);
      }
    }
    _refreshQueue.clear();
  }

  /// Логирование ошибок
  void _logError(DioException error) {
    print('❌ [ApiClient Error] ${error.message}');
    print('   URL: ${error.requestOptions.uri}');
    print('   Method: ${error.requestOptions.method}');
    if (error.response != null) {
      print('   Status: ${error.response?.statusCode}');
      print('   Data: ${error.response?.data}');
    }
  }
}

/// Специализированное исключение для ошибок загрузки фото.
class PhotoUploadException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseData;

  PhotoUploadException(
    this.message, {
    this.statusCode,
    this.responseData,
  });

  @override
  String toString() => 'PhotoUploadException: $message (status: $statusCode)';
}