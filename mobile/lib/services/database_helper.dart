import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/reference_models.dart';
import '../models/inspection_draft.dart';
import '../models/violation_photo.dart';

/// Хелпер для работы с локальной SQLite базой данных.
/// Обеспечивает оффлайн-доступ к справочникам и черновикам проверок.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Получить экземпляр базы данных (синглтон).
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Инициализация базы данных.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inspectra_offline.db');

    return await openDatabase(
      path,
      version: 5, // ⬆️ Обновлена для миграции violation_photos
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Настройка базы данных (включение внешних ключей).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Создание таблиц при первом запуске (версия 4).
  Future<void> _onCreate(Database db, int version) async {
    // ==========================================
    // СПРАВОЧНИКИ
    // ==========================================
    await db.execute('''
      CREATE TABLE pe (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE department (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        pe_id TEXT NOT NULL,
        pe_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (pe_id) REFERENCES pe(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_department_pe_id ON department(pe_id)');

    await db.execute('''
      CREATE TABLE contractor (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        is_internal INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE work_type (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE zpb_rule (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        order_num INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_sync_at TEXT NOT NULL,
        last_sync_error TEXT,
        pe_count INTEGER NOT NULL DEFAULT 0,
        department_count INTEGER NOT NULL DEFAULT 0,
        contractor_count INTEGER NOT NULL DEFAULT 0,
        work_type_count INTEGER NOT NULL DEFAULT 0,
        zpb_rule_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ==========================================
    // ЧЕРНОВИКИ ПРОВЕРОК
    // ==========================================
await db.execute('''
  CREATE TABLE inspection_drafts (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL UNIQUE,
    inspection_number TEXT,
    server_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    sync_error TEXT,
    date TEXT NOT NULL,
    pe_id TEXT,                    -- ⬅️ БЫЛО: TEXT NOT NULL
    department_id TEXT,
    contractor_id TEXT,
    work_location TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
    -- ⬅️ УБРАЛИ: FOREIGN KEY (pe_id) REFERENCES pe(id)
    -- ⬅️ УБРАЛИ: FOREIGN KEY (department_id) REFERENCES department(id)
    -- ⬅️ УБРАЛИ: FOREIGN KEY (contractor_id) REFERENCES contractor(id)
  )
''');
    await db.execute('CREATE INDEX idx_draft_sync_status ON inspection_drafts(sync_status)');
    await db.execute('CREATE INDEX idx_draft_client_id ON inspection_drafts(client_id)');

    await db.execute('''
      CREATE TABLE violation_drafts (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        work_type_id TEXT NOT NULL,
        is_safe INTEGER NOT NULL DEFAULT 0,
        violation_description TEXT,
        is_gross_violation INTEGER NOT NULL DEFAULT 0,
        is_work_stopped INTEGER NOT NULL DEFAULT 0,
        zpb_rule_id TEXT,
        is_top_violation INTEGER NOT NULL DEFAULT 0,
        order_num INTEGER NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES inspection_drafts(id) ON DELETE CASCADE,
        FOREIGN KEY (work_type_id) REFERENCES work_type(id),
        FOREIGN KEY (zpb_rule_id) REFERENCES zpb_rule(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_violation_inspection_id ON violation_drafts(inspection_id)');

    // ==========================================
    // ФОТО НАРУШЕНИЙ
    // ==========================================
    await db.execute('''
      CREATE TABLE violation_photos (
        id TEXT PRIMARY KEY,
        violation_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        thumbnail_path TEXT,
        original_filename TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        gps_latitude REAL,
        gps_longitude REAL,
        taken_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        server_photo_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (violation_id) REFERENCES violation_drafts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_photo_violation_id ON violation_photos(violation_id)');
    await db.execute('CREATE INDEX idx_photo_sync_status ON violation_photos(sync_status)');

    print('✅ [DatabaseHelper] База данных создана (версия $version)');
  }

  /// Миграция базы данных при обновлении версии.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 [DatabaseHelper] Миграция БД с версии $oldVersion на $newVersion');

    if (oldVersion < 2) {
      print('✅ [DatabaseHelper] Миграция v2 завершена');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE inspection_drafts ADD COLUMN client_id TEXT');
        await db.execute('ALTER TABLE inspection_drafts ADD COLUMN inspection_number TEXT');
      } catch (e) {
        print('⚠️ [DatabaseHelper] Колонки уже существуют: $e');
      }

      final drafts = await db.query('inspection_drafts');
      for (var draft in drafts) {
        if (draft['client_id'] == null || draft['client_id'].toString().isEmpty) {
          await db.update(
            'inspection_drafts',
            {'client_id': const Uuid().v4()},
            where: 'id = ?',
            whereArgs: [draft['id']],
          );
        }
      }
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_draft_client_id ON inspection_drafts(client_id)');
      print('✅ [DatabaseHelper] Миграция v3 завершена');
    }

    if (oldVersion < 4) {
      print('🔄 [DatabaseHelper] Миграция v4: создание таблицы violation_photos');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS violation_photos (
          id TEXT PRIMARY KEY,
          violation_id TEXT NOT NULL,
          local_path TEXT NOT NULL,
          thumbnail_path TEXT,
          original_filename TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          mime_type TEXT NOT NULL,
          gps_latitude REAL,
          gps_longitude REAL,
          taken_at TEXT NOT NULL,
          sync_status TEXT DEFAULT 'pending',
          server_photo_id TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (violation_id) REFERENCES violation_drafts(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_photo_violation_id ON violation_photos(violation_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_photo_sync_status ON violation_photos(sync_status)');

      print('✅ [DatabaseHelper] Миграция v4 завершена');
    }

    // ▼▼▼ МИГРАЦИЯ v5: pe_id → nullable, удаление FK на справочники ▼▼▼
    if (oldVersion < 5) {
      print('🔄 [DatabaseHelper] Миграция v5: pe_id → nullable');

      // SQLite не поддерживает ALTER COLUMN, поэтому пересоздаём таблицу
      await db.execute('ALTER TABLE inspection_drafts RENAME TO inspection_drafts_old');

      await db.execute('''
        CREATE TABLE inspection_drafts (
          id TEXT PRIMARY KEY,
          client_id TEXT NOT NULL UNIQUE,
          inspection_number TEXT,
          server_id TEXT,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          sync_error TEXT,
          date TEXT NOT NULL,
          pe_id TEXT,
          department_id TEXT,
          contractor_id TEXT,
          work_location TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        INSERT INTO inspection_drafts (
          id, client_id, inspection_number, server_id, sync_status, sync_error,
          date, pe_id, department_id, contractor_id, work_location, created_at, updated_at
        )
        SELECT
          id, client_id, inspection_number, server_id, sync_status, sync_error,
          date, pe_id, department_id, contractor_id, work_location, created_at, updated_at
        FROM inspection_drafts_old
      ''');

      await db.execute('DROP TABLE inspection_drafts_old');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_draft_sync_status ON inspection_drafts(sync_status)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_draft_client_id ON inspection_drafts(client_id)');

      print('✅ [DatabaseHelper] Миграция v5 завершена');
    }
    // ▲▲▲ КОНЕЦ МИГРАЦИИ v5 ▲▲▲
  }
  
  // ==========================================
  // БЕЗОПАСНЫЙ UPSERT (Обновление на месте без удаления)
  // ==========================================

  Future<void> upsertPEs(List<PE> peList) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var pe in peList) {
        await txn.rawInsert('''
          INSERT INTO pe (id, name, code, is_active) 
          VALUES (?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET 
            name = excluded.name, 
            code = excluded.code, 
            is_active = excluded.is_active
        ''', [pe.id, pe.name, pe.code, pe.isActive ? 1 : 0]);
      }
    });
    print('✅ [DatabaseHelper] Сохранено/обновлено ПЕ: ${peList.length}');
  }

  Future<void> upsertDepartments(List<Department> departments) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var dept in departments) {
        await txn.rawInsert('''
          INSERT INTO department (id, name, pe_id, pe_name, is_active) 
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET 
            name = excluded.name, 
            pe_id = excluded.pe_id, 
            pe_name = excluded.pe_name, 
            is_active = excluded.is_active
        ''', [dept.id, dept.name, dept.peId, dept.peName, dept.isActive ? 1 : 0]);
      }
    });
    print('✅ [DatabaseHelper] Сохранено/обновлено подразделений: ${departments.length}');
  }

  Future<void> upsertContractors(List<Contractor> contractors) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var contractor in contractors) {
        await txn.rawInsert('''
          INSERT INTO contractor (id, name, code, is_internal, is_active) 
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET 
            name = excluded.name, 
            code = excluded.code, 
            is_internal = excluded.is_internal, 
            is_active = excluded.is_active
        ''', [contractor.id, contractor.name, contractor.code, contractor.isInternal ? 1 : 0, contractor.isActive ? 1 : 0]);
      }
    });
    print('✅ [DatabaseHelper] Сохранено/обновлено подрядчиков: ${contractors.length}');
  }

  Future<void> upsertWorkTypes(List<WorkType> workTypes) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var workType in workTypes) {
        await txn.rawInsert('''
          INSERT INTO work_type (id, name, code, is_active) 
          VALUES (?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET 
            name = excluded.name, 
            code = excluded.code, 
            is_active = excluded.is_active
        ''', [workType.id, workType.name, workType.code, workType.isActive ? 1 : 0]);
      }
    });
    print('✅ [DatabaseHelper] Сохранено/обновлено видов работ: ${workTypes.length}');
  }

  Future<void> upsertZPBRules(List<ZPBRule> zpbRules) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var rule in zpbRules) {
        await txn.rawInsert('''
          INSERT INTO zpb_rule (id, name, order_num, is_active) 
          VALUES (?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET 
            name = excluded.name, 
            order_num = excluded.order_num, 
            is_active = excluded.is_active
        ''', [rule.id, rule.name, rule.order, rule.isActive ? 1 : 0]);
      }
    });
    print('✅ [DatabaseHelper] Сохранено/обновлено ЗПБ: ${zpbRules.length}');
  }

  // ==========================================
  // ЧТЕНИЕ ДАННЫХ
  // ==========================================

  Future<List<PE>> getPEs({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query('pe', where: activeOnly ? 'is_active = 1' : null);
    return maps.map((map) => PE.fromMap(map)).toList();
  }

  Future<List<Department>> getDepartments({String? peId, bool activeOnly = true}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (peId != null && activeOnly) {
      where = 'pe_id = ? AND is_active = 1';
      whereArgs = [peId];
    } else if (peId != null) {
      where = 'pe_id = ?';
      whereArgs = [peId];
    } else if (activeOnly) {
      where = 'is_active = 1';
    }
    final maps = await db.query('department', where: where, whereArgs: whereArgs);
    return maps.map((map) => Department.fromMap(map)).toList();
  }

  Future<List<Contractor>> getContractors({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query('contractor', where: activeOnly ? 'is_active = 1' : null);
    return maps.map((map) => Contractor.fromMap(map)).toList();
  }

  Future<List<WorkType>> getWorkTypes({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query('work_type', where: activeOnly ? 'is_active = 1' : null);
    return maps.map((map) => WorkType.fromMap(map)).toList();
  }

  Future<List<ZPBRule>> getZPBRules({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query('zpb_rule', where: activeOnly ? 'is_active = 1' : null, orderBy: 'order_num ASC');
    return maps.map((map) => ZPBRule.fromMap(map)).toList();
  }

  // ==========================================
  // МЕТАДАННЫЕ И ЧЕРНОВИКИ
  // ==========================================

  Future<void> saveSyncMetadata(ReferenceSyncMetadata metadata) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_metadata');
      await txn.insert('sync_metadata', metadata.toMap());
    });
  }

  Future<ReferenceSyncMetadata?> getSyncMetadata() async {
    final db = await database;
    final maps = await db.query('sync_metadata', orderBy: 'id DESC', limit: 1);
    if (maps.isEmpty) return null;
    return ReferenceSyncMetadata.fromMap(maps.first);
  }

  Future<DateTime?> getLastSyncAt() async {
    final metadata = await getSyncMetadata();
    return metadata?.lastSyncAt;
  }

  /// Сохранить черновик инспекции со всеми нарушениями (используется при первичном создании).
  Future<void> saveInspectionDraft(InspectionDraft draft) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'inspection_drafts',
        {
          'id': draft.id,
          'client_id': draft.clientId,
          'inspection_number': draft.inspectionNumber,
          'server_id': draft.serverId,
          'sync_status': draft.syncStatus.name,
          'date': draft.date.toIso8601String(),
          'pe_id': draft.peId,
          'department_id': draft.departmentId,
          'contractor_id': draft.contractorId,
          'work_location': draft.workLocation,
          'created_at': draft.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // violations управляются отдельно через saveViolation() для real-time режима
    });
    print('✅ [DatabaseHelper] Черновик проверки сохранён: ${draft.clientId}');
  }

  /// 🔥 НОВОЕ: Обновить существующий черновик инспекции (без пересоздания нарушений).
  /// Используется при финальном сохранении формы создания проверки.
  Future<void> updateInspectionDraft(InspectionDraft draft) async {
    final db = await database;
    await db.update(
      'inspection_drafts',
      {
        'date': draft.date.toIso8601String(),
        'pe_id': draft.peId,
        'department_id': draft.departmentId,
        'contractor_id': draft.contractorId,
        'work_location': draft.workLocation,
        'sync_status': draft.syncStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    print('✅ [DatabaseHelper] Черновик обновлён: ${draft.id}');
  }

  /// 🔥 НОВОЕ: Сохранить или обновить отдельное нарушение.
  /// Используется в реальном времени при создании/редактировании нарушений.
  Future<void> saveViolation(ViolationDraft violation) async {
    final db = await database;
    await db.insert(
      'violation_drafts',
      violation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔥 НОВОЕ: Удалить нарушение из БД (каскадно удалит фото через FK).
  Future<void> deleteViolation(String violationId) async {
    final db = await database;
    await db.delete(
      'violation_drafts',
      where: 'id = ?',
      whereArgs: [violationId],
    );
  }

  Future<List<InspectionDraft>> getInspectionDrafts() async {
    final db = await database;
    final draftMaps = await db.query('inspection_drafts', orderBy: 'created_at DESC');
    List<InspectionDraft> drafts = [];
    for (var draftMap in draftMaps) {
      final violations = await _getViolationsForDraft(db, draftMap['id'] as String);
      drafts.add(InspectionDraft(
        id: draftMap['id'] as String,
        clientId: draftMap['client_id'] as String,
        inspectionNumber: draftMap['inspection_number'] as String?,
        serverId: draftMap['server_id'] as String?,
        syncStatus: SyncStatus.values.firstWhere((e) => e.name == draftMap['sync_status'], orElse: () => SyncStatus.pending),
        date: DateTime.parse(draftMap['date'] as String),
        peId: draftMap['pe_id'] as String,
        departmentId: draftMap['department_id'] as String?,
        contractorId: draftMap['contractor_id'] as String?,
        workLocation: draftMap['work_location'] as String?,
        violations: violations,
        createdAt: DateTime.parse(draftMap['created_at'] as String),
      ));
    }
    return drafts;
  }

  Future<InspectionDraft?> getInspectionDraft(String id) async {
    final db = await database;
    final draftMaps = await db.query('inspection_drafts', where: 'id = ?', whereArgs: [id]);
    if (draftMaps.isEmpty) return null;
    final draftMap = draftMaps.first;
    final violations = await _getViolationsForDraft(db, id);
    return InspectionDraft(
      id: draftMap['id'] as String,
      clientId: draftMap['client_id'] as String,
      inspectionNumber: draftMap['inspection_number'] as String?,
      serverId: draftMap['server_id'] as String?,
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == draftMap['sync_status'], orElse: () => SyncStatus.pending),
      date: DateTime.parse(draftMap['date'] as String),
      peId: draftMap['pe_id'] as String,
      departmentId: draftMap['department_id'] as String?,
      contractorId: draftMap['contractor_id'] as String?,
      workLocation: draftMap['work_location'] as String?,
      violations: violations,
      createdAt: DateTime.parse(draftMap['created_at'] as String),
    );
  }

  Future<InspectionDraft?> getInspectionDraftByClientId(String clientId) async {
    final db = await database;
    final draftMaps = await db.query('inspection_drafts', where: 'client_id = ?', whereArgs: [clientId]);
    if (draftMaps.isEmpty) return null;
    final draftMap = draftMaps.first;
    final violations = await _getViolationsForDraft(db, draftMap['id'] as String);
    return InspectionDraft(
      id: draftMap['id'] as String,
      clientId: draftMap['client_id'] as String,
      inspectionNumber: draftMap['inspection_number'] as String?,
      serverId: draftMap['server_id'] as String?,
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == draftMap['sync_status'], orElse: () => SyncStatus.pending),
      date: DateTime.parse(draftMap['date'] as String),
      peId: draftMap['pe_id'] as String,
      departmentId: draftMap['department_id'] as String?,
      contractorId: draftMap['contractor_id'] as String?,
      workLocation: draftMap['work_location'] as String?,
      violations: violations,
      createdAt: DateTime.parse(draftMap['created_at'] as String),
    );
  }

  Future<void> deleteInspectionDraft(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Получаем ID всех нарушений черновика для каскадного удаления фото
      final violations = await txn.query(
        'violation_drafts',
        columns: ['id'],
        where: 'inspection_id = ?',
        whereArgs: [id],
      );
      final violationIds = violations.map((v) => v['id'] as String).toList();

      // Удаляем фото всех нарушений
      if (violationIds.isNotEmpty) {
        await txn.delete(
          'violation_photos',
          where: 'violation_id IN (${violationIds.map((_) => '?').join(',')})',
          whereArgs: violationIds,
        );
      }

      await txn.delete('violation_drafts', where: 'inspection_id = ?', whereArgs: [id]);
      await txn.delete('inspection_drafts', where: 'id = ?', whereArgs: [id]);
    });
    print('✅ [DatabaseHelper] Черновик удалён: $id');
  }

  Future<int> getPendingDraftsCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM inspection_drafts WHERE sync_status = 'pending'");
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<InspectionDraft>> getPendingDrafts() async {
    final db = await database;
    final draftMaps = await db.query('inspection_drafts', where: "sync_status = 'pending'", orderBy: 'created_at ASC');
    List<InspectionDraft> drafts = [];
    for (var draftMap in draftMaps) {
      final violations = await _getViolationsForDraft(db, draftMap['id'] as String);
      drafts.add(InspectionDraft(
        id: draftMap['id'] as String,
        clientId: draftMap['client_id'] as String,
        syncStatus: SyncStatus.pending,
        date: DateTime.parse(draftMap['date'] as String),
        peId: draftMap['pe_id'] as String,
        departmentId: draftMap['department_id'] as String?,
        contractorId: draftMap['contractor_id'] as String?,
        workLocation: draftMap['work_location'] as String?,
        violations: violations,
        createdAt: DateTime.parse(draftMap['created_at'] as String),
      ));
    }
    return drafts;
  }

  Future<void> markDraftAsSynced(String id, String? serverId, String? inspectionNumber) async {
    final db = await database;
    await db.update(
      'inspection_drafts',
      {
        'sync_status': 'synced',
        'server_id': serverId,
        'inspection_number': inspectionNumber,
        'sync_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('✅ [DatabaseHelper] Черновик отмечен как синхронизированный: $id');
  }

  Future<void> markDraftAsFailed(String id, String error) async {
    final db = await database;
    await db.update(
      'inspection_drafts',
      {
        'sync_status': 'failed',
        'sync_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('⚠️ [DatabaseHelper] Черновик отмечен как ошибочный: $id');
  }

  Future<void> updateDraftStatus(String id, String newStatus) async {
    final db = await database;
    await db.update(
      'inspection_drafts',
      {'sync_status': newStatus, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ViolationDraft>> _getViolationsForDraft(Database db, String draftId) async {
    final violationMaps = await db.query('violation_drafts', where: 'inspection_id = ?', whereArgs: [draftId], orderBy: 'order_num ASC');
    final violations = <ViolationDraft>[];
    
    for (final vMap in violationMaps) {
      final violationId = vMap['id'] as String;
      // Загружаем фото для каждого нарушения
      final photos = await getPhotosForViolation(violationId);
      
      violations.add(ViolationDraft(
        id: violationId,
        inspectionId: vMap['inspection_id'] as String,
        workTypeId: vMap['work_type_id'] as String,
        isSafe: vMap['is_safe'] == 1,
        violationDescription: vMap['violation_description'] as String?,
        isGrossViolation: vMap['is_gross_violation'] == 1,
        isWorkStopped: vMap['is_work_stopped'] == 1,
        zpbRuleId: vMap['zpb_rule_id'] as String?,
        isTopViolation: vMap['is_top_violation'] == 1,
        order: vMap['order_num'] as int,
        photos: photos,
      ));
    }
    
    return violations;
  }

  // ==========================================
  // ФОТО НАРУШЕНИЙ (CRUD)
  // ==========================================

  /// Сохранить фото нарушения в локальную БД.
  Future<void> savePhoto(ViolationPhoto photo) async {
    final db = await database;
    await db.insert(
      'violation_photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Получить все фото для конкретного нарушения.
  Future<List<ViolationPhoto>> getPhotosForViolation(String violationId) async {
    final db = await database;
    final maps = await db.query(
      'violation_photos',
      where: 'violation_id = ?',
      whereArgs: [violationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ViolationPhoto.fromMap(m)).toList();
  }

  /// Получить нарушение по его ID.
  Future<ViolationDraft?> getViolationById(String violationId) async {
    final db = await database;
    final maps = await db.query(
      'violation_drafts',
      where: 'id = ?',
      whereArgs: [violationId],
    );
    if (maps.isEmpty) return null;
    
    final vMap = maps.first;
    return ViolationDraft(
      id: vMap['id'] as String,
      inspectionId: vMap['inspection_id'] as String,
      workTypeId: vMap['work_type_id'] as String,
      isSafe: vMap['is_safe'] == 1,
      violationDescription: vMap['violation_description'] as String?,
      isGrossViolation: vMap['is_gross_violation'] == 1,
      isWorkStopped: vMap['is_work_stopped'] == 1,
      zpbRuleId: vMap['zpb_rule_id'] as String?,
      isTopViolation: vMap['is_top_violation'] == 1,
      order: vMap['order_num'] as int,
    );
  }

  /// Удалить запись о фото из БД.
  Future<void> deletePhoto(String photoId) async {
    final db = await database;
    await db.delete('violation_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  /// Получить список всех фото со статусом "pending" для синхронизации.
  Future<List<ViolationPhoto>> getPendingPhotos() async {
    final db = await database;
    final maps = await db.query(
      'violation_photos',
      where: "sync_status = 'pending'",
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ViolationPhoto.fromMap(m)).toList();
  }

  /// Отметить фото как синхронизированное с сервером.
  Future<void> markPhotoSynced(String photoId, String serverId) async {
    final db = await database;
    await db.update(
      'violation_photos',
      {'sync_status': 'synced', 'server_photo_id': serverId},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  /// Отметить фото как ошибочное (не удалось загрузить).
  Future<void> markPhotoFailed(String photoId) async {
    final db = await database;
    await db.update(
      'violation_photos',
      {'sync_status': 'failed'},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  // ==========================================
  // УТИЛИТЫ
  // ==========================================

  Future<bool> hasData() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pe'));
    return count != null && count > 0;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('violation_photos');
      await txn.delete('sync_metadata');
      await txn.delete('violation_drafts');
      await txn.delete('inspection_drafts');
      await txn.delete('zpb_rule');
      await txn.delete('work_type');
      await txn.delete('contractor');
      await txn.delete('department');
      await txn.delete('pe');
    });
    print('⚠️ [DatabaseHelper] Все данные очищены');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}