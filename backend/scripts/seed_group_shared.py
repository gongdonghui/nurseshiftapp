"""Populate the database with sample data for the Group Shared feature."""

from __future__ import annotations

import random
from datetime import date, time, timedelta

from app import models
from app.database import SessionLocal
from app import schemas, crud


def main() -> None:
    session = SessionLocal()
    try:
        group = (
            session.query(models.Group)
            .filter(models.Group.name == "Surgical Services")
            .first()
        )
        if group is None:
            base_start = date(2025, 11, 10)
            sample_users = [
                (
                    "Jamie Ortega",
                    "jamie@nurseshift.app",
                    ["Day", "Day", "Off", "Evening", "Night", "Off", "Off"],
                    "regular",
                ),
                (
                    "Reese Patel",
                    "reese@nurseshift.app",
                    ["Night", "Night", "Night", "Off", "Off", "Day", "Day"],
                    "night_shift",
                ),
                (
                    "Morgan Wills",
                    "morgan@nurseshift.app",
                    ["Evening", "Evening", "Day", "Day", "Off", "Off", "Night"],
                    "evening",
                ),
                (
                    "Avery Chen",
                    "avery@nurseshift.app",
                    ["Charge", "Charge", "Day", "Off", "Evening", "Off", "Off"],
                    "charge",
                ),
            ]
            group = models.Group(
                name="Surgical Services",
                description="Shared calendar for 7S team swaps.",
                invite_message="Join our Surgical Services group on NurseShift so we can swap faster.",
                shared_calendar="[]",
            )
            session.add(group)
            session.commit()
            for name, email, labels, icon in sample_users:
                user = crud.get_user_by_email(session, email)
                if not user:
                    user = crud.create_user(
                        session,
                        schemas.UserCreate(
                            name=name,
                            email=email,
                            password="password123",
                        ),
                    )
                membership = models.GroupMembership(group_id=group.id, user_id=user.id)
                session.add(membership)
                session.flush()
                session.add(
                    models.GroupShare(
                        membership_id=membership.id,
                        start_date=base_start,
                        end_date=base_start + timedelta(days=len(labels) - 1),
                )
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
                    session.add(event)

                _add_december_events(session, group.id, user)
            session.commit()
            print("Seeded Surgical Services group with shared calendar sample.")
        else:
            print("Group sample already exists; skipping.")
    finally:
        session.close()


def _add_december_events(session: SessionLocal, group_id: int, user: models.User) -> None:
    rng = random.Random(hash(user.email))
    membership = (
        session.query(models.GroupMembership)
        .filter(
            models.GroupMembership.group_id == group_id,
            models.GroupMembership.user_id == user.id,
        )
        .first()
    )
    if membership is None:
        membership = models.GroupMembership(group_id=group_id, user_id=user.id)
        session.add(membership)
        session.flush()
    share = session.query(models.GroupShare).filter_by(membership_id=membership.id).first()
    if share is None:
        share = models.GroupShare(
            membership_id=membership.id,
            start_date=date(2025, 12, 1),
            end_date=date(2025, 12, 31),
        )
        session.add(share)
    else:
        share.start_date = date(2025, 12, 1)
        share.end_date = date(2025, 12, 31)

    event_types = [
        ("Day Shift", "regular", time(7, 0), time(19, 0)),
        ("Night Shift", "night_shift", time(19, 0), time(7, 0)),
        ("Evening Shift", "evening", time(15, 0), time(23, 0)),
    ]
    for day in range(1, 32):
        if rng.random() < 0.4:
            label, event_type, start, end = rng.choice(event_types)
            event = models.Event(
                title=f"{label} (Dec {day})",
                date=date(2025, 12, day),
                start_time=start,
                end_time=end,
                location="F.W. Huston Medical Center",
                event_type=event_type,
                notes=None,
                user_id=user.id,
            )
            session.add(event)


if __name__ == "__main__":
    main()
