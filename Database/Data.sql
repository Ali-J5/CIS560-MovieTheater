-- Run after Tables.sql and Procedures.sql in an EMPTY project database.
-- This script refuses to overwrite data. To reset, explicitly re-run Tables.sql first.
-- All seed writes are atomic: an error rolls back the entire seed, including its checks.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.Movie) OR EXISTS (SELECT 1 FROM dbo.ScreenRoom)
       OR EXISTS (SELECT 1 FROM dbo.Customer) OR EXISTS (SELECT 1 FROM dbo.Showtime)
       OR EXISTS (SELECT 1 FROM dbo.Booking) OR EXISTS (SELECT 1 FROM dbo.Review)
        THROW 50010, 'Seed requires empty tables. Re-run Tables.sql to reset deliberately.', 1;

    -- Use relative dates so past and upcoming screenings remain useful in every demo.
    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
    -- A reusable tally table drives set-based inserts rather than slow per-row loops.
    DECLARE @Numbers TABLE (n INT PRIMARY KEY);
    ;WITH Digit AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) d(n))
    INSERT @Numbers (n)
    SELECT 1 + a.n + 10*b.n + 100*c.n FROM Digit a CROSS JOIN Digit b CROSS JOIN Digit c;

    -- Ten physical rooms offer the four requested screen types and 50-250 seats.
    INSERT dbo.ScreenRoom (RoomNumber, Name, ScreenType, Capacity) VALUES
    (N'01',N'Grand IMAX',N'IMAX',250),
    (N'02',N'Dolby Premiere',N'Dolby',200),
    (N'03',N'Starlight 3D',N'3D',150),
    (N'04',N'Classic Hall',N'Standard',120),
    (N'05',N'Family Hall',N'Standard',100),
    (N'06',N'Panorama IMAX',N'IMAX',220),
    (N'07',N'Dolby Studio',N'Dolby',160),
    (N'08',N'Adventure 3D',N'3D',130),
    (N'09',N'Indie Lounge',N'Standard',75),
    (N'10',N'Little Screen',N'Standard',50);

    -- Real catalog releases span animation, drama, action, horror, and other genres.
    -- The first titles are memorable choices for the classroom demonstration.
    INSERT dbo.Movie (Title, ReleaseDate, Genre, RuntimeMinutes, AgeRating, Description) VALUES
    (N'The Shawshank Redemption', '1994-09-23', N'Drama', 142, N'R', N'A big-screen presentation of The Shawshank Redemption, selected for our drama spotlight.'),
    (N'The Dark Knight', '2008-07-18', N'Action', 152, N'PG-13', N'Rediscover The Dark Knight with an audience in our classic and contemporary cinema series.'),
    (N'Inception', '2010-07-16', N'Science Fiction', 148, N'PG-13', N'Our science fiction program features Inception, an inviting choice for a movie night together.'),
    (N'Interstellar', '2014-11-07', N'Science Fiction', 169, N'PG-13', N'Experience the performances and craft of Interstellar in a dedicated repertory screening.'),
    (N'Toy Story', '1995-11-22', N'Animation', 81, N'G', N'Join fellow film fans for Toy Story, part of this season’s curated animation collection.'),
    (N'Finding Nemo', '2003-05-30', N'Animation', 100, N'G', N'A big-screen presentation of Finding Nemo, selected for our animation spotlight.'),
    (N'The Lion King', '1994-06-24', N'Animation', 88, N'G', N'Rediscover The Lion King with an audience in our classic and contemporary cinema series.'),
    (N'Jurassic Park', '1993-06-11', N'Adventure', 127, N'PG-13', N'Our adventure program features Jurassic Park, an inviting choice for a movie night together.'),
    (N'Back to the Future', '1985-07-03', N'Adventure', 116, N'PG', N'Experience the performances and craft of Back to the Future in a dedicated repertory screening.'),
    (N'Spirited Away', '2002-09-20', N'Animation', 125, N'PG', N'Join fellow film fans for Spirited Away, part of this season’s curated animation collection.'),
    (N'The Godfather', '1972-03-24', N'Crime', 175, N'R', N'A big-screen presentation of The Godfather, selected for our crime spotlight.'),
    (N'The Godfather Part II', '1974-12-20', N'Crime', 202, N'R', N'Rediscover The Godfather Part II with an audience in our classic and contemporary cinema series.'),
    (N'The Matrix', '1999-03-31', N'Science Fiction', 136, N'R', N'Our science fiction program features The Matrix, an inviting choice for a movie night together.'),
    (N'Gladiator', '2000-05-05', N'Action', 155, N'R', N'Experience the performances and craft of Gladiator in a dedicated repertory screening.'),
    (N'Titanic', '1997-12-19', N'Romance', 194, N'PG-13', N'Join fellow film fans for Titanic, part of this season’s curated romance collection.'),
    (N'Jaws', '1975-06-20', N'Thriller', 124, N'PG', N'A big-screen presentation of Jaws, selected for our thriller spotlight.'),
    (N'Alien', '1979-05-25', N'Horror', 117, N'R', N'Rediscover Alien with an audience in our classic and contemporary cinema series.'),
    (N'Aliens', '1986-07-18', N'Science Fiction', 137, N'R', N'Our science fiction program features Aliens, an inviting choice for a movie night together.'),
    (N'E.T. the Extra-Terrestrial', '1982-06-11', N'Science Fiction', 115, N'PG', N'Experience the performances and craft of E.T. the Extra-Terrestrial in a dedicated repertory screening.'),
    (N'Raiders of the Lost Ark', '1981-06-12', N'Adventure', 115, N'PG', N'Join fellow film fans for Raiders of the Lost Ark, part of this season’s curated adventure collection.'),
    (N'Star Wars', '1977-05-25', N'Science Fiction', 121, N'PG', N'A big-screen presentation of Star Wars, selected for our science fiction spotlight.'),
    (N'The Empire Strikes Back', '1980-05-21', N'Science Fiction', 124, N'PG', N'Rediscover The Empire Strikes Back with an audience in our classic and contemporary cinema series.'),
    (N'Return of the Jedi', '1983-05-25', N'Science Fiction', 131, N'PG', N'Our science fiction program features Return of the Jedi, an inviting choice for a movie night together.'),
    (N'The Fellowship of the Ring', '2001-12-19', N'Fantasy', 178, N'PG-13', N'Experience the performances and craft of The Fellowship of the Ring in a dedicated repertory screening.'),
    (N'The Two Towers', '2002-12-18', N'Fantasy', 179, N'PG-13', N'Join fellow film fans for The Two Towers, part of this season’s curated fantasy collection.'),
    (N'The Return of the King', '2003-12-17', N'Fantasy', 201, N'PG-13', N'A big-screen presentation of The Return of the King, selected for our fantasy spotlight.'),
    (N'Harry Potter and the Sorcerer''s Stone', '2001-11-16', N'Fantasy', 152, N'PG', N'Rediscover Harry Potter and the Sorcerer''s Stone with an audience in our classic and contemporary cinema series.'),
    (N'Harry Potter and the Chamber of Secrets', '2002-11-15', N'Fantasy', 161, N'PG', N'Our fantasy program features Harry Potter and the Chamber of Secrets, an inviting choice for a movie night together.'),
    (N'Harry Potter and the Prisoner of Azkaban', '2004-06-04', N'Fantasy', 142, N'PG', N'Experience the performances and craft of Harry Potter and the Prisoner of Azkaban in a dedicated repertory screening.'),
    (N'The Princess Bride', '1987-09-25', N'Adventure', 98, N'PG', N'Join fellow film fans for The Princess Bride, part of this season’s curated adventure collection.'),
    (N'The Incredibles', '2004-11-05', N'Animation', 115, N'PG', N'A big-screen presentation of The Incredibles, selected for our animation spotlight.'),
    (N'Ratatouille', '2007-06-29', N'Animation', 111, N'G', N'Rediscover Ratatouille with an audience in our classic and contemporary cinema series.'),
    (N'WALL-E', '2008-06-27', N'Animation', 98, N'G', N'Our animation program features WALL-E, an inviting choice for a movie night together.'),
    (N'Up', '2009-05-29', N'Animation', 96, N'PG', N'Experience the performances and craft of Up in a dedicated repertory screening.'),
    (N'Inside Out', '2015-06-19', N'Animation', 95, N'PG', N'Join fellow film fans for Inside Out, part of this season’s curated animation collection.'),
    (N'Coco', '2017-11-22', N'Animation', 105, N'PG', N'A big-screen presentation of Coco, selected for our animation spotlight.'),
    (N'Soul', '2020-12-25', N'Animation', 100, N'PG', N'Rediscover Soul with an audience in our classic and contemporary cinema series.'),
    (N'Monsters, Inc.', '2001-11-02', N'Animation', 92, N'G', N'Our animation program features Monsters, Inc., an inviting choice for a movie night together.'),
    (N'Shrek', '2001-05-18', N'Animation', 90, N'PG', N'Experience the performances and craft of Shrek in a dedicated repertory screening.'),
    (N'How to Train Your Dragon', '2010-03-26', N'Animation', 98, N'PG', N'Join fellow film fans for How to Train Your Dragon, part of this season’s curated animation collection.'),
    (N'Frozen', '2013-11-27', N'Animation', 102, N'PG', N'A big-screen presentation of Frozen, selected for our animation spotlight.'),
    (N'Moana', '2016-11-23', N'Animation', 107, N'PG', N'Rediscover Moana with an audience in our classic and contemporary cinema series.'),
    (N'Zootopia', '2016-03-04', N'Animation', 108, N'PG', N'Our animation program features Zootopia, an inviting choice for a movie night together.'),
    (N'Beauty and the Beast', '1991-11-22', N'Animation', 84, N'G', N'Experience the performances and craft of Beauty and the Beast in a dedicated repertory screening.'),
    (N'Aladdin', '1992-11-25', N'Animation', 90, N'G', N'Join fellow film fans for Aladdin, part of this season’s curated animation collection.'),
    (N'Mulan', '1998-06-19', N'Animation', 88, N'G', N'A big-screen presentation of Mulan, selected for our animation spotlight.'),
    (N'Encanto', '2021-11-24', N'Animation', 102, N'PG', N'Rediscover Encanto with an audience in our classic and contemporary cinema series.'),
    (N'The Iron Giant', '1999-08-06', N'Animation', 86, N'PG', N'Our animation program features The Iron Giant, an inviting choice for a movie night together.'),
    (N'Paddington', '2015-01-16', N'Family', 95, N'PG', N'Experience the performances and craft of Paddington in a dedicated repertory screening.'),
    (N'Paddington 2', '2018-01-12', N'Family', 103, N'PG', N'Join fellow film fans for Paddington 2, part of this season’s curated family collection.'),
    (N'The Grand Budapest Hotel', '2014-03-28', N'Comedy', 99, N'R', N'A big-screen presentation of The Grand Budapest Hotel, selected for our comedy spotlight.'),
    (N'Fantastic Mr. Fox', '2009-11-25', N'Animation', 87, N'PG', N'Rediscover Fantastic Mr. Fox with an audience in our classic and contemporary cinema series.'),
    (N'Knives Out', '2019-11-27', N'Mystery', 130, N'PG-13', N'Our mystery program features Knives Out, an inviting choice for a movie night together.'),
    (N'Glass Onion', '2022-11-23', N'Mystery', 139, N'PG-13', N'Experience the performances and craft of Glass Onion in a dedicated repertory screening.'),
    (N'The Prestige', '2006-10-20', N'Mystery', 130, N'PG-13', N'Join fellow film fans for The Prestige, part of this season’s curated mystery collection.'),
    (N'Memento', '2001-03-16', N'Mystery', 113, N'R', N'A big-screen presentation of Memento, selected for our mystery spotlight.'),
    (N'Arrival', '2016-11-11', N'Science Fiction', 116, N'PG-13', N'Rediscover Arrival with an audience in our classic and contemporary cinema series.'),
    (N'The Martian', '2015-10-02', N'Science Fiction', 144, N'PG-13', N'Our science fiction program features The Martian, an inviting choice for a movie night together.'),
    (N'Gravity', '2013-10-04', N'Science Fiction', 91, N'PG-13', N'Experience the performances and craft of Gravity in a dedicated repertory screening.'),
    (N'Blade Runner', '1982-06-25', N'Science Fiction', 117, N'R', N'Join fellow film fans for Blade Runner, part of this season’s curated science fiction collection.'),
    (N'Blade Runner 2049', '2017-10-06', N'Science Fiction', 164, N'R', N'A big-screen presentation of Blade Runner 2049, selected for our science fiction spotlight.'),
    (N'Dune', '2021-10-22', N'Science Fiction', 155, N'PG-13', N'Rediscover Dune with an audience in our classic and contemporary cinema series.'),
    (N'Dune: Part Two', '2024-03-01', N'Science Fiction', 166, N'PG-13', N'Our science fiction program features Dune: Part Two, an inviting choice for a movie night together.'),
    (N'Mad Max: Fury Road', '2015-05-15', N'Action', 120, N'R', N'Experience the performances and craft of Mad Max: Fury Road in a dedicated repertory screening.'),
    (N'Top Gun: Maverick', '2022-05-27', N'Action', 130, N'PG-13', N'Join fellow film fans for Top Gun: Maverick, part of this season’s curated action collection.'),
    (N'Mission: Impossible', '1996-05-22', N'Action', 110, N'PG-13', N'A big-screen presentation of Mission: Impossible, selected for our action spotlight.'),
    (N'Casino Royale', '2006-11-17', N'Action', 144, N'PG-13', N'Rediscover Casino Royale with an audience in our classic and contemporary cinema series.'),
    (N'Skyfall', '2012-11-09', N'Action', 143, N'PG-13', N'Our action program features Skyfall, an inviting choice for a movie night together.'),
    (N'Black Panther', '2018-02-16', N'Action', 134, N'PG-13', N'Experience the performances and craft of Black Panther in a dedicated repertory screening.'),
    (N'Iron Man', '2008-05-02', N'Action', 126, N'PG-13', N'Join fellow film fans for Iron Man, part of this season’s curated action collection.'),
    (N'The Avengers', '2012-05-04', N'Action', 143, N'PG-13', N'A big-screen presentation of The Avengers, selected for our action spotlight.'),
    (N'Guardians of the Galaxy', '2014-08-01', N'Action', 121, N'PG-13', N'Rediscover Guardians of the Galaxy with an audience in our classic and contemporary cinema series.'),
    (N'Spider-Man: Into the Spider-Verse', '2018-12-14', N'Animation', 117, N'PG', N'Our animation program features Spider-Man: Into the Spider-Verse, an inviting choice for a movie night together.'),
    (N'Spider-Man: Across the Spider-Verse', '2023-06-02', N'Animation', 140, N'PG', N'Experience the performances and craft of Spider-Man: Across the Spider-Verse in a dedicated repertory screening.'),
    (N'The Batman', '2022-03-04', N'Action', 176, N'PG-13', N'Join fellow film fans for The Batman, part of this season’s curated action collection.'),
    (N'Wonder Woman', '2017-06-02', N'Action', 141, N'PG-13', N'A big-screen presentation of Wonder Woman, selected for our action spotlight.'),
    (N'Superman', '1978-12-15', N'Action', 143, N'PG', N'Rediscover Superman with an audience in our classic and contemporary cinema series.'),
    (N'Rocky', '1976-12-03', N'Drama', 119, N'PG', N'Our drama program features Rocky, an inviting choice for a movie night together.'),
    (N'Creed', '2015-11-25', N'Drama', 133, N'PG-13', N'Experience the performances and craft of Creed in a dedicated repertory screening.'),
    (N'Ford v Ferrari', '2019-11-15', N'Drama', 152, N'PG-13', N'Join fellow film fans for Ford v Ferrari, part of this season’s curated drama collection.'),
    (N'Moneyball', '2011-09-23', N'Drama', 133, N'PG-13', N'A big-screen presentation of Moneyball, selected for our drama spotlight.'),
    (N'Remember the Titans', '2000-09-29', N'Drama', 113, N'PG', N'Rediscover Remember the Titans with an audience in our classic and contemporary cinema series.'),
    (N'A League of Their Own', '1992-07-01', N'Comedy', 128, N'PG', N'Our comedy program features A League of Their Own, an inviting choice for a movie night together.'),
    (N'The Truman Show', '1998-06-05', N'Drama', 103, N'PG', N'Experience the performances and craft of The Truman Show in a dedicated repertory screening.'),
    (N'Groundhog Day', '1993-02-12', N'Comedy', 101, N'PG', N'Join fellow film fans for Groundhog Day, part of this season’s curated comedy collection.'),
    (N'The Breakfast Club', '1985-02-15', N'Comedy', 97, N'R', N'A big-screen presentation of The Breakfast Club, selected for our comedy spotlight.'),
    (N'Ferris Bueller''s Day Off', '1986-06-11', N'Comedy', 103, N'PG-13', N'Rediscover Ferris Bueller''s Day Off with an audience in our classic and contemporary cinema series.'),
    (N'Home Alone', '1990-11-16', N'Comedy', 103, N'PG', N'Our comedy program features Home Alone, an inviting choice for a movie night together.'),
    (N'Elf', '2003-11-07', N'Comedy', 97, N'PG', N'Experience the performances and craft of Elf in a dedicated repertory screening.'),
    (N'School of Rock', '2003-10-03', N'Comedy', 109, N'PG-13', N'Join fellow film fans for School of Rock, part of this season’s curated comedy collection.'),
    (N'La La Land', '2016-12-09', N'Musical', 128, N'PG-13', N'A big-screen presentation of La La Land, selected for our musical spotlight.'),
    (N'Singin'' in the Rain', '1952-04-11', N'Musical', 103, N'G', N'Rediscover Singin'' in the Rain with an audience in our classic and contemporary cinema series.'),
    (N'The Sound of Music', '1965-03-02', N'Musical', 174, N'G', N'Our musical program features The Sound of Music, an inviting choice for a movie night together.'),
    (N'West Side Story', '2021-12-10', N'Musical', 156, N'PG-13', N'Experience the performances and craft of West Side Story in a dedicated repertory screening.'),
    (N'Casablanca', '1943-01-23', N'Romance', 102, N'PG', N'Join fellow film fans for Casablanca, part of this season’s curated romance collection.'),
    (N'Pride and Prejudice', '2005-11-11', N'Romance', 129, N'PG', N'A big-screen presentation of Pride and Prejudice, selected for our romance spotlight.'),
    (N'Little Women', '2019-12-25', N'Drama', 135, N'PG', N'Rediscover Little Women with an audience in our classic and contemporary cinema series.'),
    (N'Good Will Hunting', '1997-12-05', N'Drama', 126, N'R', N'Our drama program features Good Will Hunting, an inviting choice for a movie night together.'),
    (N'Dead Poets Society', '1989-06-09', N'Drama', 128, N'PG', N'Experience the performances and craft of Dead Poets Society in a dedicated repertory screening.'),
    (N'The Social Network', '2010-10-01', N'Drama', 120, N'PG-13', N'Join fellow film fans for The Social Network, part of this season’s curated drama collection.'),
    (N'Whiplash', '2014-10-10', N'Drama', 106, N'R', N'A big-screen presentation of Whiplash, selected for our drama spotlight.'),
    (N'Parasite', '2019-10-11', N'Thriller', 132, N'R', N'Rediscover Parasite with an audience in our classic and contemporary cinema series.'),
    (N'Get Out', '2017-02-24', N'Horror', 104, N'R', N'Our horror program features Get Out, an inviting choice for a movie night together.'),
    (N'A Quiet Place', '2018-04-06', N'Horror', 90, N'PG-13', N'Experience the performances and craft of A Quiet Place in a dedicated repertory screening.'),
    (N'The Sixth Sense', '1999-08-06', N'Thriller', 107, N'PG-13', N'Join fellow film fans for The Sixth Sense, part of this season’s curated thriller collection.'),
    (N'Psycho', '1960-09-08', N'Horror', 109, N'R', N'A big-screen presentation of Psycho, selected for our horror spotlight.'),
    (N'Rear Window', '1954-09-01', N'Mystery', 112, N'PG', N'Rediscover Rear Window with an audience in our classic and contemporary cinema series.'),
    (N'12 Angry Men', '1957-04-10', N'Drama', 96, N'NR', N'Our drama program features 12 Angry Men, an inviting choice for a movie night together.'),
    (N'Seven Samurai', '1956-11-19', N'Adventure', 207, N'NR', N'Experience the performances and craft of Seven Samurai in a dedicated repertory screening.'),
    (N'Cinema Paradiso', '1990-02-23', N'Drama', 124, N'PG', N'Join fellow film fans for Cinema Paradiso, part of this season’s curated drama collection.');

    -- Combine 12 given names with 10 family names for 120 distinct fictional customers.
    -- Reserved example.com email addresses and fictional 555 numbers avoid real contact data.
    INSERT dbo.Customer (Email, PhoneNumber, FirstName, LastName)
    SELECT CONCAT(LOWER(f.FirstName), N'.', LOWER(l.LastName), N'@example.com'),
        CONCAT('202-555-', RIGHT('0000' + CAST((f.i-1)*10+l.i AS VARCHAR(4)),4)),
        f.FirstName, l.LastName
    FROM (VALUES (1,N'Ava'),(2,N'Liam'),(3,N'Olivia'),(4,N'Noah'),(5,N'Emma'),(6,N'Elijah'),
        (7,N'Sophia'),(8,N'James'),(9,N'Mia'),(10,N'Lucas'),(11,N'Amelia'),(12,N'Mason')) f(i,FirstName)
    CROSS JOIN (VALUES (1,N'Anderson'),(2,N'Bennett'),(3,N'Chen'),(4,N'Davis'),(5,N'Garcia'),
        (6,N'Hassan'),(7,N'Johnson'),(8,N'Kim'),(9,N'Patel'),(10,N'Rivera')) l(i,LastName);

    -- Rank actual generated IDs instead of assuming IDENTITY starts at 1 after a rollback.
    DECLARE @Movies TABLE (n INT PRIMARY KEY, MovieID INT);
    DECLARE @Rooms TABLE (n INT PRIMARY KEY, ScreenRoomID INT);
    DECLARE @Customers TABLE (n INT PRIMARY KEY, CustomerID INT);
    INSERT @Movies SELECT ROW_NUMBER() OVER (ORDER BY MovieID), MovieID FROM dbo.Movie;
    INSERT @Rooms SELECT ROW_NUMBER() OVER (ORDER BY ScreenRoomID), ScreenRoomID FROM dbo.ScreenRoom;
    INSERT @Customers SELECT ROW_NUMBER() OVER (ORDER BY CustomerID), CustomerID FROM dbo.Customer;
    DECLARE @MovieCount INT = (SELECT COUNT(*) FROM @Movies);

    -- 10 rooms x 30 days = 300 screenings: 15 past days, today, and 14 future days.
    -- Each room has one daily screening; every catalog runtime is less than 24 hours.
    -- Start hours rotate from 14:00 to 20:00 by room. This intentionally simple plan cannot overlap.
    INSERT dbo.Showtime (MovieID, ScreenRoomID, StartDateTime, TicketPrice)
    SELECT m.MovieID, r.ScreenRoomID,
        DATEADD(HOUR, 14 + (r.n % 4)*2, CAST(DATEADD(DAY,d.n-16,@Today) AS DATETIME2)),
        CAST(CASE sr.ScreenType WHEN N'IMAX' THEN 18.50 WHEN N'Dolby' THEN 16.00
             WHEN N'3D' THEN 14.50 ELSE 11.00 END AS DECIMAL(10,2))
    FROM @Rooms r CROSS JOIN @Numbers d
    JOIN @Movies m ON m.n = ((d.n-1)*10+r.n-1) % @MovieCount + 1
    JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = r.ScreenRoomID
    WHERE d.n <= 30;

    -- Use the schedule day and room number rather than calendar dates/generated IDs
    -- so party quantities and final row counts are reproducible on every machine.
    -- Set a distinct occupancy target for each screening: premium rooms and popular
    -- catalog titles sell 65-95% of seats; smaller repertory releases sell 15-45%.
    -- Start targets one point higher so whole-seat rounding stays within those bands.
    -- Build varied parties of 1-8 tickets, trimming the final party to hit the target.
    ;WITH Screenings AS (
        SELECT s.ShowtimeID, s.StartDateTime, s.TicketPrice, sr.Capacity,
            ROW_NUMBER() OVER (ORDER BY s.StartDateTime, sr.RoomNumber) AS n,
            CASE WHEN sr.ScreenType IN (N'IMAX', N'Dolby') OR m.n <= 25
                THEN 66 + (m.n * 7 + r.n * 3 + DATEDIFF(DAY, @Today, s.StartDateTime) + 16) % 30
                ELSE 16 + (m.n * 7 + r.n * 3 + DATEDIFF(DAY, @Today, s.StartDateTime) + 16) % 30
            END AS TargetPercent
        FROM dbo.Showtime s
        JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = s.ScreenRoomID
        JOIN @Rooms r ON r.ScreenRoomID = sr.ScreenRoomID
        JOIN @Movies m ON m.MovieID = s.MovieID
    ), Parties AS (
        SELECT s.*, k.n AS PartyNumber, 1 + (k.n * 5 + s.n) % 8 AS PartySize,
            s.Capacity * s.TargetPercent / 100 AS TargetTickets
        FROM Screenings s CROSS JOIN @Numbers k
        WHERE k.n <= 120
    ), RunningTickets AS (
        -- A windowed sum tells us how many seats earlier parties already reserved.
        SELECT *, SUM(PartySize) OVER (
            PARTITION BY ShowtimeID ORDER BY PartyNumber ROWS UNBOUNDED PRECEDING
        ) - PartySize AS PreviousTickets
        FROM Parties
    )
    INSERT dbo.Booking (CustomerID, ShowtimeID, BookingDate, NumberOfTickets, TotalPrice)
    SELECT c.CustomerID, s.ShowtimeID,
        DATEADD(DAY, -1-(s.n%5), CASE WHEN s.StartDateTime > CAST(@Today AS DATETIME2)
            THEN CAST(@Today AS DATETIME2) ELSE s.StartDateTime END),
        tickets.Quantity, tickets.Quantity * s.TicketPrice
    FROM RunningTickets s
    JOIN @Customers c ON c.n = ((s.n-1)*17+s.PartyNumber-1)%120+1
    CROSS APPLY (VALUES (CASE WHEN s.TargetTickets - s.PreviousTickets < s.PartySize
        THEN s.TargetTickets - s.PreviousTickets ELSE s.PartySize END)) tickets(Quantity)
    WHERE s.PreviousTickets < s.TargetTickets;

    -- Twenty-five rating-matched comments provide five different voices per score.
    DECLARE @ReviewComments TABLE (
        Rating TINYINT NOT NULL, Variant INT NOT NULL, ReviewText NVARCHAR(200) NOT NULL,
        PRIMARY KEY (Rating, Variant) -- Identify one comment for each rating/variant pair.
    );
    INSERT @ReviewComments (Rating, Variant, ReviewText) VALUES
    (1, 0, N'The pacing lost me, and the story did not hold my attention.'),
    (1, 1, N'The dialogue felt stiff and the ending left too much unresolved.'),
    (1, 2, N'Beautiful locations could not make up for a confusing plot.'),
    (1, 3, N'I struggled to connect with the characters throughout the film.'),
    (1, 4, N'The premise was promising, but the repeated twists wore me out.'),
    (2, 0, N'A few good moments, but the characters needed more development.'),
    (2, 1, N'The opening was engaging, though the middle moved far too slowly.'),
    (2, 2, N'I enjoyed the music more than the predictable story.'),
    (2, 3, N'There were clever ideas here, but they never came together for me.'),
    (2, 4, N'Some scenes were entertaining, but the tone changed too abruptly.'),
    (3, 0, N'An enjoyable evening with a solid cast, though some scenes felt slow.'),
    (3, 1, N'A dependable weekend movie with a few memorable surprises.'),
    (3, 2, N'The supporting cast brought warmth to a fairly familiar story.'),
    (3, 3, N'The visuals looked great on the big screen, even when the plot wandered.'),
    (3, 4, N'A pleasant watch that gave our group plenty to discuss afterward.'),
    (4, 0, N'Strong performances and memorable visuals. I would recommend it.'),
    (4, 1, N'The quiet character moments were just as compelling as the action.'),
    (4, 2, N'The sound design made this especially rewarding in the theater.'),
    (4, 3, N'A thoughtful story with an ending that earned its emotional payoff.'),
    (4, 4, N'The humor landed well, and the cast had wonderful chemistry.'),
    (5, 0, N'A wonderful theater experience. The story and sound stayed with me.'),
    (5, 1, N'Every scene felt carefully composed; I would happily see it again.'),
    (5, 2, N'An unforgettable performance anchored a beautifully told story.'),
    (5, 3, N'Our whole group loved the balance of spectacle and genuine emotion.'),
    (5, 4, N'The final sequence was breathtaking on a large screen.');

    -- Two distinct customers review each movie; relative dates keep reviews recent.
    INSERT dbo.Review (CustomerID, MovieID, Rating, ReviewText, ReviewDate)
    SELECT c.CustomerID, m.MovieID, v.Rating, rc.ReviewText,
        DATEADD(DAY, -(1+(m.n+k.n)%14), CAST(@Today AS DATETIME2))
    FROM @Movies m CROSS JOIN (VALUES (1),(2)) k(n)
    JOIN @Customers c ON c.n = ((m.n-1)*2+k.n-1)%120+1
    CROSS APPLY (VALUES (1+(m.n+k.n)%5)) v(Rating)
    JOIN @ReviewComments rc ON rc.Rating = v.Rating AND rc.Variant = ((m.n-1)/5+k.n)%5;

    -- Show a few historical status changes immediately in the admin lists.
    -- Retain their bookings/reviews, just as normal soft-delete operations do.
    UPDATE dbo.Movie SET IsActive = 0, DeactivatedOn = DATEADD(DAY, -2, SYSDATETIME())
    WHERE MovieID IN (SELECT MovieID FROM @Movies WHERE n >= 109);
    UPDATE dbo.ScreenRoom SET IsActive = 0, DeactivatedOn = DATEADD(DAY, -2, SYSDATETIME())
    WHERE ScreenRoomID IN (SELECT ScreenRoomID FROM @Rooms WHERE n = 10);
    UPDATE dbo.Customer SET IsActive = 0, DeactivatedOn = DATEADD(DAY, -1, SYSDATETIME())
    WHERE CustomerID IN (SELECT CustomerID FROM @Customers WHERE n >= 118);
    UPDATE s SET IsCancelled = 1, CancelledOn = DATEADD(DAY, -1, SYSDATETIME())
    FROM dbo.Showtime s
    JOIN dbo.Movie m ON m.MovieID = s.MovieID
    JOIN dbo.ScreenRoom r ON r.ScreenRoomID = s.ScreenRoomID
    WHERE m.IsActive = 0 OR r.IsActive = 0
       OR (DATEDIFF(DAY, @Today, s.StartDateTime) = -3 AND r.RoomNumber = N'01');

    -- Lookup contents are seeded with the schema and must be available for the catalog.
    IF (SELECT COUNT(*) FROM dbo.AgeRating) <> 6
        THROW 50015, 'The static age-rating lookup must contain six supported codes.', 1;
    -- Verify SQL-managed status history on all four soft-delete resources.
    IF EXISTS (SELECT 1 FROM dbo.Movie WHERE (IsActive = 1 AND DeactivatedOn IS NOT NULL) OR (IsActive = 0 AND DeactivatedOn IS NULL))
       OR EXISTS (SELECT 1 FROM dbo.ScreenRoom WHERE (IsActive = 1 AND DeactivatedOn IS NOT NULL) OR (IsActive = 0 AND DeactivatedOn IS NULL))
       OR EXISTS (SELECT 1 FROM dbo.Customer WHERE (IsActive = 1 AND DeactivatedOn IS NOT NULL) OR (IsActive = 0 AND DeactivatedOn IS NULL))
       OR EXISTS (SELECT 1 FROM dbo.Showtime WHERE (IsCancelled = 0 AND CancelledOn IS NOT NULL) OR (IsCancelled = 1 AND CancelledOn IS NULL))
        THROW 50016, 'A seed status flag does not match its history timestamp.', 1;
    -- Exact counts are deterministic: 6 lookup rows plus 7,128 managed rows = 7,134 total.
    -- Verify every table before committing; any mismatch rolls back the seed transaction.
    IF (SELECT COUNT(*) FROM dbo.Movie) <> 110 OR (SELECT COUNT(*) FROM dbo.ScreenRoom) <> 10
       OR (SELECT COUNT(*) FROM dbo.Customer) <> 120 OR (SELECT COUNT(*) FROM dbo.Showtime) <> 300
       OR (SELECT COUNT(*) FROM dbo.Booking) <> 6368 OR (SELECT COUNT(*) FROM dbo.Review) <> 220
        THROW 50011, 'Seed row counts do not meet project requirements.', 1;
    -- Compare every pair of active screenings in each room using their actual runtimes.
    IF EXISTS (SELECT 1 FROM dbo.Showtime a JOIN dbo.Showtime b
        ON a.ScreenRoomID = b.ScreenRoomID AND a.ShowtimeID < b.ShowtimeID
        JOIN dbo.Movie ma ON ma.MovieID = a.MovieID JOIN dbo.Movie mb ON mb.MovieID = b.MovieID
        WHERE a.IsCancelled = 0 AND b.IsCancelled = 0
          AND a.StartDateTime < DATEADD(MINUTE, mb.RuntimeMinutes, b.StartDateTime)
          AND b.StartDateTime < DATEADD(MINUTE, ma.RuntimeMinutes, a.StartDateTime))
        THROW 50012, 'Seed contains overlapping screenings.', 1;
    -- Historical cancellations retain bookings; check capacity and historical prices independently.
    IF EXISTS (SELECT 1 FROM dbo.Booking b JOIN dbo.Showtime s ON s.ShowtimeID = b.ShowtimeID
        JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = s.ScreenRoomID
        GROUP BY s.ShowtimeID, sr.Capacity HAVING SUM(b.NumberOfTickets) > sr.Capacity)
        THROW 50013, 'Seed exceeds room capacity.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Booking b JOIN dbo.Showtime s ON s.ShowtimeID = b.ShowtimeID
        WHERE b.TotalPrice <> b.NumberOfTickets * s.TicketPrice)
        THROW 50014, 'Seed has incorrect booking prices.', 1;
    COMMIT TRANSACTION;
    -- Display a compact verification result for the classroom demo.
    SELECT N'AgeRating' AS TableName, COUNT(*) AS [RowCount] FROM dbo.AgeRating
    UNION ALL SELECT N'Movie', COUNT(*) FROM dbo.Movie
    UNION ALL SELECT N'ScreenRoom', COUNT(*) FROM dbo.ScreenRoom
    UNION ALL SELECT N'Customer', COUNT(*) FROM dbo.Customer
    UNION ALL SELECT N'Showtime', COUNT(*) FROM dbo.Showtime
    UNION ALL SELECT N'Booking', COUNT(*) FROM dbo.Booking
    UNION ALL SELECT N'Review', COUNT(*) FROM dbo.Review;
END TRY
BEGIN CATCH
    -- Preserve the original error and leave no partial seed data behind.
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
