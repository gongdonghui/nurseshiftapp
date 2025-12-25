import html
import logging
import os
from datetime import date, time, timedelta
from typing import List, Optional
import secrets
from urllib.parse import urljoin

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy import text, func
from sqlalchemy.orm import Session

from . import crud, models, schemas
from .database import Base, engine, get_db, SessionLocal

logger = logging.getLogger(__name__)

Base.metadata.create_all(bind=engine)

def _apply_schema_patches():
    with engine.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE colleagues "
                "ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'invited'"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE colleagues "
                "ADD COLUMN IF NOT EXISTS invitation_message TEXT"
            )
        )
        connection.execute(
            text(
                "UPDATE colleagues SET status='invited' "
                "WHERE status IS NULL"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE groups "
                "ADD COLUMN IF NOT EXISTS shared_calendar TEXT NOT NULL DEFAULT '[]'"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE events "
                "ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE swap_requests "
                "ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE swap_requests "
                "ADD COLUMN IF NOT EXISTS accepted_by_user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE swap_requests "
                "ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE colleagues "
                "ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE swap_targets "
                "ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS swap_request_responses ("
                "id SERIAL PRIMARY KEY,"
                "swap_request_id INTEGER NOT NULL REFERENCES swap_requests(id) ON DELETE CASCADE,"
                "user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,"
                "status VARCHAR(32) NOT NULL,"
                "created_at TIMESTAMP NOT NULL DEFAULT NOW(),"
                "UNIQUE (swap_request_id, user_id)"
                ")"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS primary_hospital VARCHAR(255)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS primary_department VARCHAR(255)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS primary_position VARCHAR(255)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(512)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE users "
                "ALTER COLUMN avatar_url TYPE TEXT"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS group_memberships ("
                "id SERIAL PRIMARY KEY,"
                "group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,"
                "user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,"
                "joined_at TIMESTAMP NOT NULL DEFAULT NOW()"
                ")"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS group_shares ("
                "id SERIAL PRIMARY KEY,"
                "membership_id INTEGER UNIQUE NOT NULL REFERENCES group_memberships(id) ON DELETE CASCADE,"
                "start_date DATE NOT NULL,"
                "end_date DATE NOT NULL,"
                "created_at TIMESTAMP NOT NULL DEFAULT NOW(),"
                "updated_at TIMESTAMP NOT NULL DEFAULT NOW()"
                ")"
            )
        )
        connection.execute(
            text("ALTER TABLE group_shares DROP COLUMN IF EXISTS entries")
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS worksites ("
                "id SERIAL PRIMARY KEY,"
                "user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,"
                "hospital_name VARCHAR(255) NOT NULL,"
                "department_name VARCHAR(255) NOT NULL,"
                "position_name VARCHAR(255) NOT NULL,"
                "created_at TIMESTAMP NOT NULL DEFAULT NOW(),"
                "updated_at TIMESTAMP NOT NULL DEFAULT NOW()"
                ")"
            )
        )
        connection.execute(
            text(
                "DELETE FROM worksites a USING worksites b "
                "WHERE a.user_id = b.user_id AND a.id < b.id"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_worksites_user_id "
                "ON worksites(user_id)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE group_invites "
                "ADD COLUMN IF NOT EXISTS invitee_email VARCHAR(255)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE group_invites "
                "ADD COLUMN IF NOT EXISTS token VARCHAR(128)"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE group_invites "
                "ADD COLUMN IF NOT EXISTS invitee_user_id INTEGER REFERENCES users(id)"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS group_invite_links ("
                "id SERIAL PRIMARY KEY,"
                "group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,"
                "token_hash VARCHAR(128) NOT NULL UNIQUE,"
                "role VARCHAR(32) NOT NULL DEFAULT 'member',"
                "expires_at TIMESTAMP NOT NULL,"
                "max_uses INTEGER NOT NULL DEFAULT 1,"
                "use_count INTEGER NOT NULL DEFAULT 0,"
                "revoked_at TIMESTAMP NULL,"
                "created_at TIMESTAMP NOT NULL DEFAULT NOW()"
                ")"
            )
        )


_apply_schema_patches()


def _ensure_invite_tokens():
    session = SessionLocal()
    try:
        invites = (
            session.query(models.GroupInvite)
            .filter(
                (models.GroupInvite.token.is_(None))
                | (models.GroupInvite.token == "")
            )
            .all()
        )
        for invite in invites:
            invite.token = secrets.token_urlsafe(20)
        email_linked = (
            session.query(models.GroupInvite)
            .filter(models.GroupInvite.invitee_email.is_not(None))
            .filter(models.GroupInvite.invitee_user_id.is_(None))
            .all()
        )
        for invite in email_linked:
            email = invite.invitee_email.lower()
            user = (
                session.query(models.User)
                .filter(func.lower(models.User.email) == email)
                .first()
            )
            if user:
                invite.invitee_user_id = user.id
        session.commit()
    finally:
        session.close()


_ensure_invite_tokens()
INVITE_BASE_URL = os.getenv("INVITE_BASE_URL", "https://api.art168.cn")
INVITE_DEEP_LINK = os.getenv("INVITE_DEEP_LINK", "nurseshift://group-invite")
APP_DOWNLOAD_URL = os.getenv(
    "APP_DOWNLOAD_URL", "https://nurseshift.app/download"
)
INVITE_LINK_BASE_URL = os.getenv("INVITE_LINK_BASE_URL", INVITE_BASE_URL)


def _build_deep_link(token: str) -> str:
    separator = "&" if "?" in INVITE_DEEP_LINK else "?"
    return f"{INVITE_DEEP_LINK}{separator}token={token}"


def _ensure_default_user():
    with SessionLocal() as db:
        user = crud.get_user_by_email(db, "jamie@nurseshift.app")
        if not user:
            user = crud.create_user(
                db,
                schemas.UserCreate(
                    name="Jamie Ortega",
                    email="jamie@nurseshift.app",
                    password="password123",
                ),
            )
        db.execute(
            text(
                "UPDATE events SET user_id=:uid "
                "WHERE user_id IS NULL"
            ),
            {"uid": user.id},
        )
        db.execute(
            text(
                "UPDATE swap_requests SET user_id=:uid "
                "WHERE user_id IS NULL"
            ),
            {"uid": user.id},
        )
        db.execute(
            text(
                "UPDATE colleagues SET user_id=:uid "
                "WHERE user_id IS NULL"
            ),
            {"uid": user.id},
        )
        existing_groups = db.query(models.Group).all()
        for group in existing_groups:
            membership = (
                db.query(models.GroupMembership)
                .filter(
                    models.GroupMembership.group_id == group.id,
                    models.GroupMembership.user_id == user.id,
                )
                .first()
            )
            if not membership:
                db.add(
                    models.GroupMembership(group_id=group.id, user_id=user.id)
                )
        db.commit()


def _ensure_seed_users():
    seed_accounts = [
        ("Jamie Ortega", "jamie@nurseshift.app"),
        ("Reese Patel", "reese@nurseshift.app"),
        ("Morgan Wills", "morgan@nurseshift.app"),
        ("Avery Chen", "avery@nurseshift.app"),
    ]
    with SessionLocal() as db:
        for name, email in seed_accounts:
            if crud.get_user_by_email(db, email):
                continue
            crud.create_user(
                db,
                schemas.UserCreate(
                    name=name,
                    email=email,
                    password="password123",
                ),
            )


_ensure_default_user()
_ensure_seed_users()


def _seed_groups():
    with SessionLocal() as db:
        if db.query(models.Group).count():
            return
        base_start = date(2025, 11, 10)
        sample_users = [
            ("Jamie Ortega", "jamie@nurseshift.app", ["Day", "Day", "Off", "Evening", "Night", "Off", "Off"], "regular"),
            ("Reese Patel", "reese@nurseshift.app", ["Night", "Night", "Night", "Off", "Off", "Day", "Day"], "night_shift"),
            ("Morgan Wills", "morgan@nurseshift.app", ["Evening", "Evening", "Day", "Day", "Off", "Off", "Night"], "evening"),
            ("Avery Chen", "avery@nurseshift.app", ["Charge", "Charge", "Day", "Off", "Evening", "Off", "Off"], "charge"),
        ]
        group = models.Group(
            name="Surgical Services",
            description="Shared calendar for 7S team swaps.",
            invite_message="Join our Surgical Services group on NurseShift so we can trade shifts faster.",
            shared_calendar="[]",
        )
        group.invites = [
            models.GroupInvite(invitee_name="Zoe Garside"),
            models.GroupInvite(invitee_name="Imani Owens"),
        ]
        db.add(group)
        db.commit()
        for name, email, labels, icon in sample_users:
            user = crud.get_user_by_email(db, email)
            if not user:
                user = crud.create_user(
                    db,
                    schemas.UserCreate(
                        name=name,
                        email=email,
                        password="password123",
                    ),
                )
            membership = models.GroupMembership(group_id=group.id, user_id=user.id)
            db.add(membership)
            db.flush()
            share = models.GroupShare(
                membership_id=membership.id,
                start_date=base_start,
                end_date=base_start + timedelta(days=len(labels) - 1),
            )
            db.add(share)
            for index, label in enumerate(labels):
                event = models.Event(
                    title=f"{label} Shift",
                    date=base_start + timedelta(days=index),
                    start_time=time(7, 0),
                    end_time=time(19, 0),
                    location="F.W. Huston Medical Center",
                    event_type=icon,
                    notes=None,
                    user_id=user.id,
                )
                db.add(event)
        db.commit()


_seed_groups()

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


@app.get("/legal/privacy", response_class=HTMLResponse)
def privacy_policy():
    content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>NurseShift Privacy Policy</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding: 24px; color: #0a1f33; }
    h1 { margin-top: 0; }
    h2 { margin-top: 24px; }
    p, li { line-height: 1.6; color: #41526b; }
  </style>
</head>
<body>
  <h1>Privacy Policy (North America)</h1>
  <p>Effective date: 2025-01-01</p>
  <p>This Privacy Policy describes how NurseShift collects, uses, and shares information when you use the NurseShift app and services in the United States and Canada.</p>
  <h2>Information we collect</h2>
  <ul>
    <li>Account details such as name, email address, and password.</li>
    <li>Scheduling data you add to the app, including shift details.</li>
    <li>Usage data and device identifiers for analytics and troubleshooting.</li>
  </ul>
  <h2>How we use information</h2>
  <ul>
    <li>Provide the app features, including group sharing and swap requests.</li>
    <li>Maintain account security and authenticate users.</li>
    <li>Improve reliability and user experience.</li>
  </ul>
  <h2>Sharing</h2>
  <p>We share your data only with other users you choose to share with, service providers that help operate the app, or when required by law.</p>
  <h2>Your choices</h2>
  <p>You can update or delete your account information by contacting support.</p>
  <h2>Contact</h2>
  <p>Email: support@nurseshift.app</p>
</body>
</html>"""
    return HTMLResponse(content=content)


@app.get("/legal/disclaimer", response_class=HTMLResponse)
def disclaimer():
    content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>NurseShift Disclaimer</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding: 24px; color: #0a1f33; }
    h1 { margin-top: 0; }
    p, li { line-height: 1.6; color: #41526b; }
  </style>
</head>
<body>
  <h1>Disclaimer (North America)</h1>
  <p>Effective date: 2025-01-01</p>
  <p>NurseShift is provided “as is” for schedule coordination only. It does not provide medical, legal, or employment advice. Always follow your employer’s policies and clinical protocols.</p>
  <p>We are not responsible for missed shifts, staffing decisions, or employment outcomes resulting from app usage.</p>
</body>
</html>"""
    return HTMLResponse(content=content)


@app.get("/events", response_model=List[schemas.EventRead])
def list_events(
    *,
    db: Session = Depends(get_db),
    start_date: date = Query(..., description="YYYY-MM-DD"),
    end_date: date = Query(..., description="YYYY-MM-DD"),
    user_id: Optional[int] = Query(
        None, description="Filter events by owner (optional)"
    ),
):
    logger.info(
        "Listing events start=%s end=%s user_id=%s", start_date, end_date, user_id
    )
    events = crud.list_events(
        db,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
    )
    return [_to_read_schema(event) for event in events]


@app.post("/events", response_model=schemas.EventRead, status_code=201)
def create_event(*, db: Session = Depends(get_db), payload: schemas.EventCreate):
    try:
        event = crud.create_event(db, payload)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    logger.info("Created event %s for user %s", event.id, event.user_id)
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
    user_id: Optional[int] = Query(
        None, description="Limit results to the specified user id"
    ),
):
    requests = crud.list_swap_requests(
        db,
        start_date=start_date,
        end_date=end_date,
        status=status.value if status else None,
        user_id=user_id,
    )
    return [_swap_to_read_schema(item) for item in requests]


@app.get(
    "/inbox/swap-requests",
    response_model=List[schemas.SwapRequestRead],
)
def list_inbox_swap_requests(user_id: int, db: Session = Depends(get_db)):
    requests = crud.list_inbox_swap_requests(db, user_id)
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
    if swap_request.status != schemas.SwapStatus.pending.value:
        raise HTTPException(status_code=400, detail="Swap request already accepted")
    return _swap_to_read_schema(swap_request)


@app.post(
    "/swap-requests/{request_id}/accept",
    response_model=schemas.SwapRequestRead,
)
def accept_swap_request(
    request_id: int,
    payload: schemas.SwapDecision,
    db: Session = Depends(get_db),
):
    try:
        swap_request = crud.accept_swap_request_for_user(
            db, request_id=request_id, user_id=payload.user_id
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    if not swap_request:
        raise HTTPException(status_code=404, detail="Swap request not found")
    return _swap_to_read_schema(swap_request)


@app.post(
    "/swap-requests/{request_id}/decline",
    response_model=schemas.SwapRequestRead,
)
def decline_swap_request(
    request_id: int,
    payload: schemas.SwapDecision,
    db: Session = Depends(get_db),
):
    try:
        swap_request = crud.decline_swap_request_for_user(
            db, request_id=request_id, user_id=payload.user_id
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
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


@app.post("/colleagues/{colleague_id}/accept", response_model=schemas.ColleagueRead)
def accept_colleague(colleague_id: int, db: Session = Depends(get_db)):
    colleague = crud.accept_colleague(db, colleague_id)
    if not colleague:
        raise HTTPException(status_code=404, detail="Colleague not found")
    return schemas.ColleagueRead.model_validate(colleague)


@app.get("/worksites", response_model=List[schemas.WorksiteRead])
def list_worksites(
    *,
    db: Session = Depends(get_db),
    user_id: int = Query(..., description="Owner user id"),
):
    worksites = crud.list_worksites(db, user_id=user_id)
    return [
        schemas.WorksiteRead.model_validate(worksite) for worksite in worksites
    ]


@app.post("/worksites", response_model=schemas.WorksiteRead, status_code=201)
def create_worksite(
    *,
    db: Session = Depends(get_db),
    payload: schemas.WorksiteCreate,
):
    try:
        worksite = crud.create_worksite(db, payload)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    return schemas.WorksiteRead.model_validate(worksite)


@app.delete("/worksites/{worksite_id}", status_code=204)
def delete_worksite(worksite_id: int, db: Session = Depends(get_db)):
    deleted = crud.delete_worksite(db, worksite_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Worksite not found")


@app.post("/users/{user_id}/avatar", response_model=schemas.UserRead)
def update_avatar(
    user_id: int, payload: schemas.UserAvatarUpdate, db: Session = Depends(get_db)
):
    user = crud.update_user_avatar(db, user_id, payload.avatar_data)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return schemas.UserRead.model_validate(user)


@app.get("/group-shared", response_model=List[schemas.GroupRead])
def list_group_shared(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
):
    groups = crud.list_groups(db)
    results = [
        _group_to_read_schema(
            db=db,
            group=group,
            start_date=start_date,
            end_date=end_date,
        )
        for group in groups
    ]
    print(
        f"/group-shared returning {len(results)} groups "
        f"for range {start_date} to {end_date}"
    )
    return results


@app.post("/group-shared", response_model=schemas.GroupRead, status_code=201)
def create_group_shared(*, db: Session = Depends(get_db), payload: schemas.GroupCreate):
    group = crud.create_group(db, payload)
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/groups/{group_id}/invites",
    response_model=schemas.GroupInviteLinkCreateResponse,
    status_code=201,
)
def create_group_invite_link(
    group_id: int,
    *,
    db: Session = Depends(get_db),
    payload: schemas.GroupInviteLinkCreate,
):
    result = crud.create_group_invite_link(db, group_id, payload)
    if not result:
        raise HTTPException(status_code=404, detail="Group not found")
    invite, token = result
    base = INVITE_LINK_BASE_URL.rstrip("/")
    invite_url = f"{base}/ginv/{token}"
    response = schemas.GroupInviteLinkCreateResponse(
        invite_url=invite_url,
        token=token,
        expires_at=invite.expires_at,
    )
    return JSONResponse(
        status_code=201,
        content=jsonable_encoder(response.model_dump(by_alias=True)),
    )


@app.get(
    "/invites/{token}/preview",
    response_model=schemas.GroupInvitePreviewResponse,
)
def preview_invite_link(token: str, db: Session = Depends(get_db)):
    invite, reason = crud.get_invite_link_preview(db, token)
    if not invite:
        payload = schemas.GroupInvitePreviewResponse(valid=False, reason=reason)
        return JSONResponse(
            status_code=400,
            content=jsonable_encoder(payload.model_dump(by_alias=True)),
        )
    member_count = (
        db.query(models.GroupMembership)
        .filter(models.GroupMembership.group_id == invite.group_id)
        .count()
    )
    return schemas.GroupInvitePreviewResponse(
        valid=True,
        group=schemas.GroupInviteGroupSummary(
            id=str(invite.group.id),
            name=invite.group.name,
            member_count=member_count,
        ),
        expires_at=invite.expires_at,
        remaining_uses=max(invite.max_uses - invite.use_count, 0),
    )


@app.post(
    "/invites/{token}/redeem",
    response_model=schemas.GroupInviteRedeemResponse,
)
def redeem_invite_link(
    token: str,
    payload: schemas.GroupInviteRedeemRequest,
    db: Session = Depends(get_db),
):
    status, group_id, reason = crud.redeem_invite_link(
        db, token, payload.user_id
    )
    if not status:
        payload = schemas.GroupInviteRedeemResponse(
            status="INVALID_INVITE",
            group_id="",
            reason=reason,
        )
        return JSONResponse(
            status_code=400, content=payload.model_dump(by_alias=True)
        )
    return schemas.GroupInviteRedeemResponse(
        status=status,
        group_id=str(group_id),
    )


@app.post("/invites/{token}/revoke")
def revoke_invite_link(token: str, db: Session = Depends(get_db)):
    revoked = crud.revoke_invite_link(db, token)
    if not revoked:
        raise HTTPException(status_code=404, detail="Invite not found")
    return {"status": "REVOKED"}


@app.delete("/group-shared/{group_id}", status_code=204)
def delete_group_shared(group_id: int, db: Session = Depends(get_db)):
    deleted = crud.delete_group(db, group_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Group not found")


@app.post(
    "/group-shared/{group_id}/invites",
    response_model=schemas.GroupRead,
    status_code=201,
)
def create_group_invite(
    group_id: int,
    *,
    db: Session = Depends(get_db),
    payload: schemas.GroupInviteCreate,
):
    try:
        group = crud.add_group_invite(db, group_id, payload)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/group-shared/{group_id}/share",
    response_model=schemas.GroupRead,
)
def share_group_schedule(
    group_id: int,
    *,
    db: Session = Depends(get_db),
    payload: schemas.GroupShareCreate,
):
    group = crud.share_group_schedule(db, group_id, payload)
    if not group:
        raise HTTPException(status_code=404, detail="Group or user not found")
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/group-shared/{group_id}/share/cancel",
    response_model=schemas.GroupRead,
)
def cancel_group_share(
    group_id: int,
    *,
    db: Session = Depends(get_db),
    payload: schemas.GroupShareCancel,
):
    group = crud.cancel_group_share(db, group_id, payload)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/group-shared/invites/{invite_id}/accept",
    response_model=schemas.GroupRead,
)
def accept_group_invite(
    invite_id: int,
    *,
    payload: schemas.GroupInviteDecision,
    db: Session = Depends(get_db),
):
    try:
        group = crud.accept_group_invite(db, invite_id, payload.user_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    if not group:
        raise HTTPException(status_code=404, detail="Invite not found")
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/group-shared/invites/{invite_id}/decline",
    response_model=schemas.GroupRead,
)
def decline_group_invite(
    invite_id: int,
    *,
    payload: schemas.GroupInviteDecision,
    db: Session = Depends(get_db),
):
    try:
        group = crud.decline_group_invite(db, invite_id, payload.user_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    if not group:
        raise HTTPException(status_code=404, detail="Invite not found")
    return _group_to_read_schema(db=db, group=group)


@app.post(
    "/group-invites/accept-by-token",
    response_model=schemas.GroupRead,
)
def accept_invite_by_token(
    payload: schemas.GroupInviteTokenAccept,
    db: Session = Depends(get_db),
):
    try:
        group = crud.accept_group_invite_by_token(
            db, payload.token, payload.user_id
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    if not group:
        raise HTTPException(status_code=404, detail="Invite not found")
    return _group_to_read_schema(db=db, group=group)


def _build_invite_landing_html(
    *,
    title: str,
    description: str,
    token: Optional[str],
) -> str:
    safe_title = html.escape(title)
    safe_description = html.escape(description)
    deep_link = html.escape(_build_deep_link(token)) if token else None
    download_url = html.escape(APP_DOWNLOAD_URL)
    primary = (
        f'<a class="primary" href="{deep_link}">Open in the NurseShift app</a>'
        if deep_link
        else ""
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{safe_title} • NurseShift</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f9fc;
      color: #0a1f33;
      margin: 0;
      padding: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }}
    .card {{
      background: #fff;
      border-radius: 20px;
      padding: 32px;
      box-shadow: 0 15px 40px rgba(10, 31, 51, 0.08);
      max-width: 480px;
      width: 100%;
      text-align: center;
    }}
    h1 {{
      margin-top: 0;
      font-size: 28px;
    }}
    p {{
      line-height: 1.5;
      color: #41526b;
    }}
    .actions {{
      margin-top: 24px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }}
    a.primary {{
      display: inline-block;
      padding: 14px 18px;
      border-radius: 12px;
      background: #006972;
      color: #fff;
      text-decoration: none;
      font-weight: 600;
    }}
    a.secondary {{
      display: inline-block;
      padding: 14px 18px;
      border-radius: 12px;
      border: 1px solid #cfd8e6;
      color: #006972;
      text-decoration: none;
      font-weight: 600;
    }}
    .note {{
      font-size: 14px;
      color: #617087;
      margin-top: 16px;
    }}
  </style>
</head>
<body>
  <div class="card">
    <h1>{safe_title}</h1>
    <p>{safe_description}</p>
    <div class="actions">
      {primary}
      <a class="secondary" href="{download_url}" target="_blank" rel="noopener">Download the app</a>
    </div>
    <p class="note">Already installed? Tap the button above after logging in to accept automatically.</p>
  </div>
</body>
</html>"""


@app.get("/ginv/{token}", response_class=HTMLResponse)
def invite_universal_link(token: str, db: Session = Depends(get_db)):
    invite, reason = crud.get_invite_link_preview(db, token)
    if not invite:
        message = "This invite link is no longer valid."
        if reason == "EXPIRED":
            message = "This invite link has expired."
        elif reason == "REVOKED":
            message = "This invite link was revoked."
        elif reason == "NO_USES_LEFT":
            message = "This invite link has already been used."
        return HTMLResponse(
            content=_build_invite_landing_html(
                title="Invite unavailable",
                description=message,
                token=None,
            )
        )
    return HTMLResponse(
        content=_build_invite_landing_html(
            title=f"Join {invite.group.name}",
            description="Tap below to open NurseShift and accept the invite.",
            token=token,
        )
    )


@app.get("/group-invites/accept", response_class=HTMLResponse)
def invite_landing(
    token: str = Query(..., description="Invitation token"),
    db: Session = Depends(get_db),
):
    invite = (
        db.query(models.GroupInvite)
        .filter(models.GroupInvite.token == token)
        .first()
    )
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    group_name = html.escape(invite.group.name)
    invitee = html.escape(invite.invitee_name)
    deep_link = html.escape(_build_deep_link(token))
    download_url = html.escape(APP_DOWNLOAD_URL)
    content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Join {group_name} • NurseShift</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f9fc;
      color: #0a1f33;
      margin: 0;
      padding: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }}
    .card {{
      background: #fff;
      border-radius: 20px;
      padding: 32px;
      box-shadow: 0 15px 40px rgba(10, 31, 51, 0.08);
      max-width: 480px;
      width: 100%;
      text-align: center;
    }}
    h1 {{
      margin-top: 0;
      font-size: 28px;
    }}
    p {{
      line-height: 1.5;
      color: #41526b;
    }}
    .actions {{
      margin-top: 24px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }}
    a.primary {{
      display: inline-block;
      padding: 14px 18px;
      border-radius: 12px;
      background: #006972;
      color: #fff;
      text-decoration: none;
      font-weight: 600;
    }}
    a.secondary {{
      display: inline-block;
      padding: 14px 18px;
      border-radius: 12px;
      border: 1px solid #cfd8e6;
      color: #006972;
      text-decoration: none;
      font-weight: 600;
    }}
    .note {{
      font-size: 14px;
      color: #617087;
      margin-top: 16px;
    }}
  </style>
</head>
<body>
  <div class="card">
    <h1>Join {group_name}</h1>
    <p>{invitee} invited you to share schedules with their team on NurseShift.</p>
    <div class="actions">
      <a class="primary" href="{deep_link}">Open in the NurseShift app</a>
      <a class="secondary" href="{download_url}" target="_blank" rel="noopener">Download the app</a>
    </div>
    <p class="note">Already installed? Tap the button above after logging in to accept automatically.</p>
  </div>
</body>
</html>"""
    return HTMLResponse(content=content)


@app.post("/auth/login", response_model=schemas.AuthResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = crud.authenticate_user(db, payload.email, payload.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = secrets.token_hex(24)
    return schemas.AuthResponse(
        token=token,
        user=schemas.UserRead.model_validate(user),
    )


@app.post("/auth/logout")
def logout() -> dict:
    return {"message": "Logged out"}


@app.post("/auth/register", response_model=schemas.AuthResponse, status_code=201)
def register(payload: schemas.RegisterRequest, db: Session = Depends(get_db)):
    existing = crud.get_user_by_email(db, payload.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    if not payload.accept_privacy or not payload.accept_disclaimer:
        raise HTTPException(status_code=400, detail="ACCEPT_TERMS_REQUIRED")
    user = crud.create_user(
        db,
        schemas.UserCreate(
            name=payload.name,
            email=payload.email,
            password=payload.password,
        ),
    )
    token = secrets.token_hex(24)
    return schemas.AuthResponse(
        token=token,
        user=schemas.UserRead.model_validate(user),
    )


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
        accepted_by_user_id=event.accepted_by_user_id,
        accepted_at=event.accepted_at,
        accepted_by_name=event.accepted_by.name if event.accepted_by else None,
        accepted_by_email=event.accepted_by.email if event.accepted_by else None,
        owner_name=event.user.name if event.user else None,
        owner_email=event.user.email if event.user else None,
    )


def _group_to_read_schema(
    *,
    db: Session,
    group: models.Group,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
) -> schemas.GroupRead:
    shared_rows: List[schemas.GroupSharedRow] = []
    for membership in group.memberships:
        user = membership.user
        share = membership.share
        if not user or not share:
            print(
                f"Group {group.name}: membership {membership.id} missing "
                f"user or share (user={user is not None}, share={share is not None})"
            )
            continue
        window_start = share.start_date
        window_end = share.end_date
        if start_date:
            window_start = max(window_start, start_date)
        if end_date:
            window_end = min(window_end, end_date)
        print(
            f"Group {group.name}: user {user.name} share window "
            f"{window_start} -> {window_end} (share {share.start_date}->{share.end_date})"
        )
        if window_start > window_end:
            print(
                f"Group {group.name}: user {user.name} window outside requested range"
            )
            continue
        events = (
            db.query(models.Event)
            .filter(models.Event.user_id == user.id)
            .filter(models.Event.date >= window_start)
            .filter(models.Event.date <= window_end)
            .order_by(models.Event.date.asc(), models.Event.start_time.asc())
            .all()
        )
        parsed_entries = [
            schemas.GroupShareEntry(
                date=event.date,
                label=event.title,
                icon=event.event_type,
            )
            for event in events
        ]
        print(
            f"Group {group.name}: user {user.name} has {len(parsed_entries)} events "
            f"in database for window {window_start}->{window_end}"
        )
        if not parsed_entries:
            continue
        shared_rows.append(
            schemas.GroupSharedRow(
                member_name=user.name,
                entries=parsed_entries,
                member_id=user.id,
                start_date=share.start_date,
                end_date=share.end_date,
            )
        )
    return schemas.GroupRead(
        id=group.id,
        name=group.name,
        description=group.description,
        invite_message=group.invite_message,
        invites=[_invite_to_read_schema(invite) for invite in group.invites],
        shared_calendar=shared_rows,
    )


def _invite_to_read_schema(
    invite: models.GroupInvite,
) -> schemas.GroupInviteRead:
    invite_url = None
    if invite.token:
        base = INVITE_BASE_URL.rstrip("/")
        invite_url = f"{base}/group-invites/accept?token={invite.token}"
    return schemas.GroupInviteRead(
        id=invite.id,
        group_id=invite.group_id,
        invitee_name=invite.invitee_name,
        invitee_email=invite.invitee_email,
        status=schemas.GroupInviteStatus(invite.status),
        invite_url=invite_url,
        invitee_user_id=invite.invitee_user_id,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
