// lib/services/media_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../../constants.dart';
import '../../webrtc/types.dart';
import './logging_service.dart';

class MediaMetadata {
  final String fileName;
  final String mediaType;
  final int fileSize;
  final int totalChunks;
  final int timestamp;

  MediaMetadata({
    required this.fileName,
    required this.mediaType,
    required this.fileSize,
    required this.totalChunks,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'media_metadata',
      'fileName': fileName,
      'mediaType': mediaType,
      'fileSize': fileSize,
      'totalChunks': totalChunks,
      'timestamp': timestamp,
    };
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      fileName: json['fileName'] ?? '',
      mediaType: json['mediaType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      totalChunks: json['totalChunks'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
    );
  }
}

class MediaService with LoggerMixin {
  @override
  String get loggerContext => 'MediaService';

  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  Future<String> saveMediaToTempFile(Uint8List data, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(data);
      logInfo('Media saved to temp file: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      logError('Error saving media to temp file: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> saveToGallery(String filePath, String mediaType) async {
    try {
      if (mediaType == 'photo') {
        await GallerySaver.saveImage(filePath, albumName: 'Shine');
        logInfo('Photo saved to gallery');
      } else if (mediaType == 'video') {
        await GallerySaver.saveVideo(filePath, albumName: 'Shine');
        logInfo('Video saved to gallery');
      }
    } catch (e, stackTrace) {
      logError('Error saving to gallery: $e', stackTrace);
      rethrow;
    }
  }

  Future<String> capturePhotoFromTrack(MediaStreamTrack videoTrack) async {
    try {
      logInfo('Capturing frame from video track...');
      final frame = await videoTrack.captureFrame();
      logInfo('Frame captured successfully');

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.jpg';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      final bytes = frame.asUint8List();
      logInfo('Converting frame to bytes: ${bytes.length} bytes');

      await file.writeAsBytes(bytes);
      logInfo('Photo saved to: $filePath');

      await saveToGallery(filePath, 'photo');
      return filePath;
    } catch (e, stackTrace) {
      logError('Error capturing photo: $e', stackTrace);
      rethrow;
    }
  }

  Future<bool> sendMediaThroughDataChannel(
      RTCDataChannel dataChannel,
      MediaType mediaType,
      XFile media, {
        Function(String fileName, String mediaType, int sentChunks, int totalChunks, bool isCompleted)? onProgress,
      }) async {
    try {
      final bytes = await media.readAsBytes();
      final totalChunks = (bytes.length / AppConstants.maxChunkSize).ceil();

      logInfo('Sending ${mediaType.name} in $totalChunks chunks...');

      // Send metadata first
      final metadata = MediaMetadata(
        fileName: media.name,
        mediaType: mediaType == MediaType.photo ? 'photo' : 'video',
        fileSize: bytes.length,
        totalChunks: totalChunks,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final metadataMessage = jsonEncode(metadata.toJson());
      await dataChannel.send(RTCDataChannelMessage(metadataMessage));
      logInfo('Sent metadata for ${mediaType.name}');

      // Send chunks
      for (int i = 0; i < totalChunks; i++) {
        await _sendChunkWithRetry(dataChannel, bytes, i, totalChunks);

        onProgress?.call(
          media.name,
          mediaType == MediaType.photo ? 'photo' : 'video',
          i + 1,
          totalChunks,
          i + 1 == totalChunks,
        );

        // Small delay between chunks
        await Future.delayed(Duration(milliseconds: AppConstants.chunkDelayMs));
      }

      logInfo('${mediaType.name} sent successfully');
      return true;
    } catch (e, stackTrace) {
      logError('Error sending media: $e', stackTrace);
      return false;
    }
  }

  Future<void> _sendChunkWithRetry(
      RTCDataChannel dataChannel,
      Uint8List bytes,
      int chunkIndex,
      int totalChunks,
      ) async {
    int retryCount = 0;
    bool chunkSent = false;

    while (!chunkSent && retryCount < AppConstants.maxRetries) {
      try {
        final start = chunkIndex * AppConstants.maxChunkSize;
        final end = (chunkIndex + 1) * AppConstants.maxChunkSize;
        final chunk = bytes.sublist(
          start,
          end > bytes.length ? bytes.length : end,
        );

        await dataChannel.send(RTCDataChannelMessage.fromBinary(chunk));
        logInfo('Sent chunk ${chunkIndex + 1}/$totalChunks');
        chunkSent = true;
      } catch (e) {
        retryCount++;
        logWarning('Error sending chunk ${chunkIndex + 1}, attempt $retryCount: $e');

        if (retryCount >= AppConstants.maxRetries) {
          throw Exception('Failed to send chunk after ${AppConstants.maxRetries} attempts');
        }

        await Future.delayed(
          Duration(milliseconds: AppConstants.retryDelayBaseMs * retryCount),
        );
      }
    }
  }

  Future<bool> sendMediaToMultipleChannels(
      Map<String, RTCDataChannel> dataChannels,
      MediaType mediaType,
      XFile media, {
        Function(String fileName, String mediaType, int sentChunks, int totalChunks, bool isCompleted)? onProgress,
      }) async {
    if (dataChannels.isEmpty) {
      logError('No data channels available for sending media');
      return false;
    }

    bool sentToAny = false;

    for (final entry in dataChannels.entries) {
      if (entry.value.state == RTCDataChannelState.RTCDataChannelOpen) {
        try {
          final success = await sendMediaThroughDataChannel(
            entry.value,
            mediaType,
            media,
            onProgress: onProgress,
          );

          if (success) {
            logInfo('Media sent successfully to ${entry.key}');
            sentToAny = true;
          }
        } catch (e) {
          logError('Error sending media to ${entry.key}: $e');
        }
      } else {
        logWarning('Data channel not open for ${entry.key}');
      }
    }

    return sentToAny;
  }

  MediaMetadata? parseMetadata(String messageText) {
    try {
      final data = jsonDecode(messageText);
      if (data['type'] == 'media_metadata') {
        return MediaMetadata.fromJson(data);
      }
      return null;
    } catch (e, stackTrace) {
      logError('Failed to parse media metadata: $e', stackTrace);
      return null;
    }
  }

  Future<String> assembleMediaFromChunks(
      List<Uint8List> chunks,
      MediaMetadata metadata,
      ) async {
    try {
      logInfo('Assembling media from ${chunks.length} chunks');

      final allBytes = Uint8List(metadata.fileSize);
      int offset = 0;

      for (final chunk in chunks) {
        allBytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final directory = await getTemporaryDirectory();
      final mediaDir = Directory('${directory.path}/received_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final filePath = '${mediaDir.path}/${metadata.timestamp}_${metadata.fileName}';
      final file = File(filePath);
      await file.writeAsBytes(allBytes);

      logInfo('Media assembled and saved to: $filePath');
      await saveToGallery(filePath, metadata.mediaType);

      return filePath;
    } catch (e, stackTrace) {
      logError('Error assembling media: $e', stackTrace);
      rethrow;
    }
  }
}