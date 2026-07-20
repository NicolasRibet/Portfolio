#!/usr/bin/env python3
"""Generate reproducible synthetic data for the Talent Flow marketplace model.

The script creates 15 CSV files matching the normalized MySQL source schema:

- employers.csv
- locations.csv
- job_categories.csv
- skills.csv
- job_posts.csv
- job_skills.csv
- job_seekers.csv
- search_sessions.csv
- searches.csv
- sponsorship_campaigns.csv
- campaign_jobs.csv
- job_impressions.csv
- job_clicks.csv
- applications.csv
- sponsored_spend_daily.csv

Run from the repository root:

    python3 scripts/generate_data.py

By default, files are written to data/generated relative to the repository root.
All records are synthetic and generated with a fixed seed for reproducibility.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple, Union

try:
    import numpy as np
    import pandas as pd
    from faker import Faker
except ImportError as exc:  # pragma: no cover - friendly runtime guidance
    missing = getattr(exc, "name", "a required package")
    raise SystemExit(
        f"Missing dependency: {missing}. Install dependencies with:\n"
        "  python3 -m pip install pandas numpy faker"
    ) from exc


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SEED = 42
START_DATE = pd.Timestamp("2026-01-01 00:00:00")
END_DATE = pd.Timestamp("2026-03-31 23:59:59")

EMPLOYER_COUNT = 150
LOCATION_COUNT = 75
CATEGORY_COUNT = 24
SKILL_COUNT = 60
JOB_COUNT = 3_000
JOB_SEEKER_COUNT = 8_000
SESSION_COUNT = 30_000
SEARCH_COUNT = 45_000
CAMPAIGN_COUNT = 80

TARGET_IMPRESSION_MIN = 350_000
TARGET_IMPRESSION_MAX = 550_000
TARGET_CLICK_MIN = 20_000
TARGET_CLICK_MAX = 40_000
TARGET_APPLICATION_MIN = 3_000
TARGET_APPLICATION_MAX = 7_000

CSV_ORDER = [
    "employers.csv",
    "locations.csv",
    "job_categories.csv",
    "skills.csv",
    "job_posts.csv",
    "job_skills.csv",
    "job_seekers.csv",
    "search_sessions.csv",
    "searches.csv",
    "sponsorship_campaigns.csv",
    "campaign_jobs.csv",
    "job_impressions.csv",
    "job_clicks.csv",
    "applications.csv",
    "sponsored_spend_daily.csv",
]


@dataclass(frozen=True)
class CategoryDefinition:
    category_id: int
    category_name: str
    category_family: str
    parent_category_id: Optional[int]


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------


def weighted_choice(
    rng: np.random.Generator,
    values: Sequence,
    probabilities: Sequence[float],
    size: Optional[int] = None,
):
    """Choose values using normalized probabilities."""
    probs = np.asarray(probabilities, dtype=float)
    probs = probs / probs.sum()
    return rng.choice(np.asarray(values, dtype=object), size=size, p=probs)


def random_timestamp(
    rng: np.random.Generator,
    start: pd.Timestamp,
    end: pd.Timestamp,
    size: Optional[int] = None,
) -> Union[pd.Timestamp, pd.DatetimeIndex]:
    """Return uniformly distributed timestamps in an inclusive interval."""
    if end < start:
        raise ValueError("end must be on or after start")
    total_seconds = int((end - start).total_seconds())
    if size is None:
        return start + pd.to_timedelta(int(rng.integers(0, total_seconds + 1)), unit="s")
    offsets = rng.integers(0, total_seconds + 1, size=size)
    return pd.DatetimeIndex(start + pd.to_timedelta(offsets, unit="s"))


def weighted_dates(
    rng: np.random.Generator,
    start: pd.Timestamp,
    end: pd.Timestamp,
    size: int,
) -> pd.DatetimeIndex:
    """Generate dates with weekday traffic and gradual-quarter growth effects."""
    days = pd.date_range(start.normalize(), end.normalize(), freq="D")
    weekday_weight = np.array([1.08 if day.weekday() < 5 else 0.72 for day in days], dtype=float)
    trend_weight = np.linspace(0.92, 1.12, len(days))
    weights = weekday_weight * trend_weight
    weights /= weights.sum()
    selected = rng.choice(days.to_numpy(), size=size, p=weights)
    seconds = rng.integers(0, 24 * 60 * 60, size=size)
    timestamps = pd.to_datetime(selected) + pd.to_timedelta(seconds, unit="s")
    return pd.DatetimeIndex(timestamps)


def deterministic_uuid(namespace: str, seed: int, index: int) -> str:
    """Create a deterministic UUID so repeated runs are identical."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"talent-flow:{namespace}:{seed}:{index}"))


def round_money(values: Union[np.ndarray, pd.Series]) -> np.ndarray:
    return np.round(np.asarray(values, dtype=float), 2)


def safe_json(payload: Mapping[str, Optional[str]]) -> str:
    return json.dumps({k: v for k, v in payload.items() if v is not None}, separators=(",", ":"))


def cap_timestamp(value: pd.Timestamp) -> pd.Timestamp:
    return min(value, END_DATE)


def nullable_int_series(values: Iterable[Optional[int]]) -> pd.Series:
    return pd.Series(list(values), dtype="Int64")


# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------


def category_definitions() -> List[CategoryDefinition]:
    """Return 6 parent categories and 18 leaf categories."""
    definitions: List[CategoryDefinition] = []
    families = [
        (
            "Technology",
            ["Software Engineering", "Data & Analytics", "IT & Cybersecurity"],
        ),
        (
            "Business",
            ["Finance & Accounting", "Human Resources", "Product & Project Management"],
        ),
        (
            "Healthcare",
            ["Nursing", "Clinical Services", "Healthcare Administration"],
        ),
        (
            "Operations",
            ["Manufacturing", "Logistics & Supply Chain", "Construction & Skilled Trades"],
        ),
        (
            "Sales & Service",
            ["Sales", "Customer Service", "Hospitality & Retail"],
        ),
        (
            "Creative & Education",
            ["Marketing & Communications", "Design & Media", "Education & Training"],
        ),
    ]

    next_id = 1
    for family_name, children in families:
        parent_id = next_id
        definitions.append(CategoryDefinition(parent_id, family_name, family_name, None))
        next_id += 1
        for child in children:
            definitions.append(CategoryDefinition(next_id, child, family_name, parent_id))
            next_id += 1

    if len(definitions) != CATEGORY_COUNT:
        raise AssertionError(f"Expected {CATEGORY_COUNT} categories, created {len(definitions)}")
    return definitions


def skill_definitions() -> List[Tuple[str, str]]:
    skills_by_family: Mapping[str, Sequence[str]] = {
        "Technology": [
            "SQL", "Python", "Java", "JavaScript", "Cloud Platforms",
            "Data Modeling", "Machine Learning", "Cybersecurity", "DevOps", "API Integration",
        ],
        "Business": [
            "Financial Analysis", "Accounting", "Budgeting", "Recruiting",
            "Employee Relations", "Product Strategy", "Project Management",
            "Agile Delivery", "Business Analysis", "Stakeholder Management",
        ],
        "Healthcare": [
            "Patient Care", "Clinical Documentation", "Medication Administration",
            "Care Coordination", "Medical Terminology", "Healthcare Compliance",
            "Electronic Health Records", "Case Management", "Vital Signs", "HIPAA",
        ],
        "Operations": [
            "Lean Manufacturing", "Quality Control", "Inventory Management",
            "Supply Chain Planning", "Forklift Operation", "Equipment Maintenance",
            "Blueprint Reading", "Safety Compliance", "Procurement", "Process Improvement",
        ],
        "Sales & Service": [
            "Account Management", "Lead Generation", "Negotiation", "CRM",
            "Customer Support", "Conflict Resolution", "Point of Sale",
            "Merchandising", "Food Safety", "Upselling",
        ],
        "Creative & Education": [
            "Content Strategy", "Digital Marketing", "SEO", "Copywriting",
            "Graphic Design", "UX Design", "Video Editing", "Curriculum Development",
            "Instructional Design", "Classroom Management",
        ],
    }
    flattened = [(skill, family) for family, skills in skills_by_family.items() for skill in skills]
    if len(flattened) != SKILL_COUNT:
        raise AssertionError(f"Expected {SKILL_COUNT} skills, created {len(flattened)}")
    return flattened


