from fastapi import APIRouter, Depends, HTTPException, Query

from app.deps import get_current_user
from app.models import User
from app.services.stations import fetch_nearby_stations

router = APIRouter(prefix="/stations", tags=["stations"])


@router.get("/nearby")
def nearby_stations(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius_m: int = Query(5000, ge=200, le=15000),
    user: User = Depends(get_current_user),
) -> dict:
    _ = user
    try:
        stations = fetch_nearby_stations(lat, lon, radius_m)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Nie udało się pobrać stacji OSM: {exc}") from exc
    return {"stations": stations}
