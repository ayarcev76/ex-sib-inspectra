import 'package:flutter/foundation.dart';
import '../services/reference_service.dart';
import '../models/reference_models.dart';

/// Провайдер для управления состоянием справочников (ПЕ, Подразделения, и т.д.).
/// Обеспечивает работу с локальным кэшем и синхронизацию с сервером.
class ReferenceProvider with ChangeNotifier {
  final ReferenceService _referenceService;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  DateTime? _lastSyncAt;

  List<PE> _peList = [];
  List<Department> _departmentList = [];
  List<Contractor> _contractorList = [];
  List<WorkType> _workTypeList = [];
  List<ZPBRule> _zpbRuleList = [];

  ReferenceProvider(this._referenceService);

  // === Геттеры для UI ===
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncAt => _lastSyncAt;
  
  List<PE> get peList => _peList;
  List<Department> get departmentList => _departmentList;
  List<Contractor> get contractorList => _contractorList;
  List<WorkType> get workTypeList => _workTypeList;
  List<ZPBRule> get zpbRuleList => _zpbRuleList;

  /// Загрузить данные из локальной базы данных (оффлайн).
  /// Вызывается при старте приложения.
  Future<void> loadLocalData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _peList = await _referenceService.getPEs();
      _departmentList = await _referenceService.getDepartments();
      _contractorList = await _referenceService.getContractors();
      _workTypeList = await _referenceService.getWorkTypes();
      _zpbRuleList = await _referenceService.getZPBRules();

      final metadata = await _referenceService.getSyncMetadata();
      _lastSyncAt = metadata?.lastSyncAt;
    } catch (e) {
      _errorMessage = 'Ошибка загрузки локальных данных: $e';
      print('❌ [ReferenceProvider] Ошибка загрузки: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Проверить и выполнить синхронизацию с бэкендом, если она необходима.
  /// Вызывается после успешного логина.
  Future<void> syncReferencesIfNeeded() async {
    try {
      final needsSync = await _referenceService.needsSync();
      if (needsSync) {
        await _syncWithBackend();
      } else {
        print('✅ [ReferenceProvider] Синхронизация не требуется, используем кэш');
      }
    } catch (e) {
      print('❌ [ReferenceProvider] Ошибка проверки синхронизации: $e');
    }
  }

  /// Принудительная синхронизация (например, по кнопке "Обновить").
  Future<void> forceSync() async {
    await _syncWithBackend();
  }

  /// Внутренний метод синхронизации.
  Future<void> _syncWithBackend() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final metadata = await _referenceService.syncAll();
      _lastSyncAt = metadata.lastSyncAt;
      
      // После успешной синхронизации перезагружаем локальные данные
      await loadLocalData();
      
      print('✅ [ReferenceProvider] Синхронизация завершена');
    } catch (e) {
      _errorMessage = 'Ошибка синхронизации: $e';
      print('❌ [ReferenceProvider] Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Получить подразделения для конкретного ПЕ (для каскадной фильтрации).
  List<Department> getDepartmentsForPE(String peId) {
    return _departmentList.where((dept) => dept.peId == peId).toList();
  }

  /// Очистить сообщение об ошибке.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}