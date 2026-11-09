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