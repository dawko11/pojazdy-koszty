from app.services.stations import address_from_tags, parse_overpass_elements


def test_address_from_tags() -> None:
    assert address_from_tags({"name": "Orlen", "addr:street": "Długa", "addr:housenumber": "1", "addr:city": "Gdańsk"}) == (
        "Orlen, Długa 1, Gdańsk"
    )


def test_parse_overpass_elements() -> None:
    elements = [
        {"id": 1, "lat": 54.35, "lon": 18.65, "tags": {"name": "Orlen", "amenity": "fuel"}},
        {"id": 2, "center": {"lat": 54.36, "lon": 18.67}, "tags": {"brand": "BP"}},
    ]
    stations = parse_overpass_elements(elements, 54.352, 18.646)
    assert stations[0]["name"] == "Orlen"
    assert stations[0]["address"].startswith("Orlen")
    assert len(stations) == 2
    assert stations[0]["distance_km"] <= stations[1]["distance_km"]
