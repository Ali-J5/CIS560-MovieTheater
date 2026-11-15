-- Run after Tables.sql. Execute each GO-delimited batch with SSMS or sqlcmd.
-- Call these procedures from parameterized ADO.NET commands; direct table writes bypass rules.
-- Dates use server local time. Report date ranges include both endpoints.
-- UPDLOCK reserves rows for a possible update; HOLDLOCK also protects matching key ranges.
-- These validation locks last until COMMIT/ROLLBACK, preventing competing check/write races.
-- Updates are full replacements: callers supply every editable field.
-- Prices on existing bookings remain historical if a showtime price changes;
-- editing a booking recalculates its entire total using the current ticket price.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
Search the catalog; NULL filters match all values.
Parameters:
  @Title NVARCHAR(200) = NULL, -- Optional title substring.
  @Genre NVARCHAR(50) = NULL, -- Optional exact genre.
  @AgeRating NVARCHAR(10) = NULL, -- Optional exact rating.
  @IncludeInactive BIT = 0 -- Set to 1 to include deactivated movies.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetMovies
@Title NVARCHAR(200) = NULL, -- Optional title substring.
@Genre NVARCHAR(50) = NULL, -- Optional exact genre.
@AgeRating NVARCHAR(10) = NULL, -- Optional exact rating.
@IncludeInactive BIT = 0 -- Set to 1 to include deactivated movies.
AS
BEGIN
    SET NOCOUNT ON;
    -- Apply each supplied filter independently; order results for the UI.
    SELECT MovieID, Title, ReleaseDate, Genre, RuntimeMinutes, AgeRating, Description, IsActive, DeactivatedOn
    FROM dbo.Movie
    WHERE (@IncludeInactive = 1 OR IsActive = 1)
      AND (@Title IS NULL OR Title LIKE N'%' + @Title + N'%')
      AND (@Genre IS NULL OR Genre = @Genre)
      AND (@AgeRating IS NULL OR AgeRating = @AgeRating)
    ORDER BY Title, ReleaseDate;
END;
GO

/*
Read ScreenRoom records for selection or administration.
Parameters:
  @IncludeInactive BIT = 0 -- Include soft-deleted rows when 1.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetScreenRooms
@IncludeInactive BIT = 0 -- Include soft-deleted rows when 1.
AS
BEGIN
    SET NOCOUNT ON;
    -- Hide inactive records by default.
    SELECT ScreenRoomID, RoomNumber, Name, ScreenType, Capacity, IsActive, DeactivatedOn
    FROM dbo.ScreenRoom
    WHERE @IncludeInactive = 1 OR IsActive = 1
    ORDER BY ScreenRoomID;
END;
GO

/*
Read Customer records for selection or administration.
Parameters:
  @IncludeInactive BIT = 0 -- Include soft-deleted rows when 1.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetCustomers
@IncludeInactive BIT = 0 -- Include soft-deleted rows when 1.
AS
BEGIN
    SET NOCOUNT ON;
    -- Hide inactive records by default.
    SELECT CustomerID, Email, PhoneNumber, FirstName, LastName, IsActive, DeactivatedOn
    FROM dbo.Customer
    WHERE @IncludeInactive = 1 OR IsActive = 1
    ORDER BY CustomerID;
END;
GO

/*
Insert a Movie record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @Title NVARCHAR(200), -- Value for the new record.
  @ReleaseDate DATE, -- Value for the new record.
  @Genre NVARCHAR(50), -- Value for the new record.
  @RuntimeMinutes INT, -- Value for the new record.
  @AgeRating NVARCHAR(10), -- Value for the new record.
  @Description NVARCHAR(MAX) = NULL, -- Value for the new record.
  @IsActive BIT = 1 -- Value for the new record.
*/
CREATE OR ALTER PROCEDURE dbo.usp_InsertMovie
@Title NVARCHAR(200), -- Value for the new record.
@ReleaseDate DATE, -- Value for the new record.
@Genre NVARCHAR(50), -- Value for the new record.
@RuntimeMinutes INT, -- Value for the new record.
@AgeRating NVARCHAR(10), -- Value for the new record.
@Description NVARCHAR(MAX) = NULL, -- Value for the new record.
@IsActive BIT = 1 -- Value for the new record.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @RuntimeMinutes IS NULL OR @RuntimeMinutes <= 0
            THROW 50005, 'Movie runtime must be greater than zero minutes.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE Title = @Title AND ReleaseDate = @ReleaseDate)
            THROW 50007, 'This movie release is already in the catalog.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.AgeRating WITH (UPDLOCK, HOLDLOCK) WHERE AgeRating = @AgeRating)
            THROW 50007, 'Choose a supported age rating.', 1;

        -- Write the supplied fields; constraints validate references and values.
        INSERT dbo.Movie (Title, ReleaseDate, Genre, RuntimeMinutes, AgeRating, Description, IsActive, DeactivatedOn)
        VALUES (@Title, @ReleaseDate, @Genre, @RuntimeMinutes, @AgeRating, @Description, @IsActive, CASE WHEN @IsActive = 0 THEN SYSDATETIME() ELSE NULL END);
        -- Return the generated identifier to the backend.
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS MovieID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Update a Movie record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @MovieID INT, -- Record to edit.
  @Title NVARCHAR(200), -- Replacement value.
  @ReleaseDate DATE, -- Replacement value.
  @Genre NVARCHAR(50), -- Replacement value.
  @RuntimeMinutes INT, -- Replacement value.
  @AgeRating NVARCHAR(10), -- Replacement value.
  @Description NVARCHAR(MAX) = NULL, -- Replacement value.
  @IsActive BIT -- Replacement value.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateMovie
