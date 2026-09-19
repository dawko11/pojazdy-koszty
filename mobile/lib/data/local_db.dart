import 'package:sqflite_common/sqlite_api.dart';

import '../models/models.dart';
import 'db_factory.dart';

class LocalDb {
  Database? _db;

  Future<Database> get database async {
    _db ??= await openLocalDatabase(onCreate: _create, onUpgrade: _upgrade);
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        make TEXT,
        model TEXT,
        year INTEGER,
        fuel_type TEXT NOT NULL,
        tank_capacity_liters REAL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE fuel_entries (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        local_vehicle_id INTEGER NOT NULL,
        server_vehicle_id INTEGER,
        filled_at TEXT NOT NULL,
        odometer_km INTEGER NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        total_cost REAL NOT NULL,
        is_full_tank INTEGER NOT NULL DEFAULT 1,
        location TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {}

  String _now() => DateTime.now().toIso8601String();

  Future<List<Vehicle>> vehicles() async {
    final db = await database;
    final rows = await db.query('vehicles', where: 'is_deleted = 0', orderBy: 'updated_at DESC');
    return rows.map(Vehicle.fromDb).toList();
  }

  Future<Vehicle?> vehicleByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query('vehicles', where: 'local_id = ? AND is_deleted = 0', whereArgs: [localId]);
    if (rows.isEmpty) return null;
    return Vehicle.fromDb(rows.first);
  }

  Future<int> upsertVehicle({
    int? localId,
    int? serverId,
    required String name,
    String? make,
    String? model,
    int? year,
    required String fuelType,
    double? tankCapacityLiters,
    bool synced = false,
  }) async {
    final db = await database;
    final values = {
      'server_id': serverId,
      'name': name,
      'make': make,
      'model': model,
      'year': year,
      'fuel_type': fuelType,
      'tank_capacity_liters': tankCapacityLiters,
      'is_synced': synced ? 1 : 0,
      'is_deleted': 0,
      'updated_at': _now(),
    };
    if (localId != null) {
      await db.update('vehicles', values, where: 'local_id = ?', whereArgs: [localId]);
      return localId;
    }
    if (serverId != null) {
      final existing = await db.query('vehicles', where: 'server_id = ?', whereArgs: [serverId]);
      if (existing.isNotEmpty) {
        final id = (existing.first['local_id'] as num).toInt();
        final keepUnsynced = (existing.first['is_synced'] as int? ?? 1) == 0;
        if (keepUnsynced && synced) {
          return id;
        }
        await db.update('vehicles', values, where: 'local_id = ?', whereArgs: [id]);
        return id;
      }
    }
    return db.insert('vehicles', values);
  }

  Future<void> markVehicleSynced(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'vehicles',
      {'server_id': serverId, 'is_synced': 1, 'updated_at': _now()},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    await db.update(
      'fuel_entries',
      {'server_vehicle_id': serverId},
      where: 'local_vehicle_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markVehicleDeleted(int localId) async {
    final db = await database;
    await db.update(
      'vehicles',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': _now()},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> removeVehicle(int localId) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'local_vehicle_id = ?', whereArgs: [localId]);
    await db.delete('vehicles', where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<List<Map<String, dynamic>>> pendingVehicles() async {
    final db = await database;
    return db.query('vehicles', where: 'is_synced = 0');
  }

  Future<List<FuelEntry>> fuelEntries(int localVehicleId) async {
    final db = await database;
    final rows = await db.query(
      'fuel_entries',
      where: 'local_vehicle_id = ? AND is_deleted = 0',
      whereArgs: [localVehicleId],
      orderBy: 'filled_at DESC, odometer_km DESC',
    );
    return rows.map(FuelEntry.fromDb).toList();
  }

  Future<int> upsertFuel({
    int? localId,
    int? serverId,
    required int localVehicleId,
    int? serverVehicleId,
    required String filledAt,
    required int odometerKm,
    required double liters,
    required double pricePerLiter,
    required double totalCost,
    required bool isFullTank,
    String? location,
    bool synced = false,
  }) async {
    final db = await database;
    final values = {
      'server_id': serverId,
      'local_vehicle_id': localVehicleId,
      'server_vehicle_id': serverVehicleId,
      'filled_at': filledAt,
      'odometer_km': odometerKm,
      'liters': liters,
      'price_per_liter': pricePerLiter,
      'total_cost': totalCost,
      'is_full_tank': isFullTank ? 1 : 0,
      'location': location,
      'is_synced': synced ? 1 : 0,
      'is_deleted': 0,
      'updated_at': _now(),
    };
    if (localId != null) {
      await db.update('fuel_entries', values, where: 'local_id = ?', whereArgs: [localId]);
      return localId;
    }
    if (serverId != null) {
      final existing = await db.query('fuel_entries', where: 'server_id = ?', whereArgs: [serverId]);
      if (existing.isNotEmpty) {
        final id = (existing.first['local_id'] as num).toInt();
        final keepUnsynced = (existing.first['is_synced'] as int? ?? 1) == 0;
        if (keepUnsynced && synced) return id;
        await db.update('fuel_entries', values, where: 'local_id = ?', whereArgs: [id]);
        return id;
      }
    }
    return db.insert('fuel_entries', values);
  }

  Future<void> markFuelSynced(int localId, int serverId, {int? serverVehicleId}) async {
    final db = await database;
    await db.update(
      'fuel_entries',
      {'server_id': serverId, 'server_vehicle_id': serverVehicleId, 'is_synced': 1, 'updated_at': _now()},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markFuelDeleted(int localId) async {
    final db = await database;
    await db.update(
      'fuel_entries',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': _now()},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> removeFuel(int localId) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<List<Map<String, dynamic>>> pendingFuel() async {
    final db = await database;
    return db.query('fuel_entries', where: 'is_synced = 0');
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('fuel_entries');
    await db.delete('vehicles');
  }
}
