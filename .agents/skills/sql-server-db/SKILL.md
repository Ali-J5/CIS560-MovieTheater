---
name: sql-server-db
description: Use whenever creating or modifying SQL Server tables, constraints, stored procedures, aggregating queries, or seed data in the /Database folder.
---

# CIS 560 SQL Server Database Skill

## 1. File Organization (Strictly Required by Syllabus)
All database scripts MUST live in `/Database` and be split into these exact 3 files:
1. `/Database/Tables.sql` — Drops existing tables in reverse-FK order (for easy re-running) and creates the six operational tables plus the static AgeRating lookup with all constraints.
2. `/Database/Procedures.sql` — Contains `CREATE OR ALTER PROCEDURE` statements for all CRUD operations, business rule checks, and the 4 required Aggregating Queries.
3. `/Database/Data.sql` — Populates realistic data meeting the syllabus volume rules (at least 100 rows in `Movie`, `Customer`, `Showtime`, `Review`, and 500+ rows in `Booking`; plus 8–15 realistic `ScreenRoom` rows for a single theater facility).

## 2. Six Operational Tables and Static Lookup & Constraints (`Tables.sql`)
Use explicit constraint names (e.g., `PK_Movie`, `FK_Showtime_Movie`, `UQ_Customer_Email`, `CK_Movie_Runtime`). Comment every table and constraint clearly.

1. **`Movie`**
   - `MovieID INT IDENTITY(1,1)` (PK)
   - `Title NVARCHAR(200) NOT NULL`
   - `ReleaseDate DATE NOT NULL`
   - `Genre NVARCHAR(50) NOT NULL`
   - `RuntimeMinutes INT NOT NULL` -> `CHECK (RuntimeMinutes > 0)`
   - `AgeRating NVARCHAR(10) NOT NULL` -> `FK_Movie_AgeRating` references `AgeRating(AgeRating)`
   - `Description NVARCHAR(MAX) NULL`
   - `IsActive BIT NOT NULL DEFAULT 1`
   - `DeactivatedOn DATETIME2 NULL` (SQL-managed)
   - `UNIQUE (Title, ReleaseDate)`

2. **`ScreenRoom`**
   - `ScreenRoomID INT IDENTITY(1,1)` (PK)
   - `RoomNumber NVARCHAR(100) NOT NULL` -> `UNIQUE (RoomNumber)`
   - `Name NVARCHAR(100) NOT NULL`
   - `ScreenType NVARCHAR(50) NOT NULL` (e.g., Standard, IMAX, Dolby, 3D)
   - `Capacity INT NOT NULL` -> `CHECK (Capacity > 0)`
   - `IsActive BIT NOT NULL DEFAULT 1`
   - `DeactivatedOn DATETIME2 NULL` (SQL-managed)

3. **`Showtime`**
   - `ShowtimeID INT IDENTITY(1,1)` (PK)
   - `MovieID INT NOT NULL` (FK -> `Movie.MovieID`)
   - `ScreenRoomID INT NOT NULL` (FK -> `ScreenRoom.ScreenRoomID`)
   - `StartDateTime DATETIME2 NOT NULL`
   - `TicketPrice DECIMAL(10,2) NOT NULL` -> `CHECK (TicketPrice >= 0)`
   - `IsCancelled BIT NOT NULL DEFAULT 0`
   - `CancelledOn DATETIME2 NULL` (SQL-managed)
   - `UNIQUE (ScreenRoomID, StartDateTime)`

4. **`Customer`**
   - `CustomerID INT IDENTITY(1,1)` (PK)
   - `Email NVARCHAR(200) NOT NULL` -> `UNIQUE (Email)`
   - `PhoneNumber VARCHAR(25) NOT NULL` -> `UNIQUE (PhoneNumber)`
   - `FirstName NVARCHAR(50) NOT NULL`
   - `LastName NVARCHAR(50) NOT NULL`
   - `IsActive BIT NOT NULL DEFAULT 1`
   - `DeactivatedOn DATETIME2 NULL` (SQL-managed)

5. **`Booking`**
   - `BookingID INT IDENTITY(1,1)` (PK)
   - `CustomerID INT NOT NULL` (FK -> `Customer.CustomerID`)
   - `ShowtimeID INT NOT NULL` (FK -> `Showtime.ShowtimeID`)
   - `BookingDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()`
   - `NumberOfTickets INT NOT NULL` -> `CHECK (NumberOfTickets > 0)`
   - `TotalPrice DECIMAL(10,2) NOT NULL` -> `CHECK (TotalPrice >= 0)`
   - `UNIQUE (CustomerID, ShowtimeID)`

