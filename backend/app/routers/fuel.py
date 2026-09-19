from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import FuelEntry, User, Vehicle
from app.schemas import FuelEntryCreate, FuelEntryOut, FuelEntryUpdate, VehicleStatsOut
from app.services.stats import compute_vehicle_stats

router = APIRouter(tags=["fuel"])


def _owned_vehicle(db: Session, user: User, vehicle_id: int) -> Vehicle:
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None or vehicle.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pojazd nie istnieje")
    return vehicle


def _to_out(entry: FuelEntry) -> FuelEntryOut:
    liters = float(entry.liters)
    cost = float(entry.total_cost)
    stored_price = float(entry.price_per_liter) if entry.price_per_liter is not None else None
    price = stored_price if stored_price else (round(cost / liters, 3) if liters else 0)
    location = entry.station
    return FuelEntryOut(
        id=entry.id,
        vehicle_id=entry.vehicle_id,
        filled_at=entry.filled_at,
        odometer_km=entry.odometer_km,
        liters=liters,
        price_per_liter=price,
        total_cost=cost,
        is_full_tank=entry.is_full_tank,
        location=location,
        station=location,
        note=entry.note,
    )


@router.get("/vehicles/{vehicle_id}/fuel-entries", response_model=list[FuelEntryOut])
def list_fuel_entries(
    vehicle_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[FuelEntryOut]:
    _owned_vehicle(db, user, vehicle_id)
    entries = (
        db.query(FuelEntry)
        .filter(FuelEntry.vehicle_id == vehicle_id)
        .order_by(FuelEntry.filled_at.desc(), FuelEntry.odometer_km.desc())
        .all()
    )
    return [_to_out(e) for e in entries]


@router.post(
    "/vehicles/{vehicle_id}/fuel-entries",
    response_model=FuelEntryOut,
    status_code=status.HTTP_201_CREATED,
)
def create_fuel_entry(
    vehicle_id: int,
    payload: FuelEntryCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FuelEntryOut:
    _owned_vehicle(db, user, vehicle_id)
    last = (
        db.query(FuelEntry)
        .filter(FuelEntry.vehicle_id == vehicle_id)
        .order_by(FuelEntry.odometer_km.desc())
        .first()
    )
    if last and payload.odometer_km < last.odometer_km:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Licznik nie może być mniejszy niż przy poprzednim tankowaniu",
        )
    location = payload.location or payload.station
    entry = FuelEntry(
        vehicle_id=vehicle_id,
        filled_at=payload.filled_at,
        odometer_km=payload.odometer_km,
        liters=Decimal(str(payload.liters)),
        price_per_liter=Decimal(str(payload.price_per_liter)) if payload.price_per_liter is not None else None,
        total_cost=Decimal(str(payload.total_cost)),
        is_full_tank=payload.is_full_tank,
        station=location,
        note=payload.note,
    )
    db.add(entry)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Tankowanie z tym licznikiem już istnieje")
    db.refresh(entry)
    return _to_out(entry)


@router.put("/fuel-entries/{entry_id}", response_model=FuelEntryOut)
def update_fuel_entry(
    entry_id: int,
    payload: FuelEntryUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FuelEntryOut:
    entry = db.get(FuelEntry, entry_id)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tankowanie nie istnieje")
    _owned_vehicle(db, user, entry.vehicle_id)
    data = payload.model_dump(exclude_unset=True)
    if "location" in data:
        data["station"] = data.pop("location") or data.get("station")
    if "liters" in data:
        data["liters"] = Decimal(str(data["liters"]))
    if "total_cost" in data:
        data["total_cost"] = Decimal(str(data["total_cost"]))
    if "price_per_liter" in data and data["price_per_liter"] is not None:
        data["price_per_liter"] = Decimal(str(data["price_per_liter"]))
    for key, value in data.items():
        setattr(entry, key, value)
    db.commit()
    db.refresh(entry)
    return _to_out(entry)


@router.delete("/fuel-entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_fuel_entry(
    entry_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    entry = db.get(FuelEntry, entry_id)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tankowanie nie istnieje")
    _owned_vehicle(db, user, entry.vehicle_id)
    db.delete(entry)
    db.commit()


@router.get("/vehicles/{vehicle_id}/stats", response_model=VehicleStatsOut)
def vehicle_stats(
    vehicle_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> VehicleStatsOut:
    _owned_vehicle(db, user, vehicle_id)
    return VehicleStatsOut.model_validate(compute_vehicle_stats(db, vehicle_id))
