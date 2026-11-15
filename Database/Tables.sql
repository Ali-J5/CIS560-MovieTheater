-- Run in your selected SQL Server database: Tables.sql, Procedures.sql, then Data.sql.
-- WARNING: Re-running this schema script removes all existing project data.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Drop children before parents so foreign keys never reference a dropped table.
DROP TABLE IF EXISTS dbo.Review;
DROP TABLE IF EXISTS dbo.Booking;
DROP TABLE IF EXISTS dbo.Showtime;
DROP TABLE IF EXISTS dbo.Customer;
DROP TABLE IF EXISTS dbo.ScreenRoom;
DROP TABLE IF EXISTS dbo.Movie;
DROP TABLE IF EXISTS dbo.AgeRating;
GO

-- Static rating codes are shared by the catalog; this relation is not user-editable.
CREATE TABLE dbo.AgeRating
(
    -- The published rating code is the natural primary key.
    AgeRating NVARCHAR(10) NOT NULL,
    -- Explain the audience guidance for each supported rating.
    Description NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_AgeRating PRIMARY KEY (AgeRating)
);
GO
-- Populate the lookup before any Movie row can reference it.
INSERT dbo.AgeRating (AgeRating, Description) VALUES
(N'G', N'General audiences; all ages admitted.'),
(N'PG', N'Parental guidance suggested.'),
(N'PG-13', N'Parents strongly cautioned; some material may be inappropriate for children under 13.'),
(N'R', N'Restricted; children under 17 require an accompanying parent or adult guardian.'),
(N'NC-17', N'No one 17 and under admitted.'),
(N'NR', N'Not rated.');
GO

-- Movie stores the movie catalog; deactivate rows to retain history.
CREATE TABLE dbo.Movie
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    MovieID INT IDENTITY(1,1) NOT NULL,
    -- Title: required value.
    Title NVARCHAR(200) NOT NULL,
    -- ReleaseDate: required value.
    ReleaseDate DATE NOT NULL,
    -- Genre: required value.
    Genre NVARCHAR(50) NOT NULL,
    -- RuntimeMinutes: required value.
    RuntimeMinutes INT NOT NULL,
    -- AgeRating: required value.
    AgeRating NVARCHAR(10) NOT NULL,
    -- Description: optional value.
    Description NVARCHAR(MAX) NULL,
    -- Default new records to active.
    IsActive BIT NOT NULL CONSTRAINT DF_Movie_IsActive DEFAULT (1),
    -- Preserve the first deactivation time; reactivation clears this value.
    DeactivatedOn DATETIME2 NULL,
    -- Uniquely identify every movie row.
    CONSTRAINT PK_Movie PRIMARY KEY (MovieID),
    -- Prevent duplicate releases while allowing remakes.
    CONSTRAINT UQ_Movie_Title_ReleaseDate UNIQUE (Title, ReleaseDate),
    -- Require a positive runtime in minutes.
    CONSTRAINT CK_Movie_Runtime CHECK (RuntimeMinutes > 0),
    -- Require a supported code from the static rating relation.
    CONSTRAINT FK_Movie_AgeRating FOREIGN KEY (AgeRating) REFERENCES dbo.AgeRating(AgeRating)
);
GO

-- ScreenRoom stores the physical rooms in this single theater.
CREATE TABLE dbo.ScreenRoom
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    ScreenRoomID INT IDENTITY(1,1) NOT NULL,
    -- RoomNumber: required value.
    RoomNumber NVARCHAR(100) NOT NULL,
    -- Name: required value.
    Name NVARCHAR(100) NOT NULL,
    -- ScreenType: required value.
    ScreenType NVARCHAR(50) NOT NULL,
    -- Capacity: required value.
    Capacity INT NOT NULL,
    -- Default new records to active.
    IsActive BIT NOT NULL CONSTRAINT DF_ScreenRoom_IsActive DEFAULT (1),
    -- Preserve the first deactivation time; reactivation clears this value.
    DeactivatedOn DATETIME2 NULL,
    -- Uniquely identify every screenroom row.
    CONSTRAINT PK_ScreenRoom PRIMARY KEY (ScreenRoomID),
    -- Give each physical room a unique number.
    CONSTRAINT UQ_ScreenRoom_RoomNumber UNIQUE (RoomNumber),
    -- Require at least one seat.
    CONSTRAINT CK_ScreenRoom_Capacity CHECK (Capacity > 0)
);
GO

-- Customer stores customer contact details; deactivate instead of deleting.
CREATE TABLE dbo.Customer
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    CustomerID INT IDENTITY(1,1) NOT NULL,
    -- Email: required value.
    Email NVARCHAR(200) NOT NULL,
    -- PhoneNumber: required value.
    PhoneNumber VARCHAR(25) NOT NULL,
    -- FirstName: required value.
    FirstName NVARCHAR(50) NOT NULL,
    -- LastName: required value.
    LastName NVARCHAR(50) NOT NULL,
    -- Default new records to active.
    IsActive BIT NOT NULL CONSTRAINT DF_Customer_IsActive DEFAULT (1),
    -- Preserve the first deactivation time; reactivation clears this value.
    DeactivatedOn DATETIME2 NULL,
    -- Uniquely identify every customer row.
    CONSTRAINT PK_Customer PRIMARY KEY (CustomerID),
    -- Prevent duplicate email addresses.
    CONSTRAINT UQ_Customer_Email UNIQUE (Email),
    -- Prevent duplicate phone numbers.
    CONSTRAINT UQ_Customer_PhoneNumber UNIQUE (PhoneNumber)
);
GO

