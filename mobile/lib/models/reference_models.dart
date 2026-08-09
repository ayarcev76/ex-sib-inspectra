/// Модели данных для справочников системы ЕХ:Инспектра-ИПБ

/// Производственная единица (ПЕ)
class PE {
  final String id;
  final String name;
  final String code;
  final bool isActive;

  PE({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  factory PE.fromJson(Map<String, dynamic> json) {
    return PE(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory PE.fromMap(Map<String, dynamic> map) {
    return PE(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() => name;
}

/// Подразделение (привязано к ПЕ)
class Department {
  final String id;
  final String name;
  final String peId;
  final String? peName; // Для отображения
  final bool isActive;

  Department({
    required this.id,
    required this.name,
    required this.peId,
    this.peName,
    required this.isActive,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
      peId: json['pe_id'],
      peName: json['pe_name'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pe_id': peId,
      'pe_name': peName,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'],
      name: map['name'],
      peId: map['pe_id'],
      peName: map['pe_name'],
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() => name;
}

/// Подрядная организация
class Contractor {
  final String id;
  final String name;
  final String code;
  final bool isInternal;
  final bool isActive;

  Contractor({
    required this.id,
    required this.name,
    required this.code,
    required this.isInternal,
    required this.isActive,
  });

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      isInternal: json['is_internal'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_internal': isInternal ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Contractor.fromMap(Map<String, dynamic> map) {
    return Contractor(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      isInternal: map['is_internal'] == 1,
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() => name;
}

/// Вид работ
class WorkType {
  final String id;
  final String name;
  final String code;
  final bool isActive;

  WorkType({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  factory WorkType.fromJson(Map<String, dynamic> json) {
    return WorkType(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory WorkType.fromMap(Map<String, dynamic> map) {
    return WorkType(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() => name;
}

/// Золотое Правило Безопасности (ЗПБ)
class ZPBRule {
  final String id;
  final String name;
  final int order;
  final bool isActive;

  ZPBRule({
    required this.id,
    required this.name,
    required this.order,
    required this.isActive,
  });

  factory ZPBRule.fromJson(Map<String, dynamic> json) {
    return ZPBRule(
      id: json['id'],
      name: json['name'],
      // Бэкенд возвращает поле "number", маппим его в "order"
      order: json['number'] ?? json['order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      // Используем order_num, так как 'order' — зарезервированное слово в SQL
      'order_num': order,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ZPBRule.fromMap(Map<String, dynamic> map) {
    return ZPBRule(
      id: map['id'],
      name: map['name'],
      // Читаем из order_num
      order: map['order_num'] ?? 0,
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() => name;
}

/// Метаданные синхронизации справочников
class ReferenceSyncMetadata {
  final DateTime lastSyncAt;
  final String? lastSyncError;
  final int peCount;
  final int departmentCount;
  final int contractorCount;
  final int workTypeCount;
  final int zpbRuleCount;

  ReferenceSyncMetadata({
    required this.lastSyncAt,
    this.lastSyncError,
    required this.peCount,
    required this.departmentCount,
    required this.contractorCount,
    required this.workTypeCount,
    required this.zpbRuleCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'last_sync_at': lastSyncAt.toIso8601String(),
      'last_sync_error': lastSyncError,
      'pe_count': peCount,
      'department_count': departmentCount,
      'contractor_count': contractorCount,
      'work_type_count': workTypeCount,
      'zpb_rule_count': zpbRuleCount,
    };
  }

  factory ReferenceSyncMetadata.fromMap(Map<String, dynamic> map) {
    return ReferenceSyncMetadata(
      lastSyncAt: DateTime.parse(map['last_sync_at']),
      lastSyncError: map['last_sync_error'],
      peCount: map['pe_count'] ?? 0,
      departmentCount: map['department_count'] ?? 0,
      contractorCount: map['contractor_count'] ?? 0,
      workTypeCount: map['work_type_count'] ?? 0,
      zpbRuleCount: map['zpb_rule_count'] ?? 0,
    );
  }
}