@MovieID INT, -- Record to edit.
@Title NVARCHAR(200), -- Replacement value.
@ReleaseDate DATE, -- Replacement value.
@Genre NVARCHAR(50), -- Replacement value.
@RuntimeMinutes INT, -- Replacement value.
@AgeRating NVARCHAR(10), -- Replacement value.
@Description NVARCHAR(MAX) = NULL, -- Replacement value.
@IsActive BIT -- Replacement value.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @RuntimeMinutes IS NULL OR @RuntimeMinutes <= 0
            THROW 50005, 'Movie runtime must be greater than zero minutes.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE Title = @Title AND ReleaseDate = @ReleaseDate AND MovieID <> @MovieID)
            THROW 50007, 'This movie release is already in the catalog.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.AgeRating WITH (UPDLOCK, HOLDLOCK) WHERE AgeRating = @AgeRating)
            THROW 50007, 'Choose a supported age rating.', 1;

        -- Reject unknown identifiers instead of silently updating zero rows.
        IF NOT EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID)
            THROW 50004, 'Movie was not found.', 1;
        -- A runtime edit must not make any existing active screening overlap its neighbor.
        IF EXISTS (
            SELECT 1 FROM dbo.Showtime a WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Showtime b WITH (UPDLOCK, HOLDLOCK) ON a.ScreenRoomID = b.ScreenRoomID AND a.ShowtimeID < b.ShowtimeID
            JOIN dbo.Movie ma WITH (UPDLOCK, HOLDLOCK) ON ma.MovieID = a.MovieID
            JOIN dbo.Movie mb WITH (UPDLOCK, HOLDLOCK) ON mb.MovieID = b.MovieID
            WHERE a.IsCancelled = 0 AND b.IsCancelled = 0
              AND (a.MovieID = @MovieID OR b.MovieID = @MovieID)
              AND a.StartDateTime < DATEADD(MINUTE, CASE WHEN b.MovieID = @MovieID THEN @RuntimeMinutes ELSE mb.RuntimeMinutes END, b.StartDateTime)
              AND b.StartDateTime < DATEADD(MINUTE, CASE WHEN a.MovieID = @MovieID THEN @RuntimeMinutes ELSE ma.RuntimeMinutes END, a.StartDateTime))
            THROW 50001, 'Runtime change would overlap scheduled movies in a room.', 1;
        -- Replace editable fields; soft-delete by passing IsActive = 0.
        UPDATE dbo.Movie SET Title = @Title, ReleaseDate = @ReleaseDate, Genre = @Genre, RuntimeMinutes = @RuntimeMinutes, AgeRating = @AgeRating, Description = @Description, IsActive = @IsActive,
            -- Retain the original timestamp on repeated deactivation; clear it on restoration.
            DeactivatedOn = CASE WHEN @IsActive = 0 THEN COALESCE(DeactivatedOn, SYSDATETIME()) ELSE NULL END
        WHERE MovieID = @MovieID;
        SELECT @MovieID AS MovieID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Insert a ScreenRoom record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @RoomNumber NVARCHAR(100), -- Value for the new record.
  @Name NVARCHAR(100), -- Value for the new record.
  @ScreenType NVARCHAR(50), -- Value for the new record.
  @Capacity INT, -- Value for the new record.
  @IsActive BIT = 1 -- Value for the new record.
*/
CREATE OR ALTER PROCEDURE dbo.usp_InsertScreenRoom
@RoomNumber NVARCHAR(100), -- Value for the new record.
@Name NVARCHAR(100), -- Value for the new record.
@ScreenType NVARCHAR(50), -- Value for the new record.
@Capacity INT, -- Value for the new record.
@IsActive BIT = 1 -- Value for the new record.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @Capacity IS NULL OR @Capacity <= 0
            THROW 50005, 'Room capacity must be greater than zero.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE RoomNumber = @RoomNumber)
            THROW 50007, 'That room number already exists.', 1;

        -- Write the supplied fields; constraints validate references and values.
        INSERT dbo.ScreenRoom (RoomNumber, Name, ScreenType, Capacity, IsActive, DeactivatedOn)
        VALUES (@RoomNumber, @Name, @ScreenType, @Capacity, @IsActive, CASE WHEN @IsActive = 0 THEN SYSDATETIME() ELSE NULL END);
        -- Return the generated identifier to the backend.
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS ScreenRoomID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Update a ScreenRoom record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @ScreenRoomID INT, -- Record to edit.
  @RoomNumber NVARCHAR(100), -- Replacement value.
  @Name NVARCHAR(100), -- Replacement value.
  @ScreenType NVARCHAR(50), -- Replacement value.
  @Capacity INT, -- Replacement value.
  @IsActive BIT -- Replacement value.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateScreenRoom
