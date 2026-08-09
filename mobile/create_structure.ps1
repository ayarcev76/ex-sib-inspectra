# Переходим в папку мобильного приложения
cd C:\Projects\SIB\ex-sib-inspectra\mobile

# Создаём структуру папок
Write-Host "📁 Создаём структуру папок..." -ForegroundColor Cyan

$folders = @(
    "lib/core",
    "lib/services",
    "lib/providers",
    "lib/screens/login",
    "lib/screens/home"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Write-Host "  ✅ $folder" -ForegroundColor Green
}

# Создаём файл constants.dart
Write-Host "`n📝 Создаём core/constants.dart..." -ForegroundColor Cyan
@"
class AppConstants {
  // Базовый URL вашего бэкенда
  static const String baseUrl = 'http://192.168.0.112:8000';
  
  // API endpoints
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String meEndpoint = '/api/v1/auth/me';
  
  // Таймауты
  static const int connectTimeout = 10000; // 10 секунд
  static const int receiveTimeout = 15000; // 15 секунд
  
  // Ключи для хранения токенов
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
"@ | Out-File -FilePath "lib/core/constants.dart" -Encoding UTF8
Write-Host "  ✅ constants.dart" -ForegroundColor Green

# Создаём файл theme.dart
Write-Host "`n📝 Создаём core/theme.dart..." -ForegroundColor Cyan
@"
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
"@ | Out-File -FilePath "lib/core/theme.dart" -Encoding UTF8
Write-Host "  ✅ theme.dart" -ForegroundColor Green

# Создаём файл token_storage.dart
Write-Host "`n📝 Создаём services/token_storage.dart..." -ForegroundColor Cyan
@"
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class TokenStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Сохранить access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: token,
    );
  }

  // Сохранить refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: token,
    );
  }

  // Получить access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  // Получить refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  // Удалить все токены (при выходе)
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  // Проверить, есть ли токены
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }
}
"@ | Out-File -FilePath "lib/services/token_storage.dart" -Encoding UTF8
Write-Host "  ✅ token_storage.dart" -ForegroundColor Green

# Создаём файл api_client.dart
Write-Host "`n📝 Создаём services/api_client.dart..." -ForegroundColor Cyan
@"
import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'token_storage.dart';

class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;

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

    // Интерсептор для добавления JWT-токена к каждому запросу
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer \$token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Если получили 401 (Unauthorized), пытаемся обновить токен
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Повторяем оригинальный запрос с новым токеном
              final opts = error.requestOptions;
              final newToken = await _tokenStorage.getAccessToken();
              opts.headers['Authorization'] = 'Bearer \$newToken';
              
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Метод для обновления токена
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        AppConstants.refreshEndpoint,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];
        
        await _tokenStorage.saveAccessToken(newAccessToken);
        await _tokenStorage.saveRefreshToken(newRefreshToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // GET запрос
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  // POST запрос
  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  // PUT запрос
  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  // DELETE запрос
  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
"@ | Out-File -FilePath "lib/services/api_client.dart" -Encoding UTF8
Write-Host "  ✅ api_client.dart" -ForegroundColor Green

# Создаём файл auth_service.dart
Write-Host "`n📝 Создаём services/auth_service.dart..." -ForegroundColor Cyan
@"
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService(this._apiClient, this._tokenStorage);

  // Вход в систему
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {
          'username': email, // FastAPI OAuth2 ожидает 'username'
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Сохраняем токены
        await _tokenStorage.saveAccessToken(data['access_token']);
        await _tokenStorage.saveRefreshToken(data['refresh_token']);
        
        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'error': 'Неверный статус ответа: \${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'error': 'Неверный email или пароль',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'error': 'Превышено время ожидания соединения',
        };
      } else {
        return {
          'success': false,
          'error': 'Ошибка сети: \${e.message}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Неизвестная ошибка: \$e',
      };
    }
  }

  // Выход из системы
  Future<void> logout() async {
    await _tokenStorage.clearTokens();
  }

  // Получить информацию о текущем пользователе
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/api/v1/auth/me');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Проверить, авторизован ли пользователь
  Future<bool> isAuthenticated() async {
    return await _tokenStorage.hasTokens();
  }
}
"@ | Out-File -FilePath "lib/services/auth_service.dart" -Encoding UTF8
Write-Host "  ✅ auth_service.dart" -ForegroundColor Green

# Создаём файл auth_provider.dart
Write-Host "`n📝 Создаём providers/auth_provider.dart..." -ForegroundColor Cyan
@"
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  AuthProvider(this._authService);

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Инициализация при запуске приложения
  Future<void> init() async {
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      _currentUser = await _authService.getCurrentUser();
    }
    notifyListeners();
  }

  // Вход в систему
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(email, password);

    _isLoading = false;
    
    if (result['success'] == true) {
      _isAuthenticated = true;
      _currentUser = result['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Выход из системы
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  // Очистить ошибку
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
"@ | Out-File -FilePath "lib/providers/auth_provider.dart" -Encoding UTF8
Write-Host "  ✅ auth_provider.dart" -ForegroundColor Green

# Создаём файл login_screen.dart
Write-Host "`n📝 Создаём screens/login/login_screen.dart..." -ForegroundColor Cyan
@"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Логотип и заголовок
                  Icon(
                    Icons.security,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ЕХ:Инспектра',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Система инспекций безопасности',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Поле Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Некорректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Поле Пароль
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Ошибка
                  if (authProvider.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        authProvider.errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Кнопка входа
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleLogin,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
"@ | Out-File -FilePath "lib/screens/login/login_screen.dart" -Encoding UTF8
Write-Host "  ✅ login_screen.dart" -ForegroundColor Green

# Создаём файл home_screen.dart
Write-Host "`n📝 Создаём screens/home/home_screen.dart..." -ForegroundColor Cyan
@"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../login/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ЕХ:Инспектра'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Добро пожаловать!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (authProvider.currentUser != null)
              Text(
                '\${authProvider.currentUser!['full_name'] ?? 'Пользователь'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: 8),
            if (authProvider.currentUser != null)
              Text(
                '\${authProvider.currentUser!['email'] ?? ''}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
"@ | Out-File -FilePath "lib/screens/home/home_screen.dart" -Encoding UTF8
Write-Host "  ✅ home_screen.dart" -ForegroundColor Green

# Создаём файл router.dart
Write-Host "`n📝 Создаём core/router.dart..." -ForegroundColor Cyan
@"
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../services/token_storage.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final tokenStorage = TokenStorage();
    final hasToken = await tokenStorage.hasTokens();
    
    final isLoginRoute = state.matchedLocation == '/login';
    
    if (!hasToken && !isLoginRoute) {
      return '/login';
    }
    
    if (hasToken && isLoginRoute) {
      return '/home';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/home',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
"@ | Out-File -FilePath "lib/core/router.dart" -Encoding UTF8
Write-Host "  ✅ router.dart" -ForegroundColor Green

Write-Host "`n✅ Структура успешно создана!" -ForegroundColor Green
Write-Host "`n📋 Следующие шаги:" -ForegroundColor Cyan
Write-Host "  1. Обновите main.dart (я предоставлю код)"
Write-Host "  2. Запустите: flutter pub get"
Write-Host "  3. Запустите: flutter run"