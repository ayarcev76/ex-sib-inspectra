import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reference_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../core/eurochem_colors.dart';
import '../login/login_screen.dart';
import '../inspection/create_inspection_screen.dart';
import '../inspection/drafts_screen.dart';

/// Главный экран приложения (после успешной авторизации).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // 🔥 Получаем размер нижней навигационной панели
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 
                          MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ЕХ:Инспектра-ИПБ'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти из системы',
            onPressed: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
      body: authProvider.currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : Consumer<ReferenceProvider>(
              builder: (context, refProvider, child) {
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(context, authProvider, refProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 🔥 Добавляем динамический padding снизу
                    padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + bottomPadding),
                    children: [
                      _buildProfileCard(context, authProvider),
                      const SizedBox(height: 16),
                      _buildReferencesStatusCard(context, refProvider),
                      const SizedBox(height: 16),
                      _buildDraftsStatusCard(context),
                      const SizedBox(height: 16),
                      _buildQuickAccessSection(context),
                      const SizedBox(height: 16),
                      _buildInfoCard(context),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Обработчик Pull-to-Refresh: синхронизирует справочники и карты наблюдений
  Future<void> _onRefresh(
    BuildContext context,
    AuthProvider authProvider,
    ReferenceProvider refProvider,
  ) async {
    final inspectionProvider = context.read<InspectionProvider>();
    final userId = authProvider.currentUser?['id'];

    if (userId != null) {
      await inspectionProvider.syncAllPending(userId);
    }
    await refProvider.forceSync();

    if (context.mounted) {
      final hasErrors = inspectionProvider.errorMessage != null ||
          refProvider.errorMessage != null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasErrors
                ? 'Синхронизация завершена с ошибками'
                : '✅ Данные успешно синхронизированы',
          ),
          backgroundColor: hasErrors ? Colors.orange : EurochemColors.green,
        ),
      );
    }
  }

  /// Карточка профиля пользователя
  Widget _buildProfileCard(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser!;
    final fullName = user['full_name'] ?? 'Пользователь';
    final email = user['email'] ?? '';

    List<String> roleCodes = [];
    final rolesRaw = user['roles'];
    if (rolesRaw is List) {
      for (var role in rolesRaw) {
        if (role is String) {
          roleCodes.add(role);
        } else if (role is Map) {
          roleCodes.add(
              (role['name'] ?? role['code'] ?? role['id'] ?? 'unknown').toString());
        } else {
          roleCodes.add(role.toString());
        }
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: EurochemColors.primaryBlue,
              child: Text(
                fullName.toString().isNotEmpty
                    ? fullName.toString()[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.toString(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EurochemColors.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.toString(),
                    style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: roleCodes.map((roleCode) {
                      return Chip(
                        label: Text(_getRoleDisplayName(roleCode),
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor: EurochemColors.lightGreen,
                        labelStyle: const TextStyle(
                            color: EurochemColors.primaryBlue,
                            fontWeight: FontWeight.w600),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка статуса справочников
  Widget _buildReferencesStatusCard(
      BuildContext context, ReferenceProvider refProvider) {
    final lastSync = refProvider.lastSyncAt;
    final isSyncing = refProvider.isSyncing;
    final hasError = refProvider.errorMessage != null;

    return Card(
      elevation: 2,
      color: hasError ? Colors.red.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasError
                      ? Icons.warning_amber_rounded
                      : Icons.cloud_done_outlined,
                  color: hasError ? Colors.red : EurochemColors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Справочники (Оффлайн-режим)',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: EurochemColors.primaryBlue),
                  ),
                ),
                if (isSyncing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: EurochemColors.primaryBlue),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('ПЕ', refProvider.peList.length),
                _buildStatItem('Подразд.', refProvider.departmentList.length),
                _buildStatItem('Подряд.', refProvider.contractorList.length),
                _buildStatItem('ЗПБ', refProvider.zpbRuleList.length),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (hasError)
              Text(
                'Ошибка: ${refProvider.errorMessage}',
                style: TextStyle(fontSize: 13, color: Colors.red.shade700),
              )
            else if (lastSync != null)
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: EurochemColors.gray),
                  const SizedBox(width: 6),
                  Text(
                    'Обновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(lastSync)}',
                    style: TextStyle(fontSize: 13, color: EurochemColors.gray),
                  ),
                ],
              )
            else
              Text(
                'Данные не синхронизированы',
                style: TextStyle(fontSize: 13, color: EurochemColors.gray),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSyncing
                    ? null
                    : () async {
                        await refProvider.forceSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                refProvider.errorMessage != null
                                    ? 'Ошибка: ${refProvider.errorMessage}'
                                    : '✅ Справочники обновлены',
                              ),
                              backgroundColor: refProvider.errorMessage != null
                                  ? Colors.red
                                  : EurochemColors.green,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Обновить справочники'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EurochemColors.primaryBlue,
                  side: const BorderSide(color: EurochemColors.primaryBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

/// 🔥 ИСПРАВЛЕННАЯ КАРТОЧКА: Статус карт наблюдений
Widget _buildDraftsStatusCard(BuildContext context) {
  return Consumer<InspectionProvider>(
    builder: (context, inspectionProvider, child) {
      final pendingCount = inspectionProvider.pendingCount;
      final isSyncing = inspectionProvider.isSyncing;
      final hasError = inspectionProvider.errorMessage != null;
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?['id'];

      return Card(
        elevation: 2,
        color: hasError ? Colors.red.shade50 : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с иконкой
              Row(
                children: [
                  Icon(
                    hasError
                        ? Icons.warning_amber_rounded
                        : Icons.assignment_outlined,
                    color: hasError
                        ? Colors.red
                        : pendingCount > 0
                            ? EurochemColors.yellow
                            : EurochemColors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Карты наблюдений',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: EurochemColors.primaryBlue,
                      ),
                    ),
                  ),
                  if (isSyncing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EurochemColors.primaryBlue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Статистика (две строки)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Всего карт: ${inspectionProvider.drafts.length}',
                          style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ожидают отправки: $pendingCount',
                          style: TextStyle(
                            fontSize: 14,
                            color: pendingCount > 0
                                ? EurochemColors.yellow
                                : EurochemColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 🔥 ИСПРАВЛЕНИЕ: Кнопка ПОД статистикой, а не рядом
              if (pendingCount > 0 && userId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSyncing
                        ? null
                        : () async {
                            await inspectionProvider.syncAllPending(userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    inspectionProvider.errorMessage != null
                                        ? 'Ошибка синхронизации'
                                        : '✅ Карты синхронизированы',
                                  ),
                                  backgroundColor: inspectionProvider.errorMessage != null
                                      ? Colors.red
                                      : EurochemColors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: const Text('Отправить на сервер'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EurochemColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],

              // 🔥 ИСПРАВЛЕНИЕ: Убрано отображение ошибки в карточке
              // Ошибка показывается только в SnackBar при действии пользователя
            ],
          ),
        ),
      );
    },
  );
}

  /// Вспомогательный виджет для статистики
  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: EurochemColors.primaryBlue),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: EurochemColors.gray),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Секция быстрого доступа
  Widget _buildQuickAccessSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Быстрый доступ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: EurochemColors.primaryBlue),
            ),
            const SizedBox(height: 16),
            _buildQuickAccessItem(
              context,
              icon: Icons.add_circle_outline,
              title: 'Создать карту наблюдений',
              subtitle: 'Новая карта наблюдений',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreateInspectionScreen()),
                );
              },
            ),
            _buildQuickAccessItem(
              context,
              icon: Icons.list_alt,
              title: 'Мои карты наблюдений',
              subtitle: 'Список созданных карт',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DraftsScreen()),
                );
              },
            ),
            _buildQuickAccessItem(
              context,
              icon: Icons.calendar_today,
              title: 'План инспекций',
              subtitle: 'Расписание проверок',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
            _buildQuickAccessItem(
              context,
              icon: Icons.qr_code_scanner,
              title: 'Сканировать QR',
              subtitle: 'Быстрое заполнение данных объекта',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: EurochemColors.primaryBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: EurochemColors.gray),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: EurochemColors.gray.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  /// Информационная карточка об оффлайн-режиме
  Widget _buildInfoCard(BuildContext context) {
    return Card(
      elevation: 2,
      color: EurochemColors.yellow.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: EurochemColors.yellow, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Оффлайн-режим',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EurochemColors.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Вы можете создавать карты наблюдений даже без интернета. Данные будут синхронизированы автоматически при появлении сети.',
                    style: TextStyle(fontSize: 13, color: EurochemColors.gray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Выход из системы'),
          content: const Text('Вы уверены, что хотите выйти?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => const LoginScreen()));
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );
  }

  String _getRoleDisplayName(dynamic role) {
    String roleCode = '';
    if (role is String) {
      roleCode = role;
    } else if (role is Map) {
      roleCode = (role['name'] ?? role['code'] ?? role['id'] ?? '').toString();
    } else {
      roleCode = role.toString();
    }
    final code = roleCode.trim().toLowerCase();
    const roleMap = {
      'admin': 'Администратор',
      'coordinator': 'Координатор',
      'manager': 'Руководитель',
      'inspector': 'Инспектор',
      'observer': 'Наблюдатель',
      'contractor': 'Подрядчик',
    };
    return roleMap[code] ?? code;
  }
}