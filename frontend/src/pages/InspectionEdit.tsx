import React, { useEffect, useState } from 'react';
import { Form, Select, Input, DatePicker, Button, Card, message, Divider, Spin, Alert, Breadcrumb } from 'antd';
import { ArrowLeftOutlined, SaveOutlined, HomeOutlined } from '@ant-design/icons';
import { useParams, useNavigate, Link } from 'react-router-dom';
import dayjs from 'dayjs';
import apiClient from '../api/client';
import ViolationRows from '../components/ViolationRows';
import type { ViolationRow } from '../components/ViolationRows';

interface PE {
  id: string;
  name: string;
}

interface Department {
  id: string;
  name: string;
}

interface Contractor {
  id: string;
  name: string;
}

interface InspectionData {
  id: string;
  inspection_number: string;
  date: string;
  pe_id: string;
  department_id: string;
  inspector_id: string;
  contractor_id?: string;
  work_location: string;
  status: 'draft' | 'submitted' | 'approved';
  violations: ViolationRow[];
}

const InspectionEdit: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [contractors, setContractors] = useState<Contractor[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [violations, setViolations] = useState<ViolationRow[]>([]);
  const [inspectionData, setInspectionData] = useState<InspectionData | null>(null);

  useEffect(() => {
    const loadData = async () => {
      if (!id) return;
      try {
        setLoading(true);
        const [inspectionResponse, peResponse, contractorResponse] = await Promise.all([
          apiClient.get(`/inspections/${id}`),
          apiClient.get('/references/pe'),
          apiClient.get('/references/contractors'),
        ]);

        const inspection = inspectionResponse.data;
        setInspectionData(inspection);
        setPes(peResponse.data);
        setContractors(contractorResponse.data);
        setViolations(inspection.violations || []);

        if (inspection.pe_id) {
          const deptResponse = await apiClient.get(`/references/departments?pe_id=${inspection.pe_id}`);
          setDepartments(deptResponse.data);
        }

        form.setFieldsValue({
          date: inspection.date ? dayjs(inspection.date) : null,
          pe_id: inspection.pe_id,
          department_id: inspection.department_id,
          contractor_id: inspection.contractor_id,
          work_location: inspection.work_location,
        });
      } catch (err) {
        console.error('Ошибка загрузки данных:', err);
        message.error('Не удалось загрузить данные проверки');
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [id, form]);

  const handlePEChange = async (peId: string) => {
    if (peId) {
      try {
        const response = await apiClient.get(`/references/departments?pe_id=${peId}`);
        setDepartments(response.data);
        form.setFieldsValue({ department_id: undefined });
      } catch {
        message.error('Ошибка загрузки подразделений');
      }
    } else {
      setDepartments([]);
      form.setFieldsValue({ department_id: undefined });
    }
  };

  const onFinish = async (values: any) => {
    if (!id) return;
    setSaving(true);
    try {
      const updateData: any = {
        date: values.date.format('YYYY-MM-DD'),
        pe_id: values.pe_id,
        department_id: values.department_id,
        work_location: values.work_location?.trim() || 'Не указано',
      };

      if (values.contractor_id) {
        updateData.contractor_id = values.contractor_id;
      }

      await apiClient.put(`/inspections/${id}`, updateData);
      message.success('Проверка обновлена');
      navigate(`/inspections/${id}`);
    } catch (error: any) {
      console.error('Ошибка обновления:', error);
      message.error('Ошибка обновления проверки');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: 50 }}><Spin size="large" /><p>Загрузка...</p></div>;
  }

  if (!inspectionData) {
    return <Alert title="Ошибка" description="Проверка не найдена" type="error" showIcon />;
  }

  if (inspectionData.status !== 'draft') {
    return (
      <div>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(`/inspections/${id}`)} style={{ marginBottom: 16 }}>
          Назад к проверке
        </Button>
        <Alert
          title="Редактирование недоступно"
          description={`Проверка имеет статус "${inspectionData.status === 'submitted' ? 'Завершена' : 'Утверждена'}".`}
          type="warning"
          showIcon
        />
      </div>
    );
  }

  return (
    <div>
      {/* ✅ Осмысленные breadcrumbs с реальным номером проверки */}
      <Breadcrumb style={{ marginBottom: 16 }}>
        <Breadcrumb.Item>
          <Link to="/"><HomeOutlined /> Главная</Link>
        </Breadcrumb.Item>
        <Breadcrumb.Item>
          <Link to="/inspections">Карты наблюдений</Link>
        </Breadcrumb.Item>
        <Breadcrumb.Item>
          <Link to={`/inspections/${id}`}>{inspectionData.inspection_number}</Link>
        </Breadcrumb.Item>
        <Breadcrumb.Item>
          Редактирование
        </Breadcrumb.Item>
      </Breadcrumb>

      <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(`/inspections/${id}`)} style={{ marginBottom: 16 }}>
        Назад к проверке
      </Button>

      <Card title={`Редактирование проверки ${inspectionData.inspection_number}`}>
        <Form form={form} layout="vertical" onFinish={onFinish}>
          <Form.Item
            name="date"
            label="Дата проведения"
            rules={[{ required: true, message: 'Выберите дату' }]}
          >
            <DatePicker style={{ width: '100%' }} />
          </Form.Item>

          <Form.Item
            name="pe_id"
            label="Производственная единица"
            rules={[{ required: true, message: 'Выберите ПЕ' }]}
          >
            <Select
              placeholder="Выберите ПЕ"
              onChange={handlePEChange}
              options={pes.map((pe) => ({ value: pe.id, label: pe.name }))}
            />
          </Form.Item>

          <Form.Item
            name="department_id"
            label="Подразделение"
            rules={[{ required: true, message: 'Выберите подразделение' }]}
          >
            <Select
              placeholder="Выберите подразделение"
              options={departments.map((dept) => ({ value: dept.id, label: dept.name }))}
            />
          </Form.Item>

          <Form.Item
            name="contractor_id"
            label="Подрядная организация"
          >
            <Select
              placeholder="Выберите подрядчика (опционально)"
              allowClear
              options={contractors.map((c) => ({ value: c.id, label: c.name }))}
            />
          </Form.Item>

          <Form.Item
            name="work_location"
            label="Место производства работ"
            rules={[{ required: true, message: 'Укажите место работ' }]}
          >
            <Input placeholder="Например: Цех №1, участок 5, эстакада" />
          </Form.Item>

          <Divider>Строки наблюдений</Divider>
          <ViolationRows inspectionId={id!} violations={violations} onChange={setViolations} />

          <Form.Item style={{ marginTop: 24 }}>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving} style={{ marginRight: 8 }}>
              Сохранить изменения
            </Button>
            <Button onClick={() => navigate(`/inspections/${id}`)}>Отмена</Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default InspectionEdit;