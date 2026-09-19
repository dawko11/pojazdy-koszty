import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/garage_store.dart';
import '../models/models.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle, this.onFinished});

  final Vehicle? vehicle;
  final ValueChanged<bool>? onFinished;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _tank;
  late String _fuelType;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _tank = TextEditingController(text: v?.tankCapacityLiters?.toString() ?? '');
    _fuelType = normalizeFuelType(v?.fuelType);
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _tank.dispose();
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

  Future<void> _save() async {
    final make = _make.text.trim();
    final model = _model.text.trim();
    if (make.isEmpty || model.isEmpty) {
      setState(() => _error = 'Podaj markę i model');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final yearText = _year.text.trim();
    final tankText = _tank.text.trim().replaceAll(',', '.');
    try {
      await context.read<GarageStore>().saveVehicle(
            existing: widget.vehicle,
            name: '$make $model',
            make: make,
            model: model,
            year: yearText.isEmpty ? null : int.tryParse(yearText),
            fuelType: _fuelType,
            tankCapacityLiters: tankText.isEmpty ? null : double.tryParse(tankText),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Nowy pojazd' : 'Edycja pojazdu'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => _finish(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _make, decoration: const InputDecoration(labelText: 'Marka', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _model, decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rok produkcji', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _fuelType,
            decoration: const InputDecoration(labelText: 'Typ paliwa', border: OutlineInputBorder()),
            items: [for (final type in fuelTypes) DropdownMenuItem(value: type, child: Text(type))],
            onChanged: _busy ? null : (value) { if (value != null) setState(() => _fuelType = value); },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tank,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pojemność baku (l)', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Zapisywanie…' : 'Zapisz'),
          ),
        ],
      ),
    );
  }
}
