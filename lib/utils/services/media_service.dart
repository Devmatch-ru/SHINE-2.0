import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:camera/camera.dart';

import '../core/error_handler.dart';
import '../core/logger.dart';


class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final Logger _logger = Logger();
  final ErrorHandler _errorHandler = ErrorHandler();

  Future<Directory> getMediaDirectory() async {
    try {
      final directory = await getTemporaryDirectory();
      final mediaDir = Directory('${directory.path}/media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      return mediaDir;
    } catch (e) {
      _errorHandler.handleError('MediaService.getMediaDirectory', e);
      rethrow;
    }
  }

  Future<XFile> savePhoto(Uint8List bytes, {String? customName}) async {
    try {
      _logger.log('MediaService', 'Saving photo...');

      final directory = await getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customName ?? 'photo_$timestamp.jpg';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await GallerySaver.saveImage(filePath, albumName: 'Shine');

      _logger.log('MediaService', 'Photo saved: $filePath');
      return XFile(filePath);
    } catch (e) {
      _errorHandler.handleError('MediaService.savePhoto', e);
      rethrow;
    }
  }

  Future<XFile> saveVideo(String sourcePath, {String? customName}) async {
    try {
      _logger.log('MediaService', 'Saving video...');

      await GallerySaver.saveVideo(sourcePath, albumName: 'Shine');

      _logger.log('MediaService', 'Video saved: $sourcePath');
      return XFile(sourcePath);
    } catch (e) {
      _errorHandler.handleError('MediaService.saveVideo', e);
      rethrow;
    }
  }

  Future<File> saveReceivedMedia(
      String broadcasterUrl,
      String mediaType,
      Uint8List data,
      String fileName,
      int timestamp
      ) async {
    try {
      _logger.log('MediaService', 'Saving received $mediaType: $fileName');

      final directory = await getTemporaryDirectory();
      final mediaDir = Directory('${directory.path}/received_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final filePath = '${mediaDir.path}/${timestamp}_$fileName';
      final file = File(filePath);
      await file.writeAsBytes(data);

      if (mediaType == 'photo') {
        await GallerySaver.saveImage(filePath, albumName: 'Shine');
      } else if (mediaType == 'video') {
        await GallerySaver.saveVideo(filePath, albumName: 'Shine');
      }

      _logger.log('MediaService', 'Received media saved: $filePath');
      return file;
    } catch (e) {
      _errorHandler.handleError('MediaService.saveReceivedMedia', e);
      rethrow;
    }
  }
}