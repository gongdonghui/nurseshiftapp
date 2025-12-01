## NurseShift Backend

This FastAPI service persists calendar events in PostgreSQL and exposes REST
endpoints consumed by the Flutter showcase.

### Prerequisites

- Python 3.11+
- Docker (optional, but simplifies running Postgres)

### Local environment variables

Copy `.env.example` to `.env` and adjust credentials as needed:

```bash
cp backend/.env.example backend/.env
```

```
DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/nurseshift
```

### Install dependencies

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Start Postgres and API with Docker

The included `docker-compose.yml` spins up both the database and the API:

```bash
docker compose up --build
```

The API becomes available at http://localhost:8000 and includes an
interactive Swagger UI at http://localhost:8000/docs.

### Manual startup (without Docker)

1. Start Postgres locally and ensure it matches the `DATABASE_URL`.
2. From `backend/`, run:

   ```bash
   uvicorn app.main:app --reload
   ```

### API overview

| Method | Path      | Description                               |
| ------ | --------- | ----------------------------------------- |
| GET    | /health   | Health check                              |
| GET    | /events   | List events within a date range           |
| POST   | /events   | Create a new event                        |
| GET    | /events/{event_id} | Retrieve a single event by id    |
| PUT    | /events/{event_id} | Update an existing event          |
| DELETE | /events/{event_id} | Delete an event                   |
| GET    | /swap-requests | List swap / give away requests        |
| POST   | /swap-requests | Create a swap or give away request    |
| GET    | /swap-requests/{id} | Retrieve a single swap request   |
| POST   | /swap-requests/{id}/retract | Mark a request as retracted |
| GET    | /colleagues | List saved colleagues                   |
| POST   | /colleagues | Create a new colleague entry            |

**Query params for `GET /events`:**

- `start_date` *(required)* – ISO date string `YYYY-MM-DD`
- `end_date` *(required)* – ISO date string `YYYY-MM-DD`

Example:

```
GET /events?start_date=2025-11-01&end_date=2025-11-30
```

**Query params for `GET /swap-requests`:**

- `start_date` *(optional)* – filter to events on/after this date
- `end_date` *(optional)* – filter to events on/before this date
- `status` *(optional, default `pending`)* – `pending`, `retracted`, or `fulfilled`

### Database schema

`events` table columns:

| Column       | Type      | Notes                                   |
| ------------ | --------- | --------------------------------------- |
| id           | SERIAL PK |                                         |
| title        | text      | Event label shown in the UI             |
| date         | date      | Calendar day                            |
| start_time   | time      | Shift start                             |
| end_time     | time      | Shift end                               |
| location     | text      | Worksite name                           |
| event_type   | text      | Matches the Flutter event type ids      |
| notes        | text      | Optional                                |
| created_at   | timestamp | Defaults to `now()`                     |

The FastAPI app automatically creates the table on startup if it does not
exist, simplifying first-time setup.

`swap_requests` table columns:

| Column                  | Type        | Notes                                              |
| ----------------------- | ----------- | -------------------------------------------------- |
| id                      | SERIAL PK   |                                                    |
| event_id                | INT FK      | References `events.id`                             |
| mode                    | text        | `swap` or `give_away`                              |
| desired_shift_type      | text        | User-entered preference                            |
| available_start_time    | time        | Optional lower bound for acceptable coverage       |
| available_end_time      | time        | Optional upper bound                               |
| available_start_date    | date        | Optional start of acceptable date range            |
| available_end_date      | date        | Optional end of acceptable date range              |
| visible_to_all          | bool        | Broadcast to all colleagues                        |
| share_with_staffing_pool| bool        | Also expose to staffing pool                       |
| notes                   | text        | Optional instructions                              |
| status                  | text        | `pending`, `retracted`, `fulfilled`                |
| created_at              | timestamp   | Default `now()`                                    |
| updated_at              | timestamp   | Auto-updated                                       |

`swap_targets` table columns:

| Column         | Type      | Notes                                  |
| -------------- | --------- | -------------------------------------- |
| id             | SERIAL PK |                                        |
| swap_request_id| INT FK    | References `swap_requests.id`          |
| colleague_name | text      | Person explicitly targeted by request  |

`colleagues` table columns:

| Column      | Type      | Notes                                    |
| ----------- | --------- | ---------------------------------------- |
| id          | SERIAL PK |                                          |
| name        | text      | Colleague's full name                    |
| department  | text      | Team or specialty                        |
| facility    | text      | Work location                            |
| role        | text      | Optional job title                       |
| email       | text      | Optional contact                         |
| created_at  | timestamp | Defaults to `now()`                      |
