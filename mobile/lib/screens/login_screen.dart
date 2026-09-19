import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../state/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _apiUrl;
  bool _register = false;
  bool _busy = false;
  bool _showApi = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiUrl = TextEditingController(text: context.read<ApiClient>().baseUrl);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _apiUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Hasło musi mieć co najmniej 6 znaków');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Podaj poprawny email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      await context.read<ApiClient>().setBaseUrl(_apiUrl.text);
      if (_register) {
        await session.register(_email.text.trim(), _password.text);
      } else {
        await session.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('Pojazdy i koszty', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_register ? 'Utwórz konto' : 'Zaloguj się, aby zarządzać pojazdami'),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Hasło (min. 6 znaków)', border: OutlineInputBorder()),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _showApi = !_showApi),
              child: Text(_showApi ? 'Ukryj adres API' : 'Adres API (gdy logowanie nie łączy się)'),
            ),
            if (_showApi) ...[
              TextField(
                controller: _apiUrl,
                decoration: const InputDecoration(
                  labelText: 'Adres API',
                  helperText: 'Emulator Androida: http://10.0.2.2:8000\nChrome: http://localhost:8000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Proszę czekać…' : (_register ? 'Zarejestruj' : 'Zaloguj')),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _register = !_register),
              child: Text(_register ? 'Mam już konto' : 'Nie mam konta — rejestracja'),
            ),
          ],
        ),
      ),
    );
  }
}