-- Showtime stores scheduled screenings; cancellation preserves history.
CREATE TABLE dbo.Showtime
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    ShowtimeID INT IDENTITY(1,1) NOT NULL,
    -- MovieID: required value.
    MovieID INT NOT NULL,
    -- ScreenRoomID: required value.
    ScreenRoomID INT NOT NULL,
    -- StartDateTime: required value.
    StartDateTime DATETIME2 NOT NULL,
    -- TicketPrice: required value.
    TicketPrice DECIMAL(10,2) NOT NULL,
    -- Default new screenings to not cancelled.
    IsCancelled BIT NOT NULL CONSTRAINT DF_Showtime_IsCancelled DEFAULT (0),
    -- Preserve the first cancellation time; restoration clears this value.
    CancelledOn DATETIME2 NULL,
    -- Uniquely identify every showtime row.
    CONSTRAINT PK_Showtime PRIMARY KEY (ShowtimeID),
    -- Require an existing movie; no cascading deletion.
    CONSTRAINT FK_Showtime_Movie FOREIGN KEY (MovieID) REFERENCES dbo.Movie(MovieID),
    -- Require an existing room; no cascading deletion.
    CONSTRAINT FK_Showtime_ScreenRoom FOREIGN KEY (ScreenRoomID) REFERENCES dbo.ScreenRoom(ScreenRoomID),
    -- Prevent duplicate start times in a room, including cancelled rows.
    CONSTRAINT UQ_Showtime_Room_Start UNIQUE (ScreenRoomID, StartDateTime),
    -- Allow free screenings but never negative prices.
    CONSTRAINT CK_Showtime_TicketPrice CHECK (TicketPrice >= 0)
);
GO

-- Booking stores ticket reservations and the price charged at booking time.
CREATE TABLE dbo.Booking
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    BookingID INT IDENTITY(1,1) NOT NULL,
    -- CustomerID: required value.
    CustomerID INT NOT NULL,
    -- ShowtimeID: required value.
    ShowtimeID INT NOT NULL,
    -- Default to the database server local date and time.
    BookingDate DATETIME2 NOT NULL CONSTRAINT DF_Booking_BookingDate DEFAULT (SYSDATETIME()),
    -- NumberOfTickets: required value.
    NumberOfTickets INT NOT NULL,
    -- TotalPrice: required value.
    TotalPrice DECIMAL(10,2) NOT NULL,
    -- Uniquely identify every booking row.
    CONSTRAINT PK_Booking PRIMARY KEY (BookingID),
    -- Require an existing customer; preserve booking history.
    CONSTRAINT FK_Booking_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID),
    -- Require an existing screening; no cascading deletion.
    CONSTRAINT FK_Booking_Showtime FOREIGN KEY (ShowtimeID) REFERENCES dbo.Showtime(ShowtimeID),
    -- Store one booking per customer and screening; edit its ticket count.
    CONSTRAINT UQ_Booking_Customer_Showtime UNIQUE (CustomerID, ShowtimeID),
    -- Require at least one ticket.
    CONSTRAINT CK_Booking_Tickets CHECK (NumberOfTickets > 0),
    -- Disallow negative booking totals.
    CONSTRAINT CK_Booking_TotalPrice CHECK (TotalPrice >= 0)
);
GO

-- Review stores customer ratings and optional written feedback.
CREATE TABLE dbo.Review
(
    -- Surrogate key: SQL Server generates consecutive identifiers.
    ReviewID INT IDENTITY(1,1) NOT NULL,
    -- CustomerID: required value.
    CustomerID INT NOT NULL,
    -- MovieID: required value.
    MovieID INT NOT NULL,
    -- Rating: required value.
    Rating TINYINT NOT NULL,
    -- ReviewText: optional value.
    ReviewText NVARCHAR(MAX) NULL,
    -- Default to the database server local date and time.
    ReviewDate DATETIME2 NOT NULL CONSTRAINT DF_Review_ReviewDate DEFAULT (SYSDATETIME()),
    -- Uniquely identify every review row.
    CONSTRAINT PK_Review PRIMARY KEY (ReviewID),
    -- Require an existing reviewer; no cascading deletion.
    CONSTRAINT FK_Review_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID),
    -- Require an existing movie; no cascading deletion.
    CONSTRAINT FK_Review_Movie FOREIGN KEY (MovieID) REFERENCES dbo.Movie(MovieID),
    -- Allow one review per customer and movie.
    CONSTRAINT UQ_Review_Customer_Movie UNIQUE (CustomerID, MovieID),
    -- Restrict ratings to the one-to-five scale.
    CONSTRAINT CK_Review_Rating CHECK (Rating BETWEEN 1 AND 5)
);
GO