def title_templates() -> Mapping[str, Sequence[str]]:
    return {
        "Software Engineering": [
            "Software Engineer", "Backend Engineer", "Frontend Engineer",
            "Full Stack Developer", "Platform Engineer", "Mobile Application Engineer",
        ],
        "Data & Analytics": [
            "Data Analyst", "Business Intelligence Developer", "Analytics Engineer",
            "Data Engineer", "Data Scientist", "Reporting Analyst",
        ],
        "IT & Cybersecurity": [
            "Systems Administrator", "Security Analyst", "Network Engineer",
            "IT Support Specialist", "Cloud Security Engineer", "Identity Access Analyst",
        ],
        "Finance & Accounting": [
            "Financial Analyst", "Staff Accountant", "Senior Accountant",
            "FP&A Analyst", "Payroll Specialist", "Controller",
        ],
        "Human Resources": [
            "HR Generalist", "Talent Acquisition Specialist", "Recruiter",
            "People Operations Analyst", "Compensation Analyst", "HR Business Partner",
        ],
        "Product & Project Management": [
            "Product Manager", "Project Manager", "Program Manager",
            "Product Operations Manager", "Scrum Master", "Implementation Manager",
        ],
        "Nursing": [
            "Registered Nurse", "Licensed Practical Nurse", "Nurse Practitioner",
            "Travel Nurse", "Charge Nurse", "Clinical Nurse Manager",
        ],
        "Clinical Services": [
            "Medical Assistant", "Physical Therapist", "Radiology Technologist",
            "Pharmacy Technician", "Behavioral Health Specialist", "Clinical Coordinator",
        ],
        "Healthcare Administration": [
            "Healthcare Administrator", "Medical Office Manager", "Patient Access Representative",
            "Revenue Cycle Analyst", "Health Information Specialist", "Practice Manager",
        ],
        "Manufacturing": [
            "Production Associate", "Manufacturing Engineer", "Quality Technician",
            "Machine Operator", "Maintenance Technician", "Plant Supervisor",
        ],
        "Logistics & Supply Chain": [
            "Supply Chain Analyst", "Warehouse Associate", "Logistics Coordinator",
            "Inventory Planner", "Procurement Specialist", "Distribution Manager",
        ],
        "Construction & Skilled Trades": [
            "Electrician", "HVAC Technician", "Plumber", "Carpenter",
            "Construction Project Coordinator", "Field Service Technician",
        ],
        "Sales": [
            "Account Executive", "Sales Development Representative", "Regional Sales Manager",
            "Inside Sales Representative", "Business Development Manager", "Solutions Consultant",
        ],
        "Customer Service": [
            "Customer Service Representative", "Customer Success Manager", "Support Specialist",
            "Contact Center Supervisor", "Client Services Coordinator", "Technical Support Representative",
        ],
        "Hospitality & Retail": [
            "Store Manager", "Retail Associate", "Restaurant Manager",
            "Front Desk Agent", "Barista", "Assistant General Manager",
        ],
        "Marketing & Communications": [
            "Marketing Manager", "Digital Marketing Specialist", "Communications Manager",
            "Content Marketing Specialist", "Growth Marketing Analyst", "Public Relations Coordinator",
        ],
        "Design & Media": [
            "Product Designer", "UX Researcher", "Graphic Designer",
            "Video Producer", "Art Director", "Content Designer",
        ],
        "Education & Training": [
            "Teacher", "Instructional Designer", "Training Specialist",
            "Academic Advisor", "Learning Program Manager", "Tutor",
        ],
    }


def location_reference() -> List[Tuple[str, Optional[str], str, Optional[str], float, float]]:
    """Curated marketplace locations with approximate coordinates."""
    locations = [
        ("New York", "NY", "US", "10001", 40.7128, -74.0060),
        ("Los Angeles", "CA", "US", "90012", 34.0522, -118.2437),
        ("Chicago", "IL", "US", "60601", 41.8781, -87.6298),
        ("Houston", "TX", "US", "77002", 29.7604, -95.3698),
        ("Phoenix", "AZ", "US", "85004", 33.4484, -112.0740),
        ("Philadelphia", "PA", "US", "19103", 39.9526, -75.1652),
        ("San Antonio", "TX", "US", "78205", 29.4241, -98.4936),
        ("San Diego", "CA", "US", "92101", 32.7157, -117.1611),
        ("Dallas", "TX", "US", "75201", 32.7767, -96.7970),
        ("San Jose", "CA", "US", "95113", 37.3382, -121.8863),
        ("Austin", "TX", "US", "78701", 30.2672, -97.7431),
        ("Jacksonville", "FL", "US", "32202", 30.3322, -81.6557),
        ("Fort Worth", "TX", "US", "76102", 32.7555, -97.3308),
        ("Columbus", "OH", "US", "43215", 39.9612, -82.9988),
        ("Charlotte", "NC", "US", "28202", 35.2271, -80.8431),
        ("San Francisco", "CA", "US", "94105", 37.7749, -122.4194),
        ("Indianapolis", "IN", "US", "46204", 39.7684, -86.1581),
        ("Seattle", "WA", "US", "98101", 47.6062, -122.3321),
        ("Denver", "CO", "US", "80202", 39.7392, -104.9903),
        ("Washington", "DC", "US", "20001", 38.9072, -77.0369),
        ("Boston", "MA", "US", "02108", 42.3601, -71.0589),
        ("Nashville", "TN", "US", "37201", 36.1627, -86.7816),
        ("Portland", "OR", "US", "97204", 45.5152, -122.6784),
        ("Vancouver", "WA", "US", "98660", 45.6387, -122.6615),
        ("Las Vegas", "NV", "US", "89101", 36.1699, -115.1398),
        ("Detroit", "MI", "US", "48226", 42.3314, -83.0458),
        ("Minneapolis", "MN", "US", "55401", 44.9778, -93.2650),
        ("Miami", "FL", "US", "33131", 25.7617, -80.1918),
        ("Atlanta", "GA", "US", "30303", 33.7490, -84.3880),
        ("Raleigh", "NC", "US", "27601", 35.7796, -78.6382),
        ("Salt Lake City", "UT", "US", "84101", 40.7608, -111.8910),
        ("Kansas City", "MO", "US", "64106", 39.0997, -94.5786),
        ("St. Louis", "MO", "US", "63101", 38.6270, -90.1994),
        ("Pittsburgh", "PA", "US", "15222", 40.4406, -79.9959),
        ("Cincinnati", "OH", "US", "45202", 39.1031, -84.5120),
        ("Cleveland", "OH", "US", "44114", 41.4993, -81.6944),
        ("Sacramento", "CA", "US", "95814", 38.5816, -121.4944),
        ("Tampa", "FL", "US", "33602", 27.9506, -82.4572),
        ("Orlando", "FL", "US", "32801", 28.5383, -81.3792),
        ("Baltimore", "MD", "US", "21201", 39.2904, -76.6122),
        ("Richmond", "VA", "US", "23219", 37.5407, -77.4360),
        ("Milwaukee", "WI", "US", "53202", 43.0389, -87.9065),
        ("Omaha", "NE", "US", "68102", 41.2565, -95.9345),
        ("Albuquerque", "NM", "US", "87102", 35.0844, -106.6504),
        ("Louisville", "KY", "US", "40202", 38.2527, -85.7585),
        ("Boise", "ID", "US", "83702", 43.6150, -116.2023),
        ("Honolulu", "HI", "US", "96813", 21.3069, -157.8583),
        ("Anchorage", "AK", "US", "99501", 61.2181, -149.9003),
        ("Toronto", "ON", "CA", "M5H", 43.6532, -79.3832),
        ("Vancouver", "BC", "CA", "V6B", 49.2827, -123.1207),
        ("Montreal", "QC", "CA", "H2Y", 45.5017, -73.5673),
        ("Calgary", "AB", "CA", "T2P", 51.0447, -114.0719),
        ("London", "England", "GB", "EC1A", 51.5074, -0.1278),
        ("Manchester", "England", "GB", "M1", 53.4808, -2.2426),
        ("Dublin", "Leinster", "IE", "D02", 53.3498, -6.2603),
        ("Paris", "Île-de-France", "FR", "75001", 48.8566, 2.3522),
        ("Lyon", "Auvergne-Rhône-Alpes", "FR", "69001", 45.7640, 4.8357),
        ("Berlin", "Berlin", "DE", "10115", 52.5200, 13.4050),
        ("Munich", "Bavaria", "DE", "80331", 48.1351, 11.5820),
        ("Amsterdam", "North Holland", "NL", "1012", 52.3676, 4.9041),
        ("Madrid", "Community of Madrid", "ES", "28001", 40.4168, -3.7038),
        ("Barcelona", "Catalonia", "ES", "08001", 41.3874, 2.1686),
        ("Milan", "Lombardy", "IT", "20121", 45.4642, 9.1900),
        ("Warsaw", "Masovian", "PL", "00-001", 52.2297, 21.0122),
        ("Prague", "Prague", "CZ", "11000", 50.0755, 14.4378),
        ("Stockholm", "Stockholm County", "SE", "11120", 59.3293, 18.0686),
        ("Sydney", "NSW", "AU", "2000", -33.8688, 151.2093),
        ("Melbourne", "VIC", "AU", "3000", -37.8136, 144.9631),
        ("Singapore", None, "SG", "018989", 1.3521, 103.8198),
        ("Tokyo", "Tokyo", "JP", "100-0001", 35.6762, 139.6503),
        ("Bengaluru", "Karnataka", "IN", "560001", 12.9716, 77.5946),
        ("Hyderabad", "Telangana", "IN", "500001", 17.3850, 78.4867),
        ("Mexico City", "CDMX", "MX", "06000", 19.4326, -99.1332),
        ("São Paulo", "São Paulo", "BR", "01000-000", -23.5505, -46.6333),
        ("Remote", None, "US", None, 39.8283, -98.5795),
    ]
    if len(locations) != LOCATION_COUNT:
        raise AssertionError(f"Expected {LOCATION_COUNT} locations, created {len(locations)}")
    return locations


