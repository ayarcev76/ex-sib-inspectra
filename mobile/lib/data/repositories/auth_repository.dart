import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';

class AuthRepository {
  final DioClient _dioClient;
  final FlutterSecureStorage _secureStorage;

  AuthRepository({required this._dioClient})
      : _secureStorage = const FlutterSecureStorage();

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      // FastAPI OAuth2 ожидает form-urlencoded, а не JSON
      final formData = FormData.fromMap({
        'username': request.username,
        'password': request.password,
      });

      final response = await _dioClient.dio.post(
        ApiConstants.login,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Сохраняем токены безопасно
      await _secureStorage.write(key: 'access_token', value: authResponse.accessToken);
      await _secureStorage.write(key: 'refresh_token', value: authResponse.refreshToken);

      // Устанавливаем токен в Dio для последующих запросов
      _dioClient.setAuthToken(authResponse.accessToken);

      return authResponse;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Ошибка авторизации');
    } catch (e) {
      throw Exception('Неизвестная ошибка: $e');
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
    _dioClient.setAuthToken(null);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }
}