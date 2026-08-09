import 'dart:io';

/// Модель фотографии нарушения для локального хранения и синхронизации.
class ViolationPhoto {
  final String id;           // Локальный UUID
  final String violationId;  // FK → violation_drafts.id
  final String localPath;    // Путь к файлу на устройстве
  final String? thumbnailPath;
  final String originalFilename;
  final int fileSize;
  final String mimeType;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final DateTime takenAt;
  final String syncStatus;   // pending / uploading / synced / failed
  final String? serverPhotoId;
  final DateTime createdAt;

  ViolationPhoto({
    required this.id,
    required this.violationId,
    required this.localPath,
    this.thumbnailPath,
    required this.originalFilename,
    required this.fileSize,
    required this.mimeType,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.takenAt,
    this.syncStatus = 'pending',
    this.serverPhotoId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'violation_id': violationId,
    'local_path': localPath,
    'thumbnail_path': thumbnailPath,
    'original_filename': originalFilename,
    'file_size': fileSize,
    'mime_type': mimeType,
    'gps_latitude': gpsLatitude,
    'gps_longitude': gpsLongitude,
    'taken_at': takenAt.toIso8601String(),
    'sync_status': syncStatus,
    'server_photo_id': serverPhotoId,
    'created_at': createdAt.toIso8601String(),
  };

  factory ViolationPhoto.fromMap(Map<String, dynamic> map) => ViolationPhoto(
    id: map['id'] as String,
    violationId: map['violation_id'] as String,
    localPath: map['local_path'] as String,
    thumbnailPath: map['thumbnail_path'] as String?,
    originalFilename: map['original_filename'] as String,
    fileSize: map['file_size'] as int,
    mimeType: map['mime_type'] as String,
    gpsLatitude: (map['gps_latitude'] as num?)?.toDouble(),
    gpsLongitude: (map['gps_longitude'] as num?)?.toDouble(),
    takenAt: DateTime.parse(map['taken_at'] as String),
    syncStatus: map['sync_status'] as String,
    serverPhotoId: map['server_photo_id'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}