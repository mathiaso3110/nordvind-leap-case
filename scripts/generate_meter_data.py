"""Synthetic smart meter readings — stands in for real ingestion.

Production would be Snowpipe reading Parquet from Azure Blob. This exists so
there is something realistic in RAW to transform, mask and bill for.

Usage: python scripts/generate_meter_data.py > meter_readings.csv
"""

import csv
import random
import sys
from datetime import datetime, timedelta, timezone

METERS = 50
DAYS = 30
GRID_AREAS = ["DK1_NORTH", "DK1_SOUTH", "DK2_EAST"]

# Fixed seed: rerunning the generator must not silently change the numbers
# people are looking at in a demo.
random.seed(42)


def hourly_kwh(hour: int, has_ev: bool) -> float:
    """Rough Danish household curve: morning and evening peaks, low at night.

    An EV shows up as a large, flat overnight charging block — which is exactly
    why a consumption curve counts as personal data.
    """
    base = 0.3 if 0 <= hour < 6 else 0.6
    if 6 <= hour < 9 or 17 <= hour < 21:
        base += 0.8
    if has_ev and 1 <= hour < 5:
        base += 3.0
    return round(base * random.uniform(0.7, 1.3), 3)


def main() -> None:
    start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    ) - timedelta(days=DAYS)

    meters = [
        {
            "meter_id": f"DK{100000 + i}",
            "customer_id": f"CUST{2000 + i}",
            "grid_area": random.choice(GRID_AREAS),
            "has_ev": random.random() < 0.25,
        }
        for i in range(METERS)
    ]

    writer = csv.writer(sys.stdout)
    writer.writerow(
        ["meter_id", "customer_id", "grid_area", "read_at", "kwh"]
    )

    for meter in meters:
        for hour in range(DAYS * 24):
            read_at = start + timedelta(hours=hour)
            writer.writerow([
                meter["meter_id"],
                meter["customer_id"],
                meter["grid_area"],
                read_at.strftime("%Y-%m-%d %H:%M:%S"),
                hourly_kwh(read_at.hour, meter["has_ev"]),
            ])


if __name__ == "__main__":
    main()
