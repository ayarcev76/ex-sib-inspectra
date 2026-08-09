import 'package:flutter/foundation.dart';
import '../models/inspection_draft.dart';
import '../services/inspection_service.dart';

/// Провайдер для управления картами наблюдений (черновиками).
class InspectionProvider with ChangeNotifier {
  final InspectionService _inspectionService;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  List<InspectionDraft> _drafts = [];
  int _pendingCount = 0;

  InspectionProvider(this._inspectionService);

  // Геттеры
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  List<InspectionDraft> get drafts => _drafts;
  int get pendingCount => _pendingCount;

  /// Загрузить все черновики из локальной БД.
  Future<void> loadDrafts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _drafts = await _inspectionService.getDrafts();
      _pendingCount = _drafts.where((d) => d.syncStatus == SyncStatus.pending).length;
      print('✅ [InspectionProvider] Загружено карт наблюдений: ${_drafts.length}, ожидают синхронизации: $_pendingCount');
    } catch (e) {
      _errorMessage = 'Ошибка загрузки: $e';
      print('❌ [InspectionProvider] Ошибка: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Сохранить новую карту наблюдений.
  Future<String?> saveDraft(InspectionDraft draft) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _inspectionService.saveDraft(draft);
      await loadDrafts();
      print('✅ [InspectionProvider] Карта сохранена: $id');
      return id;
    } catch (e) {
      _errorMessage = 'Ошибка сохранения: $e';
      print('❌ [InspectionProvider] Ошибка: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔥 НОВОЕ: Удалить черновик.
  Future<void> deleteDraft(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _inspectionService.deleteDraft(id);
      await loadDrafts(); // Перезагружаем список после удаления
      print('✅ [InspectionProvider] Черновик удалён: $id');
    } catch (e) {
      _errorMessage = 'Ошибка удаления: $e';
      print('❌ [InspectionProvider] Ошибка: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Синхронизировать все карты со статусом pending.
  Future<int> syncAllPending(String currentUserId) async {
    if (_isSyncing) return 0;

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final count = await _inspectionService.syncPendingInspections(currentUserId);
      await loadDrafts();
      print('✅ [InspectionProvider] Синхронизировано: $count');
      return count;
    } catch (e) {
      _errorMessage = 'Ошибка синхронизации: $e';
      print('❌ [InspectionProvider] Ошибка: $e');
      return 0;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Принудительная синхронизация одной карты (для повторной попытки).
  Future<void> retrySync(String clientId, String currentUserId) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _inspectionService.retrySync(clientId, currentUserId);
      await loadDrafts();
      print('✅ [InspectionProvider] Повторная синхронизация успешна: $clientId');
    } catch (e) {
      _errorMessage = 'Ошибка повторной синхронизации: $e';
      print('❌ [InspectionProvider] Ошибка: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Очистить сообщение об ошибке.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}