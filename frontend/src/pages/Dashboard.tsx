import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Statistic, Select, Table, Tag, Button, Space, message, Spin } from 'antd';
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

// --- Типы для данных дашборда ---
interface KPI {
  totalInspections: number;
  totalObservations: number;
  safePercentage: number;
  violationPercentage: number;
  topViolations: number;
  workStops: number;
}

interface TrendItem {
  date: string;
  inspections: number;
  violations: number;
}

interface PEViolationItem {
  name: string;
  violations: number;
  inspections: number;
}

interface WorkTypeViolationItem {
  name: string;
  count: number;
}

interface ZPBViolationItem {
  name: string;
  count: number;
}

interface DistributionItem {
  name: string;
  value: number;
  color: string;
}

interface RecentInspectionItem {
  key: string;
  date: string;
  pe_name: string;
  department_name: string;
  inspector_name: string;
  observations: number;
  violations: number;
  topViolations: number;
  status: string;
}

interface TopViolationItem {
  key: string;
  date: string;
  pe_name: string;
  department_name: string;
  description: string;
  zpb_rule: string;
  workStopped: boolean;
}

interface DashboardData {
  kpi: KPI;
  trendData: TrendItem[];
  topPE: PEViolationItem[];
  workTypeViolations: WorkTypeViolationItem[];
  zpbViolations: ZPBViolationItem[];
  distribution: DistributionItem[];
  recentInspections: RecentInspectionItem[];
  topViolationsList: TopViolationItem[];
}

const Dashboard: React.FC = () => {
  const [period, setPeriod] = useState<string>('month');
  const [loading, setLoading] = useState<boolean>(false);
  
  // Реальные данные из API
  const [pes, setPes] = useState<PE[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null);
  
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

  // Загрузка данных дашборда
  useEffect(() => {
    const loadDashboardData = async () => {
      setLoading(true);
      try {
        const params: Record<string, string> = { period };
        if (selectedPE) params.pe_id = selectedPE;
        if (selectedDepartment) params.department_id = selectedDepartment;
        
        const response = await apiClient.get('/analytics/dashboard', { params });
        setDashboardData(response.data);
      } catch (error) {
        message.error('Ошибка загрузки данных дашборда');
        console.error('Dashboard error:', error);
      } finally {
        setLoading(false);
      }
    };
    
    loadDashboardData();
  }, [period, selectedPE, selectedDepartment]);

  // Каскадная загрузка подразделений при выборе ПЕ
  const handlePEChange = async (peId: string | undefined) => {
    setSelectedPE(peId);
    setSelectedDepartment(undefined);
    setDepartments([]);

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

  const emptyDistribution = [
    { name: 'Безопасные', value: 0, color: '#52c41a' },
    { name: 'Обычные нарушения', value: 0, color: '#faad14' },
    { name: 'Грубейшие', value: 0, color: '#ff4d4f' },
    { name: 'ТОП', value: 0, color: '#cf1322' },
  ];

  return (
    <Spin spinning={loading}>
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
                value={dashboardData?.kpi.totalInspections || 0}
                suffix={
                  <span style={{ fontSize: 14, color: '#1890ff' }}>
                    —
                  </span>
                }
              />
            </Card>
          </Col>
          <Col span={4}>
            <Card>
              <Statistic title="Всего наблюдений" value={dashboardData?.kpi.totalObservations || 0} />
            </Card>
          </Col>
          <Col span={4}>
            <Card>
              <Statistic
                title="Безопасные"
                value={dashboardData?.kpi.safePercentage || 0}
                suffix="%"
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
          <Col span={4}>
            <Card>
              <Statistic
                title="Нарушения"
                value={dashboardData?.kpi.violationPercentage || 0}
                suffix="%"
                valueStyle={{ color: '#ff4d4f' }}
              />
            </Card>
          </Col>
          <Col span={4}>
            <Card>
              <Statistic
                title="ТОП-нарушения"
                value={dashboardData?.kpi.topViolations || 0}
                valueStyle={{ color: '#cf1322' }}
                prefix={<WarningOutlined />}
              />
            </Card>
          </Col>
          <Col span={4}>
            <Card>
              <Statistic
                title="Остановки работ"
                value={dashboardData?.kpi.workStops || 0}
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
                <LineChart data={dashboardData?.trendData || []}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="inspections" stroke="#1890ff" name="Проверки" />
                  <Line type="monotone" dataKey="violations" stroke="#ff4d4f" name="Нарушения" />
                </LineChart>
              </ResponsiveContainer>
            </Card>
          </Col>
          <Col span={12}>
            <Card title="ТОП-5 ПЕ по нарушениям">
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={dashboardData?.topPE || []} layout="vertical">
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
                <BarChart data={dashboardData?.workTypeViolations || []}>
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
                <BarChart data={dashboardData?.zpbViolations || []} layout="vertical">
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
                    data={dashboardData?.distribution || emptyDistribution}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                    outerRadius={100}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {(dashboardData?.distribution || emptyDistribution).map((entry, index) => (
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
              <Table columns={columns} dataSource={dashboardData?.recentInspections || []} pagination={false} size="small" />
            </Card>
          </Col>
          <Col span={12}>
            <Card title="ТОП-нарушения за период">
              <Table columns={topViolationsColumns} dataSource={dashboardData?.topViolationsList || []} pagination={false} size="small" />
            </Card>
          </Col>
        </Row>
      </div>
    </Spin>
  );
};

export default Dashboard;
