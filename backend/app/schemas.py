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
    user_id: Optional[int] = None


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
    accepted_by_user_id: Optional[int] = None
    accepted_at: Optional[datetime] = None
    accepted_by_name: Optional[str] = None
    accepted_by_email: Optional[str] = None
    owner_name: Optional[str] = None
    owner_email: Optional[str] = None

    class Config:
        from_attributes = True


class ColleagueStatus(str, Enum):
    invited = "invited"
    accepted = "accepted"


class ColleagueBase(BaseModel):
    name: str = Field(..., max_length=255)
    department: str = Field(..., max_length=255)
    facility: str = Field(..., max_length=255)
    role: Optional[str] = Field(None, max_length=255)
    email: Optional[str] = Field(None, max_length=255)


class ColleagueCreate(ColleagueBase):
    pass


class ColleagueRead(ColleagueBase):
    id: int
    status: ColleagueStatus
    invitation_message: Optional[str] = None

    class Config:
        from_attributes = True


class WorksiteBase(BaseModel):
    hospital_name: str = Field(..., max_length=255)
    department_name: str = Field(..., max_length=255)
    position_name: str = Field(..., max_length=255)


class WorksiteCreate(WorksiteBase):
    user_id: int


class WorksiteRead(WorksiteBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True


class GroupInviteStatus(str, Enum):
    invited = "invited"
    accepted = "accepted"
    declined = "declined"


class GroupInviteBase(BaseModel):
    invitee_name: str = Field(..., max_length=255)
    invitee_email: Optional[str] = Field(None, max_length=255)


class GroupInviteCreate(GroupInviteBase):
    @validator("invitee_email")
    def require_email(cls, value: Optional[str]) -> str:
        if value is None or not value.strip():
            raise ValueError("invitee_email is required")
        return value.strip()


class GroupInviteRead(GroupInviteBase):
    id: int
    group_id: int
    status: GroupInviteStatus
    invite_url: Optional[str] = None
    invitee_user_id: Optional[int] = None

    class Config:
        from_attributes = True


class GroupInviteDecision(BaseModel):
    user_id: int


class GroupInviteTokenAccept(BaseModel):
    token: str
    user_id: int


class GroupInviteLinkCreate(BaseModel):
    role: str = Field("member", max_length=32)
    expires_in_seconds: int = Field(
        60 * 60 * 24 * 7, alias="expiresInSeconds", ge=60
    )
    max_uses: int = Field(20, alias="maxUses", ge=1)

    model_config = {"populate_by_name": True}


class GroupInviteLinkCreateResponse(BaseModel):
    invite_url: str = Field(..., alias="inviteUrl")
    token: str
    expires_at: datetime = Field(..., alias="expiresAt")

    model_config = {"populate_by_name": True}


class GroupInviteGroupSummary(BaseModel):
    id: str
    name: str
    member_count: int = Field(..., alias="memberCount")

    model_config = {"populate_by_name": True}


class GroupInvitePreviewResponse(BaseModel):
    valid: bool
    group: Optional[GroupInviteGroupSummary] = None
    expires_at: Optional[datetime] = Field(None, alias="expiresAt")
    remaining_uses: Optional[int] = Field(None, alias="remainingUses")
    reason: Optional[str] = None

    model_config = {"populate_by_name": True}


class GroupInviteRedeemRequest(BaseModel):
    user_id: str = Field(..., alias="userId")

    model_config = {"populate_by_name": True}


class GroupInviteRedeemResponse(BaseModel):
    status: str
    group_id: str = Field(..., alias="groupId")
    reason: Optional[str] = None

    model_config = {"populate_by_name": True}


class GroupBase(BaseModel):
    name: str = Field(..., max_length=255)
    description: Optional[str] = None


class GroupCreate(GroupBase):
    pass


class GroupShareEntry(BaseModel):
    date: date
    label: str = Field(..., max_length=64)
    icon: Optional[str] = None


class GroupSharedRow(BaseModel):
    member_name: str
    entries: List[GroupShareEntry] = Field(default_factory=list)
    member_id: Optional[int] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None


class GroupShareCreate(BaseModel):
    user_id: int
    start_date: date
    end_date: date

    @validator("end_date")
    def validate_range(cls, value, values):
        start = values.get("start_date")
        if start and value < start:
            raise ValueError("end_date must be after start_date")
        if start and (value - start).days > 180:
            raise ValueError("Cannot share more than 180 days at once")
        return value


class GroupShareCancel(BaseModel):
    user_id: int
    start_date: date
    end_date: date


class GroupRead(GroupBase):
    id: int
    invite_message: str
    invites: List[GroupInviteRead] = Field(default_factory=list)
    shared_calendar: List[GroupSharedRow] = Field(default_factory=list)

    class Config:
        from_attributes = True


class UserBase(BaseModel):
    name: str = Field(..., max_length=255)
    email: str = Field(..., max_length=255)


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)


class UserRead(UserBase):
    id: int
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True


class UserAvatarUpdate(BaseModel):
    avatar_data: Optional[str] = None


class SwapDecision(BaseModel):
    user_id: int


class LoginRequest(BaseModel):
    email: str
    password: str


class AuthResponse(BaseModel):
    token: str
    user: UserRead


class RegisterRequest(BaseModel):
    name: str = Field(..., max_length=255)
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=6)
    confirm_password: str
    accept_privacy: bool = Field(False)
    accept_disclaimer: bool = Field(False)

    @validator("confirm_password")
    def passwords_match(cls, confirm, values):
        password = values.get("password")
        if password and confirm != password:
            raise ValueError("Passwords do not match")
        return confirm

    @validator("accept_privacy", "accept_disclaimer")
    def require_acceptance(cls, value):
        if value is not True:
            raise ValueError("Terms acceptance required")
        return value


GroupRead.model_rebuild()
