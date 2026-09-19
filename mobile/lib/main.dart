import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../data/garage_store.dart';
import '../data/local_db.dart';
import '../screens/login_screen.dart';
import '../screens/vehicles_screen.dart';
import '../state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.loadSettings();
  final garage = GarageStore(api, LocalDb());
  final session = Session(api, garage);
  await session.restore();
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: garage),
        ChangeNotifierProvider.value(value: session),
      ],
      child: const PojazdyApp(),
    ),
  );
}

class PojazdyApp extends StatelessWidget {
  const PojazdyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pojazdy i koszty',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
      home: Consumer<Session>(
        builder: (context, session, _) {
          return session.loggedIn ? const VehiclesScreen() : const LoginScreen();
        },
      ),
    );
  }
}
