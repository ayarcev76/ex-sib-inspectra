import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Statistic, Select, Table, Tag, Button, Space, message } from 'antd';
import { 
  WarningOutlined, 
  StopOutlined,
  FileExcelOutlined,
  FilePdfOutlined,
  FilePptOutlined
} from '@ant-design/icons';
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';
import apiClient from '../api/client';

// --- Типы для справочников ---
interface PE {
  id: string;
  name: string;
  code: string;
}

interface Department {
  id: string;
  name: string;
  pe_id: string;
}

// --- Моковые данные для графиков и таблиц (пока бэкенд аналитики не готов) ---
const mockKPI = {
  totalInspections: { current: 156, previous: 142, change: 9.86 },
  totalObservations: { current: 1247, previous: 1189, change: 4.88 },
  safePercentage: { current: 68.5, previous: 65.2, change: 5.06 },
  violationPercentage: { current: 31.5, previous: 34.8, change: -9.48 },
  topViolations: { current: 23, previous: 31, change: -25.81 },
  workStops: { current: 8, previous: 12, change: -33.33 },
};

const mockTrendData = [
  { date: '01.07', inspections: 5, violations: 18, previousViolations: 22 },
  { date: '08.07', inspections: 7, violations: 24, previousViolations: 28 },
  { date: '15.07', inspections: 6, violations: 19, previousViolations: 25 },
  { date: '22.07', inspections: 8, violations: 27, previousViolations: 30 },
];

const mockTopPE = [
  { name: 'ЕВРОХИМ-БМУ', violations: 45, inspections: 38 },
  { name: 'ПГ Фосфорит', violations: 38, inspections: 35 },
  { name: 'НАК Азот', violations: 32, inspections: 30 },
  { name: 'Невинномысский Азот', violations: 28, inspections: 28 },
  { name: 'ЕВРОХИМ-Северо-Запад', violations: 22, inspections: 25 },
];

const mockWorkTypeViolations = [
  { name: 'Ремонтные', count: 35 },
  { name: 'Огневые', count: 28 },
  { name: 'На высоте', count: 24 },
  { name: 'Газоопасные', count: 18 },
  { name: 'С ГПМ', count: 15 },
  { name: 'Электромонтаж', count: 12 },
  { name: 'Земляные', count: 8 },
  { name: 'Эксплуатация', count: 6 },
];

const mockZPBViolations = [
  { name: 'Оценка рисков', count: 18 },
  { name: 'СИЗ', count: 22 },
  { name: 'Наряд-допуск', count: 15 },
  { name: 'Право на остановку', count: 8 },
  { name: 'Нештатные ситуации', count: 5 },
  { name: 'Трезвость', count: 3 },
  { name: 'Сокрытие инцидентов', count: 2 },
];

const mockDistributionData = [
  { name: 'Безопасные', value: 854, color: '#52c41a' },
  { name: 'Обычные нарушения', value: 312, color: '#faad14' },
  { name: 'Грубейшие', value: 58, color: '#ff4d4f' },
  { name: 'ТОП', value: 23, color: '#cf1322' },
];

const mockRecentInspections = [
  {
    key: '1',
    date: '2026-07-25',
    pe_name: 'ООО «ЕВРОХИМ-БМУ»',
    department_name: 'Цех добычи',
    inspector_name: 'Иванов И.И.',
    observations: 12,
    violations: 4,
    topViolations: 1,
    status: 'submitted',
  },
  {
    key: '2',
    date: '2026-07-24',
    pe_name: 'ООО «ПГ Фосфорит»',
    department_name: 'Цех обогащения',
    inspector_name: 'Петров П.П.',
    observations: 8,
    violations: 2,
    topViolations: 0,
    status: 'submitted',
  },
  {
    key: '3',
    date: '2026-07-24',
    pe_name: 'АО «НАК Азот»',
    department_name: 'Цех аммиака',
    inspector_name: 'Сидоров С.С.',
    observations: 15,
    violations: 6,
    topViolations: 2,
    status: 'draft',
  },
];

