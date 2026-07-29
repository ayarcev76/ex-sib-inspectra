import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Modal, Form, Select, DatePicker, message, Popconfirm, Tag, Space } from 'antd';
import { PlusOutlined, StopOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import apiClient from '../api/client';
import { canManageAssignments } from '../utils/permissions';

interface User { id: string; email: string; full_name: string; }
interface PE { id: string; name: string; }
interface Assignment {
  id: string;
  user_id: string;
  user_name?: string;
  user_email?: string;
  pe_id: string;
  pe_name?: string;
  valid_from: string;
  valid_to?: string;
  is_active: boolean;
}

const Assignments: React.FC = () => {
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [pes, setPes] = useState<PE[]>([]);
  const [canManage, setCanManage] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [form] = Form.useForm();

  useEffect(() => {
    setCanManage(canManageAssignments());
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [usersRes, peRes] = await Promise.all([
        apiClient.get('/users'),
        apiClient.get('/references/pe'),
      ]);
      setUsers(usersRes.data);
      setPes(peRes.data);

      const allAssignments: Assignment[] = [];
      for (const user of usersRes.data) {
        try {
          const assignmentsRes = await apiClient.get(`/users/${user.id}/assignments`);
          const enriched = assignmentsRes.data.map((a: any) => ({
            ...a,
            user_name: user.full_name,
            user_email: user.email,
          }));
          allAssignments.push(...enriched);
        } catch {
          // пропускаем пользователей без назначений
        }
      }
      setAssignments(allAssignments);
    } catch (error) {
      message.error('Ошибка загрузки данных');
    }
  };

  const handleAdd = () => {
    form.resetFields();
    form.setFieldsValue({ valid_from: dayjs() });
    setModalVisible(true);
  };

  const handleTerminate = async (assignmentId: string) => {
    try {
      await apiClient.post(`/users/assignments/${assignmentId}/terminate`);
      message.success('Назначение завершено');
      loadData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Ошибка завершения');
    }
  };

  const handleSave = async () => {
    try {
      const values = await form.validateFields();
      await apiClient.post(`/users/${values.user_id}/assignments`, {
        pe_id: values.pe_id,
        valid_from: values.valid_from.format('YYYY-MM-DD'),
      });
      message.success('Назначение создано');
      setModalVisible(false);
      loadData();
    } catch (error: any) {
      const detail = error.response?.data?.detail;
      message.error(Array.isArray(detail) ? detail.map((e: any) => e.msg).join(', ') : (detail || 'Ошибка сохранения'));
    }
  };

  const columns = [
    { title: 'Инспектор', key: 'user', render: (_: any, r: Assignment) => `${r.user_name || '—'} (${r.user_email || ''})` },
    { title: 'ПЕ', dataIndex: 'pe_name', key: 'pe_name', render: (v: string) => v || '—' },
    {
      title: 'Дата начала',
      dataIndex: 'valid_from',
      key: 'valid_from',
      render: (date: string) => date ? dayjs(date).format('DD.MM.YYYY') : '—',
    },
    {
      title: 'Дата окончания',
      dataIndex: 'valid_to',
      key: 'valid_to',
      render: (date?: string) => date ? dayjs(date).format('DD.MM.YYYY') : '—',
    },
    {
      title: 'Статус',
      key: 'is_active',
      render: (_: any, record: Assignment) => (
        <Tag color={record.is_active ? 'green' : 'default'}>
          {record.is_active ? 'Активно' : 'Завершено'}
        </Tag>
      ),
    },
    {
      title: 'Действия',
      key: 'actions',
      render: (_: any, record: Assignment) => (
        record.is_active && canManage ? (
          <Popconfirm title="Завершить назначение?" onConfirm={() => handleTerminate(record.id)}>
            <Button icon={<StopOutlined />} danger>Завершить</Button>
          </Popconfirm>
        ) : null
      ),
    },
  ];

  return (
    <div>
      <Card title="Назначения инспекторов на ПЕ">
        {!canManage && (
          <div style={{ marginBottom: 16 }}>
            <Tag color="orange">У вас нет прав на управление назначениями</Tag>
          </div>
        )}

        <div style={{ marginBottom: 16 }}>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAdd} disabled={!canManage}>
            Назначить инспектора
          </Button>
        </div>

        <Table dataSource={assignments} columns={columns} rowKey="id" pagination={{ pageSize: 20 }} />

        <Modal
          title="Новое назначение"
          open={modalVisible}
          onOk={handleSave}
          onCancel={() => setModalVisible(false)}
          okText="Создать"
          cancelText="Отмена"
        >
          <Form form={form} layout="vertical">
            <Form.Item name="user_id" label="Инспектор" rules={[{ required: true, message: 'Выберите инспектора' }]}>
              <Select
                showSearch
                optionFilterProp="label"
                options={users.map(u => ({ value: u.id, label: `${u.full_name} (${u.email})` }))}
                placeholder="Выберите инспектора"
              />
            </Form.Item>
            <Form.Item name="pe_id" label="Производственная единица" rules={[{ required: true, message: 'Выберите ПЕ' }]}>
              <Select options={pes.map(pe => ({ value: pe.id, label: pe.name }))} placeholder="Выберите ПЕ" />
            </Form.Item>
            <Form.Item name="valid_from" label="Дата начала" rules={[{ required: true, message: 'Выберите дату' }]}>
              <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
            </Form.Item>
          </Form>
        </Modal>
      </Card>
    </div>
  );
};

export default Assignments;