namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class MoviePerformanceResult
{
    // MovieID: generated row identifier.
    public int MovieId { get; set; }

    // Title: value read from the matching SQL result column.
    public string Title { get; set; } = string.Empty;

    // ShowtimeCount: value read from the matching SQL result column.
    public int ShowtimeCount { get; set; }

    // Sum of ticket quantities; SQL BIGINT maps to C# long.
    public long TicketsSold { get; set; }

    // TotalRevenue: value read from the matching SQL result column.
    public decimal TotalRevenue { get; set; }

    // AverageTicketsPerShowtime: value read from the matching SQL result column.
    public decimal AverageTicketsPerShowtime { get; set; }
}

// Response fields map explicitly to the stored procedure result columns.
public class CustomerBookingActivityResult
{
    // CustomerID: generated row identifier.
    public int CustomerId { get; set; }

    // CustomerName: value read from the matching SQL result column.
    public string CustomerName { get; set; } = string.Empty;

    // BookingCount: value read from the matching SQL result column.
    public int BookingCount { get; set; }

    // TicketsPurchased: value read from the matching SQL result column.
    public long TicketsPurchased { get; set; }

    // TotalSpent: value read from the matching SQL result column.
    public decimal TotalSpent { get; set; }

    // SQL RANK returns BIGINT, including tied spending ranks.
    public long SpendingRank { get; set; }
}

// Response fields map explicitly to the stored procedure result columns.
public class ScreenRoomUtilizationResult
{
    // ScreenRoomID: generated row identifier.
    public int ScreenRoomId { get; set; }

    // RoomNumber: value read from the matching SQL result column.
    public string RoomNumber { get; set; } = string.Empty;

    // ShowtimeCount: value read from the matching SQL result column.
    public int ShowtimeCount { get; set; }

    // TicketsBooked: value read from the matching SQL result column.
    public long TicketsBooked { get; set; }

    // SeatsOffered: value read from the matching SQL result column.
    public long SeatsOffered { get; set; }

    // Percentage of offered seats booked; zero when no seats were offered.
    public decimal OccupancyRate { get; set; }
}

// Response fields map explicitly to the stored procedure result columns.
public class MovieReviewSummaryResult
{
    // MovieID: generated row identifier.
    public int MovieId { get; set; }

    // Title: value read from the matching SQL result column.
    public string Title { get; set; } = string.Empty;

    // ReviewCount: value read from the matching SQL result column.
    public int ReviewCount { get; set; }

    // Fractional average rating; null when the movie has no reviews.
    public decimal? AverageRating { get; set; }

    // Highest rating; null when the movie has no reviews.
    public byte? HighestRating { get; set; }

    // Lowest rating; null when the movie has no reviews.
    public byte? LowestRating { get; set; }
}