const mockTopViolations = [
  {
    key: '1',
    date: '2026-07-25',
    pe_name: 'ООО «ЕВРОХИМ-БМУ»',
    department_name: 'Цех добычи',
    description: 'Нарушение требований наряда-допуска при проведении огневых работ',
    zpb_rule: 'Наряд-допуск',
    workStopped: true,
  },
  {
    key: '2',
    date: '2026-07-24',
    pe_name: 'АО «НАК Азот»',
    department_name: 'Цех аммиака',
    description: 'Работа без СИЗ на высоте более 1.8 м',
    zpb_rule: 'СИЗ',
    workStopped: true,
  },
];

const Dashboard: React.FC = () => {
  const [period, setPeriod] = useState<string>('month');
  
  // Реальные данные из API
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  
  // Состояние фильтров
  const [selectedPE, setSelectedPE] = useState<string | undefined>(undefined);
  const [selectedDepartment, setSelectedDepartment] = useState<string | undefined>(undefined);

  // Загрузка списка ПЕ при монтировании компонента
  useEffect(() => {
    const loadPEs = async () => {
      try {
        const response = await apiClient.get('/references/pe');
        setPes(response.data);
      } catch (error) {
        message.error('Ошибка загрузки списка ПЕ');
      }
    };
    loadPEs();
  }, []);

  // Каскадная загрузка подразделений при выборе ПЕ
  const handlePEChange = async (peId: string | undefined) => {
    setSelectedPE(peId);
    setSelectedDepartment(undefined); // Сбрасываем подразделение
    setDepartments([]); // Очищаем список подразделений

    if (peId) {
      try {
        const response = await apiClient.get(`/references/departments?pe_id=${peId}`);
        setDepartments(response.data);
      } catch (error) {
        message.error('Ошибка загрузки подразделений');
      }
    }
  };

  const handleDepartmentChange = (deptId: string | undefined) => {
    setSelectedDepartment(deptId);
  };

  const handleExport = (format: string) => {
    message.info(`Экспорт в формате ${format.toUpperCase()} находится в разработке`);
  };

  const columns = [
    { title: 'Дата', dataIndex: 'date', key: 'date' },
    { title: 'ПЕ', dataIndex: 'pe_name', key: 'pe_name' },
    { title: 'Подразделение', dataIndex: 'department_name', key: 'department_name' },
    { title: 'Инспектор', dataIndex: 'inspector_name', key: 'inspector_name' },
    { title: 'Наблюдения', dataIndex: 'observations', key: 'observations' },
    { title: 'Нарушения', dataIndex: 'violations', key: 'violations' },
    { 
      title: 'ТОП', 
      dataIndex: 'topViolations', 
      key: 'topViolations',
      render: (val: number) => val > 0 ? <Tag color="red">{val}</Tag> : <Tag color="green">0</Tag>
    },
    {
      title: 'Статус',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        const color = status === 'submitted' ? 'green' : 'orange';
        const text = status === 'submitted' ? 'Завершена' : 'Черновик';
        return <Tag color={color}>{text}</Tag>;
      },
    },
  ];

  const topViolationsColumns = [
    { title: 'Дата', dataIndex: 'date', key: 'date' },
    { title: 'ПЕ', dataIndex: 'pe_name', key: 'pe_name' },
    { title: 'Подразделение', dataIndex: 'department_name', key: 'department_name' },
    { title: 'Описание', dataIndex: 'description', key: 'description' },
    { title: 'ЗПБ', dataIndex: 'zpb_rule', key: 'zpb_rule' },
    { 
      title: 'Остановка', 
      dataIndex: 'workStopped', 
      key: 'workStopped',
      render: (val: boolean) => val ? <Tag color="red">Да</Tag> : <Tag color="green">Нет</Tag>
    },
  ];

  return (
    <div>
      {/* Фильтры и экспорт */}
      <Card style={{ marginBottom: 16 }}>
        <Row gutter={16} align="middle">
          <Col>
            <Select
              value={period}
              onChange={setPeriod}
              style={{ width: 200 }}
              options={[
                { value: 'today', label: 'Сегодня' },
                { value: 'week', label: 'Неделя' },
                { value: 'month', label: 'Месяц' },
                { value: 'quarter', label: 'Квартал' },
                { value: 'year', label: 'Год' },
              ]}
            />
          </Col>
          <Col>
            <Select
              placeholder="Выберите ПЕ"
              value={selectedPE}
              onChange={handlePEChange}
              style={{ width: 250 }}
              allowClear
              loading={pes.length === 0}
              options={pes.map((pe) => ({ value: pe.id, label: pe.name }))}
            />
          </Col>
          <Col>
            <Select
              placeholder="Выберите подразделение"
              value={selectedDepartment}
              onChange={handleDepartmentChange}
              style={{ width: 250 }}
              allowClear
              disabled={!selectedPE}
              options={departments.map((dept) => ({ value: dept.id, label: dept.name }))}
            />
          </Col>
          <Col flex="auto" />
          <Col>
            <Space>
              <Button icon={<FilePdfOutlined />} onClick={() => handleExport('pdf')}>PDF</Button>
              <Button icon={<FileExcelOutlined />} onClick={() => handleExport('excel')}>Excel</Button>
              <Button icon={<FilePptOutlined />} onClick={() => handleExport('pptx')}>PPTX</Button>
            </Space>
          </Col>
        </Row>
      </Card>

      {/* KPI карточки */}
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={4}>
          <Card>
            <Statistic
              title="Всего проверок"
              value={mockKPI.totalInspections.current}
              suffix={
                <span style={{ fontSize: 14, color: mockKPI.totalInspections.change > 0 ? '#52c41a' : '#ff4d4f' }}>
                  {mockKPI.totalInspections.change > 0 ? '↑' : '↓'} {Math.abs(mockKPI.totalInspections.change)}%
                </span>
              }
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card>
            <Statistic title="Всего наблюдений" value={mockKPI.totalObservations.current} />
          </Card>
        </Col>
        <Col span={4}>
          <Card>
            <Statistic
              title="Безопасные"
              value={mockKPI.safePercentage.current}
              suffix="%"
              valueStyle={{ color: '#52c41a' }}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card>
            <Statistic
              title="Нарушения"
              value={mockKPI.violationPercentage.current}
              suffix="%"
              valueStyle={{ color: '#ff4d4f' }}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card>
            <Statistic
              title="ТОП-нарушения"
              value={mockKPI.topViolations.current}
              valueStyle={{ color: '#cf1322' }}
              prefix={<WarningOutlined />}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card>
            <Statistic
              title="Остановки работ"
              value={mockKPI.workStops.current}
              valueStyle={{ color: '#cf1322' }}
              prefix={<StopOutlined />}
            />
          </Card>
        </Col>
      </Row>

      {/* Графики - первая строка */}
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={12}>
          <Card title="Динамика проверок и нарушений">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={mockTrendData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="inspections" stroke="#1890ff" name="Проверки" />
                <Line type="monotone" dataKey="violations" stroke="#ff4d4f" name="Нарушения (текущий)" />
                <Line type="monotone" dataKey="previousViolations" stroke="#ff4d4f" strokeDasharray="5 5" name="Нарушения (прошлый)" />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={12}>
          <Card title="ТОП-5 ПЕ по нарушениям">
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={mockTopPE} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis type="number" />
                <YAxis type="category" dataKey="name" width={150} />
                <Tooltip />
                <Legend />
                <Bar dataKey="violations" fill="#ff4d4f" name="Нарушения" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>

      {/* Графики - вторая строка */}
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={8}>
          <Card title="Нарушения по видам работ">
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={mockWorkTypeViolations}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#faad14" name="Нарушения" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Нарушения Золотых Правил Безопасности">
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={mockZPBViolations} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis type="number" />
                <YAxis type="category" dataKey="name" width={150} />
                <Tooltip />
                <Bar dataKey="count" fill="#722ed1" name="Нарушения" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Распределение наблюдений">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={mockDistributionData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                  outerRadius={100}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {mockDistributionData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>

      {/* Таблицы */}
      <Row gutter={16}>
        <Col span={12}>
          <Card title="Последние проверки">
            <Table columns={columns} dataSource={mockRecentInspections} pagination={false} size="small" />
          </Card>
        </Col>
        <Col span={12}>
          <Card title="ТОП-нарушения за период">
            <Table columns={topViolationsColumns} dataSource={mockTopViolations} pagination={false} size="small" />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;