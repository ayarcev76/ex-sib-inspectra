# rollback_export.ps1
# Скрипт отката системы к состоянию до попыток наладить экспорт PDF/DOCX
# Запуск: powershell -ExecutionPolicy Bypass -File .\rollback_export.ps1

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backup_before_rollback_$timestamp"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Откат системы к состоянию до экспорта" -ForegroundColor Cyan
Write-Host "Бэкап будет сохранён в: $backupDir" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Создаём папку для бэкапа
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# ==================== 1. Бэкап текущих файлов ====================
Write-Host "[1/6] Создание бэкапа текущих файлов..." -ForegroundColor Cyan

$filesToBackup = @(
    "backend/app/api/v1/router.py",
    "backend/app/main.py",
    "backend/app/core/minio_client.py",
    "frontend/src/pages/InspectionDetail.tsx",
    "backend/requirements.txt"
)

foreach ($file in $filesToBackup) {
    if (Test-Path $file) {
        $destDir = Join-Path $backupDir (Split-Path $file -Parent)
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item $file $destDir -Force
        Write-Host "  ✓ Бэкап: $file" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Пропущен (не найден): $file" -ForegroundColor Yellow
    }
}

# Бэкап файлов экспорта (если есть)
$exportFiles = @(
    "backend/app/services/export_service.py",
    "backend/app/api/v1/export.py"
)

foreach ($file in $exportFiles) {
    if (Test-Path $file) {
        $destDir = Join-Path $backupDir (Split-Path $file -Parent)
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item $file $destDir -Force
        Write-Host "  ✓ Бэкап: $file" -ForegroundColor Green
    }
}

Write-Host ""

# ==================== 2. Удаление файлов экспорта ====================
Write-Host "[2/6] Удаление файлов экспорта..." -ForegroundColor Cyan

if (Test-Path "backend/app/services/export_service.py") {
    Remove-Item "backend/app/services/export_service.py" -Force
    Write-Host "  ✓ Удалён: backend/app/services/export_service.py" -ForegroundColor Green
}

if (Test-Path "backend/app/api/v1/export.py") {
    Remove-Item "backend/app/api/v1/export.py" -Force
    Write-Host "  ✓ Удалён: backend/app/api/v1/export.py" -ForegroundColor Green
}

# Удаляем папку static/fonts если пуста
if (Test-Path "backend/app/static/fonts") {
    $fontFiles = Get-ChildItem "backend/app/static/fonts" -File
    if ($fontFiles.Count -eq 0) {
        Remove-Item "backend/app/static/fonts" -Force
        Write-Host "  ✓ Удалена пустая папка: backend/app/static/fonts" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Папка backend/app/static/fonts не пуста, оставлена" -ForegroundColor Yellow
    }
}

Write-Host ""

# ==================== 3. Восстановление router.py ====================
Write-Host "[3/6] Восстановление backend/app/api/v1/router.py..." -ForegroundColor Cyan

$routerContent = @'
"""Корневой роутер API v1."""
from fastapi import APIRouter
from app.api.v1 import auth, inspections, photos, references, users

router = APIRouter()

# Подключаем роутеры
router.include_router(auth.router)
router.include_router(references.router)
router.include_router(users.router)
router.include_router(inspections.router)
router.include_router(photos.router)


@router.get("/health", tags=["system"])
def health_check():
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.4.0",
    }
'@

$routerContent | Out-File -FilePath "backend/app/api/v1/router.py" -Encoding utf8 -NoNewline
Write-Host "  ✓ router.py восстановлен (без import export)" -ForegroundColor Green
Write-Host ""

# ==================== 4. Восстановление main.py ====================
Write-Host "[4/6] Восстановление backend/app/main.py..." -ForegroundColor Cyan

$mainContent = @'
"""Точка входа FastAPI приложения."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()

# Настраиваем логирование
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения."""
    logger.info("🚀 Запуск приложения ЕХ:Инспектра-ИПБ...")
    yield
    logger.info("🛑 Остановка приложения...")


