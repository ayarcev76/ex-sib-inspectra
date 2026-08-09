import React, { useEffect, useState } from 'react';
import { Form, Select, Input, DatePicker, Button, Card, message } from 'antd';
import { ArrowLeftOutlined, SaveOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import apiClient from '../api/client';
import { getCurrentUser } from '../utils/auth';

interface PE {
  id: string;
  name: string;
}

interface Department {
  id: string;
  name: string;
  pe_id: string;
}

interface Contractor {
  id: string;
  name: string;
}

const InspectionForm: React.FC = () => {
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [contractors, setContractors] = useState<Contractor[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const loadReferences = async () => {
      try {
        const [peResponse, contractorResponse] = await Promise.all([
          apiClient.get('/references/pe'),
          apiClient.get('/references/contractors'),
        ]);
        setPes(peResponse.data);
        setContractors(contractorResponse.data);
      } catch (error) {
        message.error('Ошибка загрузки справочников');
      }
    };
    loadReferences();
  }, []);

  const handlePEChange = async (peId: string) => {
    if (peId) {
      try {
        const response = await apiClient.get(`/references/departments?pe_id=${peId}`);
        setDepartments(response.data);
        form.setFieldsValue({ department_id: undefined });
      } catch (error) {
        message.error('Ошибка загрузки подразделений');
      }
    } else {
      setDepartments([]);
      form.setFieldsValue({ department_id: undefined });
    }
  };

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const currentUser = await getCurrentUser();
      if (!currentUser) {
        message.error('Пользователь не авторизован');
        navigate('/login');
        return;
      }

      // 🔑 ГЕНЕРИРУЕМ УНИКАЛЬНЫЙ ID КЛИЕНТА (UUID v4)
      const clientId = crypto.randomUUID();

      const inspectionData = {
        client_id: clientId, // 🔑 ДОБАВЛЯЕМ ЕГО В ЗАПРОС
        date: values.date.format('YYYY-MM-DD'),
        pe_id: values.pe_id,
        department_id: values.department_id,
        inspector_id: currentUser.id,
        contractor_id: values.contractor_id || null,
        work_location: values.work_location,
        source: 'web',
        status: 'draft',
        violations: [],
      };

      // 🔑 ВАЖНО: добавлен слэш в конце '/inspections/' чтобы избежать 307 редиректа FastAPI
      const response = await apiClient.post('/inspections/', inspectionData);
      const newInspectionId = response.data.id;
      
      message.success('Карта наблюдения создана. Теперь добавьте строки наблюдений.');
      navigate(`/inspections/${newInspectionId}/edit`);
    } catch (error: any) {
      console.error('Ошибка создания карты наблюдения:', error);
      const errorMsg = error.response?.data?.detail || 'Ошибка создания карты наблюдения';
      message.error(typeof errorMsg === 'string' ? errorMsg : 'Произошла неизвестная ошибка');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/inspections')} style={{ marginBottom: 16 }}>
        Назад к списку
      </Button>
      <Card title="Создание карты наблюдения">
        <Form form={form} layout="vertical" onFinish={onFinish}>
          <Form.Item
            name="date"
            label="Дата проведения"
            rules={[{ required: true, message: 'Выберите дату' }]}
          >
            <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
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

          <Form.Item style={{ marginTop: 24 }}>
            <Button
              type="primary"
              htmlType="submit"
              icon={<SaveOutlined />}
              loading={loading}
              style={{ marginRight: 8 }}
            >
              Создать карту наблюдения
            </Button>
            <Button onClick={() => navigate('/inspections')}>Отмена</Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default InspectionForm;