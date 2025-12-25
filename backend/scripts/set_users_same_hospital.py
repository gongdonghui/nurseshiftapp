"""Assign every user to the same default hospital/department/position."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("PYTHONPATH", str(ROOT))

from app.database import SessionLocal  # type: ignore
from app import models  # type: ignore


HOSPITAL_NAME = "F.W. Huston Medical Center"
DEPARTMENT_NAME = "Weight Management"
POSITION_NAME = "Registered Nurse"


def main() -> None:
    session = SessionLocal()
    try:
        users = session.query(models.User).all()
        print(f"Updating {len(users)} users...")
        for user in users:
            worksite = (
                session.query(models.Worksite)
                .filter(models.Worksite.user_id == user.id)
                .first()
            )
            if worksite is None:
                worksite = models.Worksite(
                    user_id=user.id,
                    hospital_name=HOSPITAL_NAME,
                    department_name=DEPARTMENT_NAME,
                    position_name=POSITION_NAME,
                )
                session.add(worksite)
            else:
                worksite.hospital_name = HOSPITAL_NAME
                worksite.department_name = DEPARTMENT_NAME
                worksite.position_name = POSITION_NAME

            user.primary_hospital = HOSPITAL_NAME
            user.primary_department = DEPARTMENT_NAME
            user.primary_position = POSITION_NAME
        session.commit()
        print("All users now share the same worksite details.")
    finally:
        session.close()


if __name__ == "__main__":
    main()
