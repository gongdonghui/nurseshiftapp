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
2. From `backend/`, run the helper script (it stops any previously running
   `uvicorn` process before starting a fresh one):

   ```bash
   ./scripts/run_dev_server.sh
   ```

   You can override the port/host if needed:

   ```bash
   PORT=9000 HOST=127.0.0.1 ./scripts/run_dev_server.sh
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
| POST   | /colleagues/{id}/accept | Mark a colleague as accepted |
| GET    | /group-shared | List NurseShift groups (supports `start_date`/`end_date` filters) |
| POST   | /group-shared | Create a new group                         |
| POST   | /group-shared/{id}/invites | Invite a member to a group     |
| POST   | /group-shared/invites/{id}/accept | Mark an invite as accepted |
| POST   | /group-shared/{id}/share | Publish a member's schedule for a custom date range |
| POST   | /group-shared/{id}/share/cancel | Remove a previously shared date range |
| POST   | /auth/login | Obtain a session token for a known user     |
| POST   | /auth/logout | End the current session (stateless hint)   |

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

**Query params for `GET /group-shared`:**

- `start_date` *(optional)* – date range lower bound for shared entries
- `end_date` *(optional)* – date range upper bound for shared entries

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
| status      | text      | `invited` or `accepted`                  |
| invitation_message | text | Generated invite text for sharing     |
| created_at  | timestamp | Defaults to `now()`                      |

`groups` table columns:

| Column      | Type      | Notes                                    |
| ----------- | --------- | ---------------------------------------- |
| id          | SERIAL PK |                                          |
| name        | text      | Group name                               |
| description | text      | Optional details                         |
| invite_message | text   | Prefilled invite snippet                 |
| shared_calendar | json  | Derived weekly schedule data returned by `/group-shared` |
| created_at  | timestamp | Defaults to `now()`                      |

`group_invites` table columns:

| Column      | Type      | Notes                                    |
| ----------- | --------- | ---------------------------------------- |
| id          | SERIAL PK |                                          |
| group_id    | INT FK    | References `groups.id`                   |
| invitee_name| text      | Person invited                           |
| status      | text      | `invited` or `accepted`                  |
| created_at  | timestamp | Defaults to `now()`                      |

`users` table columns:

| Column        | Type      | Notes                                                |
| ------------- | --------- | ---------------------------------------------------- |
| id            | SERIAL PK |                                                      |
| name          | text      | Full name shown throughout the UI                    |
| email         | text      | Lowercased and indexed for case-insensitive auth     |
| password_hash | text      | SHA-256 hashed password                              |
| created_at    | timestamp | Defaults to `now()`                                  |

`group_memberships` table columns:

| Column      | Type      | Notes                                                    |
| ----------- | --------- | -------------------------------------------------------- |
| id          | SERIAL PK |                                                          |
| group_id    | INT FK    | References `groups.id`                                   |
| user_id     | INT FK    | References `users.id`                                    |
| joined_at   | timestamp | When the member was added                                |

`group_shares` table columns:

| Column        | Type      | Notes                                                     |
| ------------- | --------- | --------------------------------------------------------- |
| id            | SERIAL PK |                                                           |
| membership_id | INT FK    | References `group_memberships.id` (1:1 relationship)      |
| start_date    | date      | Beginning of the date range the member chose to share     |
| end_date      | date      | End of the shared window (max 180 days per request)       |
| created_at    | timestamp | Defaults to `now()`                                       |
| updated_at    | timestamp | Automatically refreshed on updates                        |

When `/group-shared` is called, the API derives the `shared_calendar` payload by
loading each member with an active `GroupShare`, pulling their `events` within
the requested date range, and formatting the entries on the fly—no serialized
JSON is stored in the database anymore.

### Seeding the Group Shared sample data

To quickly test the Group Shared calendar UI, populate the database with a
sample group and three members:

```bash
cd backend
python scripts/seed_group_shared.py
```

The script is idempotent. It ensures the “Surgical Services” group exists, adds
the demo nurses (Jamie, Reese, Morgan) to the group, assigns them default share
windows, and inserts a mix of November and December shifts so the Flutter app
always has real calendar data to render from `/group-shared`.

### Demo logins

All demo accounts share the password `password123`. Emails are normalized to
lowercase during login, so `Jamie@NurseShift.app` also works.

| Name          | Email                 |
| ------------- | --------------------- |
| Jamie Ortega  | `jamie@nurseshift.app` |
| Reese Patel   | `reese@nurseshift.app` |
| Morgan Wills  | `morgan@nurseshift.app` |
| Avery Chen    | `avery@nurseshift.app` |
