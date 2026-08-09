import 'dart:io';
import 'package:dio/dio.dart';
import '../models/inspection_draft.dart';
import '../models/violation_photo.dart';
import 'api_client.dart';
import 'database_helper.dart';

// ==========================================
// DTO для отправки на сервер (согласно ТЗ и Этапу 2.6)
// ==========================================

/// DTO для элемента синхронизации (шапка карты).
class InspectionSyncItem {
  final String clientId;
  final String date; // Формат YYYY-MM-DD
  final String peId;
  final String? departmentId;
  final String inspectorId; // Обязательно для бэкенда
  final String? contractorId;
  final String? workLocation;
  final List<ViolationSyncItem> violations;

  InspectionSyncItem({
    required this.clientId,
    required this.date,
    required this.peId,
    this.departmentId,
    required this.inspectorId,
    this.contractorId,
    this.workLocation,
    required this.violations,
  });

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'date': date,
      'pe_id': peId,
      'department_id': departmentId,
      'inspector_id': inspectorId,
      'contractor_id': contractorId,
      'work_location': workLocation,
      'violations': violations.map((v) => v.toMap()).toList(),
    };
  }
}

/// DTO для нарушения в синхронизации.
class ViolationSyncItem {
  final String workTypeId;
  final bool isSafe;
  final String? violationDescription;
  final bool isGrossViolation;
  final bool isWorkStopped;
  final String? zpbRuleId;
  final int order;

  ViolationSyncItem({
    required this.workTypeId,
    required this.isSafe,
    this.violationDescription,
    this.isGrossViolation = false,
    this.isWorkStopped = false,
    this.zpbRuleId,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'work_type_id': workTypeId,
      'is_safe': isSafe,
      'violation_description': violationDescription,
      'is_gross_violation': isGrossViolation,
      'is_work_stopped': isWorkStopped,
      'zpb_rule_id': zpbRuleId,
      'order': order,
    };
  }
}

/// DTO ответа сервера при синхронизации.
class SyncResponse {
  final String clientId;
  final String? inspectionNumber; // Назначается сервером (INSP-YYMMDD-XXXX)
  final String? serverId; // UUID на сервере
  final String status; // 'created' или 'already_synced'

  SyncResponse({
    required this.clientId,
    this.inspectionNumber,
    this.serverId,
    required this.status,
  });

  factory SyncResponse.fromMap(Map<String, dynamic> map) {
    return SyncResponse(
      clientId: map['client_id'] as String,
      inspectionNumber: map['inspection_number'] as String?,
      serverId: map['server_id'] as String?,
      status: map['status'] as String,
    );
  }
}

// ==========================================
// Сервис инспекций
// ==========================================

/// Сервис для работы с картами наблюдений.
/// Обеспечивает локальное сохранение и пакетную синхронизацию с бэкендом.
/// 🔥 Также загружает фото нарушений после синхронизации инспекций.
class InspectionService {
  final ApiClient _apiClient;
  final DatabaseHelper _dbHelper;

  InspectionService(this._apiClient, this._dbHelper);

  // ==========================================
  // Локальные операции
  // ==========================================

  /// Сохранить черновик карты наблюдений в локальную БД.
  Future<String> saveDraft(InspectionDraft draft) async {
    await _dbHelper.saveInspectionDraft(draft);
    print('✅ [InspectionService] Черновик сохранён локально: ${draft.clientId}');
    return draft.id;
  }

  /// Получить все карты наблюдений.
  Future<List<InspectionDraft>> getDrafts() async {
    return await _dbHelper.getInspectionDrafts();
  }

  /// Получить карту по ID.
  Future<InspectionDraft?> getDraft(String id) async {
    return await _dbHelper.getInspectionDraft(id);
  }

  /// Удалить карту наблюдений (и все связанные нарушения).
  Future<void> deleteDraft(String id) async {
    await _dbHelper.deleteInspectionDraft(id);
    print('✅ [InspectionService] Карта удалена: $id');
  }

  /// Получить количество карт, ожидающих синхронизации.
  Future<int> getPendingCount() async {
    return await _dbHelper.getPendingDraftsCount();
  }