# Создание экземпляра FastAPI
app = FastAPI(
    title="ЕХ:Инспектра-ИПБ API",
    description="Система инспекций производственной безопасности ГК «ЕВРОХИМ»",
    version="0.4.0",
    lifespan=lifespan,
)

# Настройка CORS (для доступа с фронтенда)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Подключение API-роутеров
from app.api.v1.router import router as v1_router

app.include_router(v1_router, prefix="/api/v1")


# Health-check эндпоинт
@app.get("/health", tags=["system"])
def health_check():
    """Проверка работоспособности сервиса."""
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.4.0",
    }


# Корневой эндпоинт
@app.get("/", tags=["system"])
def root():
    """Корневой эндпоинт API."""
    return {
        "message": "ЕХ:Инспектра-ИПБ API",
        "docs": "/docs",
        "health": "/health",
    }
'@

$mainContent | Out-File -FilePath "backend/app/main.py" -Encoding utf8 -NoNewline
Write-Host "  ✓ main.py восстановлен (без блока TEMP)" -ForegroundColor Green
Write-Host ""

# ==================== 5. Восстановление InspectionDetail.tsx ====================
Write-Host "[5/6] Восстановление frontend/src/pages/InspectionDetail.tsx..." -ForegroundColor Cyan

$tsxContent = @'
import React, { useEffect, useState } from 'react';
import {
  Card, Row, Col, Descriptions, Tag, Spin, Alert, Button, Space,
  Divider, message, Popconfirm, Image, Empty, Statistic
} from 'antd';
import {
  ArrowLeftOutlined,
  EditOutlined,
  DeleteOutlined,
  CheckCircleOutlined,
  WarningOutlined,
  StopOutlined,
  EnvironmentOutlined,
  UserOutlined,
  CalendarOutlined,
  PictureOutlined,
  FireOutlined,
  SafetyCertificateOutlined,
} from '@ant-design/icons';
import { useParams, useNavigate } from 'react-router-dom';
import apiClient from '../api/client';

interface ViolationPhoto {
  id: string;
  file_path: string;
  thumbnail_path?: string;
  original_filename: string;
  file_size: number;
  mime_type: string;
  caption?: string;
  gps_latitude?: number;
  gps_longitude?: number;
  uploaded_at: string;
}

interface ViolationRecord {
  id: string;
  work_type_id: string;
  work_type_name?: string;
  is_safe: boolean;
  violation_description?: string;
  is_gross_violation: boolean;
  is_work_stopped: boolean;
  zpb_rule_id?: string;
  zpb_rule_name?: string;
  is_top_violation: boolean;
  order: number;
  photos: ViolationPhoto[];
}

interface InspectionDetail {
  id: string;
  inspection_number: string;
  date: string;
  pe_id: string;
  pe_name?: string;
  department_id: string;
  department_name?: string;
  inspector_id: string;
  inspector_name?: string;
  contractor_id?: string;
  contractor_name?: string;
  work_location: string;
  source: 'mobile' | 'web';
  status: 'draft' | 'submitted' | 'approved';
  created_at: string;
  violations: ViolationRecord[];
}

const InspectionDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [inspection, setInspection] = useState<InspectionDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [photoUrls, setPhotoUrls] = useState<Record<string, { original: string; thumbnail: string }>>({});

  useEffect(() => {
    const loadInspection = async () => {
      if (!id) return;
      try {
        setLoading(true);
        const response = await apiClient.get(`/inspections/${id}`);
        setInspection(response.data);
      } catch (err) {
        console.error('Ошибка загрузки карты наблюдения:', err);
        setError('Не удалось загрузить данные карты наблюдения');
        message.error('Ошибка загрузки карты наблюдения');
      } finally {
        setLoading(false);
      }
    };
    loadInspection();
  }, [id]);

  // Загрузка presigned URLs для всех фотографий
  useEffect(() => {
    const loadPhotoUrls = async () => {
      if (!inspection) return;
      const urls: Record<string, { original: string; thumbnail: string }> = {};

      for (const violation of inspection.violations) {
        for (const photo of violation.photos) {
          try {
            const [originalRes, thumbnailRes] = await Promise.all([
              apiClient.get(`/violations/${violation.id}/photos/${photo.id}/original`),
              photo.thumbnail_path
                ? apiClient.get(`/violations/${violation.id}/photos/${photo.id}/thumbnail`)
                : Promise.resolve(null),
            ]);
            urls[photo.id] = {
              original: originalRes.data.url,
              thumbnail: thumbnailRes?.data.url || originalRes.data.url,
            };
          } catch (err) {
            console.error(`Ошибка загрузки URL для фото ${photo.id}:`, err);
          }
        }
      }
      setPhotoUrls(urls);
    };
    loadPhotoUrls();
  }, [inspection]);

  const handleDelete = async () => {
    if (!id) return;
    try {
      await apiClient.delete(`/inspections/${id}`);
      message.success('Карта наблюдения удалена');
      navigate('/inspections');
    } catch (err) {
      console.error('Ошибка удаления:', err);
      message.error('Ошибка удаления карты наблюдения');
    }
  };

  const handleSubmit = async () => {
    if (!id || !inspection) return;
    try {
      await apiClient.put(`/inspections/${id}`, { status: 'submitted' });
      message.success('Карта наблюдения отправлена');
      const response = await apiClient.get(`/inspections/${id}`);
      setInspection(response.data);
    } catch (err) {
      console.error('Ошибка отправки:', err);
      message.error('Ошибка отправки карты наблюдения');
    }
  };

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return `${bytes} Б`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} КБ`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} МБ`;
  };

  // ==================== АНАЛИТИКА НАРУШЕНИЙ ====================
  const violationsList = inspection?.violations.filter(v => !v.is_safe) || [];
  const hasViolations = violationsList.length > 0;
  const topViolationsCount = violationsList.filter(v => v.is_top_violation).length;
  const hasWorkStopped = violationsList.some(v => v.is_work_stopped);

  const zpbRulesViolated = Array.from(new Set(
    violationsList
      .filter(v => v.zpb_rule_name)
      .map(v => v.zpb_rule_name!)
  ));

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: 50 }}>
        <Spin size="large" />
        <p>Загрузка данных карты наблюдения...</p>
      </div>
    );
  }

  if (error || !inspection) {
    return <Alert message="Ошибка" description={error || 'Карта наблюдения не найдена'} type="error" showIcon />;
  }

  const statusColors: Record<string, string> = {
    draft: 'orange',
    submitted: 'green',
    approved: 'blue',
  };
  const statusTexts: Record<string, string> = {
    draft: 'Черновик',
    submitted: 'Завершена',
    approved: 'Утверждена',
  };

  return (
    <div>
      {/* Кнопка назад и действия */}
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/inspections')}>
          Назад к списку
        </Button>
        <Space>
          {inspection.status === 'draft' && (
            <>
              <Button
                icon={<EditOutlined />}
                onClick={() => navigate(`/inspections/${id}/edit`)}
              >
                Редактировать
              </Button>
              <Popconfirm
                title="Отправить карту наблюдения?"
                description="После отправки она будет доступна всем пользователям."
                onConfirm={handleSubmit}
                okText="Да, отправить"
                cancelText="Отмена"
              >
                <Button type="primary" icon={<CheckCircleOutlined />}>
                  Отправить
                </Button>
              </Popconfirm>
            </>
          )}
          <Popconfirm
            title="Удалить карту наблюдения?"
            description="Это действие нельзя отменить. Все нарушения и фотографии будут удалены."
            onConfirm={handleDelete}
            okText="Да, удалить"
            cancelText="Отмена"
            okButtonProps={{ danger: true }}
          >
            <Button danger icon={<DeleteOutlined />}>
              Удалить
            </Button>
          </Popconfirm>
        </Space>
      </div>

      {/* Шапка карты наблюдения */}
      <Card
        title={
          <Space>
            <span style={{ fontSize: 20, fontWeight: 'bold' }}>
              {inspection.inspection_number}
            </span>
            <Tag color={statusColors[inspection.status]}>
              {statusTexts[inspection.status]}
            </Tag>
          </Space>
        }
        style={{ marginBottom: 16 }}
      >
        <Descriptions column={2} bordered>
          <Descriptions.Item label={<><CalendarOutlined /> Дата</>}>
            {new Date(inspection.date).toLocaleDateString('ru-RU')}
          </Descriptions.Item>
          <Descriptions.Item label="Источник">
            <Tag color={inspection.source === 'mobile' ? 'blue' : 'green'}>
              {inspection.source === 'mobile' ? 'Мобильное приложение' : 'Веб-интерфейс'}
            </Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Производственная единица">
            {inspection.pe_name || '—'}
          </Descriptions.Item>
          <Descriptions.Item label="Подразделение">
            {inspection.department_name || '—'}
          </Descriptions.Item>
          <Descriptions.Item label={<><UserOutlined /> Инспектор</>}>
            {inspection.inspector_name || '—'}
          </Descriptions.Item>
          <Descriptions.Item label="Подрядчик">
            {inspection.contractor_name || '—'}
          </Descriptions.Item>
          <Descriptions.Item label={<><EnvironmentOutlined /> Место работ</>} span={2}>
            {inspection.work_location}
          </Descriptions.Item>
          <Descriptions.Item label="Создана">
            {new Date(inspection.created_at).toLocaleString('ru-RU')}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      {/* ==================== БЛОК СТАТИСТИКИ И БАННЕРОВ ==================== */}
      {!hasViolations ? (
        <Card
          style={{
            marginBottom: 16,
            background: 'linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%)',
            border: '2px solid #52c41a',
          }}
          bodyStyle={{ padding: 32, textAlign: 'center' }}
        >
          <CheckCircleOutlined style={{ fontSize: 64, color: '#52c41a', marginBottom: 16 }} />
          <div style={{ fontSize: 28, fontWeight: 'bold', color: '#389e0d', marginBottom: 8 }}>
            Всё безопасно
          </div>
          <div style={{ fontSize: 16, color: '#52c41a' }}>
            Нарушений не выявлено. Инспектор подтвердил безопасные условия труда.
          </div>
        </Card>
      ) : (
        <div style={{ marginBottom: 16 }}>
          <Row gutter={16} style={{ marginBottom: 16 }}>
            <Col span={12}>
              <Card
                size="small"
                style={{
                  borderLeft: '4px solid #ff4d4f',
                  background: '#fff2f0',
                }}
              >
                <Statistic
                  title={<span style={{ fontSize: 14, color: '#666' }}>Выявлено нарушений</span>}
                  value={violationsList.length}
                  valueStyle={{ color: '#cf1322', fontSize: 32 }}
                  prefix={<WarningOutlined style={{ color: '#ff4d4f' }} />}
                  suffix={violationsList.length === 1 ? 'нарушение' :
                         violationsList.length < 5 ? 'нарушения' : 'нарушений'}
                />
              </Card>
            </Col>
            <Col span={12}>
              <Card
                size="small"
                style={{
                  borderLeft: '4px solid #cf1322',
                  background: topViolationsCount > 0 ? '#fff1f0' : '#fafafa',
                }}
              >
                <Statistic
                  title={<span style={{ fontSize: 14, color: '#666' }}>ТОП-нарушений</span>}
                  value={topViolationsCount}
                  valueStyle={{
                    color: topViolationsCount > 0 ? '#cf1322' : '#999',
                    fontSize: 32,
                    fontWeight: 'bold',
                  }}
                  prefix={<FireOutlined style={{ color: topViolationsCount > 0 ? '#cf1322' : '#d9d9d9' }} />}
                />
              </Card>
            </Col>
          </Row>

          {hasWorkStopped && (
            <Alert
              type="error"
              showIcon
              icon={<StopOutlined style={{ fontSize: 20 }} />}
              style={{
                marginBottom: 12,
                border: '2px solid #ff4d4f',
                background: '#fff1f0',
              }}
              message={
                <span style={{ fontSize: 16, fontWeight: 'bold', color: '#cf1322' }}>
                  ⛔ РАБОТЫ ОСТАНОВЛЕНЫ
                </span>
              }
              description="Инспектор принял решение о полной остановке работ из-за критических нарушений."
            />
          )}

          {zpbRulesViolated.length > 0 && (
            <Alert
              type="warning"
              showIcon
              icon={<SafetyCertificateOutlined style={{ fontSize: 20 }} />}
              style={{
                marginBottom: 12,
                border: '2px solid #faad14',
                background: '#fffbe6',
              }}
              message={
                <span style={{ fontSize: 16, fontWeight: 'bold', color: '#ad6800' }}>
                  ⚠️ НАРУШЕНЫ ЗОЛОТЫЕ ПРАВИЛА БЕЗОПАСНОСТИ
                </span>
              }
              description={
                <div style={{ marginTop: 8 }}>
                  {zpbRulesViolated.map((rule, idx) => (
                    <div key={idx} style={{
                      padding: '6px 12px',
                      marginBottom: 4,
                      background: 'rgba(255, 255, 255, 0.7)',
                      borderLeft: '3px solid #faad14',
                      borderRadius: 4,
                      fontSize: 14,
                    }}>
                      {rule}
                    </div>
                  ))}
                </div>
              }
            />
          )}
        </div>
      )}

      {/* ==================== СПИСОК НАРУШЕНИЙ (только если есть) ==================== */}
      {hasViolations && (
        <Card title={`Нарушения (${violationsList.length})`}>
          {violationsList.map((violation, index) => (
            <Card
              key={violation.id}
              size="small"
              style={{
                marginBottom: 16,
                borderLeft: violation.is_top_violation ? '4px solid #cf1322' : '4px solid #faad14',
                background: violation.is_top_violation ? '#fff1f0' : '#fff',
              }}
              title={
                <Space wrap>
                  <span>Нарушение #{index + 1}</span>
                  {violation.is_top_violation && (
                    <Tag color="red" icon={<WarningOutlined />}>
                      ТОП-НАРУШЕНИЕ
                    </Tag>
                  )}
                  {violation.is_gross_violation && (
                    <Tag color="orange" icon={<WarningOutlined />}>
                      Грубейшее
                    </Tag>
                  )}
                  {violation.is_work_stopped && (
                    <Tag color="red" icon={<StopOutlined />}>
                      Остановка работ
                    </Tag>
                  )}
                </Space>
              }
            >
              <Descriptions column={1} size="small">
                <Descriptions.Item label="Описание нарушения">
                  <span style={{ fontSize: 14 }}>
                    {violation.violation_description || '—'}
                  </span>
                </Descriptions.Item>
                <Descriptions.Item label="Вид работ">
                  <Tag>{violation.work_type_name || '—'}</Tag>
                </Descriptions.Item>
                {violation.zpb_rule_name && (
                  <Descriptions.Item label="Нарушенное ЗПБ">
                    <Tag color="purple">{violation.zpb_rule_name}</Tag>
                  </Descriptions.Item>
                )}
              </Descriptions>

              {violation.photos.length > 0 ? (
                <>
                  <Divider style={{ margin: '12px 0' }} />
                  <div>
                    <Space style={{ marginBottom: 8 }}>
                      <PictureOutlined />
                      <strong>Фотографии ({violation.photos.length})</strong>
                    </Space>
                    <Image.PreviewGroup>
                      <Row gutter={[8, 8]}>
                        {violation.photos.map(photo => {
                          const urls = photoUrls[photo.id];
                          const thumbnailUrl = urls?.thumbnail || '';
                          const originalUrl = urls?.original || '';
                          return (
                            <Col key={photo.id} span={6}>
                              <Card
                                size="small"
                                hoverable
                                cover={
                                  thumbnailUrl ? (
                                    <Image
                                      src={thumbnailUrl}
                                      alt={photo.original_filename}
                                      style={{
                                        height: 150,
                                        objectFit: 'cover',
                                        width: '100%'
                                      }}
                                      preview={{ src: originalUrl }}
                                      fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFhAJ/wlseKgAAAABJRU5ErkJggg=="
                                    />
                                  ) : (
                                    <div style={{
                                      height: 150,
                                      background: '#f0f0f0',
                                      display: 'flex',
                                      alignItems: 'center',
                                      justifyContent: 'center',
                                      color: '#999'
                                    }}>
                                      <Spin />
                                    </div>
                                  )
                                }
                              >
                                <Card.Meta
                                  title={
                                    <div style={{
                                      fontSize: 12,
                                      overflow: 'hidden',
                                      textOverflow: 'ellipsis',
                                      whiteSpace: 'nowrap'
                                    }}>
                                      {photo.original_filename}
                                    </div>
                                  }
                                  description={
                                    <div style={{ fontSize: 11, color: '#999' }}>
                                      {formatFileSize(photo.file_size)}
                                      {photo.gps_latitude && photo.gps_longitude && (
                                        <div>📍 {photo.gps_latitude.toFixed(4)}, {photo.gps_longitude.toFixed(4)}</div>
                                      )}
                                    </div>
                                  }
                                />
                              </Card>
                            </Col>
                          );
                        })}
                      </Row>
                    </Image.PreviewGroup>
                  </div>
                </>
              ) : (
                <>
                  <Divider style={{ margin: '12px 0' }} />
                  <Empty
                    image={Empty.PRESENTED_IMAGE_SIMPLE}
                    description="Фотографии не прикреплены"
                  />
                </>
              )}
            </Card>
          ))}
        </Card>
      )}
    </div>
  );
};

