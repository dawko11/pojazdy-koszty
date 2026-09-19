import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../data/garage_store.dart';

class Session extends ChangeNotifier {
  Session(this.api, this.garage);

  final ApiClient api;
  final GarageStore garage;
  bool ready = false;
  bool loggedIn = false;

  Future<void> restore() async {
    final token = await api.getToken();
    loggedIn = token != null && token.isNotEmpty;
    ready = true;
    notifyListeners();
    if (loggedIn) {
      await garage.refreshLocal();
      garage.syncInBackground();
    }
  }

  Future<void> login(String email, String password) async {
    await api.login(email, password);
    loggedIn = true;
    notifyListeners();
    await garage.refreshLocal();
    garage.syncInBackground();
  }

  Future<void> register(String email, String password) async {
    await api.register(email, password);
    await login(email, password);
  }

  Future<void> logout() async {
    await api.clearToken();
    await garage.db.clear();
    await garage.refreshLocal();
    loggedIn = false;
    notifyListeners();
  }
}
