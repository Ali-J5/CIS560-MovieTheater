-- Run after Tables.sql and Procedures.sql in an EMPTY project database.
-- This script refuses to overwrite data. To reset, explicitly re-run Tables.sql first.
-- All seed writes are atomic: an error rolls back the entire seed, including its checks.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    -- Use the same lock as the procedures to prevent concurrent application writes.
    DECLARE @LockResult INT;
    EXEC @LockResult = sys.sp_getapplock @Resource = N'MovieTheaterBusinessRules',
        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    IF @LockResult < 0 THROW 50003, 'Could not obtain the theater write lock.', 1;
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
    (N'The Shawshank Redemption', '1994-09-23', N'Drama', 142, N'R', N'Drama repertory screening: The Shawshank Redemption. Part of our classic and contemporary cinema program.'),
    (N'The Dark Knight', '2008-07-18', N'Action', 152, N'PG-13', N'Action repertory screening: The Dark Knight. Part of our classic and contemporary cinema program.'),
    (N'Inception', '2010-07-16', N'Science Fiction', 148, N'PG-13', N'Science Fiction repertory screening: Inception. Part of our classic and contemporary cinema program.'),
    (N'Interstellar', '2014-11-07', N'Science Fiction', 169, N'PG-13', N'Science Fiction repertory screening: Interstellar. Part of our classic and contemporary cinema program.'),
    (N'Toy Story', '1995-11-22', N'Animation', 81, N'G', N'Animation repertory screening: Toy Story. Part of our classic and contemporary cinema program.'),
    (N'Finding Nemo', '2003-05-30', N'Animation', 100, N'G', N'Animation repertory screening: Finding Nemo. Part of our classic and contemporary cinema program.'),
    (N'The Lion King', '1994-06-24', N'Animation', 88, N'G', N'Animation repertory screening: The Lion King. Part of our classic and contemporary cinema program.'),
    (N'Jurassic Park', '1993-06-11', N'Adventure', 127, N'PG-13', N'Adventure repertory screening: Jurassic Park. Part of our classic and contemporary cinema program.'),
    (N'Back to the Future', '1985-07-03', N'Adventure', 116, N'PG', N'Adventure repertory screening: Back to the Future. Part of our classic and contemporary cinema program.'),
    (N'Spirited Away', '2002-09-20', N'Animation', 125, N'PG', N'Animation repertory screening: Spirited Away. Part of our classic and contemporary cinema program.'),
    (N'The Godfather', '1972-03-24', N'Crime', 175, N'R', N'Crime repertory screening: The Godfather. Part of our classic and contemporary cinema program.'),
    (N'The Godfather Part II', '1974-12-20', N'Crime', 202, N'R', N'Crime repertory screening: The Godfather Part II. Part of our classic and contemporary cinema program.'),
    (N'The Matrix', '1999-03-31', N'Science Fiction', 136, N'R', N'Science Fiction repertory screening: The Matrix. Part of our classic and contemporary cinema program.'),
    (N'Gladiator', '2000-05-05', N'Action', 155, N'R', N'Action repertory screening: Gladiator. Part of our classic and contemporary cinema program.'),
    (N'Titanic', '1997-12-19', N'Romance', 194, N'PG-13', N'Romance repertory screening: Titanic. Part of our classic and contemporary cinema program.'),
    (N'Jaws', '1975-06-20', N'Thriller', 124, N'PG', N'Thriller repertory screening: Jaws. Part of our classic and contemporary cinema program.'),
    (N'Alien', '1979-05-25', N'Horror', 117, N'R', N'Horror repertory screening: Alien. Part of our classic and contemporary cinema program.'),
    (N'Aliens', '1986-07-18', N'Science Fiction', 137, N'R', N'Science Fiction repertory screening: Aliens. Part of our classic and contemporary cinema program.'),
    (N'E.T. the Extra-Terrestrial', '1982-06-11', N'Science Fiction', 115, N'PG', N'Science Fiction repertory screening: E.T. the Extra-Terrestrial. Part of our classic and contemporary cinema program.'),
    (N'Raiders of the Lost Ark', '1981-06-12', N'Adventure', 115, N'PG', N'Adventure repertory screening: Raiders of the Lost Ark. Part of our classic and contemporary cinema program.'),
    (N'Star Wars', '1977-05-25', N'Science Fiction', 121, N'PG', N'Science Fiction repertory screening: Star Wars. Part of our classic and contemporary cinema program.'),
    (N'The Empire Strikes Back', '1980-05-21', N'Science Fiction', 124, N'PG', N'Science Fiction repertory screening: The Empire Strikes Back. Part of our classic and contemporary cinema program.'),
    (N'Return of the Jedi', '1983-05-25', N'Science Fiction', 131, N'PG', N'Science Fiction repertory screening: Return of the Jedi. Part of our classic and contemporary cinema program.'),
    (N'The Fellowship of the Ring', '2001-12-19', N'Fantasy', 178, N'PG-13', N'Fantasy repertory screening: The Fellowship of the Ring. Part of our classic and contemporary cinema program.'),
    (N'The Two Towers', '2002-12-18', N'Fantasy', 179, N'PG-13', N'Fantasy repertory screening: The Two Towers. Part of our classic and contemporary cinema program.'),
    (N'The Return of the King', '2003-12-17', N'Fantasy', 201, N'PG-13', N'Fantasy repertory screening: The Return of the King. Part of our classic and contemporary cinema program.'),
    (N'Harry Potter and the Sorcerer''s Stone', '2001-11-16', N'Fantasy', 152, N'PG', N'Fantasy repertory screening: Harry Potter and the Sorcerer''s Stone. Part of our classic and contemporary cinema program.'),
    (N'Harry Potter and the Chamber of Secrets', '2002-11-15', N'Fantasy', 161, N'PG', N'Fantasy repertory screening: Harry Potter and the Chamber of Secrets. Part of our classic and contemporary cinema program.'),
    (N'Harry Potter and the Prisoner of Azkaban', '2004-06-04', N'Fantasy', 142, N'PG', N'Fantasy repertory screening: Harry Potter and the Prisoner of Azkaban. Part of our classic and contemporary cinema program.'),
    (N'The Princess Bride', '1987-09-25', N'Adventure', 98, N'PG', N'Adventure repertory screening: The Princess Bride. Part of our classic and contemporary cinema program.'),
    (N'The Incredibles', '2004-11-05', N'Animation', 115, N'PG', N'Animation repertory screening: The Incredibles. Part of our classic and contemporary cinema program.'),
    (N'Ratatouille', '2007-06-29', N'Animation', 111, N'G', N'Animation repertory screening: Ratatouille. Part of our classic and contemporary cinema program.'),
    (N'WALL-E', '2008-06-27', N'Animation', 98, N'G', N'Animation repertory screening: WALL-E. Part of our classic and contemporary cinema program.'),
    (N'Up', '2009-05-29', N'Animation', 96, N'PG', N'Animation repertory screening: Up. Part of our classic and contemporary cinema program.'),
    (N'Inside Out', '2015-06-19', N'Animation', 95, N'PG', N'Animation repertory screening: Inside Out. Part of our classic and contemporary cinema program.'),
    (N'Coco', '2017-11-22', N'Animation', 105, N'PG', N'Animation repertory screening: Coco. Part of our classic and contemporary cinema program.'),
    (N'Soul', '2020-12-25', N'Animation', 100, N'PG', N'Animation repertory screening: Soul. Part of our classic and contemporary cinema program.'),
    (N'Monsters, Inc.', '2001-11-02', N'Animation', 92, N'G', N'Animation repertory screening: Monsters, Inc.. Part of our classic and contemporary cinema program.'),
    (N'Shrek', '2001-05-18', N'Animation', 90, N'PG', N'Animation repertory screening: Shrek. Part of our classic and contemporary cinema program.'),
    (N'How to Train Your Dragon', '2010-03-26', N'Animation', 98, N'PG', N'Animation repertory screening: How to Train Your Dragon. Part of our classic and contemporary cinema program.'),
    (N'Frozen', '2013-11-27', N'Animation', 102, N'PG', N'Animation repertory screening: Frozen. Part of our classic and contemporary cinema program.'),
    (N'Moana', '2016-11-23', N'Animation', 107, N'PG', N'Animation repertory screening: Moana. Part of our classic and contemporary cinema program.'),
    (N'Zootopia', '2016-03-04', N'Animation', 108, N'PG', N'Animation repertory screening: Zootopia. Part of our classic and contemporary cinema program.'),
    (N'Beauty and the Beast', '1991-11-22', N'Animation', 84, N'G', N'Animation repertory screening: Beauty and the Beast. Part of our classic and contemporary cinema program.'),
    (N'Aladdin', '1992-11-25', N'Animation', 90, N'G', N'Animation repertory screening: Aladdin. Part of our classic and contemporary cinema program.'),
    (N'Mulan', '1998-06-19', N'Animation', 88, N'G', N'Animation repertory screening: Mulan. Part of our classic and contemporary cinema program.'),
    (N'Encanto', '2021-11-24', N'Animation', 102, N'PG', N'Animation repertory screening: Encanto. Part of our classic and contemporary cinema program.'),
    (N'The Iron Giant', '1999-08-06', N'Animation', 86, N'PG', N'Animation repertory screening: The Iron Giant. Part of our classic and contemporary cinema program.'),
    (N'Paddington', '2015-01-16', N'Family', 95, N'PG', N'Family repertory screening: Paddington. Part of our classic and contemporary cinema program.'),
    (N'Paddington 2', '2018-01-12', N'Family', 103, N'PG', N'Family repertory screening: Paddington 2. Part of our classic and contemporary cinema program.'),
    (N'The Grand Budapest Hotel', '2014-03-28', N'Comedy', 99, N'R', N'Comedy repertory screening: The Grand Budapest Hotel. Part of our classic and contemporary cinema program.'),
    (N'Fantastic Mr. Fox', '2009-11-25', N'Animation', 87, N'PG', N'Animation repertory screening: Fantastic Mr. Fox. Part of our classic and contemporary cinema program.'),
    (N'Knives Out', '2019-11-27', N'Mystery', 130, N'PG-13', N'Mystery repertory screening: Knives Out. Part of our classic and contemporary cinema program.'),
    (N'Glass Onion', '2022-11-23', N'Mystery', 139, N'PG-13', N'Mystery repertory screening: Glass Onion. Part of our classic and contemporary cinema program.'),
    (N'The Prestige', '2006-10-20', N'Mystery', 130, N'PG-13', N'Mystery repertory screening: The Prestige. Part of our classic and contemporary cinema program.'),
    (N'Memento', '2001-03-16', N'Mystery', 113, N'R', N'Mystery repertory screening: Memento. Part of our classic and contemporary cinema program.'),
    (N'Arrival', '2016-11-11', N'Science Fiction', 116, N'PG-13', N'Science Fiction repertory screening: Arrival. Part of our classic and contemporary cinema program.'),
    (N'The Martian', '2015-10-02', N'Science Fiction', 144, N'PG-13', N'Science Fiction repertory screening: The Martian. Part of our classic and contemporary cinema program.'),
    (N'Gravity', '2013-10-04', N'Science Fiction', 91, N'PG-13', N'Science Fiction repertory screening: Gravity. Part of our classic and contemporary cinema program.'),
    (N'Blade Runner', '1982-06-25', N'Science Fiction', 117, N'R', N'Science Fiction repertory screening: Blade Runner. Part of our classic and contemporary cinema program.'),
    (N'Blade Runner 2049', '2017-10-06', N'Science Fiction', 164, N'R', N'Science Fiction repertory screening: Blade Runner 2049. Part of our classic and contemporary cinema program.'),
    (N'Dune', '2021-10-22', N'Science Fiction', 155, N'PG-13', N'Science Fiction repertory screening: Dune. Part of our classic and contemporary cinema program.'),
    (N'Dune: Part Two', '2024-03-01', N'Science Fiction', 166, N'PG-13', N'Science Fiction repertory screening: Dune: Part Two. Part of our classic and contemporary cinema program.'),
    (N'Mad Max: Fury Road', '2015-05-15', N'Action', 120, N'R', N'Action repertory screening: Mad Max: Fury Road. Part of our classic and contemporary cinema program.'),
    (N'Top Gun: Maverick', '2022-05-27', N'Action', 130, N'PG-13', N'Action repertory screening: Top Gun: Maverick. Part of our classic and contemporary cinema program.'),
    (N'Mission: Impossible', '1996-05-22', N'Action', 110, N'PG-13', N'Action repertory screening: Mission: Impossible. Part of our classic and contemporary cinema program.'),
    (N'Casino Royale', '2006-11-17', N'Action', 144, N'PG-13', N'Action repertory screening: Casino Royale. Part of our classic and contemporary cinema program.'),
    (N'Skyfall', '2012-11-09', N'Action', 143, N'PG-13', N'Action repertory screening: Skyfall. Part of our classic and contemporary cinema program.'),
    (N'Black Panther', '2018-02-16', N'Action', 134, N'PG-13', N'Action repertory screening: Black Panther. Part of our classic and contemporary cinema program.'),
    (N'Iron Man', '2008-05-02', N'Action', 126, N'PG-13', N'Action repertory screening: Iron Man. Part of our classic and contemporary cinema program.'),
    (N'The Avengers', '2012-05-04', N'Action', 143, N'PG-13', N'Action repertory screening: The Avengers. Part of our classic and contemporary cinema program.'),
    (N'Guardians of the Galaxy', '2014-08-01', N'Action', 121, N'PG-13', N'Action repertory screening: Guardians of the Galaxy. Part of our classic and contemporary cinema program.'),
    (N'Spider-Man: Into the Spider-Verse', '2018-12-14', N'Animation', 117, N'PG', N'Animation repertory screening: Spider-Man: Into the Spider-Verse. Part of our classic and contemporary cinema program.'),
    (N'Spider-Man: Across the Spider-Verse', '2023-06-02', N'Animation', 140, N'PG', N'Animation repertory screening: Spider-Man: Across the Spider-Verse. Part of our classic and contemporary cinema program.'),
    (N'The Batman', '2022-03-04', N'Action', 176, N'PG-13', N'Action repertory screening: The Batman. Part of our classic and contemporary cinema program.'),
    (N'Wonder Woman', '2017-06-02', N'Action', 141, N'PG-13', N'Action repertory screening: Wonder Woman. Part of our classic and contemporary cinema program.'),
    (N'Superman', '1978-12-15', N'Action', 143, N'PG', N'Action repertory screening: Superman. Part of our classic and contemporary cinema program.'),
    (N'Rocky', '1976-12-03', N'Drama', 119, N'PG', N'Drama repertory screening: Rocky. Part of our classic and contemporary cinema program.'),
    (N'Creed', '2015-11-25', N'Drama', 133, N'PG-13', N'Drama repertory screening: Creed. Part of our classic and contemporary cinema program.'),
    (N'Ford v Ferrari', '2019-11-15', N'Drama', 152, N'PG-13', N'Drama repertory screening: Ford v Ferrari. Part of our classic and contemporary cinema program.'),
    (N'Moneyball', '2011-09-23', N'Drama', 133, N'PG-13', N'Drama repertory screening: Moneyball. Part of our classic and contemporary cinema program.'),
    (N'Remember the Titans', '2000-09-29', N'Drama', 113, N'PG', N'Drama repertory screening: Remember the Titans. Part of our classic and contemporary cinema program.'),
    (N'A League of Their Own', '1992-07-01', N'Comedy', 128, N'PG', N'Comedy repertory screening: A League of Their Own. Part of our classic and contemporary cinema program.'),
    (N'The Truman Show', '1998-06-05', N'Drama', 103, N'PG', N'Drama repertory screening: The Truman Show. Part of our classic and contemporary cinema program.'),
    (N'Groundhog Day', '1993-02-12', N'Comedy', 101, N'PG', N'Comedy repertory screening: Groundhog Day. Part of our classic and contemporary cinema program.'),
    (N'The Breakfast Club', '1985-02-15', N'Comedy', 97, N'R', N'Comedy repertory screening: The Breakfast Club. Part of our classic and contemporary cinema program.'),
    (N'Ferris Bueller''s Day Off', '1986-06-11', N'Comedy', 103, N'PG-13', N'Comedy repertory screening: Ferris Bueller''s Day Off. Part of our classic and contemporary cinema program.'),
    (N'Home Alone', '1990-11-16', N'Comedy', 103, N'PG', N'Comedy repertory screening: Home Alone. Part of our classic and contemporary cinema program.'),
    (N'Elf', '2003-11-07', N'Comedy', 97, N'PG', N'Comedy repertory screening: Elf. Part of our classic and contemporary cinema program.'),
    (N'School of Rock', '2003-10-03', N'Comedy', 109, N'PG-13', N'Comedy repertory screening: School of Rock. Part of our classic and contemporary cinema program.'),
    (N'La La Land', '2016-12-09', N'Musical', 128, N'PG-13', N'Musical repertory screening: La La Land. Part of our classic and contemporary cinema program.'),
    (N'Singin'' in the Rain', '1952-04-11', N'Musical', 103, N'G', N'Musical repertory screening: Singin'' in the Rain. Part of our classic and contemporary cinema program.'),
    (N'The Sound of Music', '1965-03-02', N'Musical', 174, N'G', N'Musical repertory screening: The Sound of Music. Part of our classic and contemporary cinema program.'),
    (N'West Side Story', '2021-12-10', N'Musical', 156, N'PG-13', N'Musical repertory screening: West Side Story. Part of our classic and contemporary cinema program.'),
    (N'Casablanca', '1943-01-23', N'Romance', 102, N'PG', N'Romance repertory screening: Casablanca. Part of our classic and contemporary cinema program.'),
    (N'Pride and Prejudice', '2005-11-11', N'Romance', 129, N'PG', N'Romance repertory screening: Pride and Prejudice. Part of our classic and contemporary cinema program.'),
    (N'Little Women', '2019-12-25', N'Drama', 135, N'PG', N'Drama repertory screening: Little Women. Part of our classic and contemporary cinema program.'),
    (N'Good Will Hunting', '1997-12-05', N'Drama', 126, N'R', N'Drama repertory screening: Good Will Hunting. Part of our classic and contemporary cinema program.'),
    (N'Dead Poets Society', '1989-06-09', N'Drama', 128, N'PG', N'Drama repertory screening: Dead Poets Society. Part of our classic and contemporary cinema program.'),
    (N'The Social Network', '2010-10-01', N'Drama', 120, N'PG-13', N'Drama repertory screening: The Social Network. Part of our classic and contemporary cinema program.'),
    (N'Whiplash', '2014-10-10', N'Drama', 106, N'R', N'Drama repertory screening: Whiplash. Part of our classic and contemporary cinema program.'),
    (N'Parasite', '2019-10-11', N'Thriller', 132, N'R', N'Thriller repertory screening: Parasite. Part of our classic and contemporary cinema program.'),
    (N'Get Out', '2017-02-24', N'Horror', 104, N'R', N'Horror repertory screening: Get Out. Part of our classic and contemporary cinema program.'),
    (N'A Quiet Place', '2018-04-06', N'Horror', 90, N'PG-13', N'Horror repertory screening: A Quiet Place. Part of our classic and contemporary cinema program.'),
    (N'The Sixth Sense', '1999-08-06', N'Thriller', 107, N'PG-13', N'Thriller repertory screening: The Sixth Sense. Part of our classic and contemporary cinema program.'),
    (N'Psycho', '1960-09-08', N'Horror', 109, N'R', N'Horror repertory screening: Psycho. Part of our classic and contemporary cinema program.'),
    (N'Rear Window', '1954-09-01', N'Mystery', 112, N'PG', N'Mystery repertory screening: Rear Window. Part of our classic and contemporary cinema program.'),
    (N'12 Angry Men', '1957-04-10', N'Drama', 96, N'NR', N'Drama repertory screening: 12 Angry Men. Part of our classic and contemporary cinema program.'),
    (N'Seven Samurai', '1956-11-19', N'Adventure', 207, N'NR', N'Adventure repertory screening: Seven Samurai. Part of our classic and contemporary cinema program.'),
    (N'Cinema Paradiso', '1990-02-23', N'Drama', 124, N'PG', N'Drama repertory screening: Cinema Paradiso. Part of our classic and contemporary cinema program.');

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

    -- Three different customers per screening produce 900 bookings.
    -- Ticket quantities 1, 2, 3 total only six seats per screening, below the minimum capacity of 50.
    -- Booking dates precede each screening and never fall after the seed execution date.
    ;WITH Screenings AS (
        SELECT ShowtimeID, StartDateTime, TicketPrice,
            ROW_NUMBER() OVER (ORDER BY StartDateTime, ShowtimeID) AS n FROM dbo.Showtime
    )
    INSERT dbo.Booking (CustomerID, ShowtimeID, BookingDate, NumberOfTickets, TotalPrice)
    SELECT c.CustomerID, s.ShowtimeID,
        DATEADD(DAY, -1-(s.n%5), CASE WHEN s.StartDateTime > CAST(@Today AS DATETIME2)
            THEN CAST(@Today AS DATETIME2) ELSE s.StartDateTime END),
        k.n, k.n * s.TicketPrice
    FROM Screenings s CROSS JOIN (VALUES (1),(2),(3)) k(n)
    JOIN @Customers c ON c.n = ((s.n-1)*3+k.n-1)%120+1;

    -- Two distinct reviewers per movie produce 220 reviews (for this 110-movie catalog).
    -- Cycle all five ratings and match each rating to an appropriate realistic comment.
    INSERT dbo.Review (CustomerID, MovieID, Rating, ReviewText, ReviewDate)
    SELECT c.CustomerID, m.MovieID, v.Rating,
        CASE v.Rating
            WHEN 1 THEN N'The pacing lost me, and the story did not hold my attention.'
            WHEN 2 THEN N'A few good moments, but the characters needed more development.'
            WHEN 3 THEN N'An enjoyable evening with a solid cast, though some scenes felt slow.'
            WHEN 4 THEN N'Strong performances and memorable visuals. I would recommend it.'
            WHEN 5 THEN N'A wonderful theater experience. The story and sound stayed with me.' END,
        DATEADD(DAY, -(1+(m.n+k.n)%14), CAST(@Today AS DATETIME2))
    FROM @Movies m CROSS JOIN (VALUES (1),(2)) k(n)
    JOIN @Customers c ON c.n = ((m.n-1)*2+k.n-1)%120+1
    CROSS APPLY (VALUES (1+(m.n+k.n)%5)) v(Rating);

    -- Verify syllabus volumes before committing; any mismatch rolls back every seed row.
    IF (SELECT COUNT(*) FROM dbo.Movie) < 100 OR (SELECT COUNT(*) FROM dbo.ScreenRoom) <> 10
       OR (SELECT COUNT(*) FROM dbo.Customer) < 120 OR (SELECT COUNT(*) FROM dbo.Showtime) < 250
       OR (SELECT COUNT(*) FROM dbo.Booking) < 800 OR (SELECT COUNT(*) FROM dbo.Review) < 200
        THROW 50011, 'Seed row counts do not meet project requirements.', 1;
    -- Compare every pair of active screenings in each room using their actual runtimes.
    IF EXISTS (SELECT 1 FROM dbo.Showtime a JOIN dbo.Showtime b
        ON a.ScreenRoomID = b.ScreenRoomID AND a.ShowtimeID < b.ShowtimeID
        JOIN dbo.Movie ma ON ma.MovieID = a.MovieID JOIN dbo.Movie mb ON mb.MovieID = b.MovieID
        WHERE a.IsCancelled = 0 AND b.IsCancelled = 0
          AND a.StartDateTime < DATEADD(MINUTE, mb.RuntimeMinutes, b.StartDateTime)
          AND b.StartDateTime < DATEADD(MINUTE, ma.RuntimeMinutes, a.StartDateTime))
        THROW 50012, 'Seed contains overlapping screenings.', 1;
    -- Group tickets per screening to verify capacity, and check every calculated price.
    IF EXISTS (SELECT 1 FROM dbo.Booking b JOIN dbo.Showtime s ON s.ShowtimeID = b.ShowtimeID
        JOIN dbo.ScreenRoom sr ON sr.ScreenRoomID = s.ScreenRoomID
        GROUP BY s.ShowtimeID, sr.Capacity HAVING SUM(b.NumberOfTickets) > sr.Capacity)
        THROW 50013, 'Seed exceeds room capacity.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Booking b JOIN dbo.Showtime s ON s.ShowtimeID = b.ShowtimeID
        WHERE b.TotalPrice <> b.NumberOfTickets * s.TicketPrice OR s.IsCancelled = 1)
        THROW 50014, 'Seed has incorrect prices or bookings on cancelled screenings.', 1;
    COMMIT TRANSACTION;
    -- Display a compact verification result for the classroom demo.
    SELECT N'Movie' AS TableName, COUNT(*) AS [RowCount] FROM dbo.Movie
    UNION ALL SELECT N'ScreenRoom', COUNT(*) FROM dbo.ScreenRoom
    UNION ALL SELECT N'Customer', COUNT(*) FROM dbo.Customer
    UNION ALL SELECT N'Showtime', COUNT(*) FROM dbo.Showtime
    UNION ALL SELECT N'Booking', COUNT(*) FROM dbo.Booking
    UNION ALL SELECT N'Review', COUNT(*) FROM dbo.Review;
END TRY
BEGIN CATCH
    -- Preserve the original error and leave no partial seed data behind.
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
