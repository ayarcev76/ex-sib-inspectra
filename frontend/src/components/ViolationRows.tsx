import React, { useEffect, useState, useRef } from 'react';
import { Form, Select, Input, Checkbox, Button, Space, Card, Divider, message, Alert, Modal } from 'antd';
import { PlusOutlined, DeleteOutlined, CheckCircleOutlined } from '@ant-design/icons';
import apiClient from '../api/client';
import PhotoUpload from './PhotoUpload';

const { TextArea } = Input;

interface WorkType {
  id: string;
  name: string;
}

interface ZPBRule {
  id: string;
  number: number;
  name: string;
}

export interface ViolationRow {
  id: string;
  inspection_id: string;
  work_type_id: string;
  work_type_name?: string;
  is_safe: boolean;
  violation_description?: string | null;
  is_gross_violation: boolean;
  is_work_stopped: boolean;
  zpb_rule_id?: string | null;
  zpb_rule_name?: string;
  is_top_violation: boolean;
  order: number;
  photos: any[];
}

interface ViolationRowsProps {
  inspectionId: string;
  violations: ViolationRow[];
  onChange: (violations: ViolationRow[]) => void;
}

// Отдельный компонент для строки нарушения с локальным состоянием
const ViolationRowItem: React.FC<{
  violation: ViolationRow;
  index: number;
  workTypes: WorkType[];
  zpbRules: ZPBRule[];
  onUpdate: (violationId: string, field: string, value: any) => void;
  onRemove: (violationId: string) => void;
}> = ({ violation, index, workTypes, zpbRules, onUpdate, onRemove }) => {
  // Локальное состояние для описания (не вызывает перерисовку родителя)
  const [localDescription, setLocalDescription] = useState(violation.violation_description || '');
  const debounceTimer = useRef<NodeJS.Timeout | null>(null);

  // Синхронизация локального состояния при изменении извне
  useEffect(() => {
    setLocalDescription(violation.violation_description || '');
  }, [violation.violation_description]);

  // Обработчик изменения описания с debounce
  const handleDescriptionChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    setLocalDescription(newValue); // Мгновенное обновление локального состояния

    // Очищаем предыдущий таймер
    if (debounceTimer.current) {
      clearTimeout(debounceTimer.current);
    }

    // Устанавливаем новый таймер для отправки на сервер
    debounceTimer.current = setTimeout(() => {
      onUpdate(violation.id, 'violation_description', newValue);
    }, 800); // 800мс задержка
  };

  // Очистка таймера при размонтировании
  useEffect(() => {
    return () => {
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current);
      }
    };
  }, []);

  return (
    <Card
      size="small"
      style={{ marginBottom: 16, background: violation.is_safe ? '#f6ffed' : '#fff' }}
      title={
        violation.is_safe ? (
          <span><CheckCircleOutlined style={{ color: '#52c41a' }} /> Всё безопасно</span>
        ) : (
          `Нарушение ${index + 1}`
        )
      }
      extra={
        <Button type="text" danger icon={<DeleteOutlined />} onClick={() => onRemove(violation.id)}>
          Удалить
        </Button>
      }
    >
      {violation.is_safe ? (
        <div style={{ padding: 16, textAlign: 'center', color: '#52c41a' }}>
          <CheckCircleOutlined style={{ fontSize: 32, marginBottom: 8 }} />
          <p>Нарушений не выявлено</p>
        </div>
      ) : (
        <div className="ant-form ant-form-vertical" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <Form.Item label="Вид работ" required>
            <Select
              value={violation.work_type_id || undefined}
              onChange={(value) => onUpdate(violation.id, 'work_type_id', value)}
              placeholder="Выберите вид работ"
              options={workTypes.map((wt) => ({ value: wt.id, label: wt.name }))}
            />
          </Form.Item>

          <Form.Item label="Описание нарушения" required>
            <TextArea
              value={localDescription}
              onChange={handleDescriptionChange}
              placeholder="Опишите нарушение"
              rows={3}
              autoFocus={false}
            />
          </Form.Item>

          <Form.Item>
            <Space orientation="vertical" style={{ width: '100%' }}>
              <Checkbox
                checked={violation.is_gross_violation}
                onChange={(e) => onUpdate(violation.id, 'is_gross_violation', e.target.checked)}
              >
                Грубейшее нарушение
              </Checkbox>
              <Checkbox
                checked={violation.is_work_stopped}
                onChange={(e) => onUpdate(violation.id, 'is_work_stopped', e.target.checked)}
              >
                Остановка работ
              </Checkbox>
            </Space>
          </Form.Item>

          <Form.Item label="Нарушенное Золотое Правило Безопасности">
            <Select
              value={violation.zpb_rule_id || undefined}
              onChange={(value) => onUpdate(violation.id, 'zpb_rule_id', value)}
              placeholder="Выберите ЗПБ (если нарушено)"
              allowClear
              options={zpbRules.map((zpb) => ({ value: zpb.id, label: `${zpb.number}. ${zpb.name}` }))}
            />
          </Form.Item>

          {violation.is_top_violation && (
            <Alert
              title="⚠️ ТОП-НАРУШЕНИЕ"
              description="Выбрано ЗПБ + остановка работ"
              type="error"
              showIcon
            />
          )}

          <Divider>Фотографии</Divider>
          <PhotoUpload
            violationId={violation.id}
            photos={violation.photos || []}
            onChange={(photos) => onUpdate(violation.id, 'photos', photos)}
          />
        </div>
      )}
    </Card>
  );
};

