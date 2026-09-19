import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/garage_store.dart';
import '../models/models.dart';
import '../state/session.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  Vehicle? _formVehicle;
  bool _showForm = false;

  void _openForm([Vehicle? vehicle]) {
    setState(() {
      _formVehicle = vehicle;
      _showForm = true;
    });
  }

  void _closeForm(bool saved) {
    setState(() {
      _showForm = false;
      _formVehicle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return VehicleFormScreen(vehicle: _formVehicle, onFinished: _closeForm);
    }
    final garage = context.watch<GarageStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garaż'),
        actions: [
          if (garage.syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              onPressed: garage.syncInBackground,
              icon: const Icon(Icons.sync),
              tooltip: 'Synchronizuj',
            ),
          IconButton(
            onPressed: () => context.read<Session>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj pojazd'),
      ),
      body: garage.vehicles.isEmpty
          ? Center(
              child: Text(
                garage.syncError == null
                    ? 'Brak pojazdów. Dodaj pierwszy — działa też offline.'
                    : 'Brak pojazdów.\n${garage.syncError}',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await garage.refreshLocal();
                garage.syncInBackground();
              },
              child: ListView.separated(
                itemCount: garage.vehicles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = garage.vehicles[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(vehicle.synced ? Icons.directions_car : Icons.cloud_upload_outlined),
                    ),
                    title: Text(vehicle.name),
                    subtitle: Text(
                      vehicle.synced
                          ? vehicle.subtitle
                          : '${vehicle.subtitle} · Oczekiwanie na dostęp do internetu w celu synchronizacji',
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
                      );
                      await garage.refreshLocal();
                    },
                  );
                },
              ),
            ),
    );
  }
}
