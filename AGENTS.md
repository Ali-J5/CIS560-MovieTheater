# CIS 560 Movie Theater Booking System — Agent Instructions

## 1. Project Overview & Tech Stack
This is a university database course project (CIS 560) building a **Movie Theater Booking System** for a single theater with multiple screening rooms.
- **Database:** Microsoft SQL Server (T-SQL)
- **Backend:** C# ASP.NET Core Web API (.NET 8)
- **Database Access:** Raw ADO.NET (`Microsoft.Data.SqlClient`) ONLY
- **Frontend:** React (JavaScript + Vite) with simple, clean CSS

## 2. STRICT NON-NEGOTIABLE CONSTRAINTS
1. **NO ORM FRAMEWORKS ALLOWED:** Never use Entity Framework, EF Core, Dapper, NHibernate, or LINQ-to-SQL. All database operations MUST use `Microsoft.Data.SqlClient` (`SqlConnection`, `SqlCommand`, `SqlDataReader`, `SqlParameter`) executing raw parameterized T-SQL queries or Stored Procedures.
2. **EDUCATIONAL CODE COMMENTS (CRITICAL):** The developer is using this codebase to learn and present for a class demo. You MUST comment every logical step of the code concisely and clearly:
   - In **SQL**: Explain every table constraint, foreign key, parameters, and step inside stored procedures and aggregating queries.
   - In **C#**: Explain opening the connection, building the `SqlCommand`, adding parameters, reading rows with `SqlDataReader`, and handling SQL errors.
   - In **React**: Explain state variables (`useState`), API calls (`useEffect` / `fetch`), and how form submissions talk to the C# backend.
3. **KEEP IT SIMPLE:** Do not over-engineer. Do not add authentication/JWTs, Redux, TypeScript, Tailwind bloat, or unnecessary abstractions. Keep the folder structure flat and easy to read.
4. **SOFT DELETES:** Never hard-delete `Movie`, `ScreenRoom`, or `Customer` records (toggle `IsActive = 0`). Never hard-delete `Showtime` records (toggle `IsCancelled = 1`). Hard `DELETE` is only used for `Booking` and `Review`.

## 3. Required Submission Folder Structure
Maintain this exact repository structure so it matches the CIS 560 code submission requirements:
- `/Database/Tables.sql` — All `CREATE TABLE` statements with PK, FK, UNIQUE, CHECK, and DEFAULT constraints.
- `/Database/Procedures.sql` — All Stored Procedures and parameterized SQL operations (including the 4 Aggregating Queries).
- `/Database/Data.sql` — Seed script populating realistic data (100+ rows per major table, 500+ bookings).
- `/Backend` — C# ASP.NET Core Web API project.
- `/Frontend` — React (Vite) frontend application.
- `/README.md` — Clear guide explaining the file structure and how to run the project.

## 4. Professor Feedback and Presentation Rules
- Maintain six operational tables plus the static `AgeRating` lookup (seven tables total).
- `AgeRating(AgeRating NVARCHAR(10) PRIMARY KEY, Description NVARCHAR(200) NOT NULL)` contains G, PG, PG-13, R, NC-17, NR. Seed it in Tables.sql and reference it with `FK_Movie_AgeRating`; do not use a duplicate rating CHECK constraint.
- Movie, ScreenRoom, and Customer have nullable `DeactivatedOn DATETIME2`; Showtime has nullable `CancelledOn DATETIME2`. SQL sets status timestamps, preserves the first timestamp on repeated deactivation/cancellation, and clears it on reactivation/restoration. Record timestamps on initially inactive/cancelled inserts too.
- Use ordinary `XACT_ABORT`, TRY/CATCH, and transactions, with `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;`. Do not use `sp_getapplock`. Explain transaction-scoped `UPDLOCK, HOLDLOCK` reads that protect validation from concurrent writes.
- Check common duplicates and inactive booking references with friendly SQL THROW messages; retain constraints as final safeguards.
- Seed varied 1-8 ticket parties, high/low occupancy, at least 20 review texts, and timestamped historical inactive/cancelled rows.
- Format JSX and CSS across readable indented lines. Show names, room labels, and dates instead of surrogate IDs outside the four specified admin reports, including accessible labels.
- Bind nonnullable C# parameters directly; use DBNull.Value only for genuinely nullable parameters. Status timestamps are response-only fields.


## 5. Clone-and-Run Startup
- `start.sh` / `start.bat` launch SQL Server (Docker when needed), restore frontend dependencies, select free app ports, and start both apps. Keep launcher-selected `BackendUrl` and Vite's `VITE_API_BASE_URL` consistent.
- `Backend/DatabaseInitializer.cs` uses raw ADO.NET, honors `ConnectionStrings__DefaultConnection`, creates the selected database through master, and splits the three source scripts on standalone GO lines.
- `AutoInitializeDatabase=true` initializes new/empty databases. Never run destructive Tables.sql automatically over populated tables; refuse incompatible/partial populated schemas clearly. Later starts preserve records and refresh CREATE OR ALTER procedures.
- Keep SQL scripts copied into backend output/publish folders. Default classroom database: MovieTheaterBooking.
- Seed counts are date-independent: AgeRating 6, Movie 110, ScreenRoom 10, Customer 120, Showtime 300, Booking 6368, Review 220 (7134 total).