@ScreenRoomID INT, -- Record to edit.
@RoomNumber NVARCHAR(100), -- Replacement value.
@Name NVARCHAR(100), -- Replacement value.
@ScreenType NVARCHAR(50), -- Replacement value.
@Capacity INT, -- Replacement value.
@IsActive BIT -- Replacement value.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @Capacity IS NULL OR @Capacity <= 0
            THROW 50005, 'Room capacity must be greater than zero.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE RoomNumber = @RoomNumber AND ScreenRoomID <> @ScreenRoomID)
            THROW 50007, 'That room number already exists.', 1;

        -- Reject unknown identifiers instead of silently updating zero rows.
        IF NOT EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID)
            THROW 50004, 'ScreenRoom was not found.', 1;
        -- Reducing capacity cannot strand tickets already booked for any screening.
        IF EXISTS (SELECT 1 FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK) JOIN dbo.Booking b WITH (UPDLOCK, HOLDLOCK) ON b.ShowtimeID = s.ShowtimeID
            WHERE s.ScreenRoomID = @ScreenRoomID GROUP BY s.ShowtimeID
            HAVING SUM(CONVERT(BIGINT, b.NumberOfTickets)) > @Capacity)
            THROW 50002, 'Room capacity cannot be less than tickets already booked.', 1;
        -- Replace editable fields; soft-delete by passing IsActive = 0.
        UPDATE dbo.ScreenRoom SET RoomNumber = @RoomNumber, Name = @Name, ScreenType = @ScreenType, Capacity = @Capacity, IsActive = @IsActive,
            -- Retain the original timestamp on repeated deactivation; clear it on restoration.
            DeactivatedOn = CASE WHEN @IsActive = 0 THEN COALESCE(DeactivatedOn, SYSDATETIME()) ELSE NULL END
        WHERE ScreenRoomID = @ScreenRoomID;
        SELECT @ScreenRoomID AS ScreenRoomID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Insert a Customer record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @Email NVARCHAR(200), -- Value for the new record.
  @PhoneNumber VARCHAR(25), -- Value for the new record.
  @FirstName NVARCHAR(50), -- Value for the new record.
  @LastName NVARCHAR(50), -- Value for the new record.
  @IsActive BIT = 1 -- Value for the new record.
*/
CREATE OR ALTER PROCEDURE dbo.usp_InsertCustomer
@Email NVARCHAR(200), -- Value for the new record.
@PhoneNumber VARCHAR(25), -- Value for the new record.
@FirstName NVARCHAR(50), -- Value for the new record.
@LastName NVARCHAR(50), -- Value for the new record.
@IsActive BIT = 1 -- Value for the new record.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE Email = @Email)
            THROW 50007, 'That email address is already used by another customer.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE PhoneNumber = @PhoneNumber)
            THROW 50007, 'That phone number is already used by another customer.', 1;

        -- Write the supplied fields; constraints validate references and values.
        INSERT dbo.Customer (Email, PhoneNumber, FirstName, LastName, IsActive, DeactivatedOn)
        VALUES (@Email, @PhoneNumber, @FirstName, @LastName, @IsActive, CASE WHEN @IsActive = 0 THEN SYSDATETIME() ELSE NULL END);
        -- Return the generated identifier to the backend.
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS CustomerID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Update a Customer record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @CustomerID INT, -- Record to edit.
  @Email NVARCHAR(200), -- Replacement value.
  @PhoneNumber VARCHAR(25), -- Replacement value.
  @FirstName NVARCHAR(50), -- Replacement value.
  @LastName NVARCHAR(50), -- Replacement value.
  @IsActive BIT -- Replacement value.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateCustomer
@CustomerID INT, -- Record to edit.
@Email NVARCHAR(200), -- Replacement value.
@PhoneNumber VARCHAR(25), -- Replacement value.
@FirstName NVARCHAR(50), -- Replacement value.
@LastName NVARCHAR(50), -- Replacement value.
@IsActive BIT -- Replacement value.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE Email = @Email AND CustomerID <> @CustomerID)
            THROW 50007, 'That email address is already used by another customer.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE PhoneNumber = @PhoneNumber AND CustomerID <> @CustomerID)
            THROW 50007, 'That phone number is already used by another customer.', 1;

        -- Reject unknown identifiers instead of silently updating zero rows.
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID)
            THROW 50004, 'Customer was not found.', 1;
        -- Replace editable fields; soft-delete by passing IsActive = 0.
        UPDATE dbo.Customer SET Email = @Email, PhoneNumber = @PhoneNumber, FirstName = @FirstName, LastName = @LastName, IsActive = @IsActive,
            -- Retain the original timestamp on repeated deactivation; clear it on restoration.
            DeactivatedOn = CASE WHEN @IsActive = 0 THEN COALESCE(DeactivatedOn, SYSDATETIME()) ELSE NULL END
        WHERE CustomerID = @CustomerID;
        SELECT @CustomerID AS CustomerID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Insert a Review record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @CustomerID INT, -- Value for the new record.
  @MovieID INT, -- Value for the new record.
  @Rating TINYINT, -- Value for the new record.
  @ReviewText NVARCHAR(MAX) = NULL -- Value for the new record.
