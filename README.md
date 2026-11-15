# CIS 560 Movie Theater Booking System

**After `git clone`, run one command from the project folder:**

```sh
./start.sh
```

On Windows, double-click **start.bat** or run:

```bat
start.bat
```

Open the **Frontend URL printed by the launcher** (normally **http://localhost:5173**). The API explorer is the printed backend URL plus `/swagger` (normally **http://localhost:5000/swagger**).

Install these prerequisites once: **.NET SDK 8+**, **Node.js 22.12+ or 24+**, and a running **SQL Server**. The easiest SQL option on macOS/Linux is **Docker Desktop**, installed and running; Windows can also use **LocalDB** or a running **SQL Express** instance. First startup downloads NuGet/npm dependencies and, if needed, the SQL Server Docker image, so internet access is required. No AI assistant, SQL client, manual database creation, or global Vite install is needed.

The launchers check tools and ports, use an available local SQL Server or start the project's Docker container, install frontend dependencies with `npm ci` if `node_modules` is missing, start the backend, wait for database setup, then start React. On macOS/Linux, Ctrl+C stops both apps. On Windows, use Ctrl+C in each app's console. SQL Server and its persistent volume stay available for the next launch.

## Automatic database setup

`Backend/DatabaseInitializer.cs` uses only raw ADO.NET (`Microsoft.Data.SqlClient`):

1. Honors `ConnectionStrings__DefaultConnection` if explicitly set. Otherwise tries the configured connection, Windows LocalDB/SQL Express, and the local TCP endpoint.
2. Connects to `master` and creates **MovieTheaterBooking** if missing. An explicit connection string can select a different database. The login needs permission to create the database on first launch; an existing database needs the schema/procedure permissions used by setup.
3. Checks all seven project tables and whether managed data exists.
4. For a new or empty project database, runs `Tables.sql`, `Procedures.sql`, and `Data.sql` in order, splitting standalone `GO` batch separators.
5. On later launches, preserves all rows and refreshes the 24 procedures with `CREATE OR ALTER`. Prints each table's row count and a completion message.

A populated database with missing tables or old timestamp columns is **never automatically reset**. Setup stops with instructions to choose a fresh database or migrate the existing schema. This also protects previous versions using `MovieTheaterDB`. Automatic initialization is not a general schema migration system. Start only one backend instance per database during first-run setup.

`AutoInitializeDatabase` defaults to `true` in `Backend/appsettings.json`. To use an already provisioned database without automatic SQL execution, set `AutoInitializeDatabase=false` in the environment or configuration. With initialization disabled, provide a correct connection string yourself.

The three SQL scripts are copied into backend build/publish output, so published startup also has the scripts it needs. A single backend connection is selected at startup and used by all controllers.

## SQL Server options and credentials

The launchers create **cis560-movie-booking-sql** using the official SQL Server 2022 Developer image, with physical data in Docker volume **cis560-movie-booking-data**. Port 1433 is published only on `127.0.0.1`. On Apple Silicon, the image uses x86-64 emulation; Docker must support it. Running the launcher to create this container accepts the SQL Server image's EULA; Developer Edition is for development/classroom use.

The public local-demo password is `Cinema560!LocalDemo2026`. It matches `appsettings.json`; it is not a production credential. You can set `MSSQL_SA_PASSWORD` before creating the launcher-managed container to choose a different password. The container keeps its original password with its volume, so continue using that same value on later launches.

For an existing server with other credentials, set the complete connection string before running the launcher. The launcher will not start local Docker when this override is present:

```sh
export ConnectionStrings__DefaultConnection='Server=localhost,1433;Database=MovieTheaterBooking;User Id=sa;Password=YOUR_PASSWORD;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5;'
./start.sh
```

Windows Command Prompt:

```bat
set "ConnectionStrings__DefaultConnection=Server=(localdb)\MSSQLLocalDB;Database=MovieTheaterBooking;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;"
start.bat
```

You may also use an untracked `Backend/appsettings.Development.json` override when running the backend directly. Environment connection overrides are authoritative: setup never silently switches away from them. The startup logs omit passwords and full connection strings.

If port 1433 is already occupied, the launchers leave that server alone. Supply its credentials if they differ from the local-demo defaults. The launchers automatically select a free backend port from 5000–5010 and frontend port from 5173–5183, passing `BackendUrl` to ASP.NET and `VITE_API_BASE_URL` to Vite. This handles macOS AirPlay using port 5000 without changing system settings. Check the printed URLs; other applications are left running.

## Required submission files

- `Database/Tables.sql`: seven relations and named PK/FK/UNIQUE/CHECK/DEFAULT constraints; seeds the six static age-rating codes. **Manual execution drops existing project tables/data.**
- `Database/Procedures.sql`: 20 managed-table operations and four parameterized aggregation reports.
- `Database/Data.sql`: deterministic demo data, relative screening dates, and transactional integrity/count checks; requires empty managed tables.
- `Backend/`: ASP.NET Core .NET 8 Web API, raw ADO.NET controllers/models, startup initializer, and configuration.
- `Frontend/`: React/JavaScript + Vite, one readable CSS stylesheet, customer portal, and admin views.
- `README.md`: startup, setup, behavior, and submission guide.
- `start.sh` and `start.bat`: include both launchers in the submission so another machine can start the project.

For a source submission zip, include the files above and `Frontend/package-lock.json`. Exclude `.git/`, `node_modules/`, `dist/`, `bin/`, `obj/`, local configuration overrides, and Docker volumes. Never include `.mdf`, `.ldf`, or `.ndf` files. No ORM, authentication framework, Redux, TypeScript, or Tailwind is used.

## Exact first-run seed counts

| Relation | Rows |
| --- | ---: |
| AgeRating | 6 |
| Movie | 110 |
| ScreenRoom | 10 |
| Customer | 120 |
| Showtime | 300 |
| Booking | 6,368 |
| Review | 220 |
| **Total** | **7,134** |

Real movie titles and fictional names/contact details support a class demo. Parties contain 1–8 tickets. Premium rooms and popular titles have roughly 65–95% occupancy; other screenings have 15–45%. Twenty-five rating-matched review sentences and varied movie descriptions avoid numbered placeholders. Schedule-day math and named-room ordering keep row counts reproducible even though dates are relative to the day of initialization.

Some movies, customers, and a room begin inactive. Affected screenings are cancelled while retaining their booking history. SQL records nullable `DeactivatedOn`/`CancelledOn` timestamps, preserves the first timestamp on repeated status changes, and clears it on restoration. The UI displays available history without extra timestamp inputs.

## Run components manually

With SQL Server running, use two terminals at the repository root:

```sh
dotnet run --project Backend/Backend.csproj
```

```sh
npm ci --prefix Frontend
npm run dev --prefix Frontend
```

Backend startup performs the same automatic initialization as the launchers. The project targets .NET 8 and permits a newer installed runtime through `RollForward=LatestMajor`. Manual startup defaults to frontend port 5173 and backend port 5000. If those ports are occupied, prefer the launchers, which select matching free ports automatically. For manual custom ports, set `BackendUrl` for ASP.NET and `VITE_API_BASE_URL` for Vite to the same backend URL (append `/api` for Vite).

To verify builds:

```sh
dotnet build Backend/Backend.csproj
npm run build --prefix Frontend
```

For a manual database reset, deliberately select a disposable database and run `Tables.sql`, `Procedures.sql`, then `Data.sql`. This deletes existing project data. Normal startup and re-launches do not require a reset. Dates remain as originally seeded on subsequent starts; schedule new screenings through the UI when the original schedule becomes historical.

## API and UI functionality

All JSON uses camelCase. Dates use `yyyy-MM-dd`; screening times are theater-local values with no UTC conversion.

| Resource | Read/create/update | Removal |
| --- | --- | --- |
| Movies | GET/POST `/api/movies`, PUT `/api/movies/{id}` | PUT `isActive=false` |
| Screen rooms | GET/POST `/api/screenrooms`, PUT `/api/screenrooms/{id}` | PUT `isActive=false` |
| Customers | GET/POST `/api/customers`, PUT `/api/customers/{id}` | PUT `isActive=false` |
| Showtimes | GET/POST `/api/showtimes`, PUT `/api/showtimes/{id}` | PUT `isCancelled=true` |
| Bookings | GET `/api/bookings?customerId=...`, POST `/api/bookings`, PUT `/api/bookings/{id}` | DELETE `/api/bookings/{id}` |
| Reviews | GET `/api/reviews?movieId=...`, POST `/api/reviews`, PUT `/api/reviews/{id}` | DELETE `/api/reviews/{id}` |

PUT replaces editable fields; booking PUT accepts only `numberOfTickets`. SQL computes booking totals, prevents overlaps/overbooking, and rejects inactive participants and common duplicates with friendly messages. Existing prices remain historical until a booking is edited, when its full total is recalculated at the current ticket price. Cancellation preserves booking history until a booking is explicitly deleted.

Select an active customer in the top bar and use **Manage customers** for create/edit/deactivate/reactivate. **Browse movies** offers title/genre/rating filters, upcoming screenings, booking, and review management. **My bookings** edits ticket counts or cancels reservations. Admin **Movies & rooms** and **Showtimes** manage catalog/scheduling/status changes. The mode switch is for the class demo and does not implement login.

Forms use names/dropdowns, date inputs, star-rating choices, and checkboxes rather than raw foreign-key entry. Surrogate IDs are shown only in the four required report tables. SQL and ASP.NET validation errors appear in red accessible banners; successful changes appear in green.

## Four aggregation reports

Each report joins multiple tables, uses `GROUP BY`, and accepts SQL parameters through ADO.NET.

| Procedure / `/api/reports/` suffix | Parameters | Output columns |
| --- | --- | --- |
| `usp_Report_MoviePerformance` / `movie-performance` | `FirstDate`, `LastDate` | MovieID, Title, ShowtimeCount, TicketsSold, TotalRevenue, AverageTicketsPerShowtime |
| `usp_Report_CustomerBookingActivity` / `customer-booking-activity` | `FirstDate`, `LastDate` | CustomerID, CustomerName, BookingCount, TicketsPurchased, TotalSpent, SpendingRank |
| `usp_Report_ScreenRoomUtilization` / `screen-room-utilization` | `FirstDate`, `LastDate` | ScreenRoomID, RoomNumber, ShowtimeCount, TicketsBooked, SeatsOffered, OccupancyRate |
| `usp_Report_MovieReviewSummary` / `movie-review-summary` | `MinimumReviewCount` | MovieID, Title, ReviewCount, AverageRating, HighestRating, LowestRating |

Date ranges include both endpoints. Performance/utilization use non-cancelled screening dates; customer activity uses booking dates and includes retained bookings on cancelled screenings. Ranking uses `RANK`; review thresholds use `HAVING`. With a minimum review count of zero, movies without reviews have null rating statistics. Report tables include applied filters and formatted currency/percentages for screenshots.
