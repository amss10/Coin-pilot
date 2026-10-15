import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locations of app-private files. Paths stored in the database are always
/// **relative** to [AppPaths.root] because the iOS container path changes
/// between installs and restores.
final class AppPaths {
  const AppPaths(this.root);

  /// Application Support (backed up per the rules in docs/privacy.md).
  static Future<AppPaths> resolve() async => AppPaths(await getApplicationSupportDirectory());

  final Directory root;

  /// Folder for receipt photos (excluded from Android cloud backup).
  static const String receiptsFolder = 'receipts';

  String absolute(String relativePath) => p.join(root.path, relativePath);

  String relativeReceiptPath(String fileName) => p.join(receiptsFolder, fileName);
}
