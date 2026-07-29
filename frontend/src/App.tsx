import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ConfigProvider, theme } from 'antd';
import ruRU from 'antd/locale/ru_RU';
import Login from './pages/Login';
import AppLayout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Inspections from './pages/Inspections';
import InspectionForm from './pages/InspectionForm';
import InspectionDetail from './pages/InspectionDetail';
import InspectionEdit from './pages/InspectionEdit';
import References from './pages/References';
import Users from './pages/Users';
import Assignments from './pages/Assignments';
import { isAuthenticated } from './utils/auth';

const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return isAuthenticated() ? <>{children}</> : <Navigate to="/login" />;
};

const App: React.FC = () => {
  return (
    <ConfigProvider
      locale={ruRU}
      theme={{
        token: {
          colorPrimary: '#1677ff',
          borderRadius: 6,
        },
        algorithm: theme.defaultAlgorithm,
      }}
    >
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="inspections" element={<Inspections />} />
            <Route path="inspections/new" element={<InspectionForm />} />
            <Route path="inspections/:id" element={<InspectionDetail />} />
            <Route path="inspections/:id/edit" element={<InspectionEdit />} />
            <Route path="references" element={<References />} />
            <Route path="users" element={<Users />} />
            <Route path="assignments" element={<Assignments />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </ConfigProvider>
  );
};

export default App;