  // ==========================================
  // Синхронизация с сервером (Offline-First)
  // ==========================================

  /// Пакетная синхронизация всех карт со статусом pending.
  /// 🔥 После успешной синхронизации инспекций загружает их фото на сервер.
  Future<int> syncPendingInspections(String currentUserId) async {
    final pendingDrafts = await _dbHelper.getPendingDrafts();

    if (pendingDrafts.isEmpty) {
      print('ℹ️ [InspectionService] Нет карт для синхронизации');
      // Даже если нет новых инспекций, пытаемся загрузить фото
      // (могли остаться от предыдущих неудачных попыток)
      await syncPendingPhotos();
      return 0;
    }

    print('🔄 [InspectionService] Начало синхронизации ${pendingDrafts.length} карт...');

    // 1. Преобразуем локальные черновики в DTO для отправки
    final syncItems = pendingDrafts.map((draft) {
      return InspectionSyncItem(
        clientId: draft.clientId,
        date: draft.date.toIso8601String().split('T')[0], // YYYY-MM-DD
        peId: draft.peId,
        departmentId: draft.departmentId,
        inspectorId: currentUserId, // ID текущего инспектора
        contractorId: draft.contractorId,
        workLocation: draft.workLocation,
        violations: draft.violations.map((v) {
          return ViolationSyncItem(
            workTypeId: v.workTypeId,
            isSafe: v.isSafe,
            violationDescription: v.violationDescription,
            isGrossViolation: v.isGrossViolation,
            isWorkStopped: v.isWorkStopped,
            zpbRuleId: v.zpbRuleId,
            order: v.order,
          );
        }).toList(),
      );
    }).toList();

    try {
      // 2. Отправляем пакетный запрос на сервер
      final response = await _apiClient.post(
        '/api/v1/inspections/sync',
        data: syncItems.map((item) => item.toMap()).toList(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Ошибка сервера при синхронизации: статус ${response.statusCode}');
      }

      // 3. Обрабатываем ответ
      final responseData = response.data as List;
      int syncedCount = 0;

      for (var responseMap in responseData) {
        final syncResponse = SyncResponse.fromMap(responseMap);

        // Находим соответствующий локальный черновик по client_id
        final draft = pendingDrafts.firstWhere(
          (d) => d.clientId == syncResponse.clientId,
          orElse: () => throw Exception('Не найден черновик с client_id ${syncResponse.clientId}'),
        );

        if (syncResponse.status == 'created' || syncResponse.status == 'already_synced') {
          // Отмечаем как синхронизированный (сохраняем номер и server_id)
          await _dbHelper.markDraftAsSynced(
            draft.id,
            syncResponse.serverId,
            syncResponse.inspectionNumber,
          );
          syncedCount++;
          print('✅ [InspectionService] Карта ${draft.clientId} синхронизирована: ${syncResponse.inspectionNumber}');
        } else {
          // Неизвестный статус — помечаем как ошибку
          await _dbHelper.markDraftAsFailed(draft.id, 'Неизвестный статус: ${syncResponse.status}');
          print('⚠️ [InspectionService] Карта ${draft.clientId} не синхронизирована: ${syncResponse.status}');
        }
      }

      print('✅ [InspectionService] Синхронизация инспекций завершена: $syncedCount из ${pendingDrafts.length}');

      // 4. 🔥 НОВОЕ: После синхронизации инспекций загружаем их фото
      await syncPendingPhotos();

      return syncedCount;
    } on DioException catch (e) {
      print('❌ [InspectionService] Ошибка сети при синхронизации: ${e.message}');

      // Отмечаем все как failed
      for (var draft in pendingDrafts) {
        await _dbHelper.markDraftAsFailed(draft.id, 'Ошибка сети: ${e.message}');
      }

      throw Exception('Ошибка сети: ${e.message}');
    } catch (e) {
      print('❌ [InspectionService] Ошибка синхронизации: $e');

      // Отмечаем все как failed
      for (var draft in pendingDrafts) {
        await _dbHelper.markDraftAsFailed(draft.id, e.toString());
      }

      throw Exception('Ошибка синхронизации: $e');
    }
  }

  /// 🔥 НОВОЕ: Загрузка всех фото со статусом "pending" на сервер.
  /// Использует inspection_client_id + violation_order для поиска нарушения на сервере.
  /// Вызывается автоматически после синхронизации инспекций.
  Future<void> syncPendingPhotos() async {
    final pendingPhotos = await _dbHelper.getPendingPhotos();
    if (pendingPhotos.isEmpty) {
      return;
    }

    print('📸 [InspectionService] Найдено фото для загрузки: ${pendingPhotos.length}');

    int successCount = 0;
    int failCount = 0;

    for (final photo in pendingPhotos) {
      try {
        // 1. Находим нарушение для получения order_num
        final violation = await _dbHelper.getViolationById(photo.violationId);
        if (violation == null) {
          print('⚠️ [InspectionService] Нарушение не найдено: ${photo.violationId}');
          await _dbHelper.deletePhoto(photo.id);
          continue;
        }

        // 2. Проверяем, что нарушение привязано к инспекции
        final inspectionId = violation.inspectionId;
        if (inspectionId == null) {
          print('⚠️ [InspectionService] Нарушение не привязано к инспекции: ${violation.id}');
          continue;
        }

        // 3. Находим инспекцию для получения client_id
        final inspection = await _dbHelper.getInspectionDraft(inspectionId);
        if (inspection == null) {
          print('⚠️ [InspectionService] Инспекция не найдена: $inspectionId');
          continue;
        }

        // 4. Проверяем, что инспекция уже синхронизирована
        if (inspection.syncStatus != SyncStatus.synced) {
          print('⏳ [InspectionService] Инспекция ещё не синхронизирована, пропускаем фото');
          continue;
        }

        // 5. Проверяем существование файла на диске
        final file = File(photo.localPath);
        if (!await file.exists()) {
          print('⚠️ [InspectionService] Файл не найден на диске, удаляем запись: ${photo.localPath}');
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

        print('✅ [InspectionService] Фото загружено: ${photo.originalFilename} → $serverPhotoId');

      } catch (e) {
        print('⚠️ [InspectionService] Ошибка загрузки фото ${photo.id}: $e');
        // Помечаем как failed — попробуем снова при следующей синхронизации
        await _dbHelper.markPhotoFailed(photo.id);
        failCount++;
      }
    }

    print(
      '🏁 [InspectionService] Итог загрузки фото: '
      'успешно=$successCount, ошибок=$failCount, всего=${pendingPhotos.length}',
    );
  }

  /// Принудительная повторная синхронизация одной карты (например, после ошибки).
  Future<void> retrySync(String draftId, String currentUserId) async {
    final draft = await _dbHelper.getInspectionDraft(draftId);
    if (draft == null) {
      throw Exception('Карта не найдена: $draftId');
    }

    // Сбрасываем статус failed на pending
    await _dbHelper.updateDraftStatus(draftId, 'pending');

    // Синхронизируем только эту карту
    final syncItem = InspectionSyncItem(
      clientId: draft.clientId,
      date: draft.date.toIso8601String().split('T')[0],
      peId: draft.peId,
      departmentId: draft.departmentId,
      inspectorId: currentUserId,
      contractorId: draft.contractorId,
      workLocation: draft.workLocation,
      violations: draft.violations.map((v) {
        return ViolationSyncItem(
          workTypeId: v.workTypeId,
          isSafe: v.isSafe,
          violationDescription: v.violationDescription,
          isGrossViolation: v.isGrossViolation,
          isWorkStopped: v.isWorkStopped,
          zpbRuleId: v.zpbRuleId,
          order: v.order,
        );
      }).toList(),
    );

    final response = await _apiClient.post(
      '/api/v1/inspections/sync',
      data: [syncItem.toMap()], // Чистый список из одного элемента
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка сервера: статус ${response.statusCode}');
    }

    final responseData = response.data as List;
    if (responseData.isNotEmpty) {
      final syncResponse = SyncResponse.fromMap(responseData.first);
      await _dbHelper.markDraftAsSynced(
        draftId,
        syncResponse.serverId,
        syncResponse.inspectionNumber,
      );

      // 🔥 НОВОЕ: после успешной синхронизации загружаем фото
      await syncPendingPhotos();
    }
  }
}