const ViolationRows: React.FC<ViolationRowsProps> = ({ inspectionId, violations, onChange }) => {
  const [workTypes, setWorkTypes] = useState<WorkType[]>([]);
  const [zpbRules, setZpbRules] = useState<ZPBRule[]>([]);

  useEffect(() => {
    const loadReferences = async () => {
      try {
        const [wtResponse, zpbResponse] = await Promise.all([
          apiClient.get('/references/work-types'),
          apiClient.get('/references/zpb-rules'),
        ]);
        setWorkTypes(wtResponse.data);
        setZpbRules(zpbResponse.data);
      } catch (error) {
        message.error('Ошибка загрузки справочников');
      }
    };
    loadReferences();
  }, []);

  const hasSafeRow = violations.some((v) => v.is_safe);
  const hasViolationRows = violations.some((v) => !v.is_safe);

  const addSafeRow = async () => {
    if (hasViolationRows) {
      Modal.confirm({
        title: 'Подтверждение',
        content: 'У вас есть строки нарушений. При выборе "Всё безопасно" они будут удалены. Продолжить?',
        onOk: async () => {
          try {
            for (const v of violations.filter(v => !v.is_safe)) {
              await apiClient.delete(`/inspections/violations/${v.id}`);
            }
            const response = await apiClient.post(`/inspections/${inspectionId}/violations`, {
              work_type_id: workTypes[0]?.id || '00000000-0000-0000-0000-000000000000',
              is_safe: true,
              violation_description: null,
              is_gross_violation: false,
              is_work_stopped: false,
              zpb_rule_id: null,
              order: 0,
              photos: [],
            });
            onChange([response.data]);
            message.success('Отмечено "Всё безопасно"');
          } catch (error: any) {
            console.error('Ошибка создания строки:', error);
            message.error('Ошибка создания строки');
          }
        },
      });
    } else {
      try {
        const response = await apiClient.post(`/inspections/${inspectionId}/violations`, {
          work_type_id: workTypes[0]?.id || '00000000-0000-0000-0000-000000000000',
          is_safe: true,
          violation_description: null,
          is_gross_violation: false,
          is_work_stopped: false,
          zpb_rule_id: null,
          order: 0,
          photos: [],
        });
        onChange([response.data]);
        message.success('Отмечено "Всё безопасно"');
      } catch (error: any) {
        console.error('Ошибка создания строки:', error);
        message.error('Ошибка создания строки');
      }
    }
  };

  const addViolation = async () => {
    if (hasSafeRow) {
      message.warning('Сначала удалите строку "Всё безопасно"');
      return;
    }
    
    if (!workTypes.length) {
      message.error('Справочники еще не загружены');
      return;
    }

    try {
      const response = await apiClient.post(`/inspections/${inspectionId}/violations`, {
        work_type_id: workTypes[0].id,
        is_safe: false,
        violation_description: 'Новое нарушение',
        is_gross_violation: false,
        is_work_stopped: false,
        zpb_rule_id: null,
        order: violations.length,
        photos: [],
      });
      onChange([...violations, response.data]);
      message.success('Нарушение добавлено');
    } catch (error: any) {
      console.error('Ошибка создания нарушения:', error);
      message.error('Ошибка создания нарушения');
    }
  };

  const removeViolation = async (violationId: string) => {
    try {
      await apiClient.delete(`/inspections/violations/${violationId}`);
      onChange(violations.filter((v) => v.id !== violationId));
      message.success('Строка удалена');
    } catch (error: any) {
      console.error('Ошибка удаления:', error);
      message.error('Ошибка удаления');
    }
  };

  const updateViolation = async (violationId: string, field: string, value: any) => {
    const violation = violations.find((v) => v.id === violationId);
    if (!violation) return;

    const updatedViolation = { ...violation, [field]: value };

    // Авторасчет is_top_violation
    if (field === 'zpb_rule_id' || field === 'is_work_stopped') {
      updatedViolation.is_top_violation = !!updatedViolation.zpb_rule_id && updatedViolation.is_work_stopped;
    }

    // Обновляем локальное состояние
    onChange(violations.map((v) => (v.id === violationId ? updatedViolation : v)));

    // Отправляем на сервер
    try {
      const dataToSend: any = {
        work_type_id: updatedViolation.work_type_id,
        is_safe: updatedViolation.is_safe,
        violation_description: updatedViolation.violation_description || null,
        is_gross_violation: updatedViolation.is_gross_violation,
        is_work_stopped: updatedViolation.is_work_stopped,
        zpb_rule_id: updatedViolation.zpb_rule_id || null,
        order: updatedViolation.order,
      };

      const response = await apiClient.put(`/inspections/violations/${violationId}`, dataToSend);
      
      // Обновляем с данными из ответа
      onChange(violations.map((v) => (v.id === violationId ? response.data : v)));
    } catch (error: any) {
      console.error('Ошибка обновления:', error);
      message.error('Ошибка сохранения');
    }
  };

  return (
    <div>
      <Divider titlePlacement="left">Строки наблюдений</Divider>

      {violations.length === 0 && (
        <Alert
          title="Добавьте строку наблюдения"
          description="Выберите один из вариантов ниже"
          type="info"
          showIcon
          style={{ marginBottom: 16 }}
        />
      )}

      {violations.map((violation, index) => (
        <ViolationRowItem
          key={violation.id}
          violation={violation}
          index={index}
          workTypes={workTypes}
          zpbRules={zpbRules}
          onUpdate={updateViolation}
          onRemove={removeViolation}
        />
      ))}

      <Space orientation="vertical" style={{ width: '100%' }}>
        <Button type="dashed" onClick={addViolation} icon={<PlusOutlined />} block disabled={hasSafeRow}>
          Добавить строку нарушения
        </Button>

        <Button
          type="dashed"
          onClick={addSafeRow}
          icon={<CheckCircleOutlined />}
          block
          disabled={hasViolationRows && !hasSafeRow}
          style={{ borderColor: '#52c41a', color: '#52c41a' }}
        >
          Отметить "Всё безопасно"
        </Button>
      </Space>
    </div>
  );
};

export default ViolationRows;