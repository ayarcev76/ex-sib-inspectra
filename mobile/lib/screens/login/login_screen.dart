import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/eurochem_colors.dart';

/// Экран входа в систему.
/// Корпоративный стиль ЕВРОХИМ: синий #053868.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  // Состояние чекбокса биометрии
  bool _useBiometric = false;

  @override
  void initState() {
    super.initState();
    // Если биометрия уже включена — отмечаем чекбокс
    final authProvider = context.read<AuthProvider>();
    _useBiometric = authProvider.isBiometricEnabled;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Обработка нажатия кнопки "Войти"
  Future<void> _handleLogin() async {
    // Сбрасываем предыдущую ошибку
    context.read<AuthProvider>().clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.login(email, password);

    if (!mounted) return;

    if (success) {
      // Если пользователь отметил чекбокс биометрии — предлагаем подтвердить
      if (_useBiometric && authProvider.isBiometricAvailable) {
        await _confirmBiometric(email, password);
      } else {
        // Переход на главный экран
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
    // При ошибке сообщение уже сохранено в authProvider.errorMessage
    // и автоматически отобразится в UI через Consumer
  }

  /// Диалог подтверждения биометрии после успешного входа
  Future<void> _confirmBiometric(String email, String password) async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Показываем системный диалог биометрии
    final confirmed = await authProvider.enableBiometricWithConfirmation(
      email,
      password,
    );

    if (!mounted) return;

    if (confirmed) {
      // Биометрия успешно подтверждена и сохранена
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Биометрический вход включён'),
            backgroundColor: EurochemColors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Пользователь отменил или не прошёл биометрию
      // Сбрасываем чекбокс
      setState(() {
        _useBiometric = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Биометрический вход не включён'),
            backgroundColor: EurochemColors.gray,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // В любом случае переходим на главный экран
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Логотип
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: EurochemColors.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield,
                          size: 60,
                          color: EurochemColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Заголовок
                      const Text(
                        'ЕХ:Инспектра-ИПБ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: EurochemColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Система инспекций производственной безопасности',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: EurochemColors.gray,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Поле Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: EurochemColors.primaryBlue),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите email';
                          }
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Некорректный формат email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Поле Пароль
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline, color: EurochemColors.primaryBlue),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: EurochemColors.gray,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите пароль';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🔐 Чекбокс "Использовать биометрию"
                      if (authProvider.isBiometricAvailable)
                        CheckboxListTile(
                          value: _useBiometric,
                          onChanged: (value) {
                            setState(() {
                              _useBiometric = value ?? false;
                            });
                          },
                          title: const Text(
                            'Использовать биометрию для быстрого входа',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'Вход по отпечатку пальца или лицу',
                            style: TextStyle(
                              fontSize: 12,
                              color: EurochemColors.gray,
                            ),
                          ),
                          secondary: Icon(
                            Icons.fingerprint,
                            color: EurochemColors.primaryBlue,
                          ),
                          activeColor: EurochemColors.primaryBlue,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      if (!authProvider.isBiometricAvailable)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: EurochemColors.gray.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: EurochemColors.gray, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Биометрия не настроена на этом устройстве',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: EurochemColors.gray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Сообщение об ошибке
                      if (authProvider.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (authProvider.errorMessage != null)
                        const SizedBox(height: 16),

                      // Кнопка "Войти"
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EurochemColors.primaryBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: EurochemColors.primaryBlue.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}