from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import User, Vehicle
from app.schemas import VehicleCreate, VehicleOut, VehicleUpdate

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


def _owned_vehicle(db: Session, user: User, vehicle_id: int) -> Vehicle:
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None or vehicle.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pojazd nie istnieje")
    return vehicle


@router.get("", response_model=list[VehicleOut])
def list_vehicles(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Vehicle]:
    return db.query(Vehicle).filter(Vehicle.user_id == user.id).order_by(Vehicle.created_at.desc()).all()


@router.post("", response_model=VehicleOut, status_code=status.HTTP_201_CREATED)
def create_vehicle(
    payload: VehicleCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Vehicle:
    vehicle = Vehicle(user_id=user.id, **payload.model_dump())
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(
    vehicle_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Vehicle:
    return _owned_vehicle(db, user, vehicle_id)


@router.put("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    vehicle_id: int,
    payload: VehicleUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Vehicle:
    vehicle = _owned_vehicle(db, user, vehicle_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(vehicle, key, value)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_vehicle(
    vehicle_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    vehicle = _owned_vehicle(db, user, vehicle_id)
    db.delete(vehicle)
    db.commit()
