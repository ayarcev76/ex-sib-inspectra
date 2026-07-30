import React, { useEffect, useState } from 'react';
import {
  Layout, Menu, Button, Avatar, Dropdown, Space, theme,
  Breadcrumb, Badge, ConfigProvider
} from 'antd';
import {
  DashboardOutlined,
  FileTextOutlined,
  SettingOutlined,
  UserOutlined,
  TeamOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  BellOutlined,
  BookOutlined,
  SafetyCertificateOutlined,
} from '@ant-design/icons';
import { Outlet, useNavigate, useLocation, Link } from 'react-router-dom';
import { canManageReferences, canManageUsers, canManageAssignments } from '../utils/permissions';

const { Header, Sider, Content } = Layout;

interface UserInfo {
  email: string;
  full_name: string;
  roles: string[];
}

// Маппинг технических ключей ролей на русские названия (ТЗ п. 3.1)
const ROLE_LABELS: Record<string, string> = {
  admin: 'Администратор',
  coordinator: 'Координатор',
  manager: 'Руководитель',
  inspector: 'Инспектор',
  observer: 'Наблюдатель',
  contractor: 'Подрядчик',
};

// Хелпер: преобразует массив ролей в читаемые русские названия
const formatRoles = (roles: string[] | undefined): string => {
  if (!roles || roles.length === 0) return '—';
  return roles.map(r => ROLE_LABELS[r] || r).join(', ');
};

