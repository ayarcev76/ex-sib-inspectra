import React, { useState, useEffect } from 'react';
import { Upload, message, Modal } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import type { UploadFile, UploadProps } from 'antd/es/upload/interface';
import apiClient from '../api/client';

interface Photo {
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

interface PhotoUploadProps {
  violationId: string;
  photos: Photo[];
  onChange: (photos: Photo[]) => void;
}

const PhotoUpload: React.FC<PhotoUploadProps> = ({ violationId, photos, onChange }) => {
  const [previewOpen, setPreviewOpen] = useState(false);
  const [previewImage, setPreviewImage] = useState('');
  const [previewTitle, setPreviewTitle] = useState('');
  const [fileList, setFileList] = useState<UploadFile[]>([]);
  const [loading, setLoading] = useState(false);
  
  // Храним presigned URL для каждой фотографии
  const [photoUrls, setPhotoUrls] = useState<Record<string, { original: string; thumbnail: string }>>({});

  // 1. Загружаем presigned URL для всех существующих фотографий
  useEffect(() => {
    const loadPhotoUrls = async () => {
      const urls: Record<string, { original: string; thumbnail: string }> = {};
      
      await Promise.all(
        photos.map(async (photo) => {
          try {
            const [originalRes, thumbnailRes] = await Promise.all([
              apiClient.get(`/violations/${violationId}/photos/${photo.id}/original`).catch(() => null),
              photo.thumbnail_path 
                ? apiClient.get(`/violations/${violationId}/photos/${photo.id}/thumbnail`).catch(() => null)
                : Promise.resolve(null),
            ]);

            if (originalRes) {
              urls[photo.id] = {
                original: originalRes.data.url,
                thumbnail: thumbnailRes?.data.url || originalRes.data.url,
              };
            }
          } catch (err) {
            console.error(`Ошибка загрузки URL для фото ${photo.id}:`, err);
          }
        })
      );
      
      setPhotoUrls(urls);
    };

    if (photos.length > 0) {
      loadPhotoUrls();
    }
  }, [photos, violationId]);

  // 2. Конвертируем фотографии в формат UploadFile, используя presigned URL для отображения
  useEffect(() => {
    const convertedFiles: UploadFile[] = photos.map((photo) => {
      const urls = photoUrls[photo.id];
      return {
        uid: photo.id,
        name: photo.original_filename,
        status: 'done' as const,
        url: urls?.thumbnail || '', // <-- ИСПРАВЛЕНО: используем полный presigned URL, а не относительный путь
        size: photo.file_size,
        type: photo.mime_type,
      };
    });
    setFileList(convertedFiles);
  }, [photos, photoUrls]);

  // Обработка загрузки файла
  const handleUpload = async (options: any) => {
    const { file, onSuccess, onError } = options;
    
    setLoading(true);
    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await apiClient.post(`/violations/${violationId}/photos`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      onSuccess(response.data, file);
      message.success(`${file.name} загружен успешно`);
      
      // Перезагружаем список фотографий (это запустит useEffect и загрузит новые URL)
      const photosResponse = await apiClient.get(`/violations/${violationId}/photos`);
      onChange(photosResponse.data);
    } catch (error: any) {
      console.error('Ошибка загрузки:', error);
      const errorMsg = error.response?.data?.detail || 'Ошибка загрузки файла';
      message.error(errorMsg);
      onError(error);
    } finally {
      setLoading(false);
    }
  };

  // Обработка удаления файла
  const handleRemove = async (file: UploadFile) => {
    try {
      await apiClient.delete(`/violations/${violationId}/photos/${file.uid}`);
      message.success('Фотография удалена');
      
      const response = await apiClient.get(`/violations/${violationId}/photos`);
      onChange(response.data);
      return true;
    } catch (error: any) {
      console.error('Ошибка удаления:', error);
      message.error('Ошибка удаления фотографии');
      return false;
    }
  };

  // Предпросмотр изображения
  const handlePreview = async (file: UploadFile) => {
    let url = '';
    
    // Если это уже загруженная фотография, берем presigned URL для оригинала из состояния
    if (file.uid && photoUrls[file.uid]) {
      url = photoUrls[file.uid].original;
    } else if (file.response) {
      // Если это только что загруженное фото (еще не обновилось в photos), запрашиваем URL
      url = await apiClient.get(`/violations/${violationId}/photos/${file.response.id}/original`)
        .then(res => res.data.url)
        .catch(() => '');
    } else {
      url = file.url || '';
    }
    
    setPreviewImage(url);
    setPreviewTitle(file.name || file.uid);
    setPreviewOpen(true);
  };

  const uploadProps: UploadProps = {
    customRequest: handleUpload,
    onRemove: handleRemove,
    onPreview: handlePreview,
    fileList,
    listType: 'picture-card',
    accept: 'image/jpeg,image/jpg,image/png',
    beforeUpload: (file) => {
      const isJpgOrPng = file.type === 'image/jpeg' || file.type === 'image/png';
      if (!isJpgOrPng) {
        message.error('Можно загружать только JPG/PNG файлы!');
        return false;
      }
      const isLt10M = file.size / 1024 / 1024 < 10;
      if (!isLt10M) {
        message.error('Размер файла должен быть меньше 10 МБ!');
        return false;
      }
      return true;
    },
  };

  const uploadButton = (
    <div>
      <PlusOutlined />
      <div style={{ marginTop: 8 }}>Загрузить</div>
    </div>
  );

  return (
    <>
      <Upload {...uploadProps}>{fileList.length >= 10 ? null : uploadButton}</Upload>
      
      <Modal
        open={previewOpen}
        title={previewTitle}
        footer={null}
        onCancel={() => setPreviewOpen(false)}
      >
        <img alt="preview" style={{ width: '100%' }} src={previewImage} />
      </Modal>
    </>
  );
};

export default PhotoUpload;