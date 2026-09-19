const fuelTypes = ['Benzyna', 'Diesel', 'Benzyna+LPG', 'Hybryda'];

String normalizeFuelType(String? value) {
  if (value == null || value.isEmpty) return 'Benzyna';
  final lower = value.toLowerCase();
  for (final type in fuelTypes) {
    if (type.toLowerCase() == lower) return type;
  }
  return 'Benzyna';
}

class Vehicle {
  Vehicle({
    required this.localId,
    this.serverId,
    required this.name,
    this.make,
    this.model,
    this.year,
    required this.fuelType,
    this.tankCapacityLiters,
    this.synced = true,
  });

  final int localId;
  final int? serverId;
  final String name;
  final String? make;
  final String? model;
  final int? year;
  final String fuelType;
  final double? tankCapacityLiters;
  final bool synced;

  int get id => serverId ?? localId;

  factory Vehicle.fromServer(Map<String, dynamic> json) {
    return Vehicle(
      localId: 0,
      serverId: (json['id'] as num).toInt(),
      name: json['name'] as String,
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: (json['year'] as num?)?.toInt(),
      fuelType: normalizeFuelType(json['fuel_type'] as String?),
      tankCapacityLiters: (json['tank_capacity_liters'] as num?)?.toDouble(),
      synced: true,
    );
  }

  factory Vehicle.fromDb(Map<String, dynamic> row) {
    return Vehicle(
      localId: (row['local_id'] as num).toInt(),
      serverId: (row['server_id'] as num?)?.toInt(),
      name: row['name'] as String,
      make: row['make'] as String?,
      model: row['model'] as String?,
      year: (row['year'] as num?)?.toInt(),
      fuelType: normalizeFuelType(row['fuel_type'] as String?),
      tankCapacityLiters: (row['tank_capacity_liters'] as num?)?.toDouble(),
      synced: (row['is_synced'] as num? ?? 0) == 1,
    );
  }

  String get subtitle {
    final parts = [make, model, if (year != null) year.toString()].whereType<String>().where((e) => e.isNotEmpty);
    final fuel = tankCapacityLiters == null ? fuelType : '$fuelType · ${tankCapacityLiters!.toStringAsFixed(0)} l';
    return parts.isEmpty ? fuel : '${parts.join(' ')} · $fuel';
  }
}

class FuelEntry {
  FuelEntry({
    required this.localId,
    this.serverId,
    required this.localVehicleId,
    this.serverVehicleId,
    required this.filledAt,
    required this.odometerKm,
    required this.liters,
    required this.pricePerLiter,
    required this.totalCost,
    required this.isFullTank,
    this.location,
    this.synced = true,
  });

  final int localId;
  final int? serverId;
  final int localVehicleId;
  final int? serverVehicleId;
  final String filledAt;
  final int odometerKm;
  final double liters;
  final double pricePerLiter;
  final double totalCost;
  final bool isFullTank;
  final String? location;
  final bool synced;

  int get id => serverId ?? localId;

  factory FuelEntry.fromServer(Map<String, dynamic> json, {required int localVehicleId}) {
    final liters = (json['liters'] as num).toDouble();
    final cost = (json['total_cost'] as num).toDouble();
    final price = (json['price_per_liter'] as num?)?.toDouble() ?? (liters == 0 ? 0 : cost / liters);
    return FuelEntry(
      localId: 0,
      serverId: (json['id'] as num).toInt(),
      localVehicleId: localVehicleId,
      serverVehicleId: (json['vehicle_id'] as num?)?.toInt(),
      filledAt: json['filled_at'] as String,
      odometerKm: (json['odometer_km'] as num).toInt(),
      liters: liters,
      pricePerLiter: price,
      totalCost: cost,
      isFullTank: json['is_full_tank'] as bool? ?? true,
      location: (json['location'] ?? json['station']) as String?,
      synced: true,
    );
  }

