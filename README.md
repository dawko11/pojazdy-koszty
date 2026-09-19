# Pojazdy i koszty

Aplikacja mobilna (Flutter) + REST API (FastAPI) + PostgreSQL + lokalny SQLite.  
**Autorzy:** Anna Kaim 52699, Dawid Miter 52833.

Pełny opis założeń, podziału zadań, API i schematu bazy: **[DOKUMENTACJA.md](DOKUMENTACJA.md)**.

## Uruchomienie backendu

```powershell
docker compose up --build
```

- API: http://127.0.0.1:8000
- Swagger: http://127.0.0.1:8000/docs
- PostgreSQL: `localhost:5432` (pojazdy / pojazdy / pojazdy_koszty)

## Aplikacja Flutter

```powershell
cd mobile
flutter pub get
flutter run -d chrome
```

Adres API: emulator Androida `http://10.0.2.2:8000`, Chrome `http://localhost:8000`.

Najpierw rejestracja, potem logowanie. Tankowanie można dodać offline — po sieci nastąpi synchronizacja (`is_synced`).

## Testy API

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
pytest -q
```
