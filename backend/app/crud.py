from datetime import date, datetime, timedelta
from typing import List, Optional
import hashlib
import secrets

from sqlalchemy import select, update, func
from sqlalchemy.orm import Session, joinedload

from . import models, schemas


DEFAULT_USER_EMAIL = "jamie@nurseshift.app"


def create_event(db: Session, event_in: schemas.EventCreate) -> models.Event:
    payload = event_in.model_dump()
    requested_user_id = payload.pop("user_id", None)
    user: Optional[models.User]
    if requested_user_id is not None:
        user = db.get(models.User, requested_user_id)
        if not user:
            raise ValueError("USER_NOT_FOUND")
    else:
        user = _get_or_create_default_user(db)
    payload["user_id"] = user.id
    event = models.Event(**payload)
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def get_event(db: Session, event_id: int) -> Optional[models.Event]:
    return db.get(models.Event, event_id)


def list_events(
    db: Session, *, start_date: date, end_date: date, user_id: Optional[int] = None
) -> List[models.Event]:
    stmt = (
        select(models.Event)
        .where(models.Event.date >= start_date)
        .where(models.Event.date <= end_date)
        .order_by(models.Event.date.asc(), models.Event.start_time.asc())
    )
    if user_id is not None:
        stmt = stmt.where(models.Event.user_id == user_id)
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
    owner = event.user or _get_or_create_default_user(db)
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
        user_id=owner.id,
    )
    for colleague in payload.targeted_colleagues:
        match = (
            db.query(models.User)
            .filter(models.User.email == colleague.lower())
            .first()
        )
        swap_request.targets.append(
            models.SwapTarget(
                colleague_name=colleague,
                user_id=match.id if match else None,
            )
        )
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
    user_id: Optional[int] = None,
) -> List[models.SwapRequest]:
    stmt = select(models.SwapRequest).join(models.Event)
    if start_date:
        stmt = stmt.where(models.Event.date >= start_date)
    if end_date:
        stmt = stmt.where(models.Event.date <= end_date)
    if status:
        stmt = stmt.where(models.SwapRequest.status == status)
    if user_id is not None:
        stmt = stmt.where(models.Event.user_id == user_id)
    stmt = stmt.order_by(
        models.Event.date.asc(), models.Event.start_time.asc(), models.SwapRequest.id.asc()
    )
    return list(db.scalars(stmt).unique().all())


def list_inbox_swap_requests(db: Session, user_id: int) -> List[models.SwapRequest]:
    user = (
        db.query(models.User)
        .options(joinedload(models.User.group_memberships))
        .filter(models.User.id == user_id)
        .first()
    )
    if not user:
        return []
    user_groups = {membership.group_id for membership in user.group_memberships}
    responded_ids = {
        response.swap_request_id
        for response in db.query(models.SwapRequestResponse)
        .filter(models.SwapRequestResponse.user_id == user_id)
    }
    requests = (
        db.query(models.SwapRequest)
        .join(models.Event)
        .options(
            joinedload(models.SwapRequest.user).joinedload(
                models.User.group_memberships
            ),
            joinedload(models.SwapRequest.targets),
            joinedload(models.SwapRequest.event),
            joinedload(models.SwapRequest.accepted_by),
        )
        .filter(models.SwapRequest.status == schemas.SwapStatus.pending.value)
        .filter(models.SwapRequest.user_id != user_id)
        .order_by(models.Event.date.asc(), models.Event.start_time.asc())
        .all()
    )
    inbox: List[models.SwapRequest] = []
    for swap in requests:
        if swap.id in responded_ids:
            continue
        owner = swap.user
        if not owner:
            continue
        owner_groups = {membership.group_id for membership in owner.group_memberships}
        target_match = any(
            target.user_id == user_id for target in swap.targets if target.user_id
        )
        shared_worksite = (
            user.primary_hospital
            and owner.primary_hospital
            and user.primary_hospital == owner.primary_hospital
        )
        shared_group = bool(user_groups & owner_groups)
        if target_match or shared_worksite or shared_group:
            inbox.append(swap)
    existing_ids = {swap.id for swap in inbox}
    owner_notifications = (
        db.query(models.SwapRequest)
        .join(models.Event)
        .options(
            joinedload(models.SwapRequest.user),
            joinedload(models.SwapRequest.event),
            joinedload(models.SwapRequest.accepted_by),
        )
        .filter(models.SwapRequest.user_id == user_id)
        .filter(models.SwapRequest.status == schemas.SwapStatus.fulfilled.value)
        .order_by(models.Event.date.asc(), models.Event.start_time.asc())
        .all()
    )
    for swap in owner_notifications:
        if swap.id in existing_ids:
            continue
        inbox.append(swap)
    return inbox


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


