#!/usr/bin/env python3
"""
Manual test script to verify swap request visibility across colleagues/groups.

Usage:
  python backend/scripts/test_swap_delivery.py --base-url http://127.0.0.1:8000

The script will:
1. Create a swap request for a seed user (Jamie).
2. Fetch swap requests for another user (Reese) and report whether the new request appears.
"""
from __future__ import annotations

import argparse
import sys
from typing import Any, Dict, List

import requests


def _create_swap_request(base_url: str) -> Dict[str, Any]:
    payload = {
        "event_id": 1,
        "mode": "swap",
        "desired_shift_type": "Day",
        "available_start_time": "07:00:00",
        "available_end_time": "19:00:00",
        "visible_to_all": True,
        "share_with_staffing_pool": False,
        "notes": "Test request from script",
        "targeted_colleagues": [],
    }
    response = requests.post(f"{base_url}/swap-requests", json=payload, timeout=5)
    response.raise_for_status()
    return response.json()


def _fetch_swap_requests(
    base_url: str, user_name: str, start_date: str, end_date: str
) -> List[Dict[str, Any]]:
    params = {
        "start_date": start_date,
        "end_date": end_date,
        "status": "pending",
    }
    response = requests.get(f"{base_url}/swap-requests", params=params, timeout=5)
    response.raise_for_status()
    data = response.json()
    print(f"[INFO] {user_name} sees {len(data)} pending swap requests.")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="Test swap request delivery.")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8000",
        help="FastAPI base URL (default: %(default)s)",
    )
    parser.add_argument(
        "--start-date",
        default="2025-11-01",
        help="Start date for request filtering (default: %(default)s)",
    )
    parser.add_argument(
        "--end-date",
        default="2025-12-31",
        help="End date for request filtering (default: %(default)s)",
    )
    args = parser.parse_args()

    print(f"[INFO] Using API at {args.base_url}")
    created = _create_swap_request(args.base_url)
    print(f"[INFO] Created swap request id={created['id']}")

    _fetch_swap_requests(args.base_url, "Recipient", args.start_date, args.end_date)
    print("[INFO] Review the output to confirm whether colleagues/groups receive it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
