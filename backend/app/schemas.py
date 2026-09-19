from datetime import date, datetime
from typing import Annotated, Self

from pydantic import AfterValidator, BaseModel, Field, model_validator
_FUEL_CANONICAL = {
    "benzyna": "Benzyna",
    "diesel": "Diesel",
    "benzyna+lpg": "Benzyna+LPG",
    "hybryda": "Hybryda",
}


def _normalize_fuel_type(value: str) -> str:
    mapped = _FUEL_CANONICAL.get(value.strip().lower())
    if mapped is None:
        raise ValueError("Nieobsługiwany rodzaj paliwa")
    return mapped


NormalizedFuelType = Annotated[str, AfterValidator(_normalize_fuel_type)]


class UserCreate(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6, max_length=128)


class UserLogin(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: int
    email: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class VehicleCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    make: str | None = Field(default=None, max_length=80)
    model: str | None = Field(default=None, max_length=80)
    year: int | None = Field(default=None, ge=1950, le=2100)
    fuel_type: NormalizedFuelType = "Benzyna"
    tank_capacity_liters: float | None = Field(default=None, gt=0, le=500)


class VehicleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    make: str | None = Field(default=None, max_length=80)
    model: str | None = Field(default=None, max_length=80)
    year: int | None = Field(default=None, ge=1950, le=2100)
    fuel_type: NormalizedFuelType | None = None
    tank_capacity_liters: float | None = Field(default=None, gt=0, le=500)


class VehicleOut(BaseModel):
    id: int
    name: str
    make: str | None
    model: str | None
    year: int | None
    fuel_type: str
    tank_capacity_liters: float | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class FuelEntryCreate(BaseModel):
    filled_at: date
    odometer_km: int = Field(ge=0)
    liters: float = Field(gt=0)
    price_per_liter: float | None = Field(default=None, gt=0)
    total_cost: float | None = Field(default=None, gt=0)
    is_full_tank: bool = True
    location: str | None = Field(default=None, max_length=255)
    station: str | None = Field(default=None, max_length=255)
    note: str | None = Field(default=None, max_length=255)

    @model_validator(mode="after")
    def fill_cost_and_location(self) -> Self:
        self.location = self.location or self.station
        if self.price_per_liter is None and self.total_cost is None:
            raise ValueError("Podaj cenę za litr albo koszt całkowity")
        if self.price_per_liter is None and self.total_cost is not None:
            self.price_per_liter = round(self.total_cost / self.liters, 3)
        if self.total_cost is None and self.price_per_liter is not None:
            self.total_cost = round(self.liters * self.price_per_liter, 2)
        return self


class FuelEntryUpdate(BaseModel):
    filled_at: date | None = None
    odometer_km: int | None = Field(default=None, ge=0)
    liters: float | None = Field(default=None, gt=0)
    price_per_liter: float | None = Field(default=None, gt=0)
    total_cost: float | None = Field(default=None, gt=0)
    is_full_tank: bool | None = None
    location: str | None = Field(default=None, max_length=255)
    station: str | None = Field(default=None, max_length=255)
    note: str | None = Field(default=None, max_length=255)


class FuelEntryOut(BaseModel):
    id: int
    vehicle_id: int
    filled_at: date
    odometer_km: int
    liters: float
    price_per_liter: float
    total_cost: float
    is_full_tank: bool
    location: str | None
    station: str | None
    note: str | None

    model_config = {"from_attributes": True}


class VehicleStatsOut(BaseModel):
    vehicle_id: int
    fillup_count: int
    total_cost: float
    total_liters: float
    total_distance_km: int
    avg_consumption_l_per_100km: float | None
    cost_per_km: float | None
    avg_price_per_liter: float | None
