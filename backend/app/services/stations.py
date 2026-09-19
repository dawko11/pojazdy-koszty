from __future__ import annotations

import math

import httpx

OVERPASS_URL = "https://overpass-api.de/api/interpreter"


def address_from_tags(tags: dict[str, str]) -> str:
    name = tags.get("name") or tags.get("brand") or tags.get("operator") or "Stacja paliw"
    street = " ".join(part for part in [tags.get("addr:street"), tags.get("addr:housenumber")] if part)
    city = tags.get("addr:city") or tags.get("addr:town") or tags.get("addr:village")
    parts = [name]
    if street:
        parts.append(street)
    if city:
        parts.append(city)
    return ", ".join(parts)


def _distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def parse_overpass_elements(elements: list[dict], origin_lat: float, origin_lon: float) -> list[dict]:
    stations: list[dict] = []
    for element in elements:
        lat = element.get("lat")
        lon = element.get("lon")
        if lat is None or lon is None:
            center = element.get("center") or {}
            lat = center.get("lat")
            lon = center.get("lon")
        if lat is None or lon is None:
            continue
        tags = element.get("tags") or {}
        stations.append(
            {
                "id": str(element.get("id", "")),
                "name": tags.get("name") or tags.get("brand") or "Stacja paliw",
                "lat": float(lat),
                "lon": float(lon),
                "address": address_from_tags(tags),
                "distance_km": round(_distance_km(origin_lat, origin_lon, float(lat), float(lon)), 2),
            }
        )
    stations.sort(key=lambda item: item["distance_km"])
    return stations


def fetch_nearby_stations(lat: float, lon: float, radius_m: int = 5000) -> list[dict]:
    query = f"""
    [out:json][timeout:25];
    (
      node["amenity"="fuel"](around:{radius_m},{lat},{lon});
      way["amenity"="fuel"](around:{radius_m},{lat},{lon});
    );
    out center tags;
    """
    with httpx.Client(timeout=25.0, headers={"User-Agent": "pojazdy-koszty/1.0"}) as client:
        response = client.post(OVERPASS_URL, content=query)
        response.raise_for_status()
        payload = response.json()
    return parse_overpass_elements(payload.get("elements") or [], lat, lon)
