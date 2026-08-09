import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/eurochem_colors.dart';
import '../../models/inspection_draft.dart';
import '../../models/reference_models.dart';
import '../../models/violation_photo.dart';
import '../../providers/reference_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../services/database_helper.dart';
import '../../widgets/photo_capture_widget.dart';

/// Экран создания новой проверки (Карта наблюдений).
/// Использует оффлайн-кэш справочников для работы без интернета.
/// 🔥 Создаёт пустой черновик в БД сразу при открытии, чтобы фото могли
/// привязываться к нарушениям через FK в реальном времени.
class CreateInspectionScreen extends StatefulWidget {
  const CreateInspectionScreen({super.key});

  @override
  State<CreateInspectionScreen> createState() => _CreateInspectionScreenState();
}

class _CreateInspectionScreenState extends State<CreateInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  // 🔥 ID черновика инспекции (создаётся при открытии экрана)
  late final String _inspectionDraftId;

  // Данные формы шапки
  DateTime _selectedDate = DateTime.now();
  String? _selectedPeId;
  String? _selectedDepartmentId;
  String? _selectedContractorId;
  final _workLocationController = TextEditingController();

  // Список нарушений
  List<ViolationDraft> _violations = [];

  // Справочники из кэша
  List<PE> _peList = [];
  List<Department> _filteredDepartments = [];
  List<Contractor> _contractorList = [];
  List<WorkType> _workTypeList = [];
  List<ZPBRule> _zpbRuleList = [];

  // Флаг сохранения
  bool _isSaving = false;
  bool _isDraftReady = false;

  @override
  void initState() {
  super.initState();
  _inspectionDraftId = const Uuid().v4();
  _loadReferences();
  _createInitialDraft().then((_) {
    setState(() {
      _isDraftReady = true;
    });
  });
}

  @override
  void dispose() {
    _workLocationController.dispose();
    super.dispose();
  }