def accept_swap_request_for_user(
    db: Session, request_id: int, user_id: int
) -> Optional[models.SwapRequest]:
    swap = get_swap_request(db, request_id)
    if not swap:
        return None
    if swap.status != schemas.SwapStatus.pending.value:
        return swap
    if swap.user_id == user_id:
        raise ValueError("CANNOT_ACCEPT_OWN")
    swap.status = schemas.SwapStatus.fulfilled.value
    swap.accepted_by_user_id = user_id
    swap.accepted_at = datetime.utcnow()
    # Transfer the event to the accepting user so it is no longer swappable
    # by the original owner.
    if swap.event:
        swap.event.user_id = user_id
    _record_response(db, request_id, user_id, "accepted")
    _expire_other_targets(db, swap, user_id)
    db.commit()
    db.refresh(swap)
    return swap


def decline_swap_request_for_user(
    db: Session, request_id: int, user_id: int
) -> Optional[models.SwapRequest]:
    swap = get_swap_request(db, request_id)
    if not swap:
        return None
    if swap.status != schemas.SwapStatus.pending.value:
        return swap
    if swap.user_id == user_id:
        raise ValueError("CANNOT_DECLINE_OWN")
    _record_response(db, request_id, user_id, "declined")
    db.commit()
    return swap


def _record_response(
    db: Session, request_id: int, user_id: int, status: str
) -> models.SwapRequestResponse:
    response = (
        db.query(models.SwapRequestResponse)
        .filter(
            models.SwapRequestResponse.swap_request_id == request_id,
            models.SwapRequestResponse.user_id == user_id,
        )
        .first()
    )
    now = datetime.utcnow()
    if response:
        response.status = status
        response.created_at = now
    else:
        response = models.SwapRequestResponse(
            swap_request_id=request_id,
            user_id=user_id,
            status=status,
            created_at=now,
        )
    db.add(response)
    return response


def _expire_other_targets(
    db: Session, swap: models.SwapRequest, accepted_user_id: int
) -> None:
    for target in swap.targets:
        if target.user_id and target.user_id != accepted_user_id:
            _record_response(db, swap.id, target.user_id, "expired")


def list_colleagues(db: Session) -> List[models.Colleague]:
    stmt = select(models.Colleague).order_by(models.Colleague.name.asc())
    return list(db.scalars(stmt).all())


def create_colleague(
    db: Session, payload: schemas.ColleagueCreate
) -> models.Colleague:
    owner = _get_or_create_default_user(db)
    invitation_message = (
        f"Hi {payload.name}, I'm using NurseShift to coordinate swaps. "
        "Can I add you as a colleague so we can exchange coverage more easily?"
    )
    colleague = models.Colleague(
        **payload.model_dump(),
        invitation_message=invitation_message,
        status="invited",
        user_id=owner.id,
    )
    db.add(colleague)
    db.commit()
    db.refresh(colleague)
    return colleague


def accept_colleague(db: Session, colleague_id: int) -> Optional[models.Colleague]:
    colleague = db.get(models.Colleague, colleague_id)
    if not colleague:
        return None
    colleague.status = "accepted"
    db.commit()
    db.refresh(colleague)
    return colleague


