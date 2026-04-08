import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ManagedFileStore {
  static const MethodChannel _channel = MethodChannel('easychat/managed_file_store');

  Future<String> storeBytes({
    required Uint8List bytes,
    required String fileName,
    required String bucket,
  }) async {
    final directory = await _bucketDirectory(bucket);
    final output = File(path.join(directory.path, _uniqueFileName(fileName)));
    await output.writeAsBytes(bytes, flush: true);
    await _excludeFromBackup(output.path);
    return output.path;
  }

  Future<String> createZip({
    required List<ManagedZipEntry> entries,
    required String fileName,
  }) async {
    final directory = await _bucketDirectory('exports');
    final archive = Archive();

    for (final entry in entries) {
      final bytes = await File(entry.filePath).readAsBytes();
      archive.addFile(ArchiveFile(entry.nameInZip, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);

    final output = File(path.join(directory.path, _uniqueFileName(fileName)));
    await output.writeAsBytes(encoded, flush: true);
    await _excludeFromBackup(output.path);
    return output.path;
  }

  Future<Directory> _bucketDirectory(String bucket) async {
    final root = await _rootDirectory();
    final directory = Directory(path.join(root.path, bucket));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await _excludeFromBackup(directory.path);
    return directory;
  }

  Future<Directory> _rootDirectory() async {
    final baseDirectory = await getApplicationSupportDirectory();
    final root = Directory(path.join(baseDirectory.path, 'easychat_files'));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    await _excludeFromBackup(root.path);
    return root;
  }

  Future<void> _excludeFromBackup(String filePath) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod('excludeFromBackup', {'path': filePath});
    } catch (_) {
      // Ignore iOS backup flag failures and keep the file usable.
    }
  }

  String _uniqueFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp-$sanitized';
  }
}

class ManagedZipEntry {
  const ManagedZipEntry({
    required this.filePath,
    required this.nameInZip,
  });

  final String filePath;
  final String nameInZip;
}
