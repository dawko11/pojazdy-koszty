import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/garage_store.dart';
import '../models/models.dart';
import 'fuel_form_screen.dart';
import 'vehicle_form_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Vehicle _vehicle;
  List<FuelEntry> _entries = [];
  bool _showFuelForm = false;
  bool _showEditForm = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _reload();
  }

  Future<void> _reload() async {
    final garage = context.read<GarageStore>();
    final vehicles = garage.vehicles;
    Vehicle? updated;
    for (final item in vehicles) {
      if (item.localId == _vehicle.localId) {
        updated = item;
        break;
      }
    }
    final entries = await garage.entriesFor(updated ?? _vehicle);
    if (!mounted) return;
    setState(() {
      if (updated != null) _vehicle = updated;
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.read<GarageStore>();
    if (_showEditForm) {
      return VehicleFormScreen(
        vehicle: _vehicle,
        onFinished: (saved) async {
          final navigator = Navigator.of(context);
          setState(() => _showEditForm = false);
          if (saved) {
            await garage.refreshLocal();
            if (mounted) navigator.pop();
          }
        },
      );
    }
    if (_showFuelForm) {
      return FuelFormScreen(
        vehicle: _vehicle,
        onFinished: (saved) async {
          setState(() => _showFuelForm = false);
          if (saved) await _reload();
        },
      );
    }
    final stats = VehicleStats.fromEntries(_entries);
    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicle.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => setState(() => _showEditForm = true),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<GarageStore>().deleteVehicle(_vehicle);
              if (mounted) navigator.pop();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showFuelForm = true),
        icon: const Icon(Icons.local_gas_station),
        label: const Text('Tankowanie'),
      ),
      body: _loading
          ? const Center(child: Text('Ładowanie…'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                Text('Statystyki', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(label: 'Koszt', value: '${stats.totalCost.toStringAsFixed(2)} zł'),
                    _StatChip(label: 'Litry', value: stats.totalLiters.toStringAsFixed(1)),
                    _StatChip(label: 'Dystans', value: '${stats.totalDistanceKm} km'),
                    _StatChip(label: 'l/100 km', value: stats.avgConsumption?.toStringAsFixed(1) ?? '—'),
                    _StatChip(label: 'zł/km', value: stats.costPerKm?.toStringAsFixed(2) ?? '—'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Dziennik kosztów', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_entries.isEmpty) const Text('Brak tankowań. Możesz dodać wpis offline.'),
                ..._entries.map(
                  (e) => Card(
                    child: ListTile(
                      title: Text('${e.filledAt} · ${e.odometerKm} km'),
                      subtitle: Text(
                        '${e.liters} l · ${e.pricePerLiter.toStringAsFixed(2)} zł/l · ${e.totalCost.toStringAsFixed(2)} zł'
                        '${e.location == null ? '' : ' · ${e.location}'}'
                        '${e.synced ? '' : ' · Oczekiwanie na dostęp do internetu w celu synchronizacji'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await context.read<GarageStore>().deleteFuel(e);
                          if (mounted) await _reload();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
