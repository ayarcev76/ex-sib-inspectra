import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/eurochem_colors.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/auth_provider.dart'; // 🔥 ДОБАВЛЕНО: для получения ID пользователя
import '../../models/inspection_draft.dart';

/// Экран списка карт наблюдений.
/// Отображает все карты с их статусами синхронизации.
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 Получаем размер нижней навигационной панели
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 
                          MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои карты наблюдений'),
        actions: [
          Consumer<InspectionProvider>(
            builder: (context, provider, child) {
              if (provider.pendingCount == 0) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: provider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Синхронизировать (${provider.pendingCount})',
                onPressed: provider.isSyncing
                    ? null
                    : () => _syncAll(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: EurochemColors.gray),
                  const SizedBox(height: 16),
                  Text(
                    'Нет карт наблюдений',
                    style: TextStyle(fontSize: 18, color: EurochemColors.gray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте первую карту наблюдений',
                    style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadDrafts(),
            child: ListView.builder(
              // 🔥 Добавляем динамический padding снизу
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              itemCount: provider.drafts.length,
              itemBuilder: (context, index) {
                final draft = provider.drafts[index];
                return _DraftCard(draft: draft);
              },
            ),
          );
        },
      ),
    );
  }


  /// Ручная синхронизация всех pending карт.
  Future<void> _syncAll(BuildContext context) async {
    // 🔥 ИСПРАВЛЕНО: Получаем ID текущего пользователя для передачи на бэкенд
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?['id'] as String?;

    if (currentUserId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Не удалось получить данные пользователя'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final provider = context.read<InspectionProvider>();
    final count = await provider.syncAllPending(currentUserId); // 🔥 ИСПРАВЛЕНО: передаем currentUserId

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '✅ Синхронизировано: $count карт'
                : 'Нет карт для синхронизации',
          ),
          backgroundColor: count > 0 ? EurochemColors.green : EurochemColors.gray,
        ),
      );
    }
  }
}

/// Карточка одной карты наблюдений.
class _DraftCard extends StatelessWidget {
  final InspectionDraft draft;

  const _DraftCard({required this.draft});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      // Синхронизированные карты не кликабельны
      child: InkWell(
        onTap: draft.canEdit
            ? () {
                // TODO: Навигация на экран редактирования
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Редактирование карты ${_getDisplayNumber()}')),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок: номер и статус
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _getDisplayNumber(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: draft.syncStatus == SyncStatus.synced
                            ? EurochemColors.primaryBlue
                            : EurochemColors.gray,
                      ),
                    ),
                  ),
                  _StatusBadge(status: draft.syncStatus),
                ],
              ),
              const SizedBox(height: 12),

              // Дата создания
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: EurochemColors.gray),
                  const SizedBox(width: 8),
                  Text(
                    'Создана: ${DateFormat('dd.MM.yyyy HH:mm').format(draft.createdAt)}',
                    style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Дата проверки
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: EurochemColors.gray),
                  const SizedBox(width: 8),
                  Text(
                    'Дата проверки: ${DateFormat('dd.MM.yyyy').format(draft.date)}',
                    style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Количество нарушений
              Row(
                children: [
                  Icon(Icons.list_alt, size: 16, color: EurochemColors.gray),
                  const SizedBox(width: 8),
                  Text(
                    'Наблюдений: ${draft.violations.length}',
                    style: TextStyle(fontSize: 14, color: EurochemColors.gray),
                  ),
                ],
              ),

              // Ошибка синхронизации (если есть)
              if (draft.syncStatus == SyncStatus.failed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ошибка синхронизации',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Кнопки действий
              if (draft.syncStatus != SyncStatus.synced) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Кнопка "Синхронизировать" или "Повторить"
                    if (draft.syncStatus == SyncStatus.pending || draft.syncStatus == SyncStatus.failed)
                      TextButton.icon(
                        onPressed: () => _retrySync(context),
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(
                          draft.syncStatus == SyncStatus.failed ? 'Повторить' : 'Синхронизировать',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: EurochemColors.primaryBlue,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Кнопка "Удалить"
                    TextButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Удалить'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Получить отображаемый номер карты.
  String _getDisplayNumber() {
    if (draft.syncStatus == SyncStatus.synced && draft.inspectionNumber != null) {
      return draft.inspectionNumber!;
    }
    // Для pending/failed показываем client_id (короткий UUID)
    return 'Черновик ${draft.clientId.substring(0, 8)}';
  }

  /// Повторная синхронизация одной карты.
  Future<void> _retrySync(BuildContext context) async {
    // 🔥 ИСПРАВЛЕНО: Получаем ID текущего пользователя
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?['id'] as String?;

    if (currentUserId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Не удалось получить данные пользователя'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final provider = context.read<InspectionProvider>();
    // 🔥 ИСПРАВЛЕНО: передаем currentUserId
    await provider.retrySync(draft.id, currentUserId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage != null
                ? '❌ Ошибка: ${provider.errorMessage}'
                : '✅ Карта синхронизирована',
          ),
          backgroundColor: provider.errorMessage != null
              ? Colors.red
              : EurochemColors.green,
        ),
      );
    }
  }

  /// Диалог подтверждения удаления.
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить карту?'),
          content: Text('Вы уверены, что хотите удалить карту ${_getDisplayNumber()}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await context.read<InspectionProvider>().deleteDraft(draft.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Карта удалена'),
                      backgroundColor: EurochemColors.green,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }
}

/// Бейдж статуса синхронизации.
class _StatusBadge extends StatelessWidget {
  final SyncStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case SyncStatus.pending:
        backgroundColor = EurochemColors.yellow;
        textColor = EurochemColors.yellow;
        label = 'Ожидает';
        icon = Icons.cloud_upload_outlined;
        break;
      case SyncStatus.syncing:  // ← НОВОЕ: статус "в процессе синхронизации"
        backgroundColor = EurochemColors.primaryBlue;
        textColor = EurochemColors.primaryBlue;
        label = 'Синхронизация...';
        icon = Icons.sync;
        break;
      case SyncStatus.synced:
        backgroundColor = EurochemColors.green;
        textColor = EurochemColors.green;
        label = 'Синхронизировано';
        icon = Icons.check_circle_outline;
        break;
      case SyncStatus.failed:
        backgroundColor = Colors.red;
        textColor = Colors.red;
        label = 'Ошибка';
        icon = Icons.error_outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}