import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openLocalDatabase({
  required OnDatabaseCreateFn onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
}) async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final dir = await getApplicationDocumentsDirectory();
  return openDatabase(
    p.join(dir.path, 'pojazdy.db'),
    version: 1,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}
