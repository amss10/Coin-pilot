import 'dart:io';
import 'dart:typed_data';

import 'package:coin_pilot/src/core/platform/app_paths.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Reads and writes app-private files by relative path.
final class FileStore {
  const FileStore(this._paths);

  final AppPaths _paths;

  /// Writes [bytes] and returns their SHA-256 (used to de-duplicate receipts).
  Future<String> write(String relativePath, Uint8List bytes) async {
    final file = File(_paths.absolute(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return sha256.convert(bytes).toString();
  }

  Future<Uint8List?> read(String relativePath) async {
    final file = File(_paths.absolute(relativePath));
    return file.existsSync() ? file.readAsBytes() : null;
  }

  Future<void> delete(String relativePath) async {
    final file = File(_paths.absolute(relativePath));
    if (file.existsSync()) await file.delete();
  }

  /// Deletes every receipt photo (part of "Delete all data").
  Future<void> deleteAllReceipts() async {
    final dir = Directory(p.join(_paths.root.path, AppPaths.receiptsFolder));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