def list_worksites(db: Session, user_id: int) -> List[models.Worksite]:
    stmt = (
        select(models.Worksite)
        .where(models.Worksite.user_id == user_id)
        .order_by(models.Worksite.created_at.asc())
    )
    return list(db.scalars(stmt).all())


def create_worksite(db: Session, payload: schemas.WorksiteCreate) -> models.Worksite:
    user = db.get(models.User, payload.user_id)
    if not user:
        raise ValueError("USER_NOT_FOUND")
    worksite = (
        db.query(models.Worksite)
        .filter(models.Worksite.user_id == payload.user_id)
        .first()
    )
    if worksite:
        worksite.hospital_name = payload.hospital_name
        worksite.department_name = payload.department_name
        worksite.position_name = payload.position_name
    else:
        worksite = models.Worksite(
            user_id=payload.user_id,
            hospital_name=payload.hospital_name,
            department_name=payload.department_name,
            position_name=payload.position_name,
        )
        db.add(worksite)
    db.commit()
    db.refresh(worksite)
    _sync_user_primary_worksite(db, payload.user_id)
    return worksite


def delete_worksite(db: Session, worksite_id: int) -> bool:
    worksite = db.get(models.Worksite, worksite_id)
    if not worksite:
        return False
    user_id = worksite.user_id
    db.delete(worksite)
    db.commit()
    _sync_user_primary_worksite(db, user_id)
    return True


def update_user_avatar(
    db: Session, user_id: int, avatar_data: Optional[str]
) -> Optional[models.User]:
    user = db.get(models.User, user_id)
    if not user:
        return None
    user.avatar_url = avatar_data
    db.commit()
    db.refresh(user)
    return user


def _sync_user_primary_worksite(db: Session, user_id: int) -> None:
    user = db.get(models.User, user_id)
    if not user:
        return
    stmt = (
        select(models.Worksite)
        .where(models.Worksite.user_id == user_id)
        .limit(1)
    )
    worksite = db.scalars(stmt).first()
    if worksite:
        user.primary_hospital = worksite.hospital_name
        user.primary_department = worksite.department_name
        user.primary_position = worksite.position_name
    else:
        user.primary_hospital = None
        user.primary_department = None
        user.primary_position = None
    db.commit()


def list_groups(db: Session) -> List[models.Group]:
    stmt = (
        select(models.Group)
        .options(
            joinedload(models.Group.memberships)
            .joinedload(models.GroupMembership.user),
            joinedload(models.Group.memberships).joinedload(models.GroupMembership.share),
            joinedload(models.Group.invites),
        )
        .order_by(models.Group.created_at.desc())
    )
    return list(db.scalars(stmt).unique().all())


def get_group(db: Session, group_id: int) -> Optional[models.Group]:
    return db.get(models.Group, group_id)