const AppLayout: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null);
  const [collapsed, setCollapsed] = useState(false);
  const { token: themeToken } = theme.useToken();

  // Получаем данные пользователя из JWT-токена
  useEffect(() => {
    try {
      const accessToken = localStorage.getItem('access_token');
      if (accessToken) {
        const payload = JSON.parse(atob(accessToken.split('.')[1]));
        setUserInfo({
          email: payload.email || '',
          full_name: payload.full_name || payload.sub || 'Пользователь',
          roles: payload.roles || [],
        });
      }
    } catch (error) {
      console.error('Ошибка чтения данных пользователя:', error);
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    navigate('/login');
  };

  // Генерация breadcrumbs на основе текущего пути
  const getBreadcrumbs = () => {
    const pathSegments = location.pathname.split('/').filter(Boolean);
    const breadcrumbs: { title: React.ReactNode }[] = [
      { title: <Link to="/">Главная</Link> }
    ];

    // Маппинг сегментов URL на русские названия
    const nameMap: Record<string, string> = {
      inspections: 'Карты наблюдений',
      references: 'Справочники',
      users: 'Пользователи',
      assignments: 'Назначения',
      dashboard: 'Дашборд',
      new: 'Создание',
      edit: 'Редактирование',
      profile: 'Профиль',
      detail: 'Детали',
    };

    // UUID-регулярка — пропускаем такие сегменты, чтобы не показывать #d65f6c1a
    const isUUID = (s: string) =>
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);

    pathSegments.forEach((segment, index) => {
      // Пропускаем UUID — номер проверки покажет сама страница
      if (isUUID(segment)) {
        return;
      }

      const isLast = index === pathSegments.length - 1;
      const name = nameMap[segment] || segment;
      const path = '/' + pathSegments.slice(0, index + 1).join('/');

      breadcrumbs.push({
        title: isLast ? name : <Link to={path}>{name}</Link>,
      });
    });

    return breadcrumbs;
  };

  // Формируем меню с учётом прав (ТЗ п. 3.1, 3.3)
  const getMenuItems = () => {
    const items: any[] = [
      { key: '/', icon: <DashboardOutlined />, label: 'Дашборд' },
      { key: '/inspections', icon: <FileTextOutlined />, label: 'Карты наблюдений' },
    ];

    const adminItems: any[] = [];

    if (canManageReferences()) {
      adminItems.push({ 
        key: '/references', 
        icon: <BookOutlined />, 
        label: 'Справочники' 
      });
    }

    if (canManageUsers()) {
      adminItems.push({ 
        key: '/users', 
        icon: <UserOutlined />, 
        label: 'Пользователи' 
      });
    }

    if (canManageAssignments()) {
      adminItems.push({ 
        key: '/assignments', 
        icon: <TeamOutlined />, 
        label: 'Назначения на ПЕ' 
      });
    }

    if (adminItems.length > 0) {
      items.push({ type: 'divider' });
      items.push({
        key: 'admin-group',
        icon: <SettingOutlined />,
        label: 'Администрирование',
        children: adminItems,
      });
    }

    return items;
  };

  // Меню пользователя (выпадающее) — с русскими названиями ролей
  const userMenuItems = [
    {
      key: 'profile',
      label: (
        <div>
          <div style={{ fontWeight: 'bold' }}>{userInfo?.full_name}</div>
          <div style={{ fontSize: 12, color: '#999' }}>{userInfo?.email}</div>
          <div style={{ fontSize: 11, color: '#666', marginTop: 4 }}>
            Роли: {formatRoles(userInfo?.roles)}
          </div>
        </div>
      ),
      disabled: true,
    },
    { type: 'divider' },
    {
      key: 'my-profile',
      icon: <UserOutlined />,
      label: 'Мой профиль',
      onClick: () => navigate('/profile'),
    },
    { type: 'divider' },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Выйти',
      danger: true,
      onClick: handleLogout,
    },
  ];

  // Определяем выбранный пункт меню (для подсветки)
  const getSelectedKey = () => {
    const path = location.pathname;
    if (path === '/') return '/';
    if (path.startsWith('/inspections')) return '/inspections';
    if (path.startsWith('/references')) return '/references';
    if (path.startsWith('/users')) return '/users';
    if (path.startsWith('/assignments')) return '/assignments';
    if (path.startsWith('/dashboard')) return '/';
    return path;
  };

  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: '#00A651',
          colorLink: '#00A651',
          borderRadius: 6,
          fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        },
        components: {
          Menu: {
            itemSelectedBg: '#E6F7EE',
            itemSelectedColor: '#00A651',
          },
          Layout: {
            headerBg: '#FFFFFF',
            siderBg: '#001529',
          },
        },
      }}
    >
      <Layout style={{ minHeight: '100vh' }}>
        {/* Боковое меню */}
        <Sider
          collapsible
          collapsed={collapsed}
          onCollapse={setCollapsed}
          width={240}
          theme="dark"
          style={{
            overflow: 'auto',
            height: '100vh',
            position: 'fixed',
            left: 0,
            top: 0,
            bottom: 0,
          }}
        >
          {/* Логотип — в ОДНУ строку */}
          <div
            style={{
              height: 64,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderBottom: '1px solid rgba(255,255,255,0.1)',
              padding: collapsed ? '0 8px' : '0 16px', 
              overflow: 'hidden',
            }}
          >
            <SafetyCertificateOutlined style={{ fontSize: 26, color: '#00A651', flexShrink: 0 }} />
            {!collapsed && (
              <div
                style={{
                  marginLeft: 10,
                  color: '#fff',
                  fontSize: 15,
                  fontWeight: 600,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
                title="ЕХ:Инспектра-ИПБ"
              >
                ЕХ:Инспектра-ИПБ
              </div>
            )}
          </div>

          <Menu
            theme="dark"
            mode="inline"
            selectedKeys={[getSelectedKey()]}
            items={getMenuItems()}
            onClick={(e) => {
              if (e.key.startsWith('/')) {
                navigate(e.key);
              }
            }}
            style={{ borderRight: 0 }}
          />
        </Sider>

        {/* Основная область */}
        <Layout 
          style={{ 
            marginLeft: collapsed ? 80 : 240, 
            transition: 'margin-left 0.2s' 
          }}
        >
          {/* Верхняя панель */}
          <Header
            style={{
              background: '#fff',
              padding: '0 24px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
              height: 64,
              position: 'sticky',
              top: 0,
              zIndex: 100,
            }}
          >
            {/* Левая часть: кнопка сворачивания + breadcrumbs */}
            <Space size="middle">
              <Button
                type="text"
                icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                onClick={() => setCollapsed(!collapsed)}
                style={{ fontSize: 18 }}
              />
              <Breadcrumb items={getBreadcrumbs()} />
            </Space>

            {/* Правая часть: уведомления + профиль */}
            <Space size="large">
              {/* Колокольчик уведомлений (заглушка) */}
              <Badge count={3} size="small">
                <Button 
                  type="text" 
                  icon={<BellOutlined style={{ fontSize: 18 }} />} 
                  title="Уведомления"
                />
              </Badge>

              {/* Профиль пользователя — с русскими ролями */}
              <Dropdown menu={{ items: userMenuItems }} trigger={['click']} placement="bottomRight">
                <Space style={{ cursor: 'pointer', padding: '0 8px' }}>
                  <Avatar
                    style={{ backgroundColor: themeToken.colorPrimary }}
                    icon={<UserOutlined />}
                  />
                  <div style={{ lineHeight: 1.2 }}>
                    <div style={{ fontWeight: 500, fontSize: 14 }}>
                      {userInfo?.full_name || 'Загрузка...'}
                    </div>
                    <div style={{ fontSize: 12, color: '#999' }}>
                      {formatRoles(userInfo?.roles)}
                    </div>
                  </div>
                </Space>
              </Dropdown>
            </Space>
          </Header>

          {/* Контент */}
          <Content style={{ margin: 24, minHeight: 280 }}>
            <Outlet />
          </Content>
        </Layout>
      </Layout>
    </ConfigProvider>
  );
};

export default AppLayout;