6. **`Review`**
   - `ReviewID INT IDENTITY(1,1)` (PK)
   - `CustomerID INT NOT NULL` (FK -> `Customer.CustomerID`)
   - `MovieID INT NOT NULL` (FK -> `Movie.MovieID`)
   - `Rating TINYINT NOT NULL` -> `CHECK (Rating BETWEEN 1 AND 5)`
   - `ReviewText NVARCHAR(MAX) NULL`
   - `ReviewDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()`
   - `UNIQUE (CustomerID, MovieID)`

## 3. Stored Procedures & Business Logic (`Procedures.sql`)
Every procedure MUST begin with a multi-line comment block explaining what it does and its parameters, plus inline step-by-step comments.

### Critical Business Rules to Enforce Inside Procedures:
- **Showtime Overlap Prevention (Insert/Update Showtime):** Before inserting or rescheduling a `Showtime`, look up the `RuntimeMinutes` of the new movie and verify no active (`IsCancelled = 0`) showtime in the same `ScreenRoomID` overlaps the interval `[StartDateTime, DATEADD(MINUTE, RuntimeMinutes, StartDateTime)]`. If an overlap exists, raise a descriptive error with `THROW 50001, 'Showtime overlaps with another scheduled movie in this room.', 1;`.
- **Capacity & TotalPrice Calculation (Insert/Update Booking):**
  - Automatically calculate `TotalPrice = @NumberOfTickets * Showtime.TicketPrice`.
  - Calculate remaining seats: `ScreenRoom.Capacity - ISNULL(SUM(Booking.NumberOfTickets), 0)` (excluding the current booking if updating).
  - If `@NumberOfTickets > RemainingSeats` (or if the showtime is cancelled), reject with `THROW 50002, 'Not enough remaining seats in this screening room.', 1;`.
- **Upsert / Merge Support:** For `Booking` and `Review`, support updating existing rows or clean `INSERT`/`UPDATE` procedures respecting `UNIQUE(CustomerID, ShowtimeID)` and `UNIQUE(CustomerID, MovieID)`.

### The 4 Required Aggregating Queries (Must be in `Procedures.sql`):
1. `usp_Report_MoviePerformance (@FirstDate DATE, @LastDate DATE)`
   - Returns: `MovieID`, `Title`, `ShowtimeCount`, `TicketsSold`, `TotalRevenue`, `AverageTicketsPerShowtime`
   - Aggregates across `Movie`, `Showtime`, and `Booking` using `GROUP BY`.
2. `usp_Report_CustomerBookingActivity (@FirstDate DATE, @LastDate DATE)`
   - Returns: `CustomerID`, `CustomerName`, `BookingCount`, `TicketsPurchased`, `TotalSpent`, `SpendingRank`
   - Aggregates across `Customer` and `Booking` using `GROUP BY` and `RANK() OVER (ORDER BY SUM(b.TotalPrice) DESC)`.
3. `usp_Report_ScreenRoomUtilization (@FirstDate DATE, @LastDate DATE)`
   - Returns: `ScreenRoomID`, `RoomNumber`, `ShowtimeCount`, `TicketsBooked`, `SeatsOffered`, `OccupancyRate`
   - Aggregates across `ScreenRoom`, `Showtime`, and `Booking`. (`SeatsOffered = COUNT(DISTINCT s.ShowtimeID) * sr.Capacity`).
4. `usp_Report_MovieReviewSummary (@MinimumReviewCount INT)`
   - Returns: `MovieID`, `Title`, `ReviewCount`, `AverageRating`, `HighestRating`, `LowestRating`
   - Aggregates across `Movie` and `Review` with `GROUP BY` and `HAVING COUNT(r.ReviewID) >= @MinimumReviewCount`.

## Professor Feedback and Seed Rules
- Static seventh table: `AgeRating(AgeRating NVARCHAR(10) NOT NULL PRIMARY KEY, Description NVARCHAR(200) NOT NULL)`. Seed G, PG, PG-13, R, NC-17, NR in Tables.sql before Movie inserts; drop it after Movie during resets.
- Use SQL-managed timestamps on inactive/cancelled inserts. On updates use `CASE WHEN @IsActive = 0 THEN COALESCE(DeactivatedOn, SYSDATETIME()) ELSE NULL END`; use the equivalent cancellation expression for Showtime. No timestamp request parameters.
- Use `SET XACT_ABORT ON`, TRY/CATCH and BEGIN/COMMIT TRANSACTION; catch with `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;`. No application locks. Retain row/range locks for validation reads with explained `UPDLOCK, HOLDLOCK` hints.
- Friendly checks cover duplicate natural keys, bookings/reviews, and inactive movie/customer/room booking references. UNIQUE/FK/CHECK constraints remain final safeguards.
- Seed 1-8 ticket parties with varied occupancy, at least 20 review sentences, varied descriptions, and inactive/cancelled historical examples. Historical cancelled screenings may retain bookings; validate their quantities and prices without rejecting that history.