# ---------------------------------------------------------------------------
# Table builders
# ---------------------------------------------------------------------------


def build_employers(rng: np.random.Generator, fake: Faker) -> pd.DataFrame:
    industries = [
        "Technology", "Healthcare", "Financial Services", "Retail", "Manufacturing",
        "Professional Services", "Transportation & Logistics", "Hospitality",
        "Education", "Construction", "Media & Communications", "Public Sector",
    ]
    industry_weights = [0.17, 0.14, 0.10, 0.10, 0.10, 0.10, 0.08, 0.05, 0.05, 0.04, 0.04, 0.03]
    size_bands = ["1-50", "51-200", "201-1,000", "1,001-5,000", "5,001+"]
    size_weights = [0.26, 0.29, 0.24, 0.14, 0.07]
    countries = ["US", "CA", "GB", "FR", "DE", "AU", "IN", "SG"]
    country_weights = [0.67, 0.09, 0.07, 0.05, 0.04, 0.03, 0.03, 0.02]

    names: List[str] = []
    seen = set()
    while len(names) < EMPLOYER_COUNT:
        candidate = fake.company().strip()
        if candidate not in seen:
            seen.add(candidate)
            names.append(candidate)

    selected_sizes = weighted_choice(rng, size_bands, size_weights, EMPLOYER_COUNT)
    verified_prob = {
        "1-50": 0.48,
        "51-200": 0.62,
        "201-1,000": 0.76,
        "1,001-5,000": 0.90,
        "5,001+": 0.97,
    }

    created = random_timestamp(
        rng,
        pd.Timestamp("2019-01-01"),
        pd.Timestamp("2025-12-15 23:59:59"),
        EMPLOYER_COUNT,
    )

    frame = pd.DataFrame(
        {
            "employer_id": np.arange(1, EMPLOYER_COUNT + 1, dtype=np.int64),
            "employer_name": names,
            "industry": weighted_choice(rng, industries, industry_weights, EMPLOYER_COUNT),
            "company_size_band": selected_sizes,
            "country_code": weighted_choice(rng, countries, country_weights, EMPLOYER_COUNT),
            "is_verified": [int(rng.random() < verified_prob[str(size)]) for size in selected_sizes],
            "created_at": created,
        }
    )
    return frame


def build_locations() -> pd.DataFrame:
    records = location_reference()
    return pd.DataFrame(
        [
            {
                "location_id": idx,
                "city": city,
                "state_region": state,
                "country_code": country,
                "postal_code": postal,
                "latitude": lat,
                "longitude": lon,
            }
            for idx, (city, state, country, postal, lat, lon) in enumerate(records, start=1)
        ]
    )


def build_categories() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "category_id": item.category_id,
                "category_name": item.category_name,
                "category_family": item.category_family,
                "parent_category_id": item.parent_category_id,
            }
            for item in category_definitions()
        ]
    )


def build_skills() -> pd.DataFrame:
    records = skill_definitions()
    return pd.DataFrame(
        [
            {"skill_id": idx, "skill_name": skill_name, "skill_family": family}
            for idx, (skill_name, family) in enumerate(records, start=1)
        ]
    )


def build_jobs(
    rng: np.random.Generator,
    employers: pd.DataFrame,
    locations: pd.DataFrame,
    categories: pd.DataFrame,
) -> pd.DataFrame:
    leaf_categories = categories[categories["parent_category_id"].notna()].copy()
    leaf_ids = leaf_categories["category_id"].to_numpy(dtype=int)
    category_weights = np.array(
        [0.11, 0.10, 0.06, 0.06, 0.05, 0.05, 0.08, 0.05, 0.04,
         0.06, 0.07, 0.06, 0.08, 0.07, 0.05, 0.05, 0.04, 0.02],
        dtype=float,
    )
    category_weights /= category_weights.sum()

    employer_size_weight = {
        "1-50": 0.55,
        "51-200": 0.95,
        "201-1,000": 1.35,
        "1,001-5,000": 2.00,
        "5,001+": 2.80,
    }
    employer_weights = employers["company_size_band"].map(employer_size_weight).to_numpy(dtype=float)
    employer_weights *= np.where(employers["is_verified"].to_numpy(dtype=int) == 1, 1.15, 0.90)
    employer_weights /= employer_weights.sum()

    location_weights = np.ones(len(locations), dtype=float)
    location_weights[:48] = 1.30  # US city demand
    location_weights[48:69] = 0.70
    location_weights[69:74] = 0.50
    location_weights[74] = 2.10  # Remote
    location_weights /= location_weights.sum()

    selected_employers = rng.choice(employers["employer_id"].to_numpy(), JOB_COUNT, p=employer_weights)
    selected_locations = rng.choice(locations["location_id"].to_numpy(), JOB_COUNT, p=location_weights)
    selected_categories = rng.choice(leaf_ids, JOB_COUNT, p=category_weights)

    category_name_lookup = categories.set_index("category_id")["category_name"].to_dict()
    titles = title_templates()
    levels = ["Entry", "Mid", "Senior", "Lead", "Manager"]
    level_weights = [0.18, 0.35, 0.27, 0.10, 0.10]
    employment_types = ["full_time", "part_time", "contract", "temporary", "internship"]
    employment_weights = [0.74, 0.08, 0.11, 0.04, 0.03]
    remote_types = ["onsite", "hybrid", "remote"]
    remote_weights = [0.54, 0.28, 0.18]

    job_rows: List[dict] = []
    job_created_min = pd.Timestamp("2025-11-01")
    job_posted_max = pd.Timestamp("2026-03-20 23:59:59")

    for job_id in range(1, JOB_COUNT + 1):
        category_id = int(selected_categories[job_id - 1])
        category_name = str(category_name_lookup[category_id])
        base_title = str(rng.choice(titles[category_name]))
        level = str(weighted_choice(rng, levels, level_weights))

        title_prefix = {
            "Entry": rng.choice(["Junior", "Associate", "Entry-Level"]),
            "Mid": "",
            "Senior": "Senior",
            "Lead": "Lead",
            "Manager": "Manager",
        }[level]
        if level == "Manager" and "Manager" in base_title:
            job_title = base_title
        elif title_prefix:
            job_title = f"{title_prefix} {base_title}"
        else:
            job_title = base_title
        job_title = " ".join(job_title.split())[:200]

        created_at = random_timestamp(rng, job_created_min, job_posted_max - pd.Timedelta(days=1))
        posted_at = cap_timestamp(created_at + pd.to_timedelta(int(rng.integers(1, 22)), unit="D"))
        posted_at = min(posted_at, job_posted_max)

        life_days = int(rng.integers(25, 91))
        expiry_candidate = posted_at + pd.Timedelta(days=life_days)
        has_expiry = rng.random() < 0.86
        expires_at = expiry_candidate if has_expiry else pd.NaT

        if posted_at > END_DATE:
            status = "draft"
        elif has_expiry and expiry_candidate <= END_DATE:
            status = str(weighted_choice(rng, ["closed", "expired"], [0.60, 0.40]))
        else:
            status = str(weighted_choice(rng, ["active", "paused", "closed"], [0.78, 0.12, 0.10]))
            if status == "closed":
                close_time = posted_at + pd.Timedelta(days=int(rng.integers(7, max(8, min(70, (END_DATE - posted_at).days + 1)))))
                expires_at = min(close_time, END_DATE)

        employment_type = str(weighted_choice(rng, employment_types, employment_weights))
        remote_type = str(weighted_choice(rng, remote_types, remote_weights))
        if int(selected_locations[job_id - 1]) == 75:
            remote_type = "remote"

        base_salary_by_family = {
            "Technology": 108_000,
            "Business": 82_000,
            "Healthcare": 88_000,
            "Operations": 67_000,
            "Sales & Service": 61_000,
            "Creative & Education": 66_000,
        }
        family = str(leaf_categories.set_index("category_id").loc[category_id, "category_family"])
        level_multiplier = {"Entry": 0.72, "Mid": 1.00, "Senior": 1.28, "Lead": 1.45, "Manager": 1.38}[level]
        employment_multiplier = {
            "full_time": 1.00,
            "part_time": 0.58,
            "contract": 1.10,
            "temporary": 0.72,
            "internship": 0.42,
        }[employment_type]
        midpoint = base_salary_by_family[family] * level_multiplier * employment_multiplier * float(rng.uniform(0.82, 1.18))
        salary_present = rng.random() < 0.72
        if salary_present:
            salary_min = round(midpoint * float(rng.uniform(0.82, 0.92)) / 100.0) * 100.0
            salary_max = round(midpoint * float(rng.uniform(1.08, 1.24)) / 100.0) * 100.0
            if salary_max <= salary_min:
                salary_max = salary_min + 5_000
            currency = "USD"
        else:
            salary_min = np.nan
            salary_max = np.nan
            currency = None

        updated_at = cap_timestamp(max(posted_at, random_timestamp(rng, posted_at, END_DATE)))

        job_rows.append(
            {
                "job_id": job_id,
                "employer_id": int(selected_employers[job_id - 1]),
                "location_id": int(selected_locations[job_id - 1]),
                "primary_category_id": category_id,
                "job_title": job_title,
                "employment_type": employment_type,
                "experience_level": level.lower(),
                "remote_type": remote_type,
                "salary_min": salary_min,
                "salary_max": salary_max,
                "salary_currency": currency,
                "posted_at": posted_at,
                "expires_at": expires_at,
                "status": status,
                "created_at": created_at,
                "updated_at": updated_at,
            }
        )

    return pd.DataFrame(job_rows)


