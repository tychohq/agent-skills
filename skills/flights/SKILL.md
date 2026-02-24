---
name: flights
description: Search flights via Google Flights. Find nonstop/connecting flights, filter by time, airline, and cabin class. Find cheapest dates to fly. No API key required.
---

# Flight Search

Search real-time flight schedules and prices via Google Flights data using the `fli` CLI.

## Prerequisites

```bash
# Install via pip, pipx, or uv
pip install flights
# or
pipx install flights
# or
uv tool install flights
```

Verify: `fli --help`

## Commands

### `fli flights` — Search flights on a specific date

```bash
fli flights <origin> <destination> <date> [options]
```

**Examples:**

```bash
# Basic search
fli flights JFK LAX 2026-03-15

# Nonstop only, sorted by departure time
fli flights JFK LAX 2026-03-15 --stops 0 --sort DEPARTURE_TIME

# Evening departures only
fli flights JFK LAX 2026-03-15 --time 18-24

# Business class on specific airlines
fli flights JFK LHR 2026-03-15 --class BUSINESS --airlines BA VS

# Round-trip
fli flights JFK LHR 2026-03-15 --return 2026-03-22
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--time` | `-t` | Departure time window, 24h format (e.g., `6-20`, `18-24`) |
| `--airlines` | `-a` | Filter by airline IATA codes (e.g., `BA KL DL`) |
| `--class` | `-c` | `ECONOMY`, `PREMIUM_ECONOMY`, `BUSINESS`, `FIRST` |
| `--stops` | `-s` | `ANY`, `0` (nonstop), `1`, `2+` |
| `--sort` | `-o` | `CHEAPEST`, `DURATION`, `DEPARTURE_TIME`, `ARRIVAL_TIME` |
| `--return` | `-r` | Return date for round-trip (YYYY-MM-DD) |

### `fli dates` — Find cheapest dates to fly

```bash
fli dates <origin> <destination> [options]
```

**Examples:**

```bash
# Cheapest dates in the next 2 months
fli dates JFK LAX --sort

# Cheapest Friday departures
fli dates JFK LAX --friday --sort

# Nonstop weekend flights in March
fli dates JFK LAX --from 2026-03-01 --to 2026-03-31 --friday --saturday --stops 0

# Round-trip with 7-day duration
fli dates JFK LHR --round --duration 7 --sort
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--from` | | Start date (default: today) |
| `--to` | | End date (default: +2 months) |
| `--duration` | `-d` | Trip duration in days (default: 3) |
| `--round` | `-R` | Search round-trip |
| `--sort` | | Sort by price (lowest first) |
| `--monday` through `--sunday` | `-mon` through `-sun` | Filter by day of week |
| `--time` | `-time` | Departure time window (e.g., `6-20`) |
| `--airlines` | `-a` | Filter by airline IATA codes |
| `--class` | `-c` | Cabin class |
| `--stops` | `-s` | Max stops |

## Notes

- **Date format:** `YYYY-MM-DD`
- **Airport codes:** Standard IATA codes (JFK, LAX, LHR, NRT, etc.)
- **No API key required** — uses Google Flights data via reverse-engineered API
- Prices shown in USD
- Times shown in local airport timezone

## Data Source

Uses Google Flights data via the [`flights`](https://github.com/punitarani/fli) Python package. No scraping — uses Google's protobuf API directly.
