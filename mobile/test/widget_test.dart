import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pojazdy_koszty/api/client.dart';
import 'package:pojazdy_koszty/data/garage_store.dart';
import 'package:pojazdy_koszty/data/local_db.dart';
import 'package:pojazdy_koszty/screens/login_screen.dart';
import 'package:pojazdy_koszty/state/session.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ekran logowania pokazuje tytuł', (tester) async {
    final api = ApiClient();
    final garage = GarageStore(api, LocalDb());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          ChangeNotifierProvider.value(value: garage),
          ChangeNotifierProvider(create: (_) => Session(api, garage)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text('Pojazdy i koszty'), findsOneWidget);
    expect(find.text('Zaloguj'), findsOneWidget);
  });
}