*/
CREATE OR ALTER PROCEDURE dbo.usp_InsertReview
@CustomerID INT, -- Value for the new record.
@MovieID INT, -- Value for the new record.
@Rating TINYINT, -- Value for the new record.
@ReviewText NVARCHAR(MAX) = NULL -- Value for the new record.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Review WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND MovieID = @MovieID)
            THROW 50007, 'You already reviewed this movie. Edit your existing review instead.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND IsActive = 1)
            THROW 50007, 'Choose an active customer before reviewing a movie.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID AND IsActive = 1)
            THROW 50007, 'This movie is unavailable for new or updated reviews.', 1;
        IF @Rating IS NULL OR @Rating NOT BETWEEN 1 AND 5
            THROW 50007, 'Choose a rating from one to five stars.', 1;

        -- Write the supplied fields; constraints validate references and values.
        INSERT dbo.Review (CustomerID, MovieID, Rating, ReviewText)
        VALUES (@CustomerID, @MovieID, @Rating, @ReviewText);
        -- Return the generated identifier to the backend.
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS ReviewID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Update a Review record; friendly checks explain duplicate values before UNIQUE constraints act as safeguards.
Parameters:
  @ReviewID INT, -- Record to edit.
  @CustomerID INT, -- Replacement value.
  @MovieID INT, -- Replacement value.
  @Rating TINYINT, -- Replacement value.
  @ReviewText NVARCHAR(MAX) = NULL -- Replacement value.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateReview
@ReviewID INT, -- Record to edit.
@CustomerID INT, -- Replacement value.
@MovieID INT, -- Replacement value.
@Rating TINYINT, -- Replacement value.
@ReviewText NVARCHAR(MAX) = NULL -- Replacement value.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Review WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND MovieID = @MovieID AND ReviewID <> @ReviewID)
            THROW 50007, 'You already reviewed this movie. Edit your existing review instead.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND IsActive = 1)
            THROW 50007, 'Choose an active customer before reviewing a movie.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID AND IsActive = 1)
            THROW 50007, 'This movie is unavailable for new or updated reviews.', 1;
        IF @Rating IS NULL OR @Rating NOT BETWEEN 1 AND 5
            THROW 50007, 'Choose a rating from one to five stars.', 1;

        -- Reject unknown identifiers instead of silently updating zero rows.
        IF NOT EXISTS (SELECT 1 FROM dbo.Review WITH (UPDLOCK, HOLDLOCK) WHERE ReviewID = @ReviewID)
            THROW 50004, 'Review was not found.', 1;
        -- Write the supplied fields; constraints validate references and values.
        UPDATE dbo.Review SET CustomerID = @CustomerID, MovieID = @MovieID, Rating = @Rating, ReviewText = @ReviewText
        WHERE ReviewID = @ReviewID;
        SELECT @ReviewID AS ReviewID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Read screenings with live seat availability; sold tickets include every booking.
Parameters:
  @MovieID INT = NULL, -- Optional movie filter.
  @FirstDate DATE = NULL, -- Optional inclusive start date.
  @LastDate DATE = NULL, -- Optional inclusive end date.
  @IncludeCancelled BIT = 0 -- Include cancelled screenings when 1.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetShowtimes
@MovieID INT = NULL, -- Optional movie filter.
@FirstDate DATE = NULL, -- Optional inclusive start date.
@LastDate DATE = NULL, -- Optional inclusive end date.
@IncludeCancelled BIT = 0 -- Include cancelled screenings when 1.
AS
BEGIN
    SET NOCOUNT ON;
    -- Aggregate bookings first so one screening produces exactly one result row.
    SELECT s.ShowtimeID, s.MovieID, m.Title, m.RuntimeMinutes, s.ScreenRoomID,
        sr.RoomNumber, sr.Name AS RoomName, sr.Capacity AS RoomCapacity,
        s.StartDateTime, s.TicketPrice, s.IsCancelled, s.CancelledOn,
        COALESCE(b.TicketsSold, 0) AS TicketsSold,
        sr.Capacity - COALESCE(b.TicketsSold, 0) AS RemainingSeats
    FROM dbo.Showtime s
    JOIN dbo.Movie m ON m.MovieID = s.MovieID
    JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = s.ScreenRoomID
    LEFT JOIN (SELECT ShowtimeID, SUM(CONVERT(BIGINT, NumberOfTickets)) AS TicketsSold
               FROM dbo.Booking GROUP BY ShowtimeID) b ON b.ShowtimeID = s.ShowtimeID
    WHERE (@MovieID IS NULL OR s.MovieID = @MovieID)
      AND (@FirstDate IS NULL OR CAST(s.StartDateTime AS DATE) >= @FirstDate)
      AND (@LastDate IS NULL OR CAST(s.StartDateTime AS DATE) <= @LastDate)
      AND (@IncludeCancelled = 1 OR s.IsCancelled = 0)
    ORDER BY s.StartDateTime, sr.RoomNumber;
END;
GO