def create_group(db: Session, payload: schemas.GroupCreate) -> models.Group:
    invite_message = (
        f"Join my NurseShift group \"{payload.name}\" so we can coordinate swaps together."
    )
    group = models.Group(
        name=payload.name,
        description=payload.description,
        invite_message=invite_message,
        shared_calendar="[]",
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    user = _get_or_create_default_user(db)
    _get_or_create_membership(db, group.id, user.id)
    return group


def delete_group(db: Session, group_id: int) -> bool:
    group = get_group(db, group_id)
    if not group:
        return False
    db.delete(group)
    db.commit()
    return True


def add_group_invite(
    db: Session, group_id: int, payload: schemas.GroupInviteCreate
) -> Optional[models.Group]:
    group = get_group(db, group_id)
    if not group:
        return None
    email = (payload.invitee_email or "").strip().lower()
    if not email:
        raise ValueError("INVITE_EMAIL_REQUIRED")
    token = secrets.token_urlsafe(20)
    invite = models.GroupInvite(
        group_id=group_id,
        invitee_name=payload.invitee_name,
        invitee_email=email,
        token=token,
        status=schemas.GroupInviteStatus.invited.value,
    )
    match = (
        db.query(models.User)
        .filter(func.lower(models.User.email) == email)
        .first()
    )
    if not match:
        match = (
            db.query(models.User)
            .filter(
                func.lower(models.User.name) == payload.invitee_name.strip().lower()
            )
            .first()
        )
    if match:
        invite.invitee_user_id = match.id
    db.add(invite)
    db.commit()
    db.refresh(group)
    return group


def _hash_invite_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_group_invite_link(
    db: Session, group_id: int, payload: schemas.GroupInviteLinkCreate
) -> Optional[tuple[models.GroupInviteLink, str]]:
    group = get_group(db, group_id)
    if not group:
        return None
    token = secrets.token_urlsafe(24)
    token_hash = _hash_invite_token(token)
    expires_at = datetime.utcnow() + timedelta(seconds=payload.expires_in_seconds)
    invite = models.GroupInviteLink(
        group_id=group_id,
        token_hash=token_hash,
        role=payload.role,
        expires_at=expires_at,
        max_uses=payload.max_uses,
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    return invite, token


def get_invite_link_preview(
    db: Session, token: str
) -> tuple[Optional[models.GroupInviteLink], Optional[str]]:
    token_hash = _hash_invite_token(token)
    invite = (
        db.query(models.GroupInviteLink)
        .filter(models.GroupInviteLink.token_hash == token_hash)
        .first()
    )
    if not invite:
        return None, "NOT_FOUND"
    if invite.revoked_at is not None:
        return None, "REVOKED"
    if invite.expires_at <= datetime.utcnow():
        return None, "EXPIRED"
    if invite.use_count >= invite.max_uses:
        return None, "NO_USES_LEFT"
    return invite, None


def redeem_invite_link(
    db: Session, token: str, user_id: str
) -> tuple[Optional[str], Optional[int], Optional[str]]:
    invite, reason = get_invite_link_preview(db, token)
    if not invite:
        return None, None, reason
    user = db.get(models.User, int(user_id))
    if not user:
        return None, None, "USER_NOT_FOUND"
    membership = (
        db.query(models.GroupMembership)
        .filter(
            models.GroupMembership.group_id == invite.group_id,
            models.GroupMembership.user_id == user.id,
        )
        .first()
    )
    if membership:
        return "ALREADY_MEMBER", invite.group_id, None
    db.add(models.GroupMembership(group_id=invite.group_id, user_id=user.id))
    invite.use_count += 1
    db.commit()
    return "JOINED", invite.group_id, None


def revoke_invite_link(db: Session, token: str) -> bool:
    token_hash = _hash_invite_token(token)
    invite = (
        db.query(models.GroupInviteLink)
        .filter(models.GroupInviteLink.token_hash == token_hash)
        .first()
    )
    if not invite:
        return False
    invite.revoked_at = datetime.utcnow()
    db.commit()
    return True


def accept_group_invite(
    db: Session, invite_id: int, user_id: int
) -> Optional[models.Group]:
    invite = db.get(models.GroupInvite, invite_id)
    if not invite:
        return None
    user = db.get(models.User, user_id)
    if not user:
        raise ValueError("USER_NOT_FOUND")
    if invite.status == schemas.GroupInviteStatus.accepted.value:
        return invite.group
    normalized_email = user.email.lower()
    name_match = user.name.strip().lower()
    if invite.invitee_email:
        if invite.invitee_email.lower() != normalized_email and (
            invite.invitee_user_id and invite.invitee_user_id != user.id
        ):
            raise ValueError("INVITE_EMAIL_MISMATCH")
    elif invite.invitee_name.lower() != name_match:
        raise ValueError("INVITE_EMAIL_MISMATCH")
    _get_or_create_membership(db, invite.group_id, user.id)
    invite.status = schemas.GroupInviteStatus.accepted.value
    invite.invitee_user_id = user.id
    db.commit()
    db.refresh(invite.group)
    return invite.group


def decline_group_invite(
    db: Session, invite_id: int, user_id: int
) -> Optional[models.Group]:
    invite = db.get(models.GroupInvite, invite_id)
    if not invite:
        return None
    user = db.get(models.User, user_id)
    if not user:
        raise ValueError("USER_NOT_FOUND")
    normalized_email = user.email.lower()
    name_match = user.name.strip().lower()
    if invite.invitee_email:
        if invite.invitee_email.lower() != normalized_email and (
            invite.invitee_user_id and invite.invitee_user_id != user.id
        ):
            raise ValueError("INVITE_EMAIL_MISMATCH")
    elif invite.invitee_name.lower() != name_match:
        raise ValueError("INVITE_EMAIL_MISMATCH")
    invite.status = schemas.GroupInviteStatus.declined.value
    invite.invitee_user_id = user.id
    db.commit()
    db.refresh(invite.group)
    return invite.group


def accept_group_invite_by_token(
    db: Session, token: str, user_id: int
) -> Optional[models.Group]:
    invite = (
        db.query(models.GroupInvite)
        .filter(models.GroupInvite.token == token)
        .first()
    )
    if not invite:
        return None
    return accept_group_invite(db, invite.id, user_id)


def share_group_schedule(
    db: Session, group_id: int, payload: schemas.GroupShareCreate
) -> Optional[models.Group]:
    group = get_group(db, group_id)
    if not group:
        return None
    user = db.get(models.User, payload.user_id)
    if not user:
        return None
    membership = _get_or_create_membership(db, group_id, user.id)
    share = membership.share
    if share:
        share.start_date = payload.start_date
        share.end_date = payload.end_date
    else:
        share = models.GroupShare(
            membership_id=membership.id,
            start_date=payload.start_date,
            end_date=payload.end_date,
        )
        db.add(share)
    db.commit()
    db.refresh(group)
    return group


def cancel_group_share(
    db: Session, group_id: int, payload: schemas.GroupShareCancel
) -> Optional[models.Group]:
    membership = (
        db.query(models.GroupMembership)
        .filter(
            models.GroupMembership.group_id == group_id,
            models.GroupMembership.user_id == payload.user_id,
        )
        .first()
    )
    if not membership:
        return None
    if membership.share:
        db.delete(membership.share)
        db.commit()
    db.refresh(membership.group)
    return membership.group


def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def create_user(db: Session, payload: schemas.UserCreate) -> models.User:
    user = models.User(
        name=payload.name,
        email=payload.email.lower(),
        password_hash=_hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def get_user_by_email(db: Session, email: str) -> Optional[models.User]:
    stmt = select(models.User).where(models.User.email == email.lower())
    return db.scalars(stmt).first()


def authenticate_user(db: Session, email: str, password: str) -> Optional[models.User]:
    user = get_user_by_email(db, email)
    if not user:
        return None
    if user.password_hash != _hash_password(password):
        return None
    return user


def _get_or_create_default_user(db: Session) -> models.User:
    user = get_user_by_email(db, DEFAULT_USER_EMAIL)
    if user:
        return user
    return create_user(
        db,
        schemas.UserCreate(
            name="Jamie Ortega",
            email=DEFAULT_USER_EMAIL,
            password="password123",
        ),
    )


def _get_or_create_membership(
    db: Session, group_id: int, user_id: int
) -> models.GroupMembership:
    membership = (
        db.query(models.GroupMembership)
        .filter(
            models.GroupMembership.group_id == group_id,
            models.GroupMembership.user_id == user_id,
        )
        .first()
    )
    if membership:
        return membership
    membership = models.GroupMembership(group_id=group_id, user_id=user_id)
    db.add(membership)
    db.commit()
    db.refresh(membership)
    return membership
    membership_exists = (
        db.query(models.GroupMembership)
        .filter(
            models.GroupMembership.group_id == group_id,
            models.GroupMembership.user_id == user.id,
        )
        .first()
    )
    if not membership_exists:
        db.add(models.GroupMembership(group_id=group_id, user_id=user.id))
        db.commit()
