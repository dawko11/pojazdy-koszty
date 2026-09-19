import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/garage_store.dart';
import '../models/models.dart';
import 'stations_map_screen.dart';

class FuelFormScreen extends StatefulWidget {
  const FuelFormScreen({super.key, required this.vehicle, this.onFinished, this.initialLocation});

  final Vehicle vehicle;
  final ValueChanged<bool>? onFinished;
  final String? initialLocation;

  @override
  State<FuelFormScreen> createState() => _FuelFormScreenState();
}

class _FuelFormScreenState extends State<FuelFormScreen> {
  final _odometer = TextEditingController();
  final _liters = TextEditingController();
  final _price = TextEditingController();
  late final TextEditingController _location;
  DateTime _date = DateTime.now();
  bool _fullTank = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _location = TextEditingController(text: widget.initialLocation ?? '');
  }

  @override
  void dispose() {
    _odometer.dispose();
    _liters.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  void _finish(bool saved) {
    final callback = widget.onFinished;
    if (callback != null) {
      callback(saved);
      return;
    }
    Navigator.of(context).pop(saved);
  }

  bool _showMap = false;

  Future<void> _pickStation() async {
    setState(() => _showMap = true);
  }

  Future<void> _save() async {
    final odometer = int.tryParse(_odometer.text.trim());
    final liters = double.tryParse(_liters.text.trim().replaceAll(',', '.'));
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (odometer == null || liters == null || price == null) {
      setState(() => _error = 'Uzupełnij licznik, litry i cenę za litr');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<GarageStore>().saveFuel(
            vehicle: widget.vehicle,
            filledAt: DateFormat('yyyy-MM-dd').format(_date),
            odometerKm: odometer,
            liters: liters,
            pricePerLiter: price,
            isFullTank: _fullTank,
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          );
      if (mounted) _finish(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showMap) {
      return StationsMapScreen(
        onPicked: (station) {
          setState(() {
            _location.text = station.address;
            _showMap = false;
          });
        },
        onCancel: () => setState(() => _showMap = false),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowe tankowanie'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => _finish(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null && mounted) setState(() => _date = picked);
                  },
          ),
          TextField(
            controller: _odometer,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Stan licznika (km)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Ilość paliwa (l)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cena za litr (zł)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Lokalizacja', border: OutlineInputBorder()),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _pickStation,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Znajdź stację na mapie'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pełny bak'),
            subtitle: const Text('Potrzebny do wyliczenia średniego spalania'),
            value: _fullTank,
            onChanged: _busy ? null : (v) => setState(() => _fullTank = v),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Zapisywanie…' : 'Zapisz tankowanie'),
          ),
        ],
      ),
    );
  }
}