/*
Schedule or cancel a screening while enforcing runtime-based room availability.
Parameters:
  @MovieID INT, -- Movie whose runtime defines the end time.
  @ScreenRoomID INT, -- Physical room for the screening.
  @StartDateTime DATETIME2, -- Local screening start time.
  @TicketPrice DECIMAL(10,2), -- Current price per ticket.
  @IsCancelled BIT = 0 -- Cancel instead of deleting the screening.
*/
CREATE OR ALTER PROCEDURE dbo.usp_InsertShowtime
@MovieID INT, -- Movie whose runtime defines the end time.
@ScreenRoomID INT, -- Physical room for the screening.
@StartDateTime DATETIME2, -- Local screening start time.
@TicketPrice DECIMAL(10,2), -- Current price per ticket.
@IsCancelled BIT = 0 -- Cancel instead of deleting the screening.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @TicketPrice IS NULL OR @TicketPrice < 0
            THROW 50005, 'Ticket price cannot be negative.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Showtime WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID AND StartDateTime = @StartDateTime)
            THROW 50007, 'This room already has a screening at that start time, possibly cancelled. Edit that screening or choose another time.', 1;
        IF @IsCancelled = 0 AND (NOT EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID AND IsActive = 1) OR NOT EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID AND IsActive = 1))
            THROW 50007, 'Choose an active movie and screening room before scheduling or restoring a screening.', 1;

        -- Read the referenced movie and reject missing references with a clear error.
        DECLARE @Runtime INT;
        SELECT @Runtime = RuntimeMinutes FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID;
        IF @Runtime IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID)
            THROW 50004, 'Movie or screening room was not found.', 1;
        -- Half-open intervals allow the next movie to start exactly when this one ends.
        IF @IsCancelled = 0 AND EXISTS (
            SELECT 1 FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK) JOIN dbo.Movie m WITH (UPDLOCK, HOLDLOCK) ON m.MovieID = s.MovieID
            WHERE s.ScreenRoomID = @ScreenRoomID AND s.IsCancelled = 0
              AND s.StartDateTime < DATEADD(MINUTE, @Runtime, @StartDateTime)
              AND @StartDateTime < DATEADD(MINUTE, m.RuntimeMinutes, s.StartDateTime))
            THROW 50001, 'Showtime overlaps with another scheduled movie in this room.', 1;
        -- Insert after validation and return the generated key.
        INSERT dbo.Showtime (MovieID, ScreenRoomID, StartDateTime, TicketPrice, IsCancelled, CancelledOn)
        VALUES (@MovieID, @ScreenRoomID, @StartDateTime, @TicketPrice, @IsCancelled, CASE WHEN @IsCancelled = 1 THEN SYSDATETIME() ELSE NULL END);
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS ShowtimeID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Schedule or cancel a screening while enforcing runtime-based room availability.
Parameters:
  @ShowtimeID INT, -- Screening to edit.
  @MovieID INT, -- Movie whose runtime defines the end time.
  @ScreenRoomID INT, -- Physical room for the screening.
  @StartDateTime DATETIME2, -- Local screening start time.
  @TicketPrice DECIMAL(10,2), -- Current price per ticket.
  @IsCancelled BIT = 0 -- Cancel instead of deleting the screening.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateShowtime
@ShowtimeID INT, -- Screening to edit.
@MovieID INT, -- Movie whose runtime defines the end time.
@ScreenRoomID INT, -- Physical room for the screening.
@StartDateTime DATETIME2, -- Local screening start time.
@TicketPrice DECIMAL(10,2), -- Current price per ticket.
@IsCancelled BIT = 0 -- Cancel instead of deleting the screening.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Validate numeric ranges before writing the row.
        IF @TicketPrice IS NULL OR @TicketPrice < 0
            THROW 50005, 'Ticket price cannot be negative.', 1;

        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Showtime WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID AND StartDateTime = @StartDateTime AND ShowtimeID <> @ShowtimeID)
            THROW 50007, 'This room already has a screening at that start time, possibly cancelled. Edit that screening or choose another time.', 1;
        IF @IsCancelled = 0 AND (NOT EXISTS (SELECT 1 FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID AND IsActive = 1) OR NOT EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID AND IsActive = 1))
            THROW 50007, 'Choose an active movie and screening room before scheduling or restoring a screening.', 1;

        -- Ensure an update targets an existing screening.
        IF NOT EXISTS (SELECT 1 FROM dbo.Showtime WITH (UPDLOCK, HOLDLOCK) WHERE ShowtimeID = @ShowtimeID)
            THROW 50004, 'Showtime was not found.', 1;
        -- Read the referenced movie and reject missing references with a clear error.
        DECLARE @Runtime INT;
        SELECT @Runtime = RuntimeMinutes FROM dbo.Movie WITH (UPDLOCK, HOLDLOCK) WHERE MovieID = @MovieID;
        IF @Runtime IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID)
            THROW 50004, 'Movie or screening room was not found.', 1;
        -- Half-open intervals allow the next movie to start exactly when this one ends.
        IF @IsCancelled = 0 AND EXISTS (
            SELECT 1 FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK) JOIN dbo.Movie m WITH (UPDLOCK, HOLDLOCK) ON m.MovieID = s.MovieID
            WHERE s.ScreenRoomID = @ScreenRoomID AND s.IsCancelled = 0
              AND s.ShowtimeID <> @ShowtimeID
              AND s.StartDateTime < DATEADD(MINUTE, @Runtime, @StartDateTime)
              AND @StartDateTime < DATEADD(MINUTE, m.RuntimeMinutes, s.StartDateTime))
            THROW 50001, 'Showtime overlaps with another scheduled movie in this room.', 1;
        -- Moving a screening to a smaller room must preserve capacity for existing bookings.
        IF (SELECT COALESCE(SUM(CONVERT(BIGINT, NumberOfTickets)), 0) FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE ShowtimeID = @ShowtimeID)
           > (SELECT Capacity FROM dbo.ScreenRoom WITH (UPDLOCK, HOLDLOCK) WHERE ScreenRoomID = @ScreenRoomID)
            THROW 50002, 'Destination room cannot hold tickets already booked.', 1;
        -- Cancellation retains the screening and its booking history.
        UPDATE dbo.Showtime SET MovieID = @MovieID, ScreenRoomID = @ScreenRoomID,
            StartDateTime = @StartDateTime, TicketPrice = @TicketPrice, IsCancelled = @IsCancelled,
            -- Retain the original cancellation time until the screening is restored.
            CancelledOn = CASE WHEN @IsCancelled = 1 THEN COALESCE(CancelledOn, SYSDATETIME()) ELSE NULL END
        WHERE ShowtimeID = @ShowtimeID;
        SELECT @ShowtimeID AS ShowtimeID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Read booking history with movie, room, and screening details.
