import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Сервисы
import 'services/token_storage.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/database_helper.dart';
import 'services/reference_service.dart';
import 'services/inspection_service.dart';
import 'services/sync_manager.dart';
import 'services/auth_event_bus.dart';

// Провайдеры
import 'providers/auth_provider.dart';
import 'providers/reference_provider.dart';
import 'providers/inspection_provider.dart';

// Экраны
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';

/// Корпоративные цвета ЕвроХим из брендбука v1.3
class EurochemColors {
  static const Color primaryBlue = Color(0xFF053868);      // Pantone 2955 C
  static const Color lightBlue = Color(0xFF00B0F0);        // Pantone 2995 C
  static const Color green = Color(0xFF95C11F);            // Pantone 376C
  static const Color yellow = Color(0xFFFFC211);           // Pantone 1235C
  static const Color gray = Color(0xFF6D727A);             // Pantone 431
  static const Color darkBlue = Color(0xFF001529);         // Для сайдбара
  static const Color lightGreen = Color(0xFFE6F7EE);       // Для выделения
}

/// Глобальные экземпляры сервисов
late final TokenStorage _tokenStorage;
late final ApiClient _apiClient;
late final AuthService _authService;
late final BiometricService _biometricService;
late final DatabaseHelper _databaseHelper;
late final ReferenceService _referenceService;
late final InspectionService _inspectionService;
late final SyncManager _syncManager;

/// Глобальные экземпляры провайдеров
late final AuthProvider _authProvider;
late final ReferenceProvider _referenceProvider;
late final InspectionProvider _inspectionProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // ИНИЦИАЛИЗАЦИЯ СЕРВИСОВ (порядок важен!)
  // ==========================================
  _tokenStorage = TokenStorage();
  _apiClient = ApiClient(_tokenStorage);
  _authService = AuthService(_apiClient, _tokenStorage);
  _biometricService = BiometricService();

  // Справочники и инспекции
  _databaseHelper = DatabaseHelper();
  _referenceService = ReferenceService(_apiClient, _databaseHelper);
  _inspectionService = InspectionService(_apiClient, _databaseHelper);

  // ==========================================
  // ИНИЦИАЛИЗАЦИЯ ПРОВАЙДЕРОВ
  // ==========================================
  _authProvider = AuthProvider(_authService, _biometricService);
  _referenceProvider = ReferenceProvider(_referenceService);
  _inspectionProvider = InspectionProvider(_inspectionService);

  // SyncManager с четырьмя параметрами
  _syncManager = SyncManager(
    _inspectionService,
    _authService,
    _databaseHelper,
    _apiClient,
  );

  // ==========================================
  // ИНИЦИАЛИЗАЦИЯ ДАННЫХ
  // ==========================================
  // 1. Проверяем токены и биометрию
  await _authProvider.init();

  // 2. Загружаем локальные справочники (работает без интернета!)
  await _referenceProvider.loadLocalData();

  // 3. Загружаем черновики из локальной БД
  await _inspectionProvider.loadDrafts();

  // 4. Запускаем менеджер синхронизации (отслеживает сеть)
  _syncManager.init();

  runApp(const InspectraApp());
}

/// ✅ ИСПРАВЛЕНО: InspectraApp теперь StatefulWidget для подписки на AuthEventBus
class InspectraApp extends StatefulWidget {
  const InspectraApp({super.key});

  @override
  State<InspectraApp> createState() => _InspectraAppState();
}

class _InspectraAppState extends State<InspectraApp> {
  /// ✅ Ключ для доступа к Navigator из любого места (нужен для обработки событий авторизации)
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// ✅ Подписка на события авторизации (для автоматического logout при истечении токена)
  StreamSubscription<AuthEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Подписываемся на события авторизации из ApiClient
    _authSubscription = _apiClient.authEventBus.stream.listen((event) {
      _handleAuthEvent(event);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// ✅ Обработка событий авторизации
  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.tokenExpired:
      case AuthEventType.tokensCleared:
        _showSessionExpiredDialog(event.message);
        break;
      case AuthEventType.loggedOut:
        _navigateToLogin();
        break;
    }
  }

  /// ✅ Показ диалога об истечении сессии
  void _showSessionExpiredDialog(String? message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: EurochemColors.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: EurochemColors.yellow,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Сессия истекла',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message ?? 'Пожалуйста, войдите снова для продолжения работы.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _navigateToLogin();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: EurochemColors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Войти снова',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Переход на экран входа с очисткой стека навигации
  void _navigateToLogin() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<ReferenceProvider>.value(value: _referenceProvider),
        ChangeNotifierProvider<InspectionProvider>.value(value: _inspectionProvider),
      ],
      child: MaterialApp(
        /// ✅ Передаём navigatorKey для доступа к Navigator из AuthEventBus
        navigatorKey: _navigatorKey,
        title: 'ЕХ:Инспектра-ИПБ',
        debugShowCheckedModeBanner: false,

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: EurochemColors.primaryBlue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          primaryColor: EurochemColors.primaryBlue,
          scaffoldBackgroundColor: Colors.grey[50],

          appBarTheme: const AppBarTheme(
            backgroundColor: EurochemColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: EurochemColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: EurochemColors.gray.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: EurochemColors.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          chipTheme: ChipThemeData(
            backgroundColor: EurochemColors.lightGreen,
            labelStyle: const TextStyle(
              color: EurochemColors.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Маршруты
        initialRoute: '/',
        routes: {
          '/': (context) {
            if (!_authProvider.isInitialized) {
              return const _SplashScreen();
            }
            // ✅ ИСПРАВЛЕНО: Сначала проверяем биометрию!
            // Если пользователь включил биометрию - всегда требуем подтверждение
            if (_authProvider.isBiometricEnabled && _authProvider.isBiometricAvailable) {
              return const _BiometricLoginScreen();
            }
            // Если токены есть (но биометрия не включена) - автоматический вход
            if (_authProvider.isAuthenticated) {
              return const HomeScreen();
            }
            // Иначе - экран обычного входа
            return const LoginScreen();
          },
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

/// Splash-экран
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EurochemColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield,
                size: 70,
                color: EurochemColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ЕХ:Инспектра-ИПБ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Система инспекций производственной безопасности',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран биометрической авторизации
class _BiometricLoginScreen extends StatefulWidget {
  const _BiometricLoginScreen();

  @override
  State<_BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<_BiometricLoginScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.tryAutoLogin();

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      final currentUserId = authProvider.currentUser?['id'] as String?;

      await context.read<ReferenceProvider>().syncReferencesIfNeeded();

      if (currentUserId != null) {
        await context.read<InspectionProvider>().syncAllPending(currentUserId);
      } else {
        print('⚠️ [BiometricLogin] Не удалось получить ID пользователя для синхронизации');
      }

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = 'Не удалось пройти биометрическую авторизацию';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EurochemColors.primaryBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _isAuthenticating
                      ? const Center(
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: EurochemColors.primaryBlue,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.fingerprint,
                          size: 70,
                          color: EurochemColors.primaryBlue,
                        ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Биометрическая авторизация',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Подтвердите свою личность для входа в систему',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 24),
                if (_errorMessage != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: EurochemColors.primaryBlue,
                      ),
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                    child: const Text(
                      'Войти по паролю',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}