/// Создать пустой черновик инспекции при открытии экрана.
Future<void> _createInitialDraft() async {
  final draft = InspectionDraft(
    id: _inspectionDraftId,
    date: _selectedDate,
    peId: '', // Пустая строка вместо 'pending' — FK убран
    violations: [],
    syncStatus: SyncStatus.pending,
  );
  
  try {
    await _dbHelper.saveInspectionDraft(draft);
    print('✅ [CreateInspection] Черновик создан: $_inspectionDraftId');
  } catch (e) {
    print('❌ [CreateInspection] Ошибка создания черновика: $e');
  }
}

  /// Загрузить справочники из локального кэша
  void _loadReferences() {
    final refProvider = context.read<ReferenceProvider>();
    setState(() {
      _peList = refProvider.peList;
      _contractorList = refProvider.contractorList;
      _workTypeList = refProvider.workTypeList;
      _zpbRuleList = refProvider.zpbRuleList;
    });
  }

  /// При выборе ПЕ — фильтруем подразделения (каскадная фильтрация)
  void _onPeChanged(String? peId) {
    setState(() {
      _selectedPeId = peId;
      _selectedDepartmentId = null;

      final refProvider = context.read<ReferenceProvider>();
      _filteredDepartments = peId != null
          ? refProvider.getDepartmentsForPE(peId)
          : [];
    });
  }

  /// 🔥 Добавить новую строку нарушения с СОХРАНЕНИЕМ В БД
  void _addViolation() async {
    if (_violations.any((v) => v.isSafe)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя добавить нарушения, если уже отмечено "Всё безопасно"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newViolation = ViolationDraft(
      inspectionId: _inspectionDraftId, // 🔥 Привязка к инспекции для FK
      workTypeId: _workTypeList.isNotEmpty ? _workTypeList.first.id : '',
      isSafe: false,
      order: _violations.length + 1,
    );

    // 🔥 Сохраняем в БД СРАЗУ (чтобы фото могли привязаться через FK)
    await _dbHelper.saveViolation(newViolation);

    setState(() {
      _violations.add(newViolation);
    });

    print('✅ [CreateInspection] Нарушение сохранено в БД: ${newViolation.id}');
  }

  /// 🔥 Удалить строку нарушения с каскадным удалением фото
  void _removeViolation(int index) async {
    final violation = _violations[index];

    // Удаляем все фото этого нарушения из БД и с диска
    for (final photo in violation.photos) {
      await _dbHelper.deletePhoto(photo.id);
      // TODO: Удалить файл с диска через PhotoService
    }

    // 🔥 Удаляем нарушение из БД (каскадно удалит фото через FK)
    await _dbHelper.deleteViolation(violation.id);

    setState(() {
      _violations.removeAt(index);
      // Перенумеровываем оставшиеся
      for (int i = 0; i < _violations.length; i++) {
        _violations[i] = _violations[i].copyWith(order: i + 1);
      }
    });

    // 🔥 Обновляем порядок в БД
    for (final v in _violations) {
      await _dbHelper.saveViolation(v);
    }
  }

  /// 🔥 Обновить строку нарушения с СОХРАНЕНИЕМ В БД
  void _updateViolation(int index, ViolationDraft updated) async {
    setState(() {
      _violations[index] = updated;
    });

    // 🔥 Сохраняем в БД
    await _dbHelper.saveViolation(updated);
  }

  /// Добавить фото к нарушению
  Future<void> _addPhotoToViolation(int index, ViolationPhoto photo) async {
    // Сохраняем фото в БД (теперь FK работает, т.к. нарушение уже в БД)
    await _dbHelper.savePhoto(photo);

    setState(() {
      _violations[index] = _violations[index].addPhoto(photo);
    });
  }

  /// Удалить фото из нарушения
  Future<void> _removePhotoFromViolation(int index, String photoId) async {
    // Удаляем из БД
    await _dbHelper.deletePhoto(photoId);

    setState(() {
      _violations[index] = _violations[index].removePhoto(photoId);
    });
  }

  /// 🔥 Сохранить проверку — ОБНОВЛЯЕМ существующий черновик, а не создаём новый
  Future<void> _saveInspection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_violations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно наблюдение'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите производственную единицу'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🔥 Обновляем существующий черновик (не создаём новый)
    final draft = InspectionDraft(
      id: _inspectionDraftId,
      date: _selectedDate,
      peId: _selectedPeId!,
      departmentId: _selectedDepartmentId,
      contractorId: _selectedContractorId,
      workLocation: _workLocationController.text.trim(),
      violations: _violations,
      syncStatus: SyncStatus.pending,
    );

    setState(() {
      _isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 🔥 Обновляем существующий черновик
    await _dbHelper.updateInspectionDraft(draft);

    // Синхронизируем через провайдер (отправит на сервер при наличии сети)
    final inspectionProvider = context.read<InspectionProvider>();
    await inspectionProvider.loadDrafts();

    if (!mounted) return;
    Navigator.of(context).pop();

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Проверка сохранена локально'),
        backgroundColor: EurochemColors.green,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
                          MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание проверки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveInspection,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomPadding),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildViolationsSection(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_violations.any((v) => v.isSafe) || _isSaving || !_isDraftReady)
                    ? null  // ← блокируем, пока черновик не готов
                    : _addViolation,
                icon: const Icon(Icons.add),
                label: Text(
                  _isDraftReady ? 'Добавить строку наблюдения' : 'Подготовка...',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EurochemColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка шапки проверки
  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шапка проверки',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EurochemColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),

            // Дата проверки
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата проверки',
                  prefixIcon: Icon(Icons.calendar_today, color: EurochemColors.primaryBlue),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ПЕ
            DropdownButtonFormField<String>(
              value: _selectedPeId,
              decoration: const InputDecoration(
                labelText: 'Производственная единица (ПЕ)',
                prefixIcon: Icon(Icons.factory, color: EurochemColors.primaryBlue),
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _peList.map((pe) {
                return DropdownMenuItem(
                  value: pe.id,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(pe.name, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: _onPeChanged,
              validator: (value) {
                if (value == null) return 'Выберите ПЕ';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Подразделение
            DropdownButtonFormField<String>(
              value: _selectedDepartmentId,
              decoration: const InputDecoration(
                labelText: 'Подразделение',
                prefixIcon: Icon(Icons.account_tree, color: EurochemColors.primaryBlue),
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _filteredDepartments.map((dept) {
                return DropdownMenuItem(
                  value: dept.id,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(dept.name, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: _selectedPeId == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedDepartmentId = value;
                      });
                    },
              validator: (value) {
                if (_selectedPeId != null && value == null) {
                  return 'Выберите подразделение';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Подрядчик
            DropdownButtonFormField<String>(
              value: _selectedContractorId,
              decoration: const InputDecoration(
                labelText: 'Подрядная организация',
                prefixIcon: Icon(Icons.business, color: EurochemColors.primaryBlue),
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _contractorList.map((contractor) {
                return DropdownMenuItem(
                  value: contractor.id,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(contractor.name, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedContractorId = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Место производства работ
            TextFormField(
              controller: _workLocationController,
              decoration: const InputDecoration(
                labelText: 'Место производства работ',
                prefixIcon: Icon(Icons.location_on, color: EurochemColors.primaryBlue),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Укажите место работ';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Секция нарушений
  Widget _buildViolationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Наблюдения',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: EurochemColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),

        if (_violations.isEmpty)
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: EurochemColors.gray),
                    const SizedBox(height: 8),
                    Text(
                      'Нет добавленных наблюдений',
                      style: TextStyle(color: EurochemColors.gray),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нажмите кнопку ниже, чтобы добавить',
                      style: TextStyle(fontSize: 12, color: EurochemColors.gray),
                    ),
                  ],
                ),
              ),
            ),
          ),

        ..._violations.asMap().entries.map((entry) {
          return _ViolationCard(
            key: ValueKey(entry.value.id), // 🔥 Ключ для корректного пересоздания
            index: entry.key,
            violation: entry.value,
            workTypeList: _workTypeList,
            zpbRuleList: _zpbRuleList,
            onUpdate: (updated) => _updateViolation(entry.key, updated),
            onRemove: () => _removeViolation(entry.key),
            onPhotoAdded: (photo) => _addPhotoToViolation(entry.key, photo),
            onPhotoRemoved: (photoId) => _removePhotoFromViolation(entry.key, photoId),
          );
        }),
      ],
    );
  }

  /// Выбор даты
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}

/// 🔥 Карточка одного нарушения (StatefulWidget для работы с фото)
class _ViolationCard extends StatefulWidget {
  final int index;
  final ViolationDraft violation;
  final List<WorkType> workTypeList;
  final List<ZPBRule> zpbRuleList;
  final Function(ViolationDraft) onUpdate;
  final VoidCallback onRemove;
  final Function(ViolationPhoto) onPhotoAdded;
  final Function(String) onPhotoRemoved;

  const _ViolationCard({
    super.key,
    required this.index,
    required this.violation,
    required this.workTypeList,
    required this.zpbRuleList,
    required this.onUpdate,
    required this.onRemove,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
  });

  @override
  State<_ViolationCard> createState() => _ViolationCardState();
}

class _ViolationCardState extends State<_ViolationCard> {
  @override
  Widget build(BuildContext context) {
    final violation = widget.violation;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: violation.isSafe ? EurochemColors.lightGreen : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с номером и кнопкой удаления
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: violation.isSafe ? EurochemColors.green : EurochemColors.primaryBlue,
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    violation.isSafe ? 'Всё безопасно' : 'Наблюдение',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: violation.isSafe ? EurochemColors.green : EurochemColors.primaryBlue,
                    ),
                  ),
                ),
                if (violation.isTopViolation)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.whatshot, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'ТОП',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                  tooltip: 'Удалить',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Чекбокс "Всё безопасно"
            CheckboxListTile(
              title: const Text('Всё безопасно'),
              subtitle: const Text('Отметьте, если нарушений не выявлено'),
              value: violation.isSafe,
              activeColor: EurochemColors.green,
              onChanged: (value) {
                widget.onUpdate(violation.copyWith(
                  isSafe: value ?? false,
                  violationDescription: value == true ? null : violation.violationDescription,
                  zpbRuleId: value == true ? null : violation.zpbRuleId,
                  isGrossViolation: value == true ? false : violation.isGrossViolation,
                  isWorkStopped: value == true ? false : violation.isWorkStopped,
                ));
              },
            ),

            if (!violation.isSafe) ...[
              const Divider(),
              const SizedBox(height: 12),

              // Вид работ
              DropdownButtonFormField<String>(
                value: violation.workTypeId,
                decoration: const InputDecoration(
                  labelText: 'Вид работ',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: widget.workTypeList.map((wt) {
                  return DropdownMenuItem(
                    value: wt.id,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(wt.name, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  widget.onUpdate(violation.copyWith(workTypeId: value));
                },
              ),
              const SizedBox(height: 12),

              // Описание нарушения
              TextFormField(
                initialValue: violation.violationDescription,
                decoration: const InputDecoration(
                  labelText: 'Описание нарушения',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onChanged: (value) {
                  widget.onUpdate(violation.copyWith(violationDescription: value));
                },
              ),
              const SizedBox(height: 12),

              // ЗПБ
              DropdownButtonFormField<String>(
                value: violation.zpbRuleId,
                decoration: const InputDecoration(
                  labelText: 'Нарушенное ЗПБ',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: widget.zpbRuleList.map((zpb) {
                  return DropdownMenuItem(
                    value: zpb.id,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text('${zpb.order}. ${zpb.name}', overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  widget.onUpdate(violation.copyWith(zpbRuleId: value));
                },
              ),
              const SizedBox(height: 12),

              // Чекбоксы
              CheckboxListTile(
                title: const Text('Грубейшее нарушение'),
                value: violation.isGrossViolation,
                activeColor: Colors.red,
                onChanged: (value) {
                  widget.onUpdate(violation.copyWith(isGrossViolation: value ?? false));
                },
              ),
              CheckboxListTile(
                title: const Text('Остановка работ'),
                subtitle: const Text('Работы остановлены до устранения'),
                value: violation.isWorkStopped,
                activeColor: Colors.orange,
                onChanged: (value) {
                  widget.onUpdate(violation.copyWith(isWorkStopped: value ?? false));
                },
              ),

              // ▼▼▼ НОВОЕ: Виджет фотофиксации ▼▼▼
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              PhotoCaptureWidget(
                violationId: violation.id,
                existingPhotos: violation.photos,
                onPhotoAdded: widget.onPhotoAdded,
                onPhotoRemoved: widget.onPhotoRemoved,
              ),
              // ▲▲▲ КОНЕЦ ВИДЖЕТА ▲▲▲
            ],
          ],
        ),
      ),
    );
  }
}