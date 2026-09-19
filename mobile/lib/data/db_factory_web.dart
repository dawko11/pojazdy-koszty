import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openLocalDatabase({
  required OnDatabaseCreateFn onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
}) {
  return databaseFactoryFfiWeb.openDatabase(
    'pojazdy.db',
    options: OpenDatabaseOptions(version: 1, onCreate: onCreate, onUpgrade: onUpgrade),
  );
}
