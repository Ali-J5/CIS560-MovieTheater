# CIS 560 Movie Theater Booking System

A single-theater booking project using SQL Server, an ASP.NET Core 8 Web API, and raw ADO.NET through `Microsoft.Data.SqlClient`.

- `Database/Tables.sql`: six tables and named constraints. **Re-running this script drops existing project tables and data.**
- `Database/Procedures.sql`: CRUD procedures, scheduling and booking rules, and four reports.
- `Database/Data.sql`: seed data and integrity checks; requires empty tables.
- `Backend/Program.cs`: HTTP server, controllers, CORS, and Swagger configuration.
- `Backend/Models/`: request bodies and typed query results.
- `Backend/Controllers/`: seven controllers that call the stored procedures directly.
- `Frontend/`: React application planned for Phase 3.

## Prepare SQL Server

Create/select a database named `MovieTheaterDB` in SQL Server Management Studio or another SQL Server client. Run `Tables.sql`, `Procedures.sql`, and `Data.sql` in that order against that database. The seed creates 110 movies, 10 rooms, 120 customers, 300 showtimes, 900 bookings, and 220 reviews.

SQL Server must be running and reachable before database endpoints will succeed. LocalDB and Windows SQL Express are Windows options; on macOS, connect to a reachable SQL Server instance or container over TCP.

## Run the backend

Install the .NET 8 SDK and ASP.NET Core 8 runtime. A newer SDK can compile `net8.0`, but running it normally still requires the .NET 8 runtime.

Set `ConnectionStrings:DefaultConnection` in `Backend/appsettings.json` to your instance, database, and login. The file includes commented alternatives for LocalDB and SQL Express. ASP.NET Core supports comments in this configuration file.

For an untracked local override, create `Backend/appsettings.Development.json` with this shape (substitute your own login):

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;Database=MovieTheaterDB;User Id=sa;Password=YOUR_LOCAL_PASSWORD;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5;"
  }
}
```

You can also set the `ConnectionStrings__DefaultConnection` environment variable. The checked-in password is a placeholder. `TrustServerCertificate=True` is provided for local development certificates.

From the repository root:

```sh
dotnet restore Backend/Backend.csproj
dotnet build Backend/Backend.csproj
dotnet run --project Backend/Backend.csproj
```

The API listens at **http://localhost:5000**. Open **http://localhost:5000/swagger** to explore request bodies and test endpoints. CORS accepts any origin, method, and header for the classroom React frontend.

## API routes

JSON uses camelCase (`movieId`, `screenRoomId`, `isActive`). Query dates use `yyyy-MM-dd`; showtime timestamps use theater local time, such as `2026-11-20T18:30:00`.

| Resource | Read | Create | Update | Delete |
| --- | --- | --- | --- | --- |
| Movies | `GET /api/movies?title=...&genre=...&ageRating=...&includeInactive=false` | `POST /api/movies` | `PUT /api/movies/{id}` | Set `isActive=false` through PUT |
| Screen rooms | `GET /api/screenrooms?includeInactive=false` | `POST /api/screenrooms` | `PUT /api/screenrooms/{id}` | Set `isActive=false` through PUT |
| Showtimes | `GET /api/showtimes?movieId=1&firstDate=2026-11-01&lastDate=2026-11-30&includeCancelled=false` | `POST /api/showtimes` | `PUT /api/showtimes/{id}` | Set `isCancelled=true` through PUT |
| Customers | `GET /api/customers?includeInactive=false` | `POST /api/customers` | `PUT /api/customers/{id}` | Set `isActive=false` through PUT |
| Bookings | `GET /api/bookings?customerId=1` (required filter) | `POST /api/bookings` | `PUT /api/bookings/{id}` | `DELETE /api/bookings/{id}` |
| Reviews | `GET /api/reviews?movieId=1` (required filter) | `POST /api/reviews` | `PUT /api/reviews/{id}` | `DELETE /api/reviews/{id}` |

PUT sends a full replacement body for movies, rooms, showtimes, customers, and reviews. Include all editable fields, including the desired `isActive` or `isCancelled` flag. Booking PUT accepts only `numberOfTickets`; it preserves the original customer and showtime. IDs for updates come from the route. Swagger lists every request property and its validation limits.

Example booking creation body:

```json
{ "customerId": 1, "showtimeId": 1, "numberOfTickets": 2 }
```

Example ticket count update body:

```json
{ "numberOfTickets": 3 }
```

SQL calculates totals, checks room capacity, rejects cancelled screenings, and prevents overlapping screenings. Unique constraints reject a second booking for the same customer/showtime or a second review for the same customer/movie; use PUT to edit the existing record. Existing booking prices remain historical when showtime prices change; editing a booking recalculates its total at the current price.

Creates return HTTP 201 and the generated identifier, updates return HTTP 200 and the saved identifier, deletes return HTTP 204, and reads return HTTP 200 with an array. SQL exceptions return HTTP 400 with `{ "error": "the original SQL error message" }`. Request validation failures return HTTP 400 with ASP.NET Core validation details under `errors`.

## Reports

| GET endpoint | Parameters | Meaning |
| --- | --- | --- |
| `/api/reports/movie-performance` | Required `firstDate`, `lastDate` | Non-cancelled screenings by screening date; revenue and average ticket sales |
| `/api/reports/customer-booking-activity` | Required `firstDate`, `lastDate` | Bookings by booking date; spending and tied spending ranks |
| `/api/reports/screen-room-utilization` | Required `firstDate`, `lastDate` | Non-cancelled screenings by screening date; offered seats and occupancy percentage |
| `/api/reports/movie-review-summary` | Optional `minimumReviewCount` (default 0) | Counts and ratings for movies meeting the minimum number of reviews |

Date ranges include both endpoints. Movies without reviews have null average/highest/lowest ratings when `minimumReviewCount=0`.
