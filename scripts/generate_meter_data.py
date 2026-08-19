"""Synthetic smart meter readings — stands in for real ingestion.

Production would be Snowpipe reading Parquet from Azure Blob. This exists so
there is something realistic in RAW to transform, mask and bill for.

The CPR numbers are invented. Format is right (DDMMYY-SSSS) so masking policies
and column tagging behave as they would in production; the values belong to
nobody.

Usage: python scripts/generate_meter_data.py > meter_readings.csv
"""

import csv
import random
import sys
from datetime import date, datetime, timedelta, timezone

METERS = 50
DAYS = 30

# DK1 is west of the Great Belt, DK2 east — the real Danish price-area split.
REGIONS = {
    "DK1": ["NORTH", "SOUTH", "WEST"],
    "DK2": ["NORTH", "SOUTH", "EAST"],
}

# Fixed seed: rerunning the generator must not silently change the numbers
# people are looking at in a demo.
random.seed(42)


def fake_cpr() -> str:
    """DDMMYY-SSSS. Real CPR encodes birth date, century and sex in the last
    four digits; only the shape matters here."""
    birth = date(1940, 1, 1) + timedelta(days=random.randrange(23_000))
    return f"{birth:%d%m%y}-{random.randrange(1000, 10000)}"


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

    meters = []
    for i in range(METERS):
        region = random.choice(list(REGIONS))
        meters.append({
            "meter_id": f"DK{100000 + i}",
            "cpr": fake_cpr(),
            "region": region,
            "subregion": random.choice(REGIONS[region]),
            "has_ev": random.random() < 0.25,
        })

    writer = csv.writer(sys.stdout)
    writer.writerow(["meter_id", "cpr", "region", "subregion", "read_at", "kwh"])

    for meter in meters:
        for hour in range(DAYS * 24):
            read_at = start + timedelta(hours=hour)
            writer.writerow([
                meter["meter_id"],
                meter["cpr"],
                meter["region"],
                meter["subregion"],
                read_at.strftime("%Y-%m-%d %H:%M:%S"),
                hourly_kwh(read_at.hour, meter["has_ev"]),
            ])


if __name__ == "__main__":
    assert len(fake_cpr()) == 11 and fake_cpr()[6] == "-"
    main()
