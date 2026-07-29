import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Modal, Form, Input, message, Popconfirm, Select, Space, Tag } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import apiClient from '../api/client';
import { canManageUsers, getRoleDisplayName } from '../utils/permissions';
import type { UserRole } from '../utils/permissions';

interface User {
  id: string;
  email: string;
  full_name: string;
  is_active: boolean;
  roles: { id: string; name: string; display_name: string }[];
}

const allRoles: UserRole[] = ['admin', 'coordinator', 'manager', 'inspector', 'observer', 'contractor'];

const Users: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [canManage, setCanManage] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [form] = Form.useForm();

  useEffect(() => {
    setCanManage(canManageUsers());
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await apiClient.get('/users');
      setUsers(response.data);
    } catch (error) {
      message.error('Ошибка загрузки пользователей');
    }
  };

  const handleAdd = () => {
    setEditingUser(null);
    form.resetFields();
    form.setFieldsValue({ is_active: true, roles: [] });
    setModalVisible(true);
  };

  const handleEdit = (user: User) => {
    setEditingUser(user);
    form.setFieldsValue({
      email: user.email,
      full_name: user.full_name,
      is_active: user.is_active,
      roles: user.roles.map(r => r.name),
    });
    setModalVisible(true);
  };

  const handleDelete = async (id: string) => {
    try {
      await apiClient.delete(`/users/${id}`);
      message.success('Пользователь удалён');
      loadUsers();
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Ошибка удаления');
    }
  };

  const handleSave = async () => {
    try {
      const values = await form.validateFields();

      if (editingUser) {
        // 1. Обновляем основные данные (без roles)
        const { roles, password, ...userData } = values;
        
        // Отправляем PUT только если есть что обновлять
        if (userData.email || userData.full_name || userData.is_active !== undefined) {
          await apiClient.put(`/users/${editingUser.id}`, {
            email: userData.email,
            full_name: userData.full_name,
            is_active: userData.is_active,
          });
        }
        
        // 2. Отдельно обновляем роли (массив строк)
        await apiClient.put(`/users/${editingUser.id}/roles`, { roles: roles });
        
        message.success('Пользователь обновлён');
      } else {
        // Создание нового пользователя
        await apiClient.post('/users', values);
        message.success('Пользователь создан');
      }

      setModalVisible(false);
      loadUsers();
    } catch (error: any) {
      console.error('Ошибка сохранения:', error);
      const detail = error.response?.data?.detail;
      let errorMsg = 'Ошибка сохранения';
      
      if (Array.isArray(detail)) {
        errorMsg = detail.map((e: any) => {
          const path = e.loc ? e.loc.join(' → ') : 'field';
          return `${path}: ${e.msg}`;
        }).join('; ');
      } else if (typeof detail === 'string') {
        errorMsg = detail;
      } else if (error.response?.status === 422) {
        errorMsg = 'Неверный формат данных. Проверьте заполнение полей.';
      }
      
      message.error(errorMsg);
    }
  };

  const columns = [
    { title: 'Email', dataIndex: 'email', key: 'email' },
    { title: 'ФИО', dataIndex: 'full_name', key: 'full_name' },
    {
      title: 'Роли',
      key: 'roles',
      render: (_: any, record: User) => (
        <Space wrap>
          {record.roles.map(role => (
            <Tag key={role.id} color="blue">{getRoleDisplayName(role.name)}</Tag>
          ))}
          {record.roles.length === 0 && <Tag>Без ролей</Tag>}
        </Space>
      ),
    },
    {
      title: 'Статус',
      key: 'is_active',
      render: (_: any, record: User) => (
        <Tag color={record.is_active ? 'green' : 'red'}>
          {record.is_active ? 'Активен' : 'Заблокирован'}
        </Tag>
      ),
    },
    {
      title: 'Действия',
      key: 'actions',
      render: (_: any, record: User) => (
        <Space>
          <Button icon={<EditOutlined />} onClick={() => handleEdit(record)} disabled={!canManage} />
          <Popconfirm title="Удалить пользователя?" onConfirm={() => handleDelete(record.id)} disabled={!canManage}>
            <Button icon={<DeleteOutlined />} danger disabled={!canManage} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Card title="Управление пользователями">
        {!canManage && (
          <div style={{ marginBottom: 16 }}>
            <Tag color="orange">У вас нет прав на управление пользователями</Tag>
          </div>
        )}

        <div style={{ marginBottom: 16 }}>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAdd} disabled={!canManage}>
            Добавить пользователя
          </Button>
        </div>

        <Table dataSource={users} columns={columns} rowKey="id" pagination={{ pageSize: 20 }} />

        <Modal
          title={editingUser ? 'Редактирование пользователя' : 'Новый пользователь'}
          open={modalVisible}
          onOk={handleSave}
          onCancel={() => setModalVisible(false)}
          okText="Сохранить"
          cancelText="Отмена"
        >
          <Form form={form} layout="vertical">
            <Form.Item name="email" label="Email" rules={[{ required: true, type: 'email', message: 'Введите корректный email' }]}>
              <Input />
            </Form.Item>
            <Form.Item name="full_name" label="ФИО" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input />
            </Form.Item>
            {!editingUser && (
              <Form.Item name="password" label="Пароль" rules={[{ required: true, min: 8, message: 'Минимум 8 символов' }]}>
                <Input.Password />
              </Form.Item>
            )}
            <Form.Item name="roles" label="Роли" rules={[{ required: true, message: 'Выберите хотя бы одну роль' }]}>
              <Select
                mode="multiple"
                placeholder="Выберите роли"
                options={allRoles.map(role => ({ value: role, label: getRoleDisplayName(role) }))}
              />
            </Form.Item>
            <Form.Item name="is_active" label="Активен" rules={[{ required: true }]}>
              <Select
                options={[
                  { value: true, label: 'Да' },
                  { value: false, label: 'Нет' },
                ]}
              />
            </Form.Item>
          </Form>
        </Modal>
      </Card>
    </div>
  );
};

export default Users;