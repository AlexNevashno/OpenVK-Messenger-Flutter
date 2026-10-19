import 'dart:io';
import 'dart:typed_data';

enum PendingUploadType {
  photo,
  document,
  audio,
  video,
}

class PendingUploadItem {
  final String id;
  final String filename;
  final PendingUploadType type;
  final File? localFile;
  final Uint8List? bytes;
  final String? remoteThumbnailUrl;
  final String? subtitle;

  double progress;
  bool isUploading;
  String? attachmentCode;
  String? error;

  PendingUploadItem({
    required this.id,
    required this.filename,
    required this.type,
    this.localFile,
    this.bytes,
    this.remoteThumbnailUrl,
    this.subtitle,
    this.progress = 0.0,
    this.isUploading = false,
    this.attachmentCode,
    this.error,
  });

  bool get isPhoto => type == PendingUploadType.photo;
  bool get isDocument => type == PendingUploadType.document;
  bool get isAudio => type == PendingUploadType.audio;
  bool get isVideo => type == PendingUploadType.video;

  String get fileExtension {
    if (filename.contains('.')) {
      return filename.split('.').last.toUpperCase();
    }
    switch (type) {
      case PendingUploadType.document:
        return 'DOC';
      case PendingUploadType.audio:
        return 'AUDIO';
      case PendingUploadType.video:
        return 'VIDEO';
      case PendingUploadType.photo:
        return 'IMG';
    }
  }
}