Parameters:
  @CustomerID INT -- Customer whose bookings are requested.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetBookingsForCustomer
@CustomerID INT -- Customer whose bookings are requested.
AS
BEGIN
    SET NOCOUNT ON;
    -- Join through Showtime to describe each reservation without storing duplicate details.
    SELECT b.BookingID, b.CustomerID, b.ShowtimeID, b.BookingDate, b.NumberOfTickets, b.TotalPrice,
        s.MovieID, m.Title, s.StartDateTime, s.TicketPrice, s.IsCancelled,
        sr.ScreenRoomID, sr.RoomNumber, sr.Name AS RoomName
    FROM dbo.Booking b JOIN dbo.Showtime s ON s.ShowtimeID = b.ShowtimeID
    JOIN dbo.Movie m ON m.MovieID = s.MovieID
    JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = s.ScreenRoomID
    WHERE b.CustomerID = @CustomerID ORDER BY s.StartDateTime DESC;
END;
GO

/*
Create a reservation; reject duplicate customer/screening pairs with a friendly message.
Parameters:
  @CustomerID INT, -- Customer reserving tickets.
  @ShowtimeID INT, -- Screening to reserve.
  @NumberOfTickets INT -- Positive ticket count to reserve.
*/
CREATE OR ALTER PROCEDURE dbo.usp_CreateBooking
@CustomerID INT, -- Customer reserving tickets.
@ShowtimeID INT, -- Screening to reserve.
@NumberOfTickets INT -- Positive ticket count to reserve.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.
        IF EXISTS (SELECT 1 FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND ShowtimeID = @ShowtimeID)
            THROW 50007, 'You already booked this screening. Update your existing booking instead.', 1;

        -- Reject invalid quantities before calculating seats or money.
        IF @NumberOfTickets IS NULL OR @NumberOfTickets <= 0
            THROW 50005, 'Number of tickets must be positive.', 1;
        DECLARE @Capacity INT, @Price DECIMAL(10,2), @Cancelled BIT, @Sold BIGINT;
        SELECT @Capacity = sr.Capacity, @Price = s.TicketPrice, @Cancelled = s.IsCancelled
        FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK) JOIN dbo.ScreenRoom sr WITH (UPDLOCK, HOLDLOCK) ON sr.ScreenRoomID = s.ScreenRoomID
        WHERE s.ShowtimeID = @ShowtimeID;
        IF @Capacity IS NULL THROW 50004, 'Showtime was not found.', 1;
        -- Reservations require active participants, even when called outside the UI.
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = @CustomerID AND IsActive = 1)
            THROW 50008, 'This customer is inactive. Reactivate the account before booking.', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Movie m WITH (UPDLOCK, HOLDLOCK) ON m.MovieID = s.MovieID
            JOIN dbo.ScreenRoom sr WITH (UPDLOCK, HOLDLOCK) ON sr.ScreenRoomID = s.ScreenRoomID
            WHERE s.ShowtimeID = @ShowtimeID AND (m.IsActive = 0 OR sr.IsActive = 0))
            THROW 50008, 'This movie or screening room is inactive. Choose another screening.', 1;
        IF @Cancelled = 1 THROW 50002, 'Cannot book tickets for a cancelled showtime.', 1;
        -- Sum existing reservations before checking available seats.
        SELECT @Sold = COALESCE(SUM(CONVERT(BIGINT, NumberOfTickets)), 0)
        FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE ShowtimeID = @ShowtimeID
        ;
        IF @NumberOfTickets > @Capacity - @Sold
            THROW 50002, 'Not enough remaining seats in this screening room.', 1;
        -- Use decimal arithmetic; never accept a caller-supplied total price.
        INSERT dbo.Booking (CustomerID, ShowtimeID, NumberOfTickets, TotalPrice)
        VALUES (@CustomerID, @ShowtimeID, @NumberOfTickets, @NumberOfTickets * @Price);
        SELECT CONVERT(INT, SCOPE_IDENTITY()) AS BookingID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Replace the ticket count of an existing booking; preserve its customer and screening.
Parameters:
  @BookingID INT, -- Existing booking to edit.
  @NumberOfTickets INT -- Positive ticket count to reserve.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateBooking
