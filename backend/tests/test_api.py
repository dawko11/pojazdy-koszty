from fastapi.testclient import TestClient


def auth_headers(client: TestClient, email: str = "dawid@example.com") -> dict[str, str]:
    client.post("/auth/register", json={"email": email, "password": "secret1"})
    token = client.post("/auth/login", json={"email": email, "password": "secret1"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_register_and_login(client: TestClient) -> None:
    created = client.post("/auth/register", json={"email": "a@b.c", "password": "secret1"})
    assert created.status_code == 201
    login = client.post("/auth/login", json={"email": "a@b.c", "password": "secret1"})
    assert login.status_code == 200
    assert login.json()["access_token"]


def test_duplicate_email(client: TestClient) -> None:
    payload = {"email": "dup@example.com", "password": "secret1"}
    assert client.post("/auth/register", json=payload).status_code == 201
    assert client.post("/auth/register", json=payload).status_code == 409


def test_vehicle_crud(client: TestClient) -> None:
    headers = auth_headers(client)
    created = client.post(
        "/vehicles",
        json={"name": "Golf", "make": "VW", "model": "Golf", "year": 2018, "fuel_type": "Benzyna"},
        headers=headers,
    )
    assert created.status_code == 201
    vehicle_id = created.json()["id"]
    listed = client.get("/vehicles", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    updated = client.put(f"/vehicles/{vehicle_id}", json={"name": "Golf 7"}, headers=headers)
    assert updated.json()["name"] == "Golf 7"
    with_tank = client.post(
        "/vehicles",
        json={"name": "Passat", "make": "VW", "tank_capacity_liters": 66, "fuel_type": "Diesel"},
        headers=headers,
    )
    assert with_tank.status_code == 201
    assert with_tank.json()["tank_capacity_liters"] == 66
    deleted = client.delete(f"/vehicles/{vehicle_id}", headers=headers)
    assert deleted.status_code == 204


def test_fuel_and_stats(client: TestClient) -> None:
    headers = auth_headers(client)
    vehicle_id = client.post("/vehicles", json={"name": "Octavia"}, headers=headers).json()["id"]
    first = client.post(
        f"/vehicles/{vehicle_id}/fuel-entries",
        json={
            "filled_at": "2026-09-01",
            "odometer_km": 100000,
            "liters": 40,
            "total_cost": 240,
            "is_full_tank": True,
        },
        headers=headers,
    )
    second = client.post(
        f"/vehicles/{vehicle_id}/fuel-entries",
        json={
            "filled_at": "2026-09-10",
            "odometer_km": 100500,
            "liters": 35,
            "price_per_liter": 6,
            "is_full_tank": True,
            "location": "Orlen",
        },
        headers=headers,
    )
    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json()["location"] == "Orlen"
    assert second.json()["price_per_liter"] == 6
    stats = client.get(f"/vehicles/{vehicle_id}/stats", headers=headers).json()
    assert stats["fillup_count"] == 2
    assert stats["total_cost"] == 450
    assert stats["total_distance_km"] == 500
    assert stats["avg_consumption_l_per_100km"] == 7.0
    assert stats["cost_per_km"] == 0.9


def test_odometer_cannot_decrease(client: TestClient) -> None:
    headers = auth_headers(client)
    vehicle_id = client.post("/vehicles", json={"name": "Fabia"}, headers=headers).json()["id"]
    client.post(
        f"/vehicles/{vehicle_id}/fuel-entries",
        json={"filled_at": "2026-09-01", "odometer_km": 20000, "liters": 30, "total_cost": 180, "is_full_tank": True},
        headers=headers,
    )
    bad = client.post(
        f"/vehicles/{vehicle_id}/fuel-entries",
        json={"filled_at": "2026-09-02", "odometer_km": 19999, "liters": 20, "total_cost": 120, "is_full_tank": True},
        headers=headers,
    )
    assert bad.status_code == 400
