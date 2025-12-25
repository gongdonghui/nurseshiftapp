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
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="events")

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
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    accepted_by_user_id = Column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    accepted_at = Column(DateTime, nullable=True)

    event: Mapped[Event] = relationship("Event", backref="swap_requests")
    targets: Mapped[List["SwapTarget"]] = relationship(
        "SwapTarget", cascade="all, delete-orphan", back_populates="swap_request"
    )
    user: Mapped["User"] = relationship(
        "User", foreign_keys=[user_id], back_populates="swap_requests"
    )
    accepted_by: Mapped["User"] = relationship(
        "User", foreign_keys=[accepted_by_user_id]
    )
    responses: Mapped[List["SwapRequestResponse"]] = relationship(
        "SwapRequestResponse", cascade="all, delete-orphan", back_populates="swap_request"
    )


class SwapTarget(Base):
    __tablename__ = "swap_targets"

    id = Column(Integer, primary_key=True, index=True)
    swap_request_id = Column(
        Integer, ForeignKey("swap_requests.id", ondelete="CASCADE"), nullable=False
    )
    colleague_name = Column(String(255), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)

    swap_request: Mapped[SwapRequest] = relationship(
        "SwapRequest", back_populates="targets"
    )
    user: Mapped["User"] = relationship("User", back_populates="swap_targets")


class Colleague(Base):
    __tablename__ = "colleagues"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    department = Column(String(255), nullable=False)
    facility = Column(String(255), nullable=False)
    role = Column(String(255), nullable=True)
    email = Column(String(255), nullable=True)
    status = Column(String(32), nullable=False, default="invited")
    invitation_message = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    user: Mapped["User"] = relationship("User", back_populates="colleagues")


class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    invite_message = Column(Text, nullable=False)
    shared_calendar = Column(Text, nullable=False, default="[]")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    invites: Mapped[List["GroupInvite"]] = relationship(
        "GroupInvite", cascade="all, delete-orphan", back_populates="group"
    )
    members: Mapped[List["User"]] = relationship(
        "User", secondary="group_memberships", back_populates="groups"
    )
    memberships: Mapped[List["GroupMembership"]] = relationship(
        "GroupMembership", cascade="all, delete-orphan", back_populates="group"
    )


class GroupInvite(Base):
    __tablename__ = "group_invites"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False)
    invitee_name = Column(String(255), nullable=False)
    status = Column(String(32), nullable=False, default="invited")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    invitee_email = Column(String(255), nullable=True)
    token = Column(String(128), nullable=False, unique=True)
    invitee_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    group: Mapped[Group] = relationship("Group", back_populates="invites")
    invitee_user: Mapped["User"] = relationship("User")


class GroupInviteLink(Base):
    __tablename__ = "group_invite_links"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False)
    token_hash = Column(String(128), nullable=False, unique=True, index=True)
    role = Column(String(32), nullable=False, default="member")
    expires_at = Column(DateTime, nullable=False)
    max_uses = Column(Integer, nullable=False, default=1)
    use_count = Column(Integer, nullable=False, default=0)
    revoked_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    group: Mapped[Group] = relationship("Group")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    avatar_url = Column(Text, nullable=True)
    events: Mapped[List[Event]] = relationship("Event", back_populates="user")
    swap_requests: Mapped[List[SwapRequest]] = relationship(
        "SwapRequest",
        back_populates="user",
        foreign_keys=[SwapRequest.user_id],
        cascade="all, delete-orphan",
    )
    swap_responses: Mapped[List["SwapRequestResponse"]] = relationship(
        "SwapRequestResponse", back_populates="user", cascade="all, delete-orphan"
    )
    swap_targets: Mapped[List[SwapTarget]] = relationship(
        "SwapTarget", back_populates="user"
    )
    groups: Mapped[List[Group]] = relationship(
        "Group", secondary="group_memberships", back_populates="members"
    )
    colleagues: Mapped[List[Colleague]] = relationship(
        "Colleague", back_populates="user", cascade="all, delete-orphan"
    )
    group_memberships: Mapped[List["GroupMembership"]] = relationship(
        "GroupMembership", back_populates="user", cascade="all, delete-orphan"
    )
    worksites: Mapped[List["Worksite"]] = relationship(
        "Worksite", back_populates="user", cascade="all, delete-orphan"
    )
    primary_hospital = Column(String(255), nullable=True)
    primary_department = Column(String(255), nullable=True)
    primary_position = Column(String(255), nullable=True)


class GroupMembership(Base):
    __tablename__ = "group_memberships"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    joined_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    group: Mapped[Group] = relationship("Group", back_populates="memberships")
    user: Mapped[User] = relationship("User", back_populates="group_memberships")
    share: Mapped["GroupShare"] = relationship(
        "GroupShare", back_populates="membership", cascade="all, delete-orphan", uselist=False
    )


class GroupShare(Base):
    __tablename__ = "group_shares"

    id = Column(Integer, primary_key=True, index=True)
    membership_id = Column(
        Integer, ForeignKey("group_memberships.id", ondelete="CASCADE"), unique=True
    )
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    membership: Mapped[GroupMembership] = relationship(
        "GroupMembership", back_populates="share"
    )


class Worksite(Base):
    __tablename__ = "worksites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    hospital_name = Column(String(255), nullable=False)
    department_name = Column(String(255), nullable=False)
    position_name = Column(String(255), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user: Mapped[User] = relationship("User", back_populates="worksites")


class SwapRequestResponse(Base):
    __tablename__ = "swap_request_responses"

    id = Column(Integer, primary_key=True, index=True)
    swap_request_id = Column(
        Integer, ForeignKey("swap_requests.id", ondelete="CASCADE"), nullable=False
    )
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(32), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    swap_request: Mapped[SwapRequest] = relationship(
        "SwapRequest", back_populates="responses"
    )
    user: Mapped[User] = relationship("User", back_populates="swap_responses")
