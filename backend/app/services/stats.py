from decimal import Decimal

from sqlalchemy.orm import Session

from app.models import FuelEntry


def _num(value) -> float:
    if isinstance(value, Decimal):
        return float(value)
    return float(value)


def compute_vehicle_stats(db: Session, vehicle_id: int) -> dict:
    entries = (
        db.query(FuelEntry)
        .filter(FuelEntry.vehicle_id == vehicle_id)
        .order_by(FuelEntry.odometer_km.asc(), FuelEntry.filled_at.asc())
        .all()
    )
    fillup_count = len(entries)
    total_cost = round(sum(_num(e.total_cost) for e in entries), 2)
    total_liters = round(sum(_num(e.liters) for e in entries), 2)
    if fillup_count < 2:
        return {
            "vehicle_id": vehicle_id,
            "fillup_count": fillup_count,
            "total_cost": total_cost,
            "total_liters": total_liters,
            "total_distance_km": 0,
            "avg_consumption_l_per_100km": None,
            "cost_per_km": None,
            "avg_price_per_liter": round(total_cost / total_liters, 3) if total_liters else None,
        }

    total_distance_km = entries[-1].odometer_km - entries[0].odometer_km
    segments: list[tuple[float, int]] = []
    previous_full: FuelEntry | None = None
    for entry in entries:
        if previous_full is not None and entry.is_full_tank:
            distance = entry.odometer_km - previous_full.odometer_km
            if distance > 0:
                segments.append((_num(entry.liters), distance))
        if entry.is_full_tank:
            previous_full = entry

    avg_consumption = None
    if segments:
        liters_sum = sum(liters for liters, _ in segments)
        km_sum = sum(km for _, km in segments)
        avg_consumption = round(liters_sum / km_sum * 100, 2)

    cost_per_km = round(total_cost / total_distance_km, 3) if total_distance_km > 0 else None
    avg_price = round(total_cost / total_liters, 3) if total_liters else None

    return {
        "vehicle_id": vehicle_id,
        "fillup_count": fillup_count,
        "total_cost": total_cost,
        "total_liters": total_liters,
        "total_distance_km": total_distance_km,
        "avg_consumption_l_per_100km": avg_consumption,
        "cost_per_km": cost_per_km,
        "avg_price_per_liter": avg_price,
    }
