from datetime import date, datetime, time
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field, validator


class EventBase(BaseModel):
    title: str
    date: date
    start_time: time
    end_time: time
    location: str
    event_type: str
    notes: Optional[str] = None


class EventCreate(EventBase):
    pass


class EventRead(EventBase):
    id: int
    created_at: datetime
    time_range: str = Field(..., description="Formatted range for UI display")

    class Config:
        from_attributes = True


class EventUpdate(EventBase):
    pass


class SwapMode(str, Enum):
    swap = "swap"
    give_away = "give_away"


class SwapStatus(str, Enum):
    pending = "pending"
    retracted = "retracted"
    fulfilled = "fulfilled"


class SwapRequestBase(BaseModel):
    event_id: int
    mode: SwapMode
    desired_shift_type: str = Field(..., max_length=64)
    available_start_time: Optional[time] = None
    available_end_time: Optional[time] = None
    available_start_date: Optional[date] = None
    available_end_date: Optional[date] = None
    visible_to_all: bool = True
    share_with_staffing_pool: bool = False
    notes: Optional[str] = None

    @validator("available_end_date")
    def validate_date_range(cls, end, values):
        start = values.get("available_start_date")
        if end and start and end < start:
            raise ValueError("available_end_date must be after start date")
        return end


class SwapRequestCreate(SwapRequestBase):
    targeted_colleagues: List[str] = Field(default_factory=list)


class SwapRequestRead(SwapRequestBase):
    id: int
    status: SwapStatus
    created_at: datetime
    updated_at: datetime
    event: EventRead
    targeted_colleagues: List[str]

    class Config:
        from_attributes = True
