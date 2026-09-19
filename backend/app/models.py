from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    vehicles: Mapped[list["Vehicle"]] = relationship(back_populates="owner", cascade="all, delete-orphan")


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    make: Mapped[str | None] = mapped_column(String(80), nullable=True)
    model: Mapped[str | None] = mapped_column(String(80), nullable=True)
    year: Mapped[int | None] = mapped_column(nullable=True)
    fuel_type: Mapped[str] = mapped_column(String(40), default="Benzyna")
    tank_capacity_liters: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    owner: Mapped[User] = relationship(back_populates="vehicles")
    fuel_entries: Mapped[list["FuelEntry"]] = relationship(
        back_populates="vehicle", cascade="all, delete-orphan", order_by="FuelEntry.odometer_km"
    )


class FuelEntry(Base):
    __tablename__ = "fuel_entries"
    __table_args__ = (UniqueConstraint("vehicle_id", "odometer_km", name="uq_vehicle_odometer"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    vehicle_id: Mapped[int] = mapped_column(ForeignKey("vehicles.id", ondelete="CASCADE"), index=True)
    filled_at: Mapped[date] = mapped_column(Date)
    odometer_km: Mapped[int]
    liters: Mapped[float] = mapped_column(Numeric(10, 2))
    price_per_liter: Mapped[float | None] = mapped_column(Numeric(10, 3), nullable=True)
    total_cost: Mapped[float] = mapped_column(Numeric(10, 2))
    is_full_tank: Mapped[bool] = mapped_column(Boolean, default=True)
    station: Mapped[str | None] = mapped_column(String(255), nullable=True)
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    vehicle: Mapped[Vehicle] = relationship(back_populates="fuel_entries")