export default InspectionDetail;
'@

$tsxContent | Out-File -FilePath "frontend/src/pages/InspectionDetail.tsx" -Encoding utf8 -NoNewline
Write-Host "  ✓ InspectionDetail.tsx восстановлен (без кнопок экспорта, но с баннерами и статистикой)" -ForegroundColor Green
Write-Host ""

# ==================== 6. Очистка временных файлов ====================
Write-Host "[6/6] Очистка временных файлов в C:\Temp..." -ForegroundColor Cyan

$tempFiles = Get-ChildItem "C:\Temp" -Filter "inspectra_*" -ErrorAction SilentlyContinue
$tempFontFiles = Get-ChildItem "C:\Temp" -Filter "tmp*.ttf" -ErrorAction SilentlyContinue

$cleaned = 0
foreach ($file in $tempFiles) {
    try {
        Remove-Item $file.FullName -Force
        $cleaned++
    } catch {
        Write-Host "  ⚠ Не удалось удалить: $($file.Name)" -ForegroundColor Yellow
    }
}

foreach ($file in $tempFontFiles) {
    try {
        Remove-Item $file.FullName -Force
        $cleaned++
    } catch {
        Write-Host "  ⚠ Не удалось удалить: $($file.Name)" -ForegroundColor Yellow
    }
}

