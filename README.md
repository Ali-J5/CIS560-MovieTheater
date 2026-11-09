# CIS 560 Movie Theater Booking System

A single-theater booking project using SQL Server, an ASP.NET Core 8 Web API, and raw ADO.NET through `Microsoft.Data.SqlClient`.

- `Database/Tables.sql`: six tables and named constraints. **Re-running this script drops existing project tables and data.**
- `Database/Procedures.sql`: CRUD procedures, scheduling and booking rules, and four reports.
- `Database/Data.sql`: seed data and integrity checks; requires empty tables.
- `Backend/Program.cs`: HTTP server, controllers, CORS, and Swagger configuration.
- `Backend/Models/`: request bodies and typed query results.
- `Backend/Controllers/`: seven controllers that call the stored procedures directly.
- `Frontend/`: React + Vite customer portal and admin dashboard (JavaScript, one CSS file).

## Prepare SQL Server

1. Start SQL Server and connect using SQL Server Management Studio or another SQL Server client.
2. Create a database named `MovieTheaterDB` if it does not exist, then select it as the query database. For example, run `CREATE DATABASE MovieTheaterDB;` once in the client, then select that database.
3. Run `Database/Tables.sql` to create all six tables. This drops existing project tables, so use it only when intentionally initializing/resetting this project database.
4. Run `Database/Procedures.sql` to create the 24 stored procedures.
5. Run `Database/Data.sql` once on the empty tables to load the demo data. The seed refuses to overwrite populated tables.

The seed creates 110 movies, 10 rooms, 120 customers, 300 showtimes, 900 bookings, and 220 reviews.

SQL Server must be running and reachable before database endpoints will succeed. LocalDB and Windows SQL Express are Windows options; on macOS, connect to a reachable SQL Server instance or container over TCP.

## Run the backend

Install the .NET 8 SDK or a newer SDK (this machine has .NET 9). The project targets `net8.0` and sets `<RollForward>LatestMajor</RollForward>`, allowing the normal run command to use the installed ASP.NET Core 9 runtime without an environment-variable workaround.

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


## Run the frontend

Use Node.js 22.12+ or a newer supported release (this machine has Node.js 24). Open a **second terminal** while the backend stays running at port 5000. From the repository root:

```sh
cd Frontend
npm install
npm run dev
```

Open **http://localhost:5173**. Vite uses a strict port so another application on port 5173 must be stopped before starting it. The frontend's only runtime dependencies are React and React DOM; Vite and its React plugin are development tools. The committed lockfile records the installed dependency versions.

`Frontend/src/api.js` centralizes fetch calls to `http://localhost:5000/api`. There is no proxy or frontend environment-variable setup. Start SQL Server, the backend, and the frontend in that order. SQL errors appear in red banners; ASP.NET validation errors are also extracted and displayed. Successful changes appear in green banners.

To verify/package the frontend:

```sh
cd Frontend
npm run build
npm run preview
```

The build writes `Frontend/dist/` (ignored by Git). Preview serves the production build at **http://localhost:4173** and still requires the backend and database.

## Use the six-view interface

1. **Top navigation / customer accounts:** select an active customer. Choose **Manage customers** to create one, edit a customer's details, deactivate them with the Active customer checkbox, or select an inactive account and reactivate it. Deactivation preserves bookings and reviews. Mode switching is for the class demo and does not implement authentication.
2. **Customer Portal → Browse movies:** search by title, exact genre, or rating. Select a movie to see upcoming screenings, screen type, room, price, and seats remaining. Book for the selected customer. Read audience reviews and their average rating; create, update, or delete the selected customer's review.
3. **Customer Portal → My bookings:** change ticket quantities or cancel a booking. The confirmed total comes from SQL; editing recalculates the full total at the screening's current price. Screening cancellations are clearly marked.
4. **Admin Dashboard → Movies & rooms:** use the two sub-tabs to create/edit movies and rooms, or deactivate/reactivate existing records. Inactive records remain visible to administrators.
5. **Admin Dashboard → Showtimes:** schedule a screening, edit its movie/room/time/price, cancel it, or restore it. Red banners display SQL's exact runtime-overlap/capacity message. The date filter defaults to 30 days ago and can be cleared to show all records.
6. **Admin Dashboard → Reports:** select one of the four report tabs. Dates default to 60 days before/after today to cover the seed's bookings and screenings. Review reports default to at least one review. Use **Run report** after editing filters. Tables include their applied dates/threshold, clear headings, currency formatting, ranks, and occupancy percentages for screenshots. Browser printing hides the navigation and filters.

Upcoming screenings use theater local time and exclude screenings that have already started. The showtime API does not include screen type, so React matches its `screenRoomId` to the room catalog. All requests use the existing API's camelCase fields; SQL remains the authority for overlaps, capacities, prices, and uniqueness.

## Troubleshooting

- **Cannot reach the cinema API:** start `dotnet run --project Backend/Backend.csproj` and verify `http://localhost:5000/swagger` loads. Confirm port 5000 is free.
- **SQL login/network error:** replace the placeholder connection string with your reachable SQL Server instance and credentials; ensure the three scripts ran against that same database. The frontend can load without SQL Server, but database actions need a working connection.
- **No upcoming screenings:** the seed dates are relative to the day `Data.sql` was run. Schedule a future screening in Admin Showtimes, or deliberately reset/reseed the database if disposable demo data is all you need.
- **Duplicate booking/review:** update the existing record in My bookings/the movie's review form rather than submitting a second one.
- **Overlap or room capacity error:** adjust the screening time, movie runtime, room, or requested ticket count. The banner preserves the database's original explanation.