@BookingID INT, -- Existing booking to edit.
@NumberOfTickets INT -- Positive replacement ticket count.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.

        -- Find the screening belonging to this booking; its customer and screening stay fixed.
        DECLARE @ShowtimeID INT;
        SELECT @ShowtimeID = ShowtimeID FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE BookingID = @BookingID;
        IF @ShowtimeID IS NULL THROW 50004, 'Booking was not found.', 1;
        -- Reject invalid quantities before calculating seats or money.
        IF @NumberOfTickets IS NULL OR @NumberOfTickets <= 0
            THROW 50005, 'Number of tickets must be positive.', 1;
        DECLARE @Capacity INT, @Price DECIMAL(10,2), @Cancelled BIT, @Sold BIGINT;
        SELECT @Capacity = sr.Capacity, @Price = s.TicketPrice, @Cancelled = s.IsCancelled
        FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK) JOIN dbo.ScreenRoom sr WITH (UPDLOCK, HOLDLOCK) ON sr.ScreenRoomID = s.ScreenRoomID
        WHERE s.ShowtimeID = @ShowtimeID;
        IF @Capacity IS NULL THROW 50004, 'Showtime was not found.', 1;
        -- Reservations require active participants, even when called outside the UI.
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK) WHERE CustomerID = (SELECT CustomerID FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE BookingID = @BookingID) AND IsActive = 1)
            THROW 50008, 'This customer is inactive. Reactivate the account before booking.', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.Showtime s WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Movie m WITH (UPDLOCK, HOLDLOCK) ON m.MovieID = s.MovieID
            JOIN dbo.ScreenRoom sr WITH (UPDLOCK, HOLDLOCK) ON sr.ScreenRoomID = s.ScreenRoomID
            WHERE s.ShowtimeID = @ShowtimeID AND (m.IsActive = 0 OR sr.IsActive = 0))
            THROW 50008, 'This movie or screening room is inactive. Choose another screening.', 1;
        IF @Cancelled = 1 THROW 50002, 'Cannot book tickets for a cancelled showtime.', 1;
        -- On update, exclude this booking so its old tickets become available to its replacement.
        SELECT @Sold = COALESCE(SUM(CONVERT(BIGINT, NumberOfTickets)), 0)
        FROM dbo.Booking WITH (UPDLOCK, HOLDLOCK) WHERE ShowtimeID = @ShowtimeID
          AND BookingID <> @BookingID
        ;
        IF @NumberOfTickets > @Capacity - @Sold
            THROW 50002, 'Not enough remaining seats in this screening room.', 1;
        -- Use decimal arithmetic; never accept a caller-supplied total price.
        UPDATE dbo.Booking SET NumberOfTickets = @NumberOfTickets,
            TotalPrice = @NumberOfTickets * @Price WHERE BookingID = @BookingID;
        SELECT @BookingID AS BookingID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Read ratings with reviewer names, newest first.
Parameters:
  @MovieID INT -- Movie whose reviews are requested.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetReviewsForMovie
@MovieID INT -- Movie whose reviews are requested.
AS
BEGIN
    SET NOCOUNT ON;
    -- Use customer names for display while retaining the review identifiers for editing.
    SELECT r.ReviewID, r.CustomerID, r.MovieID, c.FirstName, c.LastName,
        r.Rating, r.ReviewText, r.ReviewDate
    FROM dbo.Review r JOIN dbo.Customer c ON c.CustomerID = r.CustomerID
    WHERE r.MovieID = @MovieID ORDER BY r.ReviewDate DESC, r.ReviewID DESC;
END;
GO

/*
Cancel a booking and release its seats.
Parameters:
  @BookingID INT -- Record to permanently remove.
*/
CREATE OR ALTER PROCEDURE dbo.usp_DeleteBooking
@BookingID INT -- Record to permanently remove.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.

        -- Only bookings and reviews are hard-deleted in this project.
        DELETE FROM dbo.Booking WHERE BookingID = @BookingID;
        IF @@ROWCOUNT = 0 THROW 50004, 'Booking was not found.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Permanently remove a review.
Parameters:
  @ReviewID INT -- Record to permanently remove.
*/
CREATE OR ALTER PROCEDURE dbo.usp_DeleteReview
@ReviewID INT -- Record to permanently remove.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        -- Commit validation and the write together; failures roll back the transaction.
        BEGIN TRANSACTION;
        -- Explain common input mistakes before constraints act as the final safeguard.

        -- Only bookings and reviews are hard-deleted in this project.
        DELETE FROM dbo.Review WHERE ReviewID = @ReviewID;
        IF @@ROWCOUNT = 0 THROW 50004, 'Review was not found.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back failed writes, then preserve the original SQL error for ADO.NET.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
Summarize non-cancelled screenings by screening date, including movies with no screenings.
Parameters:
  @FirstDate DATE, -- Inclusive first date.
  @LastDate DATE -- Inclusive last date.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_MoviePerformance
@FirstDate DATE, -- Inclusive first date.
@LastDate DATE -- Inclusive last date.
AS
BEGIN
    SET NOCOUNT ON;
    -- Reject incomplete or reversed date ranges.
    IF @FirstDate IS NULL OR @LastDate IS NULL OR @FirstDate > @LastDate
        THROW 50006, 'Supply a valid inclusive date range.', 1;
    -- Reduce bookings to one row per screening before joining the catalog.
    ;WITH Sales AS (
        SELECT ShowtimeID, SUM(CONVERT(BIGINT, NumberOfTickets)) AS TicketsSold,
            SUM(TotalPrice) AS Revenue FROM dbo.Booking GROUP BY ShowtimeID
    )
    SELECT m.MovieID, m.Title, COUNT(DISTINCT s.ShowtimeID) AS ShowtimeCount,
        COALESCE(SUM(b.TicketsSold), 0) AS TicketsSold,
        COALESCE(SUM(b.Revenue), 0) AS TotalRevenue,
        COALESCE(CAST(SUM(b.TicketsSold) * 1.0 / NULLIF(COUNT(DISTINCT s.ShowtimeID), 0) AS DECIMAL(12,2)), 0) AS AverageTicketsPerShowtime
    FROM dbo.Movie m LEFT JOIN dbo.Showtime s ON s.MovieID = m.MovieID
        AND s.IsCancelled = 0 AND CAST(s.StartDateTime AS DATE) BETWEEN @FirstDate AND @LastDate
    LEFT JOIN Sales b ON b.ShowtimeID = s.ShowtimeID
    -- Group at movie level; NULLIF avoids division by zero for unscheduled movies.
    GROUP BY m.MovieID, m.Title ORDER BY TotalRevenue DESC, m.MovieID;