Write-Host "  ✓ Удалено временных файлов: $cleaned" -ForegroundColor Green
Write-Host ""

# ==================== Итог ====================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Откат завершён успешно!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Что было сделано:" -ForegroundColor Cyan
Write-Host "  • Удалены файлы экспорта (export_service.py, export.py)" -ForegroundColor White
Write-Host "  • Восстановлен router.py (без import export)" -ForegroundColor White
Write-Host "  • Восстановлен main.py (без блока TEMP)" -ForegroundColor White
Write-Host "  • Восстановлен InspectionDetail.tsx (без кнопок экспорта)" -ForegroundColor White
Write-Host "  • Очищены временные файлы в C:\Temp" -ForegroundColor White
Write-Host ""
Write-Host "Что было сохранено:" -ForegroundColor Cyan
Write-Host "  • Все улучшения UI (Layout, баннеры, статистика, русские роли)" -ForegroundColor White
Write-Host "  • Серверная фильтрация и пагинация" -ForegroundColor White
Write-Host "  • Функция get_file_bytes в minio_client.py (может пригодиться)" -ForegroundColor White
Write-Host "  • Зависимости python-docx и xhtml2pdf в requirements.txt" -ForegroundColor White
Write-Host ""
Write-Host "Бэкап сохранён в: $backupDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Cyan
Write-Host "  1. Перезапустите backend:  uvicorn app.main:app --reload --port 8000" -ForegroundColor White
Write-Host "  2. Обновите страницу фронтенда (F5)" -ForegroundColor White
Write-Host ""