def build_job_skills(
    rng: np.random.Generator,
    jobs: pd.DataFrame,
    categories: pd.DataFrame,
    skills: pd.DataFrame,
) -> pd.DataFrame:
    family_by_category = categories.set_index("category_id")["category_family"].to_dict()
    skills_by_family = {
        family: group["skill_id"].to_numpy(dtype=int)
        for family, group in skills.groupby("skill_family")
    }
    all_skill_ids = skills["skill_id"].to_numpy(dtype=int)

    rows: List[Tuple[int, int, int]] = []
    for job in jobs[["job_id", "primary_category_id"]].itertuples(index=False):
        family = str(family_by_category[int(job.primary_category_id)])
        core_pool = skills_by_family[family]
        skill_count = int(weighted_choice(rng, [3, 4, 5], [0.25, 0.50, 0.25]))
        core_count = min(skill_count, int(weighted_choice(rng, [2, 3, 4], [0.15, 0.60, 0.25])))
        core_count = min(core_count, len(core_pool))
        core = rng.choice(core_pool, size=core_count, replace=False).astype(int).tolist()
        remaining = skill_count - len(core)
        available_cross = np.setdiff1d(all_skill_ids, np.asarray(core, dtype=int), assume_unique=False)
        cross = rng.choice(available_cross, size=remaining, replace=False).astype(int).tolist() if remaining else []
        selected = core + cross
        rng.shuffle(selected)
        for position, skill_id in enumerate(selected):
            rows.append((int(job.job_id), int(skill_id), int(position < max(2, skill_count - 1))))

    return pd.DataFrame(rows, columns=["job_id", "skill_id", "is_required"])


def build_job_seekers(rng: np.random.Generator) -> pd.DataFrame:
    countries = ["US", "CA", "GB", "FR", "DE", "AU", "IN", "SG", "MX", "BR"]
    country_weights = [0.62, 0.08, 0.06, 0.04, 0.04, 0.03, 0.06, 0.02, 0.03, 0.02]
    levels = [None, "entry", "mid", "senior", "lead", "manager"]
    level_weights = [0.06, 0.23, 0.34, 0.24, 0.07, 0.06]
    created = random_timestamp(
        rng,
        pd.Timestamp("2021-01-01"),
        END_DATE - pd.Timedelta(days=1),
        JOB_SEEKER_COUNT,
    )
    return pd.DataFrame(
        {
            "job_seeker_id": np.arange(1, JOB_SEEKER_COUNT + 1, dtype=np.int64),
            "country_code": weighted_choice(rng, countries, country_weights, JOB_SEEKER_COUNT),
            "experience_level": weighted_choice(rng, levels, level_weights, JOB_SEEKER_COUNT),
            "created_at": created,
            "marketing_opt_in": rng.binomial(1, 0.37, size=JOB_SEEKER_COUNT).astype(int),
        }
    )


def build_sessions(
    rng: np.random.Generator,
    job_seekers: pd.DataFrame,
    seed: int,
) -> pd.DataFrame:
    signed_in_count = int(SESSION_COUNT * 0.65)
    signed_in_flags = np.array([1] * signed_in_count + [0] * (SESSION_COUNT - signed_in_count), dtype=int)
    rng.shuffle(signed_in_flags)

    # Heavy users account for more sessions than casual users.
    seeker_ids = job_seekers["job_seeker_id"].to_numpy(dtype=int)
    seeker_weights = rng.lognormal(mean=0.0, sigma=0.85, size=len(seeker_ids))
    seeker_weights /= seeker_weights.sum()
    selected_seekers = rng.choice(seeker_ids, size=signed_in_count, p=seeker_weights)
    seeker_iter = iter(selected_seekers.astype(int).tolist())

    session_times = weighted_dates(rng, START_DATE, END_DATE, SESSION_COUNT)
    device_values = ["desktop", "mobile_web", "ios", "android"]
    device_weights = [0.39, 0.27, 0.17, 0.17]
    traffic_values = ["organic", "paid_search", "email", "direct", "social", "partner"]
    traffic_weights = [0.39, 0.18, 0.12, 0.16, 0.09, 0.06]

    seeker_country = job_seekers.set_index("job_seeker_id")["country_code"].to_dict()
    anonymous_countries = ["US", "CA", "GB", "FR", "DE", "AU", "IN", "SG", "MX", "BR"]
    anonymous_weights = [0.64, 0.08, 0.06, 0.04, 0.04, 0.03, 0.05, 0.02, 0.02, 0.02]

    rows = []
    for index in range(1, SESSION_COUNT + 1):
        signed_in = signed_in_flags[index - 1] == 1
        job_seeker_id = int(next(seeker_iter)) if signed_in else None
        country_code = (
            str(seeker_country[job_seeker_id])
            if job_seeker_id is not None
            else str(weighted_choice(rng, anonymous_countries, anonymous_weights))
        )
        rows.append(
            {
                "session_id": deterministic_uuid("session", seed, index),
                "job_seeker_id": job_seeker_id,
                "anonymous_user_id": deterministic_uuid("anonymous-user", seed, int(rng.integers(1, 12_001))),
                "started_at": session_times[index - 1],
                "device_type": str(weighted_choice(rng, device_values, device_weights)),
                "traffic_source": str(weighted_choice(rng, traffic_values, traffic_weights)),
                "country_code": country_code,
            }
        )

    frame = pd.DataFrame(rows)
    frame["job_seeker_id"] = frame["job_seeker_id"].astype("Int64")
    return frame


