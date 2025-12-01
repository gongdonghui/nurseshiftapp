from datetime import date
from typing import List, Optional

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from . import models, schemas


def create_event(db: Session, event_in: schemas.EventCreate) -> models.Event:
    event = models.Event(**event_in.model_dump())
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def get_event(db: Session, event_id: int) -> Optional[models.Event]:
    return db.get(models.Event, event_id)


def list_events(
    db: Session, *, start_date: date, end_date: date
) -> List[models.Event]:
    stmt = (
        select(models.Event)
        .where(models.Event.date >= start_date)
        .where(models.Event.date <= end_date)
        .order_by(models.Event.date.asc(), models.Event.start_time.asc())
    )
    return list(db.scalars(stmt).all())


def update_event(
    db: Session, event_id: int, payload: schemas.EventUpdate
) -> Optional[models.Event]:
    event = get_event(db, event_id)
    if not event:
        return None
    for key, value in payload.model_dump().items():
        setattr(event, key, value)
    db.commit()
    db.refresh(event)
    return event


def delete_event(db: Session, event_id: int) -> bool:
    event = get_event(db, event_id)
    if not event:
        return False
    db.delete(event)
    db.commit()
    return True


def create_swap_request(
    db: Session, payload: schemas.SwapRequestCreate
) -> models.SwapRequest:
    event = get_event(db, payload.event_id)
    if not event:
        raise ValueError("EVENT_NOT_FOUND")
    swap_request = models.SwapRequest(
        event_id=payload.event_id,
        mode=payload.mode.value,
        desired_shift_type=payload.desired_shift_type,
        available_start_time=payload.available_start_time,
        available_end_time=payload.available_end_time,
        available_start_date=payload.available_start_date,
        available_end_date=payload.available_end_date,
        visible_to_all=payload.visible_to_all,
        share_with_staffing_pool=payload.share_with_staffing_pool,
        notes=payload.notes,
    )
    for colleague in payload.targeted_colleagues:
        swap_request.targets.append(models.SwapTarget(colleague_name=colleague))
    db.add(swap_request)
    db.commit()
    db.refresh(swap_request)
    return swap_request


def list_swap_requests(
    db: Session,
    *,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    status: Optional[str] = None,
) -> List[models.SwapRequest]:
    stmt = select(models.SwapRequest).join(models.Event)
    if start_date:
        stmt = stmt.where(models.Event.date >= start_date)
    if end_date:
        stmt = stmt.where(models.Event.date <= end_date)
    if status:
        stmt = stmt.where(models.SwapRequest.status == status)
    stmt = stmt.order_by(
        models.Event.date.asc(), models.Event.start_time.asc(), models.SwapRequest.id.asc()
    )
    return list(db.scalars(stmt).unique().all())


def get_swap_request(db: Session, request_id: int) -> Optional[models.SwapRequest]:
    return db.get(models.SwapRequest, request_id)


def retract_swap_request(db: Session, request_id: int) -> Optional[models.SwapRequest]:
    swap = get_swap_request(db, request_id)
    if not swap:
        return None
    if swap.status != schemas.SwapStatus.pending.value:
        return swap
    stmt = (
        update(models.SwapRequest)
        .where(models.SwapRequest.id == request_id)
        .values(status=schemas.SwapStatus.retracted.value)
        .execution_options(synchronize_session="fetch")
    )
    db.execute(stmt)
    db.commit()
    db.refresh(swap)
    return swap
