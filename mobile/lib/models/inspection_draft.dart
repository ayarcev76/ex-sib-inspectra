import 'package:uuid/uuid.dart';
import 'violation_photo.dart';

/// Статусы синхронизации черновиков с сервером.
enum SyncStatus {
  pending,   // Ожидает синхронизации
  syncing,   // В процессе синхронизации
  synced,    // Успешно синхронизировано
  failed,    // Ошибка синхронизации
}

/// Черновик строки нарушения (локальная модель для SQLite).
class ViolationDraft {
  final String id;
  final String? inspectionId;
  final String workTypeId;
  final bool isSafe;
  final String? violationDescription;
  final bool isGrossViolation;
  final bool isWorkStopped;
  final String? zpbRuleId;
  final bool isTopViolation;
  final int order;
  final List<ViolationPhoto> photos;

  ViolationDraft({
    String? id,
    this.inspectionId,
    required this.workTypeId,
    required this.isSafe,
    this.violationDescription,
    this.isGrossViolation = false,
    this.isWorkStopped = false,
    this.zpbRuleId,
    this.isTopViolation = false,
    required this.order,
    this.photos = const [],
  }) : id = id ?? const Uuid().v4();

  /// Создание копии с изменёнными полями.
  ViolationDraft copyWith({
    String? id,
    String? inspectionId,
    String? workTypeId,
    bool? isSafe,
    String? violationDescription,
    bool? isGrossViolation,
    bool? isWorkStopped,
    String? zpbRuleId,
    bool? isTopViolation,
    int? order,
    List<ViolationPhoto>? photos,
  }) {
    return ViolationDraft(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      workTypeId: workTypeId ?? this.workTypeId,
      isSafe: isSafe ?? this.isSafe,
      violationDescription: violationDescription ?? this.violationDescription,
      isGrossViolation: isGrossViolation ?? this.isGrossViolation,
      isWorkStopped: isWorkStopped ?? this.isWorkStopped,
      zpbRuleId: zpbRuleId ?? this.zpbRuleId,
      isTopViolation: isTopViolation ?? this.isTopViolation,
      order: order ?? this.order,
      photos: photos ?? this.photos,
    );
  }

  /// Добавить фото к нарушению.
  ViolationDraft addPhoto(ViolationPhoto photo) {
    return copyWith(photos: [...photos, photo]);
  }

  /// Удалить фото из нарушения.
  ViolationDraft removePhoto(String photoId) {
    return copyWith(photos: photos.where((p) => p.id != photoId).toList());
  }

  /// Преобразование в Map для SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'work_type_id': workTypeId,
      'is_safe': isSafe ? 1 : 0,
      'violation_description': violationDescription,
      'is_gross_violation': isGrossViolation ? 1 : 0,
      'is_work_stopped': isWorkStopped ? 1 : 0,
      'zpb_rule_id': zpbRuleId,
      'is_top_violation': isTopViolation ? 1 : 0,
      'order_num': order,
    };
  }

  /// Создание из Map (чтение из SQLite).
  factory ViolationDraft.fromMap(Map<String, dynamic> map) {
    return ViolationDraft(
      id: map['id'] as String,
      inspectionId: map['inspection_id'] as String?,
      workTypeId: map['work_type_id'] as String,
      isSafe: map['is_safe'] == 1,
      violationDescription: map['violation_description'] as String?,
      isGrossViolation: map['is_gross_violation'] == 1,
      isWorkStopped: map['is_work_stopped'] == 1,
      zpbRuleId: map['zpb_rule_id'] as String?,
      isTopViolation: map['is_top_violation'] == 1,
      order: map['order_num'] as int,
    );
  }
}

/// Черновик карты наблюдений (локальная модель для SQLite).
class InspectionDraft {
  final String id;
  final String clientId;
  final String? inspectionNumber;
  final String? serverId;
  final SyncStatus syncStatus;
  final DateTime date;
  final String peId;
  final String? departmentId;
  final String? contractorId;
  final String? workLocation;
  final List<ViolationDraft> violations;
  final DateTime createdAt;

  InspectionDraft({
    String? id,
    String? clientId,
    this.inspectionNumber,
    this.serverId,
    SyncStatus? syncStatus,
    required this.date,
    required this.peId,
    this.departmentId,
    this.contractorId,
    this.workLocation,
    this.violations = const [],
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        clientId = clientId ?? const Uuid().v4(),
        syncStatus = syncStatus ?? SyncStatus.pending,
        createdAt = createdAt ?? DateTime.now();

  // ▼▼▼ ГЕТТЕРЫ (безопасное место: после конструктора) ▼▼▼

  /// Можно ли редактировать черновик.
  bool get canEdit =>
      syncStatus == SyncStatus.pending || syncStatus == SyncStatus.failed;

  /// Можно ли удалить черновик.
  bool get canDelete => syncStatus != SyncStatus.syncing;

  /// Черновик ожидает синхронизации.
  bool get isPending => syncStatus == SyncStatus.pending;

  /// Черновик успешно синхронизирован.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Черновик с ошибкой синхронизации.
  bool get isFailed => syncStatus == SyncStatus.failed;

  // ▲▲▲ КОНЕЦ ГЕТТЕРОВ ▲▲▲

  /// Создание копии с изменёнными полями.
  InspectionDraft copyWith({
    String? id,
    String? clientId,
    String? inspectionNumber,
    String? serverId,
    SyncStatus? syncStatus,
    DateTime? date,
    String? peId,
    String? departmentId,
    String? contractorId,
    String? workLocation,
    List<ViolationDraft>? violations,
    DateTime? createdAt,
  }) {
    return InspectionDraft(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      inspectionNumber: inspectionNumber ?? this.inspectionNumber,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      date: date ?? this.date,
      peId: peId ?? this.peId,
      departmentId: departmentId ?? this.departmentId,
      contractorId: contractorId ?? this.contractorId,
      workLocation: workLocation ?? this.workLocation,
      violations: violations ?? this.violations,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}