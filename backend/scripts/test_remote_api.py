#!/usr/bin/env python3
"""
Quick smoke test for the deployed backend.

Usage:
    python backend/scripts/test_remote_api.py --base-url http://101.200.124.231:8000
"""
from __future__ import annotations

import argparse
import sys
from typing import Any, Dict, List

import requests


def _pretty_print(label: str, data: Any) -> None:
    print(f"\n=== {label} ===")
    if isinstance(data, list):
        for idx, item in enumerate(data[:3], start=1):
            print(f"[{idx}] {item}")
        if len(data) > 3:
            print(f"... ({len(data)} total)")
    else:
        print(data)


def call_endpoint(method: str, url: str, **kwargs: Any) -> Any:
    response = requests.request(method, url, timeout=5, **kwargs)
    response.raise_for_status()
    try:
        return response.json()
    except ValueError:
        return response.text


def main() -> int:
    parser = argparse.ArgumentParser(description="Ping remote API.")
    parser.add_argument(
        "--base-url",
        default="http://101.200.124.231:8000",
        help="Root URL of the deployment.",
    )
    args = parser.parse_args()

    base = args.base_url.rstrip("/")

    try:
        health = call_endpoint("GET", f"{base}/health")
        _pretty_print("Health", health)

        events = call_endpoint(
            "GET",
            f"{base}/events",
            params={"start_date": "2025-12-01", "end_date": "2025-12-31"},
        )
        _pretty_print("Events", events)

        swaps = call_endpoint(
            "GET",
            f"{base}/swap-requests",
            params={"start_date": "2025-12-01", "end_date": "2025-12-31"},
        )
        _pretty_print("Swap Requests", swaps)

        groups = call_endpoint("GET", f"{base}/group-shared")
        _pretty_print("Groups", groups)

        print("\nRemote API looks reachable ✅")
        return 0
    except requests.HTTPError as error:
        print(f"HTTP error: {error.response.status_code} {error.response.text}")
    except requests.RequestException as error:
        print(f"Request failed: {error}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
