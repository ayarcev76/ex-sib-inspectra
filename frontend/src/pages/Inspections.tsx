import React, { useEffect, useState, useCallback } from 'react';
import { Table, Button, Tag, Space, Spin, Alert, message, Select, DatePicker, Card, Row, Col } from 'antd';
import { EyeOutlined, EditOutlined, PlusOutlined, FilterOutlined, ClearOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import dayjs, { Dayjs } from 'dayjs';
import apiClient from '../api/client';

interface PE {
  id: string;
  name: string;
}

interface Department {
  id: string;
  name: string;
  pe_id: string;
}

interface User {
  id: string;
  full_name: string;
}

interface Inspection {
  id: string;
  inspection_number: string;
  date: string;
  pe_id: string;
  department_id: string;
  inspector_id: string;
  contractor_id: string | null;
  work_location: string;
  source: 'mobile' | 'web';
  status: 'draft' | 'submitted' | 'approved';
  created_at: string;
}

const { RangePicker } = DatePicker;

const Inspections: React.FC = () => {
  const navigate = useNavigate();
  
  // Основные данные
  const [inspections, setInspections] = useState<Inspection[]>([]);
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  
  // Состояния загрузки и ошибок
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Состояния фильтров
  const [filterPE, setFilterPE] = useState<string | null>(null);
  const [filterDepartment, setFilterDepartment] = useState<string | null>(null);
  const [filterDateRange, setFilterDateRange] = useState<[Dayjs | null, Dayjs | null] | null>(null);
  const [filterStatus, setFilterStatus] = useState<string | null>(null);
  
  // Пагинация
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
  });

  // Загрузка справочников (один раз при монтировании)
  useEffect(() => {
    const loadReferences = async () => {
      try {
        const [peResponse, deptResponse, usersResponse] = await Promise.all([
          apiClient.get('/references/pe'),
          apiClient.get('/references/departments'),
          apiClient.get('/users'),
        ]);
        
        setPes(peResponse.data);
        setDepartments(deptResponse.data);
        setUsers(usersResponse.data);
      } catch (err) {
        console.error('Ошибка загрузки справочников:', err);
        message.error('Ошибка загрузки справочников');
      }
    };
    loadReferences();
  }, []);

  // Загрузка проверок с серверной фильтрацией
  const loadInspections = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const params = new URLSearchParams();
      
      // Добавляем фильтры
      if (filterPE) params.append('pe_id', filterPE);
      if (filterDepartment) params.append('department_id', filterDepartment);
      if (filterDateRange && filterDateRange[0]) {
        params.append('date_from', filterDateRange[0].format('YYYY-MM-DD'));
      }
      if (filterDateRange && filterDateRange[1]) {
        params.append('date_to', filterDateRange[1].format('YYYY-MM-DD'));
      }
      if (filterStatus) params.append('status', filterStatus);
      
      // Добавляем пагинацию
      const skip = (pagination.current - 1) * pagination.pageSize;
      params.append('skip', String(skip));
      params.append('limit', String(pagination.pageSize));
      
      const response = await apiClient.get(`/inspections?${params.toString()}`);
      
      setInspections(response.data.items);
      setPagination(prev => ({
        ...prev,
        total: response.data.total,
      }));
    } catch (err) {
      console.error('Ошибка загрузки карт наблюдения:', err);
      setError('Не удалось загрузить список карт наблюдения');
      message.error('Ошибка загрузки списка карт наблюдения');
    } finally {
      setLoading(false);
    }
  }, [filterPE, filterDepartment, filterDateRange, filterStatus, pagination.current, pagination.pageSize]);

  // Перезагрузка при изменении фильтров или пагинации
  useEffect(() => {
    loadInspections();
  }, [loadInspections]);

  // Каскадная фильтрация подразделений по выбранной ПЕ
  const filteredDepartments = departments.filter(dept => {
    if (!filterPE) return true;
    return dept.pe_id === filterPE;
  });

  // Обработчик изменения ПЕ (сбрасывает подразделение если оно не из новой ПЕ)
  const handlePEChange = (value: string | null) => {
    setFilterPE(value);
    setPagination(prev => ({ ...prev, current: 1 })); // Сброс на первую страницу
    
    // Если выбранное подразделение не принадлежит новой ПЕ, сбрасываем его
    if (value && filterDepartment) {
      const dept = departments.find(d => d.id === filterDepartment);
      if (dept && dept.pe_id !== value) {
        setFilterDepartment(null);
      }
    }
  };

  // Обработчик изменения фильтра подразделения
  const handleDepartmentChange = (value: string | null) => {
    setFilterDepartment(value);
    setPagination(prev => ({ ...prev, current: 1 }));
  };

  // Обработчик изменения диапазона дат
  const handleDateRangeChange = (dates: [Dayjs | null, Dayjs | null] | null) => {
    setFilterDateRange(dates);
    setPagination(prev => ({ ...prev, current: 1 }));
  };

  // Обработчик изменения статуса
  const handleStatusChange = (value: string | null) => {
    setFilterStatus(value);
    setPagination(prev => ({ ...prev, current: 1 }));
  };

  // Сброс всех фильтров
  const handleClearFilters = () => {
    setFilterPE(null);
    setFilterDepartment(null);
    setFilterDateRange(null);
    setFilterStatus(null);
    setPagination(prev => ({ ...prev, current: 1 }));
  };

  // Обработчик изменения страницы
  const handleTableChange = (paginationConfig: any) => {
    setPagination(prev => ({
      ...prev,
      current: paginationConfig.current,
      pageSize: paginationConfig.pageSize,
    }));
  };

  // Проверка, есть ли активные фильтры
  const hasActiveFilters = filterPE || filterDepartment || filterDateRange || filterStatus;

  // Маппинги ID → Name для отображения
  const peMap: Record<string, string> = {};
  pes.forEach(pe => { peMap[pe.id] = pe.name; });

  const deptMap: Record<string, string> = {};
  departments.forEach(dept => { deptMap[dept.id] = dept.name; });

  const userMap: Record<string, string> = {};
  users.forEach(user => { userMap[user.id] = user.full_name; });

  const columns = [
    {
      title: 'Номер',
      dataIndex: 'inspection_number',
      key: 'inspection_number',
      render: (text: string) => <strong>{text}</strong>,
    },
    {
      title: 'Дата',
      dataIndex: 'date',
      key: 'date',
      render: (date: string) => dayjs(date).format('DD.MM.YYYY'),
      sorter: (a, b) => dayjs(a.date).unix() - dayjs(b.date).unix(),
    },
    {
      title: 'ПЕ',
      dataIndex: 'pe_id',
      key: 'pe_name',
      render: (peId: string) => peMap[peId] || '—',
    },
    {
      title: 'Подразделение',
      dataIndex: 'department_id',
      key: 'department_name',
      render: (deptId: string) => deptMap[deptId] || '—',
    },
    {
      title: 'Инспектор',
      dataIndex: 'inspector_id',
      key: 'inspector_name',
      render: (userId: string) => userMap[userId] || '—',
    },
    {
      title: 'Место работ',
      dataIndex: 'work_location',
      key: 'work_location',
      ellipsis: true,
    },
    {
      title: 'Источник',
      dataIndex: 'source',
      key: 'source',
      render: (source: string) => (
        <Tag color={source === 'mobile' ? 'blue' : 'green'}>
          {source === 'mobile' ? 'Мобильное' : 'Веб'}
        </Tag>
      ),
    },
    {
      title: 'Статус',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        const statusMap: Record<string, { color: string; text: string }> = {
          draft: { color: 'orange', text: 'Черновик' },
          submitted: { color: 'green', text: 'Завершена' },
          approved: { color: 'blue', text: 'Утверждена' },
        };
        const { color, text } = statusMap[status] || { color: 'default', text: status };
        return <Tag color={color}>{text}</Tag>;
      },
    },
    {
      title: 'Действия',
      key: 'actions',
      width: 100,
      render: (_: any, record: Inspection) => (
        <Space>
          <Button
            type="text"
            size="small"
            icon={<EyeOutlined />}
            onClick={() => navigate(`/inspections/${record.id}`)}
            title="Просмотр"
          />
          {record.status === 'draft' && (
            <Button
              type="text"
              size="small"
              icon={<EditOutlined />}
              onClick={() => navigate(`/inspections/${record.id}/edit`)}
              title="Редактировать"
            />
          )}
        </Space>
      ),
    },
  ];

  if (loading && inspections.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: 50 }}>
        <Spin size="large" />
        <p>Загрузка списка карт наблюдения...</p>
      </div>
    );
  }

  if (error) {
    return <Alert message="Ошибка" description={error} type="error" showIcon />;
  }

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>Карты наблюдения</h2>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/inspections/new')}>
          Создать карту наблюдения
        </Button>
      </div>

      {/* Блок фильтров */}
      <Card size="small" style={{ marginBottom: 16 }}>
        <Row gutter={[16, 16]} align="middle">
          <Col>
            <Space>
              <FilterOutlined style={{ color: '#1890ff' }} />
              <span style={{ fontWeight: 500 }}>Фильтры:</span>
            </Space>
          </Col>
          
          <Col flex="200px">
            <Select
              placeholder="Выберите ПЕ"
              allowClear
              style={{ width: '100%' }}
              value={filterPE}
              onChange={handlePEChange}
              options={[
                { value: null, label: 'Все ПЕ' },
                ...pes.map(pe => ({ value: pe.id, label: pe.name }))
              ]}
            />
          </Col>

          <Col flex="250px">
            <Select
              placeholder="Выберите подразделение"
              allowClear
              style={{ width: '100%' }}
              value={filterDepartment}
              onChange={handleDepartmentChange}
              disabled={!filterPE}
              options={[
                { value: null, label: 'Все подразделения' },
                ...filteredDepartments.map(dept => ({ value: dept.id, label: dept.name }))
              ]}
              notFoundContent={filterPE ? 'Нет подразделений' : 'Сначала выберите ПЕ'}
            />
          </Col>

          <Col flex="300px">
            <RangePicker
              style={{ width: '100%' }}
              value={filterDateRange as [Dayjs | null, Dayjs | null]}
              onChange={handleDateRangeChange}
              format="DD.MM.YYYY"
              placeholder={['Дата начала', 'Дата окончания']}
            />
          </Col>

          <Col flex="150px">
            <Select
              placeholder="Статус"
              allowClear
              style={{ width: '100%' }}
              value={filterStatus}
              onChange={handleStatusChange}
              options={[
                { value: null, label: 'Все статусы' },
                { value: 'draft', label: 'Черновик' },
                { value: 'submitted', label: 'Завершена' },
                { value: 'approved', label: 'Утверждена' },
              ]}
            />
          </Col>

          <Col>
            <Button
              icon={<ClearOutlined />}
              onClick={handleClearFilters}
              disabled={!hasActiveFilters}
            >
              Сбросить
            </Button>
          </Col>

          {hasActiveFilters && (
            <Col>
              <Tag color="blue">
                Найдено: {pagination.total}
              </Tag>
            </Col>
          )}
        </Row>
      </Card>

      <Table
        columns={columns}
        dataSource={inspections.map((insp) => ({ ...insp, key: insp.id }))}
        pagination={{
          current: pagination.current,
          pageSize: pagination.pageSize,
          total: pagination.total,
          showSizeChanger: true,
          showTotal: (total, range) => `${range[0]}-${range[1]} из ${total}`,
        }}
        onChange={handleTableChange}
        loading={loading}
        locale={{ emptyText: 'Карты наблюдения не найдены' }}
      />
    </div>
  );
};

export default Inspections;