def build_searches(
    rng: np.random.Generator,
    sessions: pd.DataFrame,
    categories: pd.DataFrame,
    locations: pd.DataFrame,
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Build searches and return an internal search-context table for impressions."""
    # Exactly 45,000 searches: 60% of sessions have 1, 30% have 2, and 10% have 3.
    counts = np.array([1] * 18_000 + [2] * 9_000 + [3] * 3_000, dtype=int)
    rng.shuffle(counts)
    if counts.sum() != SEARCH_COUNT:
        raise AssertionError("Search count distribution does not sum to SEARCH_COUNT")

    leaf_categories = categories[categories["parent_category_id"].notna()].copy()
    leaf_ids = leaf_categories["category_id"].to_numpy(dtype=int)
    leaf_names = leaf_categories.set_index("category_id")["category_name"].to_dict()
    query_variants: Mapping[str, Sequence[str]] = {
        name: [name.lower(), f"{name.lower()} jobs", f"remote {name.lower()}", f"{name.lower()} near me"]
        for name in leaf_categories["category_name"].tolist()
    }
    category_weights = np.array(
        [0.11, 0.10, 0.06, 0.06, 0.05, 0.05, 0.08, 0.05, 0.04,
         0.06, 0.07, 0.06, 0.08, 0.07, 0.05, 0.05, 0.04, 0.02],
        dtype=float,
    )
    category_weights /= category_weights.sum()

    location_ids = locations["location_id"].to_numpy(dtype=int)
    location_names = locations.set_index("location_id").apply(
        lambda row: row["city"] if pd.isna(row["state_region"]) else f"{row['city']}, {row['state_region']}",
        axis=1,
    ).to_dict()
    location_weights = np.ones(len(location_ids), dtype=float)
    location_weights[:48] = 1.35
    location_weights[48:69] = 0.65
    location_weights[69:74] = 0.45
    location_weights[74] = 1.70
    location_weights /= location_weights.sum()

    experience_values = [None, "entry", "mid", "senior", "lead", "manager"]
    experience_weights = [0.56, 0.11, 0.15, 0.12, 0.03, 0.03]
    employment_values = [None, "full_time", "part_time", "contract", "internship"]
    employment_weights = [0.62, 0.25, 0.04, 0.07, 0.02]
    remote_values = [None, "onsite", "hybrid", "remote"]
    remote_weights = [0.54, 0.12, 0.15, 0.19]

    search_rows: List[dict] = []
    context_rows: List[dict] = []
    search_id = 1

    for session_pos, session in enumerate(sessions.itertuples(index=False)):
        for search_number in range(int(counts[session_pos])):
            delay_minutes = int(rng.integers(0, 91)) + search_number * int(rng.integers(2, 16))
            searched_at = cap_timestamp(pd.Timestamp(session.started_at) + pd.Timedelta(minutes=delay_minutes))
            category_id = int(rng.choice(leaf_ids, p=category_weights))
            category_name = str(leaf_names[category_id])
            location_id = int(rng.choice(location_ids, p=location_weights))

            query_text = None if rng.random() < 0.04 else str(rng.choice(query_variants[category_name]))
            location_text = None if rng.random() < 0.22 else str(location_names[location_id])
            page_number = int(weighted_choice(rng, [1, 2, 3], [0.86, 0.11, 0.03]))

            is_zero_result = rng.random() < 0.05
            if is_zero_result:
                displayed_count = 0
                results_count = 0
            else:
                displayed_count = int(weighted_choice(rng, [6, 8, 10, 12, 15], [0.08, 0.17, 0.30, 0.30, 0.15]))
                results_count = int(displayed_count + rng.integers(0, 250))

            filters = safe_json(
                {
                    "experience_level": weighted_choice(rng, experience_values, experience_weights),
                    "employment_type": weighted_choice(rng, employment_values, employment_weights),
                    "remote_type": weighted_choice(rng, remote_values, remote_weights),
                }
            )
            search_rows.append(
                {
                    "search_id": search_id,
                    "session_id": session.session_id,
                    "searched_at": searched_at,
                    "query_text": query_text,
                    "location_text": location_text,
                    "filters_json": filters,
                    "results_count": results_count,
                    "page_number": page_number,
                }
            )
            context_rows.append(
                {
                    "search_id": search_id,
                    "session_id": session.session_id,
                    "searched_at": searched_at,
                    "category_id": category_id,
                    "location_id": location_id,
                    "displayed_count": displayed_count,
                    "page_number": page_number,
                    "device_type": session.device_type,
                    "job_seeker_id": session.job_seeker_id,
                }
            )
            search_id += 1

    searches = pd.DataFrame(search_rows)
    context = pd.DataFrame(context_rows)
    context["job_seeker_id"] = context["job_seeker_id"].astype("Int64")
    return searches, context


def build_campaigns(
    rng: np.random.Generator,
    employers: pd.DataFrame,
) -> pd.DataFrame:
    size_weight = {
        "1-50": 0.35,
        "51-200": 0.75,
        "201-1,000": 1.25,
        "1,001-5,000": 1.90,
        "5,001+": 2.50,
    }
    weights = employers["company_size_band"].map(size_weight).to_numpy(dtype=float)
    weights *= np.where(employers["is_verified"].to_numpy(dtype=int) == 1, 1.40, 0.70)
    weights /= weights.sum()
    employer_ids = rng.choice(employers["employer_id"].to_numpy(dtype=int), CAMPAIGN_COUNT, p=weights)

    rows = []
    for campaign_id in range(1, CAMPAIGN_COUNT + 1):
        start = pd.Timestamp("2025-12-15") + pd.Timedelta(days=int(rng.integers(0, 86)))
        duration_days = int(rng.integers(30, 101))
        end = start + pd.Timedelta(days=duration_days)
        has_end = rng.random() < 0.88
        end_date = end.date() if has_end else None

        if start > END_DATE:
            status = "planned"
        elif has_end and end <= END_DATE:
            status = "completed"
        else:
            status = str(weighted_choice(rng, ["active", "paused"], [0.84, 0.16]))

        billing = str(weighted_choice(rng, ["cpc", "cpa"], [0.76, 0.24]))
        daily_budget = round(float(rng.lognormal(mean=math.log(420), sigma=0.65)), 2)
        daily_budget = float(np.clip(daily_budget, 80.0, 3_500.0))
        created_at = random_timestamp(
            rng,
            pd.Timestamp("2025-11-01"),
            min(pd.Timestamp(start), END_DATE),
        )
        rows.append(
            {
                "campaign_id": campaign_id,
                "employer_id": int(employer_ids[campaign_id - 1]),
                "campaign_name": f"Q1 2026 Talent Campaign {campaign_id:03d}",
                "start_date": start.date(),
                "end_date": end_date,
                "daily_budget": daily_budget,
                "billing_model": billing,
                "campaign_status": status,
                "created_at": created_at,
            }
        )

    return pd.DataFrame(rows)


def build_campaign_jobs(
    rng: np.random.Generator,
    campaigns: pd.DataFrame,
    jobs: pd.DataFrame,
) -> pd.DataFrame:
    jobs_by_employer = {
        int(employer_id): group["job_id"].to_numpy(dtype=int)
        for employer_id, group in jobs.groupby("employer_id")
    }
    rows: List[dict] = []

    for campaign in campaigns.itertuples(index=False):
        employer_jobs = jobs_by_employer.get(int(campaign.employer_id), np.array([], dtype=int))
        if len(employer_jobs) == 0:
            continue
        desired = int(weighted_choice(rng, [4, 5, 6], [0.30, 0.45, 0.25]))
        count = min(desired, len(employer_jobs))
        selected = rng.choice(employer_jobs, size=count, replace=False)
        for job_id in selected:
            added_start = max(pd.Timestamp(campaign.created_at), pd.Timestamp(campaign.start_date) - pd.Timedelta(days=14))
            added_end = min(pd.Timestamp(campaign.start_date) + pd.Timedelta(days=7), END_DATE)
            added_at = random_timestamp(rng, added_start, max(added_start, added_end))
            rows.append(
                {
                    "campaign_id": int(campaign.campaign_id),
                    "job_id": int(job_id),
                    "added_at": added_at,
                }
            )

    return pd.DataFrame(rows)


def build_impressions(
    rng: np.random.Generator,
    search_context: pd.DataFrame,
    jobs: pd.DataFrame,
    campaigns: pd.DataFrame,
    campaign_jobs: pd.DataFrame,
) -> pd.DataFrame:
    """Create search-result impressions at approximately 450k rows.

    Candidate pools are precomputed as NumPy arrays so the generator remains
    fast even on a laptop while still favoring category and location matches.
    """
    eligible = jobs[jobs["status"] != "draft"].copy()
    all_job_ids = eligible["job_id"].to_numpy(dtype=np.int64)

    category_pools: Dict[int, np.ndarray] = {
        int(category_id): group["job_id"].to_numpy(dtype=np.int64)
        for category_id, group in eligible.groupby("primary_category_id", sort=False)
    }
    category_location_pools: Dict[Tuple[int, int], np.ndarray] = {
        (int(category_id), int(location_id)): group["job_id"].to_numpy(dtype=np.int64)
        for (category_id, location_id), group in eligible.groupby(
            ["primary_category_id", "location_id"], sort=False
        )
    }

    # Each campaign-job pair is valid by construction. Pick one campaign per job
    # for efficient sponsored-impression attribution.
    campaign_by_job: Dict[int, int] = {}
    for row in campaign_jobs.sample(frac=1.0, random_state=SEED).itertuples(index=False):
        campaign_by_job.setdefault(int(row.job_id), int(row.campaign_id))
    billing_by_campaign = campaigns.set_index("campaign_id")["billing_model"].to_dict()

    impression_ids: List[int] = []
    search_ids: List[int] = []
    job_ids_out: List[int] = []
    campaign_ids: List[Optional[int]] = []
    impressed_times: List[pd.Timestamp] = []
    positions: List[int] = []
    sponsored_flags: List[int] = []
    relevance_scores: List[float] = []
    bid_amounts: List[Optional[float]] = []
    device_types: List[str] = []
    seeker_ids: List[Optional[int]] = []

    impression_id = 1
    for search in search_context.itertuples(index=False):
        count = int(search.displayed_count)
        if count <= 0:
            continue

        category_id = int(search.category_id)
        location_id = int(search.location_id)
        category_pool = category_pools.get(category_id, all_job_ids)
        local_pool = category_location_pools.get((category_id, location_id), np.empty(0, dtype=np.int64))

        local_count = min(len(local_pool), int(round(count * 0.55)))
        selected: List[int] = []
        if local_count > 0:
            selected.extend(
                rng.choice(local_pool, size=local_count, replace=False).astype(int).tolist()
            )

        remaining = count - len(selected)
        if remaining > 0:
            if selected:
                remaining_pool = category_pool[~np.isin(category_pool, np.asarray(selected, dtype=np.int64))]
            else:
                remaining_pool = category_pool
            if len(remaining_pool) < remaining:
                remaining_pool = all_job_ids[~np.isin(all_job_ids, np.asarray(selected, dtype=np.int64))]
            remaining = min(remaining, len(remaining_pool))
            selected.extend(
                rng.choice(remaining_pool, size=remaining, replace=False).astype(int).tolist()
            )

        rng.shuffle(selected)
        base_position = (int(search.page_number) - 1) * 10
        search_time = pd.Timestamp(search.searched_at)
        seeker_value = None if pd.isna(search.job_seeker_id) else int(search.job_seeker_id)

        for offset, job_id in enumerate(selected, start=1):
            position = base_position + offset
            relevance = float(
                np.clip(
                    rng.beta(5.5, 2.2) * (1.04 - min(position, 30) * 0.006),
                    0.05,
                    0.9999,
                )
            )

            campaign_id = campaign_by_job.get(int(job_id))
            sponsored = int(campaign_id is not None and rng.random() < 0.65)
            bid_amount: Optional[float] = None
            if sponsored:
                billing = str(billing_by_campaign[int(campaign_id)])
                bid_amount = (
                    round(float(rng.uniform(0.80, 4.50)), 2)
                    if billing == "cpc"
                    else round(float(rng.uniform(18.0, 65.0)), 2)
                )
                relevance = float(np.clip(relevance + rng.uniform(0.01, 0.08), 0.05, 0.9999))
            else:
                campaign_id = None

            impression_ids.append(impression_id)
            search_ids.append(int(search.search_id))
            job_ids_out.append(int(job_id))
            campaign_ids.append(campaign_id)
            impressed_times.append(
                cap_timestamp(search_time + pd.Timedelta(seconds=int(rng.integers(0, 18))))
            )
            positions.append(int(position))
            sponsored_flags.append(sponsored)
            relevance_scores.append(round(relevance, 4))
            bid_amounts.append(bid_amount)
            device_types.append(str(search.device_type))
            seeker_ids.append(seeker_value)
            impression_id += 1

    frame = pd.DataFrame(
        {
            "impression_id": np.asarray(impression_ids, dtype=np.int64),
            "search_id": np.asarray(search_ids, dtype=np.int64),
            "job_id": np.asarray(job_ids_out, dtype=np.int64),
            "campaign_id": pd.Series(campaign_ids, dtype="Int64"),
            "impressed_at": pd.to_datetime(impressed_times),
            "position": np.asarray(positions, dtype=np.int64),
            "is_sponsored": np.asarray(sponsored_flags, dtype=np.int8),
            "predicted_relevance_score": np.asarray(relevance_scores, dtype=float),
            "bid_amount": bid_amounts,
            "_device_type": device_types,
            "_job_seeker_id": pd.Series(seeker_ids, dtype="Int64"),
        }
    )
    return frame

def build_clicks(
    rng: np.random.Generator,
    impressions_internal: pd.DataFrame,
) -> pd.DataFrame:
    position = impressions_internal["position"].to_numpy(dtype=float)
    relevance = impressions_internal["predicted_relevance_score"].to_numpy(dtype=float)
    sponsored = impressions_internal["is_sponsored"].to_numpy(dtype=int)
    device_factor = impressions_internal["_device_type"].map(
        {"desktop": 1.00, "mobile_web": 0.94, "ios": 1.07, "android": 1.03}
    ).to_numpy(dtype=float)

    position_factor = np.exp(-0.055 * np.maximum(position - 1.0, 0.0))
    click_probability = 0.045 + 0.055 * relevance
    click_probability *= position_factor
    click_probability *= device_factor
    click_probability *= np.where(sponsored == 1, 1.17, 1.00)
    click_probability = np.clip(click_probability, 0.006, 0.24)

    clicked_mask = rng.random(len(impressions_internal)) < click_probability
    clicked = impressions_internal.loc[
        clicked_mask,
        ["impression_id", "impressed_at", "_job_seeker_id", "job_id", "is_sponsored", "campaign_id"],
    ].copy()
    delays = rng.integers(2, 900, size=len(clicked))
    clicked_at = pd.to_datetime(clicked["impressed_at"]) + pd.to_timedelta(delays, unit="s")
    clicked_at = clicked_at.where(clicked_at <= END_DATE, END_DATE)
    dwell = np.clip(np.rint(rng.lognormal(mean=4.0, sigma=0.85, size=len(clicked))), 2, 3_600).astype(int)

    clicks = pd.DataFrame(
        {
            "click_id": np.arange(1, len(clicked) + 1, dtype=np.int64),
            "impression_id": clicked["impression_id"].to_numpy(dtype=np.int64),
            "clicked_at": clicked_at.to_numpy(),
            "dwell_seconds": dwell,
            "_job_seeker_id": clicked["_job_seeker_id"].to_numpy(),
            "_job_id": clicked["job_id"].to_numpy(dtype=np.int64),
            "_is_sponsored": clicked["is_sponsored"].to_numpy(dtype=int),
            "_campaign_id": clicked["campaign_id"].to_numpy(),
        }
    )
    clicks["_job_seeker_id"] = clicks["_job_seeker_id"].astype("Int64")
    clicks["_campaign_id"] = clicks["_campaign_id"].astype("Int64")
    return clicks


def build_applications(
    rng: np.random.Generator,
    clicks_internal: pd.DataFrame,
    job_seekers: pd.DataFrame,
    jobs: pd.DataFrame,
) -> pd.DataFrame:
    signed_clicks = clicks_internal[clicks_internal["_job_seeker_id"].notna()].copy()
    conversion_probability = np.where(
        signed_clicks["_is_sponsored"].to_numpy(dtype=int) == 1,
        0.255,
        0.225,
    )
    dwell_factor = np.clip(signed_clicks["dwell_seconds"].to_numpy(dtype=float) / 120.0, 0.65, 1.30)
    conversion_probability = np.clip(conversion_probability * dwell_factor, 0.11, 0.34)
    apply_mask = rng.random(len(signed_clicks)) < conversion_probability
    selected = signed_clicks.loc[apply_mask].copy()

    # Keep one application per seeker/job pair in this synthetic operational source.
    selected = selected.drop_duplicates(subset=["_job_seeker_id", "_job_id"], keep="first")

    rows: List[dict] = []
    seen_pairs = set()
    application_id = 1

    status_values = ["submitted", "reviewed", "rejected", "hired", "withdrawn"]
    status_weights = [0.43, 0.25, 0.22, 0.04, 0.06]

    for click in selected.to_dict("records"):
        seeker_id = int(click["_job_seeker_id"])
        job_id = int(click["_job_id"])
        pair = (seeker_id, job_id)
        if pair in seen_pairs:
            continue
        seen_pairs.add(pair)

        started_at = cap_timestamp(
            pd.Timestamp(click["clicked_at"])
            + pd.Timedelta(seconds=int(rng.integers(20, 3_600)))
        )
        status = str(weighted_choice(rng, status_values, status_weights))
        if rng.random() < 0.11:
            status = "started"

        if status == "started":
            submitted_at = pd.NaT
            completion_seconds = None
        else:
            completion_seconds = int(
                np.clip(round(rng.lognormal(mean=6.4, sigma=0.65)), 45, 7_200)
            )
            submitted_at = cap_timestamp(
                started_at + pd.Timedelta(seconds=completion_seconds)
            )

        source = (
            "sponsored_search"
            if int(click["_is_sponsored"]) == 1
            else "organic_search"
        )
        rows.append(
            {
                "application_id": application_id,
                "job_id": job_id,
                "job_seeker_id": seeker_id,
                "click_id": int(click["click_id"]),
                "started_at": started_at,
                "submitted_at": submitted_at,
                "application_status": status,
                "application_source": source,
                "completion_seconds": completion_seconds,
            }
        )
        application_id += 1

    # Add direct, saved-job, and email-alert applications with no click attribution.
    direct_target = max(350, int(len(rows) * 0.12))
    seeker_ids = job_seekers["job_seeker_id"].to_numpy(dtype=int)
    eligible_jobs = jobs[(jobs["status"] != "draft") & (jobs["posted_at"] <= END_DATE)].copy()
    job_ids = eligible_jobs["job_id"].to_numpy(dtype=int)

    attempts = 0
    while direct_target > 0 and attempts < direct_target * 20:
        attempts += 1
        seeker_id = int(rng.choice(seeker_ids))
        job_row = eligible_jobs.iloc[int(rng.integers(0, len(eligible_jobs)))]
        job_id = int(job_row["job_id"])
        pair = (seeker_id, job_id)
        if pair in seen_pairs:
            continue

        earliest = max(START_DATE, pd.Timestamp(job_row["posted_at"]))
        latest = min(END_DATE, pd.Timestamp(job_row["expires_at"]) if pd.notna(job_row["expires_at"]) else END_DATE)
        if latest < earliest:
            continue
        started_at = random_timestamp(rng, earliest, latest)
        status = str(weighted_choice(rng, status_values, [0.46, 0.24, 0.20, 0.04, 0.06]))
        if rng.random() < 0.08:
            status = "started"
        if status == "started":
            submitted_at = pd.NaT
            completion_seconds = None
        else:
            completion_seconds = int(np.clip(round(rng.lognormal(mean=6.5, sigma=0.70)), 45, 7_200))
            submitted_at = cap_timestamp(pd.Timestamp(started_at) + pd.Timedelta(seconds=completion_seconds))
        source = str(weighted_choice(rng, ["saved_job", "email_alert", "direct"], [0.42, 0.38, 0.20]))
        rows.append(
            {
                "application_id": application_id,
                "job_id": job_id,
                "job_seeker_id": seeker_id,
                "click_id": None,
                "started_at": started_at,
                "submitted_at": submitted_at,
                "application_status": status,
                "application_source": source,
                "completion_seconds": completion_seconds,
            }
        )
        seen_pairs.add(pair)
        application_id += 1
        direct_target -= 1

    frame = pd.DataFrame(rows)
    frame["click_id"] = frame["click_id"].astype("Int64")
    frame["completion_seconds"] = frame["completion_seconds"].astype("Int64")
    return frame


def build_spend_daily(
    rng: np.random.Generator,
    impressions_internal: pd.DataFrame,
    clicks_internal: pd.DataFrame,
    applications: pd.DataFrame,
    campaigns: pd.DataFrame,
) -> pd.DataFrame:
    sponsored = impressions_internal[impressions_internal["is_sponsored"] == 1].copy()
    if sponsored.empty:
        return pd.DataFrame(
            columns=[
                "spend_date", "campaign_id", "job_id", "sponsored_impressions",
                "sponsored_clicks", "sponsored_applications", "billed_units",
                "unit_cost", "spend_amount",
            ]
        )

    sponsored["spend_date"] = pd.to_datetime(sponsored["impressed_at"]).dt.date
    impression_agg = sponsored.groupby(
        ["spend_date", "campaign_id", "job_id"], as_index=False
    ).agg(sponsored_impressions=("impression_id", "count"))

    click_map = clicks_internal[["click_id", "_campaign_id", "_job_id", "clicked_at"]].copy()
    click_map = click_map[click_map["_campaign_id"].notna()].copy()
    click_map["spend_date"] = pd.to_datetime(click_map["clicked_at"]).dt.date
    click_agg = click_map.groupby(
        ["spend_date", "_campaign_id", "_job_id"], as_index=False
    ).agg(sponsored_clicks=("click_id", "count"))
    click_agg = click_agg.rename(columns={"_campaign_id": "campaign_id", "_job_id": "job_id"})

    app_sponsored = applications[applications["click_id"].notna()].merge(
        clicks_internal[["click_id", "_campaign_id", "_job_id", "clicked_at"]],
        on="click_id",
        how="inner",
    )
    app_sponsored = app_sponsored[app_sponsored["_campaign_id"].notna()].copy()
    # Attribute CPA billing to the click date so daily funnel counts reconcile.
    app_sponsored["spend_date"] = pd.to_datetime(app_sponsored["clicked_at"]).dt.date
    app_agg = app_sponsored.groupby(
        ["spend_date", "_campaign_id", "_job_id"], as_index=False
    ).agg(sponsored_applications=("application_id", "count"))
    app_agg = app_agg.rename(columns={"_campaign_id": "campaign_id", "_job_id": "job_id"})

    spend = impression_agg.merge(click_agg, on=["spend_date", "campaign_id", "job_id"], how="left")
    spend = spend.merge(app_agg, on=["spend_date", "campaign_id", "job_id"], how="left")
    spend[["sponsored_clicks", "sponsored_applications"]] = spend[
        ["sponsored_clicks", "sponsored_applications"]
    ].fillna(0).astype(int)

    campaign_meta = campaigns.set_index("campaign_id")[["billing_model", "daily_budget"]].to_dict("index")
    billed_units: List[int] = []
    unit_costs: List[float] = []
    spend_amounts: List[float] = []

    campaign_unit_cost = {
        int(c.campaign_id): (
            round(float(rng.uniform(1.20, 4.20)), 2)
            if c.billing_model == "cpc"
            else round(float(rng.uniform(22.0, 65.0)), 2)
        )
        for c in campaigns.itertuples(index=False)
    }

    for row in spend.itertuples(index=False):
        meta = campaign_meta[int(row.campaign_id)]
        units = int(row.sponsored_clicks if meta["billing_model"] == "cpc" else row.sponsored_applications)
        cost = float(campaign_unit_cost[int(row.campaign_id)])
        raw_spend = round(units * cost, 2)
        capped_spend = min(raw_spend, float(meta["daily_budget"]))
        if units > 0 and capped_spend < raw_spend:
            cost = round(capped_spend / units, 2)
            capped_spend = round(units * cost, 2)
        billed_units.append(units)
        unit_costs.append(cost)
        spend_amounts.append(capped_spend)

    spend["billed_units"] = billed_units
    spend["unit_cost"] = unit_costs
    spend["spend_amount"] = spend_amounts
    spend["campaign_id"] = spend["campaign_id"].astype(int)
    spend["job_id"] = spend["job_id"].astype(int)

    return spend[
        [
            "spend_date", "campaign_id", "job_id", "sponsored_impressions",
            "sponsored_clicks", "sponsored_applications", "billed_units",
            "unit_cost", "spend_amount",
        ]
    ].sort_values(["spend_date", "campaign_id", "job_id"]).reset_index(drop=True)


# ---------------------------------------------------------------------------
# Validation and export
# ---------------------------------------------------------------------------


def validate_tables(tables: Mapping[str, pd.DataFrame]) -> None:
    """Fail fast when generated data violates the source model or target volumes."""
    employers = tables["employers.csv"]
    locations = tables["locations.csv"]
    categories = tables["job_categories.csv"]
    skills = tables["skills.csv"]
    jobs = tables["job_posts.csv"]
    job_skills = tables["job_skills.csv"]
    seekers = tables["job_seekers.csv"]
    sessions = tables["search_sessions.csv"]
    searches = tables["searches.csv"]
    campaigns = tables["sponsorship_campaigns.csv"]
    campaign_jobs = tables["campaign_jobs.csv"]
    impressions = tables["job_impressions.csv"]
    clicks = tables["job_clicks.csv"]
    applications = tables["applications.csv"]
    spend = tables["sponsored_spend_daily.csv"]

    expected_counts = {
        "employers.csv": EMPLOYER_COUNT,
        "locations.csv": LOCATION_COUNT,
        "job_categories.csv": CATEGORY_COUNT,
        "skills.csv": SKILL_COUNT,
        "job_posts.csv": JOB_COUNT,
        "job_seekers.csv": JOB_SEEKER_COUNT,
        "search_sessions.csv": SESSION_COUNT,
        "searches.csv": SEARCH_COUNT,
        "sponsorship_campaigns.csv": CAMPAIGN_COUNT,
    }
    for filename, expected in expected_counts.items():
        actual = len(tables[filename])
        assert actual == expected, f"{filename}: expected {expected:,} rows, got {actual:,}"

    assert 9_000 <= len(job_skills) <= 15_000
    assert 300 <= len(campaign_jobs) <= 500
    assert TARGET_IMPRESSION_MIN <= len(impressions) <= TARGET_IMPRESSION_MAX
    assert TARGET_CLICK_MIN <= len(clicks) <= TARGET_CLICK_MAX
    assert TARGET_APPLICATION_MIN <= len(applications) <= TARGET_APPLICATION_MAX
    assert len(spend) >= 1_000, "Expected several thousand sponsored spend rows"

    primary_keys = {
        "employers.csv": ["employer_id"],
        "locations.csv": ["location_id"],
        "job_categories.csv": ["category_id"],
        "skills.csv": ["skill_id"],
        "job_posts.csv": ["job_id"],
        "job_skills.csv": ["job_id", "skill_id"],
        "job_seekers.csv": ["job_seeker_id"],
        "search_sessions.csv": ["session_id"],
        "searches.csv": ["search_id"],
        "sponsorship_campaigns.csv": ["campaign_id"],
        "campaign_jobs.csv": ["campaign_id", "job_id"],
        "job_impressions.csv": ["impression_id"],
        "job_clicks.csv": ["click_id"],
        "applications.csv": ["application_id"],
        "sponsored_spend_daily.csv": ["spend_date", "campaign_id", "job_id"],
    }
    for filename, columns in primary_keys.items():
        assert not tables[filename].duplicated(columns).any(), f"Duplicate primary key in {filename}"

    # Foreign-key integrity.
    assert set(jobs["employer_id"]).issubset(set(employers["employer_id"]))
    assert set(jobs["location_id"]).issubset(set(locations["location_id"]))
    assert set(jobs["primary_category_id"]).issubset(set(categories["category_id"]))
    assert set(job_skills["job_id"]).issubset(set(jobs["job_id"]))
    assert set(job_skills["skill_id"]).issubset(set(skills["skill_id"]))
    assert set(sessions["job_seeker_id"].dropna().astype(int)).issubset(set(seekers["job_seeker_id"]))
    assert set(searches["session_id"]).issubset(set(sessions["session_id"]))
    assert set(campaigns["employer_id"]).issubset(set(employers["employer_id"]))
    assert set(campaign_jobs["campaign_id"]).issubset(set(campaigns["campaign_id"]))
    assert set(campaign_jobs["job_id"]).issubset(set(jobs["job_id"]))
    assert set(impressions["search_id"]).issubset(set(searches["search_id"]))
    assert set(impressions["job_id"]).issubset(set(jobs["job_id"]))
    assert set(impressions["campaign_id"].dropna().astype(int)).issubset(set(campaigns["campaign_id"]))
    assert set(clicks["impression_id"]).issubset(set(impressions["impression_id"]))
    assert set(applications["job_id"]).issubset(set(jobs["job_id"]))
    assert set(applications["job_seeker_id"]).issubset(set(seekers["job_seeker_id"]))
    assert set(applications["click_id"].dropna().astype(int)).issubset(set(clicks["click_id"]))
    assert set(spend["campaign_id"]).issubset(set(campaigns["campaign_id"]))
    assert set(spend["job_id"]).issubset(set(jobs["job_id"]))

    # Relationship-specific rules.
    employer_by_job = jobs.set_index("job_id")["employer_id"].to_dict()
    employer_by_campaign = campaigns.set_index("campaign_id")["employer_id"].to_dict()
    assert all(
        int(employer_by_job[int(row.job_id)]) == int(employer_by_campaign[int(row.campaign_id)])
        for row in campaign_jobs.itertuples(index=False)
    ), "Campaign jobs must belong to the campaign employer"

    campaign_job_pairs = set(map(tuple, campaign_jobs[["campaign_id", "job_id"]].astype(int).to_numpy()))
    sponsored_pairs = set(
        map(
            tuple,
            impressions.loc[impressions["campaign_id"].notna(), ["campaign_id", "job_id"]]
            .astype(int)
            .to_numpy(),
        )
    )
    assert sponsored_pairs.issubset(campaign_job_pairs)
    spend_pairs = set(map(tuple, spend[["campaign_id", "job_id"]].astype(int).to_numpy()))
    assert spend_pairs.issubset(campaign_job_pairs)

    assert not impressions.duplicated(["search_id", "job_id", "position"]).any()
    assert clicks["impression_id"].is_unique
    assert not applications.duplicated(["job_seeker_id", "job_id"]).any()

    signed_in_share = sessions["job_seeker_id"].notna().mean()
    assert abs(signed_in_share - 0.65) < 0.0001
    searches_per_session = searches.groupby("session_id").size()
    assert searches_per_session.between(1, 3).all()

    assert (searches["results_count"] >= 0).all()
    assert impressions["predicted_relevance_score"].between(0, 1).all()
    assert (impressions["position"] >= 1).all()
    assert (clicks["dwell_seconds"] >= 0).all()
    assert (applications["completion_seconds"].dropna() >= 0).all()
    assert (spend[["sponsored_impressions", "sponsored_clicks", "sponsored_applications", "billed_units"]] >= 0).all().all()
    assert (spend[["unit_cost", "spend_amount"]] >= 0).all().all()
    assert (spend["sponsored_clicks"] <= spend["sponsored_impressions"]).all()
    assert (spend["sponsored_applications"] <= spend["sponsored_clicks"]).all()

    submitted = applications[applications["submitted_at"].notna()]
    assert (pd.to_datetime(submitted["submitted_at"]) >= pd.to_datetime(submitted["started_at"])).all()
    assert applications.loc[applications["application_status"] == "started", "submitted_at"].isna().all()


def prepare_for_csv(frame: pd.DataFrame) -> pd.DataFrame:
    """Format dates consistently while retaining blank values for SQL NULLs."""
    output = frame.copy()
    date_columns = {"start_date", "end_date", "spend_date"}
    datetime_columns = {
        "created_at", "updated_at", "posted_at", "expires_at", "started_at",
        "searched_at", "impressed_at", "clicked_at", "submitted_at", "added_at",
    }

    for column in output.columns:
        if column in date_columns:
            output[column] = pd.to_datetime(output[column], errors="coerce").dt.strftime("%Y-%m-%d")
        elif column in datetime_columns:
            output[column] = pd.to_datetime(output[column], errors="coerce").dt.strftime("%Y-%m-%d %H:%M:%S")
    return output


def write_outputs(output_dir: Path, tables: Mapping[str, pd.DataFrame]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename in CSV_ORDER:
        prepare_for_csv(tables[filename]).to_csv(output_dir / filename, index=False, na_rep="")


def generate(output_dir: Path, seed: int = SEED) -> Mapping[str, pd.DataFrame]:
    random.seed(seed)
    np.random.seed(seed)
    rng = np.random.default_rng(seed)
    fake = Faker("en_US")
    fake.seed_instance(seed)

    print("Generating dimensions and marketplace entities...")
    employers = build_employers(rng, fake)
    locations = build_locations()
    categories = build_categories()
    skills = build_skills()
    jobs = build_jobs(rng, employers, locations, categories)
    job_skills = build_job_skills(rng, jobs, categories, skills)
    seekers = build_job_seekers(rng)

    print("Generating sessions, searches, and sponsorships...")
    sessions = build_sessions(rng, seekers, seed)
    searches, search_context = build_searches(rng, sessions, categories, locations)
    campaigns = build_campaigns(rng, employers)
    campaign_jobs = build_campaign_jobs(rng, campaigns, jobs)

    print("Generating impression, click, application, and spend events...")
    impressions_internal = build_impressions(rng, search_context, jobs, campaigns, campaign_jobs)
    clicks_internal = build_clicks(rng, impressions_internal)
    applications = build_applications(rng, clicks_internal, seekers, jobs)
    spend = build_spend_daily(rng, impressions_internal, clicks_internal, applications, campaigns)

    impressions = impressions_internal.drop(columns=["_device_type", "_job_seeker_id"])
    clicks = clicks_internal.drop(columns=["_job_seeker_id", "_job_id", "_is_sponsored", "_campaign_id"])

    tables: Dict[str, pd.DataFrame] = {
        "employers.csv": employers,
        "locations.csv": locations,
        "job_categories.csv": categories,
        "skills.csv": skills,
        "job_posts.csv": jobs,
        "job_skills.csv": job_skills,
        "job_seekers.csv": seekers,
        "search_sessions.csv": sessions,
        "searches.csv": searches,
        "sponsorship_campaigns.csv": campaigns,
        "campaign_jobs.csv": campaign_jobs,
        "job_impressions.csv": impressions,
        "job_clicks.csv": clicks,
        "applications.csv": applications,
        "sponsored_spend_daily.csv": spend,
    }

    print("Validating generated data...")
    validate_tables(tables)
    write_outputs(output_dir, tables)
    return tables


def parse_args() -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[1]
    default_output = project_root / "data" / "generated"

    parser = argparse.ArgumentParser(
        description="Generate reproducible synthetic Talent Flow marketplace CSV files."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=default_output,
        help=f"Output directory. Default: {default_output}",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=SEED,
        help=f"Random seed. Default: {SEED}",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = args.output_dir.expanduser().resolve()
    tables = generate(output_dir=output_dir, seed=args.seed)

    print(f"\nCreated {len(tables)} CSV files in:\n  {output_dir}\n")
    for filename in CSV_ORDER:
        print(f"  {filename:<31} {len(tables[filename]):>10,} rows")

    print("\nGeneration completed successfully.")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"Validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
