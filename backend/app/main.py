from datetime import date
from typing import List, Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from . import crud, models, schemas
from .database import Base, engine, get_db

Base.metadata.create_all(bind=engine)

app = FastAPI(title="NurseShift Calendar API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/events", response_model=List[schemas.EventRead])
def list_events(
    *,
    db: Session = Depends(get_db),
    start_date: date = Query(..., description="YYYY-MM-DD"),
    end_date: date = Query(..., description="YYYY-MM-DD"),
):
    events = crud.list_events(db, start_date=start_date, end_date=end_date)
    return [_to_read_schema(event) for event in events]


@app.post("/events", response_model=schemas.EventRead, status_code=201)
def create_event(*, db: Session = Depends(get_db), payload: schemas.EventCreate):
    event = crud.create_event(db, payload)
    return _to_read_schema(event)


@app.put("/events/{event_id}", response_model=schemas.EventRead)
def update_event(
    event_id: int, *, db: Session = Depends(get_db), payload: schemas.EventUpdate
):
    event = crud.update_event(db, event_id, payload)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return _to_read_schema(event)


@app.delete("/events/{event_id}", status_code=204)
def delete_event(event_id: int, db: Session = Depends(get_db)):
    deleted = crud.delete_event(db, event_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Event not found")


@app.get("/events/{event_id}", response_model=schemas.EventRead)
def get_event(event_id: int, db: Session = Depends(get_db)):
    event = crud.get_event(db, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return _to_read_schema(event)


@app.get("/swap-requests", response_model=List[schemas.SwapRequestRead])
def list_swap_requests(
    *,
    db: Session = Depends(get_db),
    start_date: Optional[date] = Query(
        None, description="Filter requests linked to events on/after this date"
    ),
    end_date: Optional[date] = Query(
        None, description="Filter requests linked to events on/before this date"
    ),
    status: Optional[schemas.SwapStatus] = Query(
        schemas.SwapStatus.pending, description="Status filter"
    ),
):
    requests = crud.list_swap_requests(
        db,
        start_date=start_date,
        end_date=end_date,
        status=status.value if status else None,
    )
    return [_swap_to_read_schema(item) for item in requests]


@app.post(
    "/swap-requests",
    response_model=schemas.SwapRequestRead,
    status_code=201,
)
def create_swap_request(
    *, db: Session = Depends(get_db), payload: schemas.SwapRequestCreate
):
    try:
        swap_request = crud.create_swap_request(db, payload)
    except ValueError as error:
        if str(error) == "EVENT_NOT_FOUND":
            raise HTTPException(status_code=404, detail="Event not found") from error
        raise
    return _swap_to_read_schema(swap_request)


@app.get("/swap-requests/{request_id}", response_model=schemas.SwapRequestRead)
def get_swap_request(request_id: int, db: Session = Depends(get_db)):
    swap_request = crud.get_swap_request(db, request_id)
    if not swap_request:
        raise HTTPException(status_code=404, detail="Swap request not found")
    return _swap_to_read_schema(swap_request)


@app.post("/swap-requests/{request_id}/retract", response_model=schemas.SwapRequestRead)
def retract_swap_request(request_id: int, db: Session = Depends(get_db)):
    swap_request = crud.retract_swap_request(db, request_id)
    if not swap_request:
        raise HTTPException(status_code=404, detail="Swap request not found")
    return _swap_to_read_schema(swap_request)


@app.get("/colleagues", response_model=List[schemas.ColleagueRead])
def list_colleagues(db: Session = Depends(get_db)):
    colleagues = crud.list_colleagues(db)
    return [schemas.ColleagueRead.model_validate(colleague) for colleague in colleagues]


@app.post("/colleagues", response_model=schemas.ColleagueRead, status_code=201)
def create_colleague(
    *, db: Session = Depends(get_db), payload: schemas.ColleagueCreate
):
    colleague = crud.create_colleague(db, payload)
    return schemas.ColleagueRead.model_validate(colleague)


def _to_read_schema(event: models.Event) -> schemas.EventRead:
    return schemas.EventRead(
        id=event.id,
        title=event.title,
        date=event.date,
        start_time=event.start_time,
        end_time=event.end_time,
        location=event.location,
        event_type=event.event_type,
        notes=event.notes,
        created_at=event.created_at,
        time_range=event.to_time_range(),
    )


def _swap_to_read_schema(event: models.SwapRequest) -> schemas.SwapRequestRead:
    return schemas.SwapRequestRead(
        id=event.id,
        event_id=event.event_id,
        mode=schemas.SwapMode(event.mode),
        desired_shift_type=event.desired_shift_type,
        available_start_time=event.available_start_time,
        available_end_time=event.available_end_time,
        available_start_date=event.available_start_date,
        available_end_date=event.available_end_date,
        visible_to_all=event.visible_to_all,
        share_with_staffing_pool=event.share_with_staffing_pool,
        notes=event.notes,
        targeted_colleagues=[target.colleague_name for target in event.targets],
        status=schemas.SwapStatus(event.status),
        created_at=event.created_at,
        updated_at=event.updated_at,
        event=_to_read_schema(event.event),
    )