END;
GO

/*
Rank customers by spending on bookings made within the booking-date range; include zero-activity customers.
Parameters:
  @FirstDate DATE, -- Inclusive first date.
  @LastDate DATE -- Inclusive last date.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_CustomerBookingActivity
@FirstDate DATE, -- Inclusive first date.
@LastDate DATE -- Inclusive last date.
AS
BEGIN
    SET NOCOUNT ON;
    -- Reject incomplete or reversed date ranges.
    IF @FirstDate IS NULL OR @LastDate IS NULL OR @FirstDate > @LastDate
        THROW 50006, 'Supply a valid inclusive date range.', 1;
    -- Filter in the join so customers with no matching bookings remain visible.
    SELECT c.CustomerID, CONCAT(c.FirstName, N' ', c.LastName) AS CustomerName,
        COUNT(b.BookingID) AS BookingCount,
        COALESCE(SUM(CONVERT(BIGINT, b.NumberOfTickets)), 0) AS TicketsPurchased,
        COALESCE(SUM(b.TotalPrice), 0) AS TotalSpent,
        -- Equal spending receives equal rank; subsequent ranks may have gaps.
        RANK() OVER (ORDER BY COALESCE(SUM(b.TotalPrice), 0) DESC) AS SpendingRank
    FROM dbo.Customer c LEFT JOIN dbo.Booking b ON b.CustomerID = c.CustomerID
        AND CAST(b.BookingDate AS DATE) BETWEEN @FirstDate AND @LastDate
    GROUP BY c.CustomerID, c.FirstName, c.LastName ORDER BY SpendingRank, c.CustomerID;
END;
GO

/*
Measure occupancy as a percentage for non-cancelled screenings in the screening-date range.
Parameters:
  @FirstDate DATE, -- Inclusive first date.
  @LastDate DATE -- Inclusive last date.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_ScreenRoomUtilization
@FirstDate DATE, -- Inclusive first date.
@LastDate DATE -- Inclusive last date.
AS
BEGIN
    SET NOCOUNT ON;
    -- Reject incomplete or reversed date ranges.
    IF @FirstDate IS NULL OR @LastDate IS NULL OR @FirstDate > @LastDate
        THROW 50006, 'Supply a valid inclusive date range.', 1;
    -- Aggregate bookings before joining so each screening contributes its capacity only once.
    ;WITH Sales AS (
        SELECT ShowtimeID, SUM(CONVERT(BIGINT, NumberOfTickets)) AS TicketsBooked
        FROM dbo.Booking GROUP BY ShowtimeID
    )
    SELECT sr.ScreenRoomID, sr.RoomNumber, COUNT(DISTINCT s.ShowtimeID) AS ShowtimeCount,
        COALESCE(SUM(b.TicketsBooked), 0) AS TicketsBooked,
        CONVERT(BIGINT, COUNT(DISTINCT s.ShowtimeID)) * sr.Capacity AS SeatsOffered,
        -- Return zero when no seats were offered; 100.00 means fully occupied.
        COALESCE(CAST(100.0 * SUM(b.TicketsBooked) /
            NULLIF(CONVERT(BIGINT, COUNT(DISTINCT s.ShowtimeID)) * sr.Capacity, 0) AS DECIMAL(7,2)), 0) AS OccupancyRate
    FROM dbo.ScreenRoom sr LEFT JOIN dbo.Showtime s ON s.ScreenRoomID = sr.ScreenRoomID
        AND s.IsCancelled = 0 AND CAST(s.StartDateTime AS DATE) BETWEEN @FirstDate AND @LastDate
    LEFT JOIN Sales b ON b.ShowtimeID = s.ShowtimeID
    GROUP BY sr.ScreenRoomID, sr.RoomNumber, sr.Capacity ORDER BY sr.ScreenRoomID;
END;
GO

/*
Summarize ratings for movies that meet the requested review threshold.
Parameters:
  @MinimumReviewCount INT -- Nonnegative minimum number of reviews.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_MovieReviewSummary
@MinimumReviewCount INT -- Nonnegative minimum number of reviews.
AS
BEGIN
    SET NOCOUNT ON;
    -- Validate the HAVING threshold before aggregating.
    IF @MinimumReviewCount IS NULL OR @MinimumReviewCount < 0
        THROW 50006, 'Minimum review count must be nonnegative.', 1;
    SELECT m.MovieID, m.Title, COUNT(r.ReviewID) AS ReviewCount,
        -- Cast before AVG to retain fractional stars rather than integer truncation.
        CAST(AVG(CAST(r.Rating AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS AverageRating,
        MAX(r.Rating) AS HighestRating, MIN(r.Rating) AS LowestRating
    FROM dbo.Movie m LEFT JOIN dbo.Review r ON r.MovieID = m.MovieID
    GROUP BY m.MovieID, m.Title
    -- HAVING filters groups after COUNT has been calculated; no reviews yields NULL ratings.
    HAVING COUNT(r.ReviewID) >= @MinimumReviewCount
    ORDER BY AverageRating DESC, m.MovieID;
END;
GO
