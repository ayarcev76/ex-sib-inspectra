import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:exif/exif.dart';
import '../models/violation_photo.dart';

/// Автономный сервис фотофиксации.
/// Не зависит от UI и других сервисов приложения.
class PhotoService {
  static const int _maxSizeBytes = 10 * 1024 * 1024; // 10 МБ (ТЗ п.5.2.4)
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _quality = 85;
  static const int _thumbWidth = 320;
  static const int _thumbHeight = 240;

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // ─── ПУБЛИЧНЫЕ МЕТОДЫ ───────────────────────────────────────────

  /// Снять фото на камеру.
  Future<ViolationPhoto?> captureFromCamera(String violationId) async {
    final XFile? xfile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 4000, // Берём максимум, сожмём сами
      imageQuality: 95,
    );
    if (xfile == null) return null;
    return _processImage(xfile, violationId);
  }

  /// Выбрать фото из галереи.
  Future<ViolationPhoto?> pickFromGallery(String violationId) async {
    final XFile? xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4000,
      imageQuality: 95,
    );
    if (xfile == null) return null;
    return _processImage(xfile, violationId);
  }

  /// Проверка: файл подходит по формату и размеру.
  static String? validate(File file) {
    final ext = file.path.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      return 'Допустимы только JPG, JPEG, PNG';
    }
    if (file.lengthSync() > _maxSizeBytes) {
      return 'Файл превышает 10 МБ';
    }
    return null;
  }

  // ─── ВНУТРЕННЯЯ ЛОГИКА ──────────────────────────────────────────

  Future<ViolationPhoto?> _processImage(
    XFile xfile,
    String violationId,
  ) async {
    final File original = File(xfile.path);

    // 1. Валидация
    final error = validate(original);
    if (error != null) {
      throw PhotoValidationException(error);
    }

    // 2. Извлечение EXIF (до сжатия, т.к. сжатие может удалить метаданные)
    final exifData = await _extractExif(original);

    // 3. Сжатие оригинала до 1920×1080, качество 85%
    final compressedPath = await _compressImage(
      original.path,
      maxWidth: _maxWidth,
      maxHeight: _maxHeight,
      quality: _quality,
    );

    // 4. Создание миниатюры 320×240
    final thumbnailPath = await _compressImage(
      original.path,
      maxWidth: _thumbWidth,
      maxHeight: _thumbHeight,
      quality: 70,
      prefix: 'thumb',
    );

    // 5. Формирование модели
    final compressedFile = File(compressedPath);
    return ViolationPhoto(
      id: _uuid.v4(),
      violationId: violationId,
      localPath: compressedPath,
      thumbnailPath: thumbnailPath,
      originalFilename: xfile.name,
      fileSize: compressedFile.lengthSync(),
      mimeType: _getMimeType(xfile.path),
      gpsLatitude: exifData.latitude,
      gpsLongitude: exifData.longitude,
      takenAt: exifData.dateTime ?? DateTime.now(),
    );
  }

  /// Сжатие изображения с сохранением в кэш приложения.
  Future<String> _compressImage(
    String sourcePath, {
    required int maxWidth,
    required int maxHeight,
    required int quality,
    String prefix = 'img',
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final targetPath =
        '${cacheDir.path}/${prefix}_${_uuid.v4()}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    return result?.path ?? sourcePath;
  }

  /// Извлечение GPS и даты из EXIF.
  Future<_ExifResult> _extractExif(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);

      double? lat, lon;
      DateTime? dateTime;

      // GPS
      if (data.containsKey('GPS GPSLatitude')) {
        lat = _parseGpsCoordinate(
          data['GPS GPSLatitude']!,
          data['GPS GPSLatitudeRef'],
        );
      }
      if (data.containsKey('GPS GPSLongitude')) {
        lon = _parseGpsCoordinate(
          data['GPS GPSLongitude']!,
          data['GPS GPSLongitudeRef'],
        );
      }

      // Дата съёмки
      if (data.containsKey('Image DateTime')) {
        final raw = data['Image DateTime']!.printable;
        dateTime = _parseExifDate(raw);
      }

      return _ExifResult(latitude: lat, longitude: lon, dateTime: dateTime);
    } catch (_) {
      return _ExifResult();
    }
  }

  double? _parseGpsCoordinate(dynamic value, dynamic ref) {
    try {
      final parts = value.toString().split(', ');
      if (parts.length != 3) return null;
      final degrees = double.parse(parts[0]);
      final minutes = double.parse(parts[1]);
      final seconds = double.parse(parts[2]);
      double result = degrees + minutes / 60 + seconds / 3600;
      final refStr = ref?.toString() ?? '';
      if (refStr == 'S' || refStr == 'W') result = -result;
      return result;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseExifDate(String raw) {
    try {
      // Формат EXIF: "2026:08:06 14:30:00"
      return DateTime.parse(raw.replaceAll(':', '-').replaceFirst('-', ':').replaceFirst('-', ':'));
    } catch (_) {
      return null;
    }
  }

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png': return 'image/png';
      default: return 'image/jpeg';
    }
  }
}

class _ExifResult {
  final double? latitude;
  final double? longitude;
  final DateTime? dateTime;
  _ExifResult({this.latitude, this.longitude, this.dateTime});
}

class PhotoValidationException implements Exception {
  final String message;
  PhotoValidationException(this.message);
  @override
  String toString() => message;
}