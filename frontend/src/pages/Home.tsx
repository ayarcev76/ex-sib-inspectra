import React, { useEffect, useState } from 'react';
import { Card, List, Tag, Spin, Alert } from 'antd';
import apiClient from '../api/client';

interface PE {
  id: string;
  name: string;
  code: string;
  is_active: boolean;
}

const Home: React.FC = () => {
  const [pes, setPes] = useState<PE[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchPE = async () => {
      try {
        const response = await apiClient.get('/references/pe');
        setPes(response.data);
      } catch (err) {
        setError('Ошибка загрузки данных');
      } finally {
        setLoading(false);
      }
    };

    fetchPE();
  }, []);

  if (loading) return <Spin size="large" />;
  if (error) return <Alert message={error} type="error" showIcon />;

  return (
    <div>
      <h2>Производственные единицы</h2>
      <List
        grid={{ gutter: 16, column: 3 }}
        dataSource={pes}
        renderItem={(pe) => (
          <List.Item>
            <Card 
              title={pe.name} 
              size="small"
              extra={<Tag color={pe.is_active ? 'green' : 'red'}>
                {pe.is_active ? 'Активно' : 'Неактивно'}
              </Tag>}
            >
              <p>Код: {pe.code}</p>
              <p>ID: {pe.id}</p>
            </Card>
          </List.Item>
        )}
      />
    </div>
  );
};

export default Home;