import 'dart:io';
import 'package:flutter/material.dart';
import '../core/eurochem_colors.dart';
import '../models/violation_photo.dart';
import '../services/photo_service.dart';

/// Автономный виджет фотофиксации.
/// Встраивается в карточку нарушения.
/// НЕ знает о sync, API, БД — просто возвращает фото через коллбэк.
class PhotoCaptureWidget extends StatefulWidget {
  final String violationId;
  final List<ViolationPhoto> existingPhotos;
  final ValueChanged<ViolationPhoto> onPhotoAdded;
  final ValueChanged<String> onPhotoRemoved;

  const PhotoCaptureWidget({
    super.key,
    required this.violationId,
    required this.existingPhotos,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final PhotoService _photoService = PhotoService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Row(
          children: [
            const Icon(Icons.photo_camera, size: 18, color: EurochemColors.green),
            const SizedBox(width: 8),
            const Text(
              'Фотофиксация',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '(${widget.existingPhotos.length})',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Сетка превью + кнопка добавления
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Существующие фото
            ...widget.existingPhotos.map((photo) => _buildPhotoCard(photo)),

            // Кнопка добавления
            _buildAddButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoCard(ViolationPhoto photo) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photo.thumbnailPath ?? photo.localPath),
              fit: BoxFit.cover,
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          // Кнопка удаления
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => widget.onPhotoRemoved(photo.id),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
          // Индикатор статуса синхронизации
          if (photo.syncStatus == 'synced')
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: EurochemColors.green,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: 100,
      height: 100,
      child: InkWell(
        onTap: _isProcessing ? null : _showSourceDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: EurochemColors.green, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isProcessing
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: EurochemColors.green, size: 28),
                    SizedBox(height: 4),
                    Text('Добавить', style: TextStyle(fontSize: 11, color: EurochemColors.green)),
                  ],
                ),
        ),
      ),
    );
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: EurochemColors.green),
              title: const Text('Снять на камеру'),
              onTap: () {
                Navigator.pop(ctx);
                _capture(ImageSourceCamera.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: EurochemColors.green),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _capture(ImageSourceCamera.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capture(ImageSourceCamera source) async {
    setState(() => _isProcessing = true);
    try {
      final photo = source == ImageSourceCamera.camera
          ? await _photoService.captureFromCamera(widget.violationId)
          : await _photoService.pickFromGallery(widget.violationId);

      if (photo != null) {
        widget.onPhotoAdded(photo);
      }
    } on PhotoValidationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Ошибка обработки фото: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

enum ImageSourceCamera { camera, gallery }