  factory FuelEntry.fromDb(Map<String, dynamic> row) {
    return FuelEntry(
      localId: (row['local_id'] as num).toInt(),
      serverId: (row['server_id'] as num?)?.toInt(),
      localVehicleId: (row['local_vehicle_id'] as num).toInt(),
      serverVehicleId: (row['server_vehicle_id'] as num?)?.toInt(),
      filledAt: row['filled_at'] as String,
      odometerKm: (row['odometer_km'] as num).toInt(),
      liters: (row['liters'] as num).toDouble(),
      pricePerLiter: (row['price_per_liter'] as num).toDouble(),
      totalCost: (row['total_cost'] as num).toDouble(),
      isFullTank: (row['is_full_tank'] as num? ?? 1) == 1,
      location: row['location'] as String?,
      synced: (row['is_synced'] as num? ?? 0) == 1,
    );
  }
}

class VehicleStats {
  VehicleStats({
    required this.fillupCount,
    required this.totalCost,
    required this.totalLiters,
    required this.totalDistanceKm,
    this.avgConsumption,
    this.costPerKm,
    this.avgPricePerLiter,
  });

  final int fillupCount;
  final double totalCost;
  final double totalLiters;
  final int totalDistanceKm;
  final double? avgConsumption;
  final double? costPerKm;
  final double? avgPricePerLiter;

  factory VehicleStats.fromJson(Map<String, dynamic> json) {
    return VehicleStats(
      fillupCount: (json['fillup_count'] as num).toInt(),
      totalCost: (json['total_cost'] as num).toDouble(),
      totalLiters: (json['total_liters'] as num).toDouble(),
      totalDistanceKm: (json['total_distance_km'] as num).toInt(),
      avgConsumption: (json['avg_consumption_l_per_100km'] as num?)?.toDouble(),
      costPerKm: (json['cost_per_km'] as num?)?.toDouble(),
      avgPricePerLiter: (json['avg_price_per_liter'] as num?)?.toDouble(),
    );
  }

  static VehicleStats fromEntries(List<FuelEntry> entries) {
    if (entries.isEmpty) {
      return VehicleStats(fillupCount: 0, totalCost: 0, totalLiters: 0, totalDistanceKm: 0);
    }
    final ordered = [...entries]..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
    final totalCost = ordered.fold<double>(0, (sum, e) => sum + e.totalCost);
    final totalLiters = ordered.fold<double>(0, (sum, e) => sum + e.liters);
    if (ordered.length < 2) {
      return VehicleStats(
        fillupCount: ordered.length,
        totalCost: totalCost,
        totalLiters: totalLiters,
        totalDistanceKm: 0,
        avgPricePerLiter: totalLiters == 0 ? null : totalCost / totalLiters,
      );
    }
    final distance = ordered.last.odometerKm - ordered.first.odometerKm;
    FuelEntry? previousFull;
    var litersSum = 0.0;
    var kmSum = 0;
    for (final entry in ordered) {
      if (previousFull != null && entry.isFullTank) {
        final d = entry.odometerKm - previousFull.odometerKm;
        if (d > 0) {
          litersSum += entry.liters;
          kmSum += d;
        }
      }
      if (entry.isFullTank) previousFull = entry;
    }
    return VehicleStats(
      fillupCount: ordered.length,
      totalCost: totalCost,
      totalLiters: totalLiters,
      totalDistanceKm: distance,
      avgConsumption: kmSum == 0 ? null : litersSum / kmSum * 100,
      costPerKm: distance <= 0 ? null : totalCost / distance,
      avgPricePerLiter: totalLiters == 0 ? null : totalCost / totalLiters,
    );
  }
}

class GasStation {
  GasStation({required this.name, required this.address, required this.lat, required this.lon, this.distanceKm});

  final String name;
  final String address;
  final double lat;
  final double lon;
  final double? distanceKm;

  factory GasStation.fromJson(Map<String, dynamic> json) {
    return GasStation(
      name: json['name'] as String? ?? 'Stacja paliw',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
