from datetime import datetime, time
from typing import List

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
)
from sqlalchemy.orm import Mapped, relationship

from .database import Base


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    date = Column(Date, nullable=False, index=True)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    location = Column(String(255), nullable=False)
    event_type = Column(String(64), nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def to_time_range(self) -> str:
        return f"{self._format_time(self.start_time)} – {self._format_time(self.end_time)}"

    @staticmethod
    def _format_time(value: time) -> str:
        hour = value.hour % 12 or 12
        period = "AM" if value.hour < 12 else "PM"
        return f"{hour}:{value.minute:02d} {period}"


class SwapRequest(Base):
    __tablename__ = "swap_requests"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id", ondelete="CASCADE"), nullable=False)
    mode = Column(String(16), nullable=False)
    desired_shift_type = Column(String(64), nullable=False)
    available_start_time = Column(Time, nullable=True)
    available_end_time = Column(Time, nullable=True)
    available_start_date = Column(Date, nullable=True)
    available_end_date = Column(Date, nullable=True)
    visible_to_all = Column(Boolean, nullable=False, default=True)
    share_with_staffing_pool = Column(Boolean, nullable=False, default=False)
    notes = Column(Text, nullable=True)
    status = Column(String(32), nullable=False, default="pending")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    event: Mapped[Event] = relationship("Event", backref="swap_requests")
    targets: Mapped[List["SwapTarget"]] = relationship(
        "SwapTarget", cascade="all, delete-orphan", back_populates="swap_request"
    )


class SwapTarget(Base):
    __tablename__ = "swap_targets"

    id = Column(Integer, primary_key=True, index=True)
    swap_request_id = Column(
        Integer, ForeignKey("swap_requests.id", ondelete="CASCADE"), nullable=False
    )
    colleague_name = Column(String(255), nullable=False)

    swap_request: Mapped[SwapRequest] = relationship(
        "SwapRequest", back_populates="targets"
    )


class Colleague(Base):
    __tablename__ = "colleagues"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    department = Column(String(255), nullable=False)
    facility = Column(String(255), nullable=False)
    role = Column(String(255), nullable=True)
    email = Column(String(255), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
