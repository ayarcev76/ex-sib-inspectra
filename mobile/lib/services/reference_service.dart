import 'package:dio/dio.dart';
import '../models/reference_models.dart';
import 'api_client.dart';
import 'database_helper.dart';

/// Сервис для работы со справочниками (ПЕ, Подразделения, Подрядчики, Виды работ, ЗПБ).
/// Обеспечивает оффлайн-доступ через локальное кэширование в SQLite.
class ReferenceService {
  final ApiClient _apiClient;
  final DatabaseHelper _dbHelper;

  // Интервал синхронизации (6 часов)
  static const Duration _syncInterval = Duration(hours: 6);

  ReferenceService(this._apiClient, this._dbHelper);

  // ==========================================
  // Получение данных из локальной базы (оффлайн)
  // ==========================================

  /// Получить все ПЕ (из локальной базы).
  Future<List<PE>> getPEs({bool activeOnly = true}) async {
    return await _dbHelper.getPEs(activeOnly: activeOnly);
  }

  /// Получить подразделения (из локальной базы).
  /// Если передан peId — фильтрует по ПЕ.
  Future<List<Department>> getDepartments({
    String? peId,
    bool activeOnly = true,
  }) async {
    return await _dbHelper.getDepartments(
      peId: peId,
      activeOnly: activeOnly,
    );
  }

  /// Получить всех подрядчиков (из локальной базы).
  Future<List<Contractor>> getContractors({bool activeOnly = true}) async {
    return await _dbHelper.getContractors(activeOnly: activeOnly);
  }

  /// Получить все виды работ (из локальной базы).
  Future<List<WorkType>> getWorkTypes({bool activeOnly = true}) async {
    return await _dbHelper.getWorkTypes(activeOnly: activeOnly);
  }

  /// Получить все ЗПБ (из локальной базы).
  Future<List<ZPBRule>> getZPBRules({bool activeOnly = true}) async {
    return await _dbHelper.getZPBRules(activeOnly: activeOnly);
  }

  // ==========================================
  // Синхронизация с бэкендом
  // ==========================================

  /// Проверить, нужна ли синхронизация.
  /// Возвращает true, если:
  /// - База пуста (первый запуск)
  /// - Прошло больше _syncInterval с последней синхронизации
  Future<bool> needsSync() async {
    final hasData = await _dbHelper.hasData();
    if (!hasData) return true;

    final lastSyncAt = await _dbHelper.getLastSyncAt();
    if (lastSyncAt == null) return true;

    final now = DateTime.now();
    return now.difference(lastSyncAt) > _syncInterval;
  }

  /// Получить метаданные последней синхронизации.
  Future<ReferenceSyncMetadata?> getSyncMetadata() async {
    return await _dbHelper.getSyncMetadata();
  }

  /// Полная синхронизация всех справочников с бэкендом.
  /// Возвращает метаданные синхронизации или выбрасывает исключение при ошибке.
  Future<ReferenceSyncMetadata> syncAll() async {
    print('🔄 [ReferenceService] Начало синхронизации справочников...');

    try {
      // 1. Загружаем ПЕ
      print('📥 Загрузка ПЕ...');
      final peResponse = await _apiClient.get('/api/v1/references/pe');
      final peList = (peResponse.data as List)
          .map((json) => PE.fromJson(json))
          .toList();
      await _dbHelper.upsertPEs(peList);
      print('✅ Загружено ПЕ: ${peList.length}');

      // 2. Загружаем подразделения (для каждого ПЕ)
      print(' Загрузка подразделений...');
      List<Department> allDepartments = [];
      for (var pe in peList) {
        try {
          final deptResponse = await _apiClient.get(
            '/api/v1/references/departments',
            queryParameters: {'pe_id': pe.id},
          );
          final departments = (deptResponse.data as List)
              .map((json) => Department.fromJson(json))
              .toList();
          allDepartments.addAll(departments);
        } catch (e) {
          print('⚠️ Ошибка загрузки подразделений для ПЕ ${pe.name}: $e');
        }
      }
      await _dbHelper.upsertDepartments(allDepartments);
      print('✅ Загружено подразделений: ${allDepartments.length}');

      // 3. Загружаем подрядчиков
      print('📥 Загрузка подрядчиков...');
      final contractorResponse =
          await _apiClient.get('/api/v1/references/contractors');
      final contractors = (contractorResponse.data as List)
          .map((json) => Contractor.fromJson(json))
          .toList();
      await _dbHelper.upsertContractors(contractors);
      print('✅ Загружено подрядчиков: ${contractors.length}');

      // 4. Загружаем виды работ
      print(' Загрузка видов работ...');
      final workTypeResponse =
          await _apiClient.get('/api/v1/references/work-types');
      final workTypes = (workTypeResponse.data as List)
          .map((json) => WorkType.fromJson(json))
          .toList();
      await _dbHelper.upsertWorkTypes(workTypes);
      print('✅ Загружено видов работ: ${workTypes.length}');

      // 5. Загружаем ЗПБ
      print('📥 Загрузка ЗПБ...');
      final zpbResponse =
          await _apiClient.get('/api/v1/references/zpb-rules');
      final zpbRules = (zpbResponse.data as List)
          .map((json) => ZPBRule.fromJson(json))
          .toList();
      await _dbHelper.upsertZPBRules(zpbRules);
      print('✅ Загружено ЗПБ: ${zpbRules.length}');

      // 6. Сохраняем метаданные синхронизации
      final metadata = ReferenceSyncMetadata(
        lastSyncAt: DateTime.now(),
        peCount: peList.length,
        departmentCount: allDepartments.length,
        contractorCount: contractors.length,
        workTypeCount: workTypes.length,
        zpbRuleCount: zpbRules.length,
      );
      await _dbHelper.saveSyncMetadata(metadata);

      print('✅ [ReferenceService] Синхронизация завершена успешно');
      return metadata;
    } on DioException catch (e) {
      print('❌ [ReferenceService] Ошибка сети при синхронизации: ${e.message}');
      throw Exception('Ошибка сети: ${e.message}');
    } catch (e) {
      print('❌ [ReferenceService] Ошибка синхронизации: $e');
      throw Exception('Ошибка синхронизации: $e');
    }
  }

  /// Принудительная синхронизация (игнорирует интервал).
  /// Полезно для pull-to-refresh.
  Future<ReferenceSyncMetadata> forceSync() async {
    print('🔄 [ReferenceService] Принудительная синхронизация...');
    return await syncAll();
  }

  /// Очистить локальный кэш справочников.
  Future<void> clearCache() async {
    await _dbHelper.clearAllData();
    print('✅ [ReferenceService] Кэш справочников очищен');
  }
}