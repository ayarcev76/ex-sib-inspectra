import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'inspection_service.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'api_client.dart';

/// Менеджер синхронизации оффлайн-данных с сервером.
/// Отслеживает состояние сети и автоматически запускает синхронизацию
/// черновиков проверок и фотографий при появлении подключения.
class SyncManager {
  final InspectionService _inspectionService;
  final AuthService _authService;
  final DatabaseHelper _dbHelper;
  final ApiClient _apiClient;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;
  bool _isSyncing = false; // Защита от повторных запусков

  SyncManager(
    this._inspectionService,
    this._authService,
    this._dbHelper,
    this._apiClient,
  );

  /// Инициализация менеджера: проверка текущего состояния сети и подписка.
  void init() {
    _checkConnectivity();

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _handleConnectivityChange(results);
      },
    );

    print('✅ [SyncManager] Менеджер синхронизации инициализирован');
  }

  /// Ручной запуск синхронизации (например, по кнопке в UI).
  Future<void> forceSync() async {
    if (!_isOnline) {
      print('📴 [SyncManager] Нет сети — синхронизация невозможна');
      return;
    }
    await _autoSync();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      print('🌐 [SyncManager] Сеть появилась, запускаем синхронизацию...');
      _autoSync();
    } else if (!_isOnline && wasOnline) {
      print('📴 [SyncManager] Сеть пропала');
    }
  }

  /// Главный метод автосинхронизации: проверки → фото.
  Future<void> _autoSync() async {
    if (_isSyncing) {
      print('⏳ [SyncManager] Синхронизация уже запущена, пропускаем');
      return;
    }

    _isSyncing = true;
    try {
      // 🔥 ПОЛУЧАЕМ ID ПОЛЬЗОВАТЕЛЯ ИЗ КЭША
      final profile = await _authService.getLocalUserProfile();
      final userId = profile?['id'] as String?;

      if (userId == null) {
        print('⚠️ [SyncManager] Не удалось получить ID пользователя для синхронизации');
        return;
      }

      // 1. СНАЧАЛА синхронизируем проверки (чтобы получить server_id нарушений)
      await _inspectionService.syncPendingInspections(userId);

      // 2. ЗАТЕМ синхронизируем фото нарушений
      await _syncPendingPhotos();
    } catch (e) {
      print('❌ [SyncManager] Ошибка автосинхронизации: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Загрузка всех фото со статусом "pending" на сервер.
  /// Вызывается после успешной синхронизации нарушений.
  Future<void> _syncPendingPhotos() async {
    final pendingPhotos = await _dbHelper.getPendingPhotos();
    if (pendingPhotos.isEmpty) {
      return;
    }

    print('📸 [SyncManager] Найдено фото для загрузки: ${pendingPhotos.length}');

    int successCount = 0;
    int failCount = 0;

    for (final photo in pendingPhotos) {
      try {
        // 1. Находим нарушение для получения order_num
        final violation = await _dbHelper.getViolationById(photo.violationId);
        if (violation == null) {
          print('⚠️ [SyncManager] Нарушение не найдено: ${photo.violationId}');
          await _dbHelper.deletePhoto(photo.id);
          continue;
        }

        // 2. Проверяем, что нарушение привязано к инспекции
        final inspectionId = violation.inspectionId;
        if (inspectionId == null) {
          print('⚠️ [SyncManager] Нарушение не привязано к инспекции: ${violation.id}');
          continue;
        }

        // 3. Находим инспекцию для получения client_id
        final inspection = await _dbHelper.getInspectionDraft(inspectionId);
        if (inspection == null) {
          print('⚠️ [SyncManager] Инспекция не найдена: $inspectionId');
          continue;
        }

        // 4. Проверяем, что инспекция уже синхронизирована
        if (inspection.syncStatus.name != 'synced') {
          print('⏳ [SyncManager] Инспекция ещё не синхронизирована, пропускаем фото');
          continue;
        }

        // 5. Проверяем существование файла на диске
        final file = File(photo.localPath);
        if (!await file.exists()) {
          print('⚠️ [SyncManager] Файл не найден на диске, удаляем запись: ${photo.localPath}');
          await _dbHelper.deletePhoto(photo.id);
          continue;
        }

        // 6. Читаем байты файла
        final bytes = await file.readAsBytes();

        // 7. Загружаем на сервер через multipart
        final serverPhotoId = await _apiClient.uploadPhoto(
          inspectionClientId: inspection.clientId,
          violationOrder: violation.order,
          fileBytes: bytes,
          filename: photo.originalFilename,
          mimeType: photo.mimeType,
          gpsLatitude: photo.gpsLatitude,
          gpsLongitude: photo.gpsLongitude,
          takenAt: photo.takenAt,
        );

        // 8. Отмечаем фото как синхронизированное
        await _dbHelper.markPhotoSynced(photo.id, serverPhotoId);
        successCount++;

        print('✅ [SyncManager] Фото загружено: ${photo.originalFilename} → $serverPhotoId');

      } catch (e) {
        print('⚠️ [SyncManager] Ошибка загрузки фото ${photo.id}: $e');
        // Помечаем как failed — попробуем снова при следующей синхронизации
        await _dbHelper.markPhotoFailed(photo.id);
        failCount++;
      }
    }

    print(
      '🏁 [SyncManager] Итог загрузки фото: '
      'успешно=$successCount, ошибок=$failCount, всего=${pendingPhotos.length}',
    );
  }
  
  void dispose() {
    _subscription?.cancel();
  }
}