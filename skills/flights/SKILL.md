---
name: flights
description: Search flights via Google Flights. Find nonstop/connecting flights, filter by time and cabin class, get booking links.
---

# Flight Search

Search real-time flight schedules and prices via Google Flights data.

## Prerequisites

```bash
pip install fast-flights
```

The `flights-search` CLI is installed at `~/.local/bin/flights-search`.

## CLI Usage

```bash
flights-search <origin> <destination> <date> [options]
```

### Examples

```bash
# Basic search (auto-shows fewest stops available)
flights-search YYZ EWR 2026-02-06

# Nonstop flights only
flights-search YYZ JFK 2026-02-06 --nonstop

# Filter by departure time (24h format)
flights-search YYZ EWR 2026-02-06 --after 18        # After 6pm
flights-search YYZ EWR 2026-02-06 --before 12       # Before noon
flights-search YYZ EWR 2026-02-06 --after 9 --before 14

# Cabin class
flights-search YYZ EWR 2026-02-06 --class economy   # default
flights-search YYZ EWR 2026-02-06 --class premium   # premium economy
flights-search YYZ EWR 2026-02-06 --class business
flights-search YYZ EWR 2026-02-06 --class first

# Get Google Flights booking link
flights-search YYZ EWR 2026-02-06 --class business --link

# Multiple passengers
flights-search YYZ EWR 2026-02-06 --passengers 2

# Show all flights (ignore stop minimization)
flights-search YYZ EWR 2026-02-06 --all-stops
```

### Options

| Option | Description |
|--------|-------------|
| `--nonstop` | Force nonstop only |
| `--all-stops` | Show all flights regardless of stops |
| `--after HH` | Depart after hour (24h format) |
| `--before HH` | Depart before hour (24h format) |
| `--class` | Cabin: economy, premium, business, first |
| `--passengers N` | Number of travelers |
| `--link` | Print Google Flights URL |

## Default Behavior

By default, the CLI shows only flights with the **minimum stops available**:
- If nonstops exist → shows only nonstops
- If no nonstops → shows only 1-stop flights
- Use `--all-stops` to see everything

## Output

```
Depart                       Arrive                       Airline         Price      Duration
----------------------------------------------------------------------------------------------------
6:00 PM Fri, Feb 6           7:38 PM Fri, Feb 6           Air Canada      $361       1 hr 38 min
9:10 PM Fri, Feb 6           10:48 PM Fri, Feb 6          Air Canada      $361       1 hr 38 min

2 nonstop flight(s) found.
```

## Data Source

Uses Google Flights data via the `fast-flights` library (reverse-engineered protobuf API). No API key required.

## Notes

- Date format: `YYYY-MM-DD`
- Airport codes: Standard IATA codes (JFK, LAX, YYZ, etc.)
- Prices are in USD
- Times shown in local airport timezone

## ⚠️ Known Issues (Feb 14, 2026)

**`flights-search` CLI is not installed.** The symlink at `~/.local/bin/flights-search` doesn't exist. Use `uvx --with fast-flights python3` inline as a workaround:

```python
# fast-flights API uses keyword-only args now (old positional API is dead)
from fast_flights import FlightData, Passengers, get_flights

fd = FlightData(date="2026-02-20", from_airport="EWR", to_airport="BER", max_stops=0)
result = get_flights(
    flight_data=[fd],
    trip='one-way',
    passengers=Passengers(adults=1),
    seat='economy',
)
for f in result.flights:
    print(f.departure, f.arrival, f.airline, f.price, f.duration)
```

**"No flights found" with HTML dump:** When no flights match filters, the library dumps raw Google Flights HTML in the error. This is correct — Google itself has no results for that route/filter combo.
