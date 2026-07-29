import React, { useEffect, useState } from 'react';
import { 
  Card, Tabs, Table, Button, Modal, Form, Input, message, Popconfirm, 
  Select, Space, Tag, Divider, Empty 
} from 'antd';
import { 
  PlusOutlined, EditOutlined, DeleteOutlined, ApartmentOutlined,
  SaveOutlined, CloseOutlined
} from '@ant-design/icons';
import apiClient from '../api/client';
import { canManageReferences } from '../utils/permissions';

interface PE { id: string; name: string; code: string; }
interface Department { id: string; name: string; pe_id: string; pe_name?: string; }
interface Contractor { id: string; name: string; inn?: string; }
interface WorkType { id: string; name: string; code: string; }
interface ZPBRule { id: string; number: number; name: string; }

const References: React.FC = () => {
  const [activeTab, setActiveTab] = useState('pe');
  const [canManage, setCanManage] = useState(false);
  
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [contractors, setContractors] = useState<Contractor[]>([]);
  const [workTypes, setWorkTypes] = useState<WorkType[]>([]);
  const [zpbRules, setZpbRules] = useState<ZPBRule[]>([]);
  
  // Состояния для модального окна редактирования ПЕ с подразделениями
  const [peModalVisible, setPeModalVisible] = useState(false);
  const [editingPE, setEditingPE] = useState<PE | null>(null);
  const [peDepartments, setPeDepartments] = useState<Department[]>([]);
  const [newDeptName, setNewDeptName] = useState('');
  const [loadingDepts, setLoadingDepts] = useState(false);
  
  // Состояния для модалок добавления/редактирования других справочников
  const [modalVisible, setModalVisible] = useState(false);
  const [editingItem, setEditingItem] = useState<any>(null);
  const [form] = Form.useForm();
  const [peForm] = Form.useForm();

  useEffect(() => {
    setCanManage(canManageReferences());
    loadAllReferences();
  }, []);

  const loadAllReferences = async () => {
    try {
      const [peRes, deptRes, contrRes, wtRes, zpbRes] = await Promise.all([
        apiClient.get('/references/pe'),
        apiClient.get('/references/departments'),
        apiClient.get('/references/contractors'),
        apiClient.get('/references/work-types'),
        apiClient.get('/references/zpb-rules'),
      ]);
      setPes(peRes.data);
      setDepartments(deptRes.data);
      setContractors(contrRes.data);
      setWorkTypes(wtRes.data);
      setZpbRules(zpbRes.data);
    } catch (error) {
      message.error('Ошибка загрузки справочников');
    }
  };

  // ==================== Управление ПЕ с подразделениями ====================
  
  const handleAddPE = () => {
    setEditingPE(null);
    peForm.resetFields();
    setPeDepartments([]);
    setPeModalVisible(true);
  };

  const handleEditPE = async (pe: PE) => {
    setEditingPE(pe);
    peForm.setFieldsValue(pe);
    setPeModalVisible(true);
    await loadPEDepartments(pe.id);
  };

  const loadPEDepartments = async (peId: string) => {
    setLoadingDepts(true);
    try {
      const res = await apiClient.get(`/references/departments?pe_id=${peId}`);
      setPeDepartments(res.data);
    } catch (error) {
      message.error('Ошибка загрузки подразделений');
    } finally {
      setLoadingDepts(false);
    }
  };

  const handleSavePE = async () => {
    try {
      const values = await peForm.validateFields();
      if (editingPE) {
        await apiClient.put(`/references/pe/${editingPE.id}`, values);
        message.success('ПЕ обновлена');
      } else {
        await apiClient.post('/references/pe', values);
        message.success('ПЕ добавлена');
      }
      setPeModalVisible(false);
      peForm.resetFields();
      setEditingPE(null);
      setPeDepartments([]);
      loadAllReferences();
    } catch (error: any) {
      const detail = error.response?.data?.detail;
      message.error(Array.isArray(detail) ? detail.map((e: any) => e.msg).join(', ') : (detail || 'Ошибка сохранения'));
    }
  };

  const handleAddDepartment = async () => {
    if (!editingPE || !newDeptName.trim()) {
      message.warning('Введите название подразделения');
      return;
    }
    try {
      await apiClient.post('/references/departments', {
        name: newDeptName.trim(),
        pe_id: editingPE.id
      });
      message.success('Подразделение добавлено');
      setNewDeptName('');
      await loadPEDepartments(editingPE.id);
      loadAllReferences();
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Ошибка добавления подразделения');
    }
  };

  const handleDeleteDepartment = async (deptId: string) => {
    if (!editingPE) return;
    try {
      await apiClient.delete(`/references/departments/${deptId}`);
      message.success('Подразделение удалено');
      await loadPEDepartments(editingPE.id);
      loadAllReferences();
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Ошибка удаления подразделения');
    }
  };

  // ==================== Управление другими справочниками ====================
  
  const handleAdd = () => {
    // Если активна вкладка ПЕ, открываем специальную модалку для ПЕ
    if (activeTab === 'pe') {
      handleAddPE();
      return;
    }
    
    setEditingItem(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEdit = (record: any) => {
    // Если редактируем ПЕ, открываем специальную модалку
    if (activeTab === 'pe') {
      handleEditPE(record);
      return;
    }
    
    setEditingItem(record);
    form.setFieldsValue(record);
    setModalVisible(true);
  };

  const handleDelete = async (id: string) => {
    try {
      await apiClient.delete(`/references/${activeTab}/${id}`);
      message.success('Запись удалена');
      loadAllReferences();
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Ошибка удаления');
    }
  };

  const handleSave = async () => {
    try {
      const values = await form.validateFields();
      if (editingItem) {
        await apiClient.put(`/references/${activeTab}/${editingItem.id}`, values);
        message.success('Запись обновлена');
      } else {
        await apiClient.post(`/references/${activeTab}`, values);
        message.success('Запись добавлена');
      }
      setModalVisible(false);
      loadAllReferences();
    } catch (error: any) {
      const detail = error.response?.data?.detail;
      message.error(Array.isArray(detail) ? detail.map((e: any) => e.msg).join(', ') : (detail || 'Ошибка сохранения'));
    }
  };

  // ==================== Колонки таблиц ====================
  
  const getColumns = () => {
    const actions = (_: any, record: any) => (
      <Space>
        <Button icon={<EditOutlined />} onClick={() => handleEdit(record)} disabled={!canManage} />
        <Popconfirm 
          title="Удалить запись?" 
          description="Это действие нельзя отменить."
          onConfirm={() => handleDelete(record.id)} 
          disabled={!canManage}
        >
          <Button icon={<DeleteOutlined />} danger disabled={!canManage} />
        </Popconfirm>
      </Space>
    );

    switch (activeTab) {
      case 'pe':
        return [
          { title: 'Название', dataIndex: 'name', key: 'name' },
          { title: 'Код', dataIndex: 'code', key: 'code' },
          { 
            title: 'Подразделения', 
            key: 'dept_count',
            render: (_: any, record: PE) => {
              const count = departments.filter(d => d.pe_id === record.id).length;
              return <Tag color="blue">{count} подразделений</Tag>;
            }
          },
          { 
            title: 'Действия', 
            key: 'actions', 
            render: (_: any, record: PE) => (
              <Space>
                <Button 
                  icon={<ApartmentOutlined />} 
                  onClick={() => handleEditPE(record)} 
                  disabled={!canManage}
                >
                  Редактировать ПЕ и подразделения
                </Button>
                <Popconfirm 
                  title="Удалить ПЕ?" 
                  description="Все подразделения этой ПЕ также будут удалены."
                  onConfirm={() => handleDelete(record.id)} 
                  disabled={!canManage}
                >
                  <Button icon={<DeleteOutlined />} danger disabled={!canManage} />
                </Popconfirm>
              </Space>
            )
          },
        ];
      case 'contractors':
        return [
          { title: 'Название', dataIndex: 'name', key: 'name' },
          { title: 'ИНН', dataIndex: 'inn', key: 'inn' },
          { title: 'Действия', key: 'actions', render: actions },
        ];
      case 'work-types':
        return [
          { title: 'Название', dataIndex: 'name', key: 'name' },
          { title: 'Код', dataIndex: 'code', key: 'code' },
          { title: 'Действия', key: 'actions', render: actions },
        ];
      case 'zpb-rules':
        return [
          { title: '№', dataIndex: 'number', key: 'number', width: 80 },
          { title: 'Название', dataIndex: 'name', key: 'name' },
          { title: 'Действия', key: 'actions', render: actions },
        ];
      default:
        return [];
    }
  };

  const getModalFields = () => {
    switch (activeTab) {
      case 'contractors':
        return (
          <>
            <Form.Item name="name" label="Название" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input />
            </Form.Item>
            <Form.Item name="inn" label="ИНН">
              <Input />
            </Form.Item>
          </>
        );
      case 'work-types':
        return (
          <>
            <Form.Item name="name" label="Название" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input />
            </Form.Item>
            <Form.Item name="code" label="Код" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input />
            </Form.Item>
          </>
        );
      case 'zpb-rules':
        return (
          <>
            <Form.Item name="number" label="Номер" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input type="number" />
            </Form.Item>
            <Form.Item name="name" label="Название" rules={[{ required: true, message: 'Обязательно' }]}>
              <Input />
            </Form.Item>
          </>
        );
      default:
        return null;
    }
  };

  const getData = () => {
    switch (activeTab) {
      case 'pe': return pes;
      case 'contractors': return contractors;
      case 'work-types': return workTypes;
      case 'zpb-rules': return zpbRules;
      default: return [];
    }
  };

  const tabTitles: Record<string, string> = {
    pe: 'Производственные единицы',
    contractors: 'Подрядчики',
    'work-types': 'Виды работ',
    'zpb-rules': 'Золотые Правила Безопасности',
  };

  // Колонки для таблицы подразделений внутри модалки ПЕ
  const deptColumns = [
    { title: 'Название', dataIndex: 'name', key: 'name' },
    {
      title: 'Действия',
      key: 'actions',
      width: 100,
      render: (_: any, record: Department) => (
        <Popconfirm
          title="Удалить подразделение?"
          onConfirm={() => handleDeleteDepartment(record.id)}
        >
          <Button icon={<DeleteOutlined />} danger size="small" />
        </Popconfirm>
      ),
    },
  ];

  // Раскрывающиеся строки для таблицы ПЕ (быстрый просмотр подразделений)
  const expandedRowRender = (record: PE) => {
    const peDepts = departments.filter(d => d.pe_id === record.id);
    if (peDepts.length === 0) {
      return <Empty description="Нет подразделений" image={Empty.PRESENTED_IMAGE_SIMPLE} />;
    }
    return (
      <Table
        columns={[
          { title: 'Название подразделения', dataIndex: 'name', key: 'name' },
        ]}
        dataSource={peDepts}
        rowKey="id"
        pagination={false}
        size="small"
      />
    );
  };

  return (
    <div>
      <Card title="Управление справочниками">
        {!canManage && (
          <div style={{ marginBottom: 16 }}>
            <Tag color="orange">У вас нет прав на редактирование справочников</Tag>
          </div>
        )}
        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          items={[
            { key: 'pe', label: 'Производственные единицы' },
            { key: 'contractors', label: 'Подрядчики' },
            { key: 'work-types', label: 'Виды работ' },
            { key: 'zpb-rules', label: 'ЗПБ' },
          ]}
        />
        <div style={{ marginBottom: 16 }}>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAdd} disabled={!canManage}>
            Добавить в «{tabTitles[activeTab]}»
          </Button>
        </div>
        <Table
          dataSource={getData()}
          columns={getColumns()}
          rowKey="id"
          pagination={{ pageSize: 20 }}
          expandable={activeTab === 'pe' ? {
            expandedRowRender,
            rowExpandable: () => true,
          } : undefined}
        />
        
        {/* Модальное окно для других справочников */}
        <Modal
          title={editingItem ? 'Редактирование' : 'Добавление'}
          open={modalVisible}
          onOk={handleSave}
          onCancel={() => setModalVisible(false)}
          okText="Сохранить"
          cancelText="Отмена"
        >
          <Form form={form} layout="vertical">
            {getModalFields()}
          </Form>
        </Modal>

        {/* Модальное окно редактирования ПЕ с подразделениями */}
        <Modal
          title={
            <Space>
              <ApartmentOutlined />
              <span>{editingPE ? `Редактирование ПЕ: ${editingPE.name}` : 'Добавление новой ПЕ'}</span>
            </Space>
          }
          open={peModalVisible}
          onOk={handleSavePE}
          onCancel={() => {
            setPeModalVisible(false);
            peForm.resetFields();
            setEditingPE(null);
            setPeDepartments([]);
          }}
          okText="Сохранить ПЕ"
          cancelText="Отмена"
          width={800}
        >
          <Form form={peForm} layout="vertical">
            <Form.Item 
              name="name" 
              label="Название ПЕ" 
              rules={[{ required: true, message: 'Обязательно' }]}
            >
              <Input />
            </Form.Item>
            <Form.Item 
              name="code" 
              label="Код ПЕ" 
              rules={[{ required: true, message: 'Обязательно' }]}
            >
              <Input />
            </Form.Item>
          </Form>

          {/* Блок управления подразделениями показываем только при редактировании */}
          {editingPE && (
            <>
              <Divider />

              <div style={{ marginBottom: 16 }}>
                <h4>Подразделения ПЕ</h4>
                <Space.Compact style={{ width: '100%', marginBottom: 16 }}>
                  <Input
                    placeholder="Название нового подразделения"
                    value={newDeptName}
                    onChange={(e) => setNewDeptName(e.target.value)}
                    onPressEnter={handleAddDepartment}
                    style={{ width: '70%' }}
                  />
                  <Button 
                    type="primary" 
                    icon={<PlusOutlined />} 
                    onClick={handleAddDepartment}
                    disabled={!canManage}
                  >
                    Добавить
                  </Button>
                </Space.Compact>

                <Table
                  columns={deptColumns}
                  dataSource={peDepartments}
                  rowKey="id"
                  loading={loadingDepts}
                  pagination={false}
                  size="small"
                  locale={{ emptyText: <Empty description="Нет подразделений" /> }}
                />
              </div>
            </>
          )}
        </Modal>
      </Card>
    </div>
  );
};

export default References;