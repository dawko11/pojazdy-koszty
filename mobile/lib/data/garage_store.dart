import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../models/models.dart';
import 'local_db.dart';

class GarageStore extends ChangeNotifier {
  GarageStore(this.api, this.db);

  final ApiClient api;
  final LocalDb db;

  List<Vehicle> vehicles = [];
  bool syncing = false;
  String? syncError;

  Future<void> refreshLocal() async {
    vehicles = await db.vehicles();
    notifyListeners();
  }

  Future<void> syncInBackground() async {
    unawaited(_sync());
  }

  Future<void> _sync() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await _pushPending();
      await _pullServer();
      await refreshLocal();
    } catch (e) {
      syncError = e.toString();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushPending() async {
    for (final row in await db.pendingVehicles()) {
      final localId = row['local_id'] as int;
      final deleted = (row['is_deleted'] as int? ?? 0) == 1;
      final serverId = row['server_id'] as int?;
      if (deleted) {
        if (serverId != null) {
          try {
            await api.deleteVehicle(serverId);
          } on ApiException catch (e) {
            if (e.statusCode != 404) rethrow;
          }
        }
        await db.removeVehicle(localId);
        continue;
      }
      final body = {
        'name': row['name'],
        'make': row['make'],
        'model': row['model'],
        'year': row['year'],
        'fuel_type': row['fuel_type'],
        'tank_capacity_liters': row['tank_capacity_liters'],
      };
      if (serverId == null) {
        final created = await api.createVehicle(body);
        await db.markVehicleSynced(localId, (created['id'] as num).toInt());
      } else {
        await api.updateVehicle(serverId, body);
        await db.markVehicleSynced(localId, serverId);
      }
    }

    for (final row in await db.pendingFuel()) {
      final localId = row['local_id'] as int;
      final deleted = (row['is_deleted'] as int? ?? 0) == 1;
      final serverId = row['server_id'] as int?;
      var serverVehicleId = row['server_vehicle_id'] as int?;
      if (serverVehicleId == null) {
        final vehicle = await db.vehicleByLocalId(row['local_vehicle_id'] as int);
        serverVehicleId = vehicle?.serverId;
      }
      if (deleted) {
        if (serverId != null) {
          try {
            await api.deleteFuel(serverId);
          } on ApiException catch (e) {
            if (e.statusCode != 404) rethrow;
          }
        }
        await db.removeFuel(localId);
        continue;
      }
      if (serverVehicleId == null) continue;
      final body = {
        'filled_at': row['filled_at'],
        'odometer_km': row['odometer_km'],
        'liters': row['liters'],
        'price_per_liter': row['price_per_liter'],
        'total_cost': row['total_cost'],
        'is_full_tank': (row['is_full_tank'] as int? ?? 1) == 1,
        'location': row['location'],
      };
      if (serverId == null) {
        final created = await api.createFuel(serverVehicleId, body);
        await db.markFuelSynced(localId, (created['id'] as num).toInt(), serverVehicleId: serverVehicleId);
      } else {
        await db.markFuelSynced(localId, serverId, serverVehicleId: serverVehicleId);
      }
    }
  }

  Future<void> _pullServer() async {
    final remoteVehicles = await api.vehicles();
    for (final raw in remoteVehicles) {
      final map = Map<String, dynamic>.from(raw as Map);
      final localId = await db.upsertVehicle(
        serverId: (map['id'] as num).toInt(),
        name: map['name'] as String,
        make: map['make'] as String?,
        model: map['model'] as String?,
        year: (map['year'] as num?)?.toInt(),
        fuelType: map['fuel_type'] as String? ?? 'Benzyna',
        tankCapacityLiters: (map['tank_capacity_liters'] as num?)?.toDouble(),
        synced: true,
      );
      final serverVehicleId = (map['id'] as num).toInt();
      final remoteFuel = await api.fuelEntries(serverVehicleId);
      for (final fuelRaw in remoteFuel) {
        final fuel = Map<String, dynamic>.from(fuelRaw as Map);
        final liters = (fuel['liters'] as num).toDouble();
        final cost = (fuel['total_cost'] as num).toDouble();
        await db.upsertFuel(
          serverId: (fuel['id'] as num).toInt(),
          localVehicleId: localId,
          serverVehicleId: serverVehicleId,
          filledAt: fuel['filled_at'] as String,
          odometerKm: (fuel['odometer_km'] as num).toInt(),
          liters: liters,
          pricePerLiter: (fuel['price_per_liter'] as num?)?.toDouble() ?? (liters == 0 ? 0 : cost / liters),
          totalCost: cost,
          isFullTank: fuel['is_full_tank'] as bool? ?? true,
          location: (fuel['location'] ?? fuel['station']) as String?,
          synced: true,
        );
      }
    }
  }

  Future<void> saveVehicle({
    Vehicle? existing,
    required String name,
    String? make,
    String? model,
    int? year,
    required String fuelType,
    double? tankCapacityLiters,
  }) async {
    await db.upsertVehicle(
      localId: existing?.localId,
      serverId: existing?.serverId,
      name: name,
      make: make,
      model: model,
      year: year,
      fuelType: fuelType,
      tankCapacityLiters: tankCapacityLiters,
      synced: false,
    );
    await refreshLocal();
    await syncInBackground();
  }

  Future<void> deleteVehicle(Vehicle vehicle) async {
    await db.markVehicleDeleted(vehicle.localId);
    await refreshLocal();
    await syncInBackground();
  }

  Future<List<FuelEntry>> entriesFor(Vehicle vehicle) {
    return db.fuelEntries(vehicle.localId);
  }

  Future<void> saveFuel({
    required Vehicle vehicle,
    required String filledAt,
    required int odometerKm,
    required double liters,
    required double pricePerLiter,
    required bool isFullTank,
    String? location,
  }) async {
    await db.upsertFuel(
      localVehicleId: vehicle.localId,
      serverVehicleId: vehicle.serverId,
      filledAt: filledAt,
      odometerKm: odometerKm,
      liters: liters,
      pricePerLiter: pricePerLiter,
      totalCost: double.parse((liters * pricePerLiter).toStringAsFixed(2)),
      isFullTank: isFullTank,
      location: location,
      synced: false,
    );
    await syncInBackground();
  }

  Future<void> deleteFuel(FuelEntry entry) async {
    await db.markFuelDeleted(entry.localId);
    await syncInBackground();
  }

  Future<List<GasStation>> nearbyStations(double lat, double lon) async {
    final raw = await api.nearbyStations(lat, lon);
    return raw.map(GasStation.fromJson).toList();
  }
}
