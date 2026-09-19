import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/garage_store.dart';
import '../models/models.dart';

class StationsMapScreen extends StatefulWidget {
  const StationsMapScreen({super.key, this.onPicked, this.onCancel});

  final ValueChanged<GasStation>? onPicked;
  final VoidCallback? onCancel;

  @override
  State<StationsMapScreen> createState() => _StationsMapScreenState();
}

class _StationsMapScreenState extends State<StationsMapScreen> {
  static const _fallback = LatLng(52.2297, 21.0122);
  final _mapController = MapController();
  LatLng _center = _fallback;
  List<GasStation> _stations = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!mounted) return;
      final garage = context.read<GarageStore>();
      final position = await _position();
      _center = LatLng(position.latitude, position.longitude);
      final stations = await garage.nearbyStations(_center.latitude, _center.longitude);
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _loading = false;
      });
      try {
        _mapController.move(_center, 13);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _select(GasStation station) {
    final callback = widget.onPicked;
    if (callback != null) {
      callback(station);
      return;
    }
    Navigator.of(context).pop(station);
  }

  Future<Position> _position() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return Position(
        longitude: _fallback.longitude,
        latitude: _fallback.latitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    return Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Znajdź stację'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'pojazdy_koszty',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                    for (final station in _stations)
                      Marker(
                        point: LatLng(station.lat, station.lon),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _select(station),
                          child: const Icon(Icons.local_gas_station, color: Colors.red, size: 32),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: _stations.isEmpty
                ? const Center(child: Text('Brak stacji w pobliżu'))
                : ListView.builder(
                    itemCount: _stations.length,
                    itemBuilder: (context, index) {
                      final station = _stations[index];
                      return ListTile(
                        leading: const Icon(Icons.local_gas_station),
                        title: Text(station.name),
                        subtitle: Text(
                          [
                            station.address,
                            if (station.distanceKm != null) '${station.distanceKm} km',
                          ].join(' · '),
                        ),
                        onTap: () => _select(station),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
