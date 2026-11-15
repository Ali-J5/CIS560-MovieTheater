using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class Showtime
{
    // ShowtimeID: generated row identifier.
    public int ShowtimeId { get; set; }

    // MovieID: foreign key identifying the related Movie row.
    public int MovieId { get; set; }

    // Title: value read from the matching SQL result column.
    public string Title { get; set; } = string.Empty;

    // RuntimeMinutes: value read from the matching SQL result column.
    public int RuntimeMinutes { get; set; }

    // ScreenRoomID: foreign key identifying the related ScreenRoom row.
    public int ScreenRoomId { get; set; }

    // RoomNumber: value read from the matching SQL result column.
    public string RoomNumber { get; set; } = string.Empty;

    // RoomName: value read from the matching SQL result column.
    public string RoomName { get; set; } = string.Empty;

    // RoomCapacity: value read from the matching SQL result column.
    public int RoomCapacity { get; set; }

    // Theater local start time; DATETIME2 stores no time-zone offset.
    public DateTime StartDateTime { get; set; }

    // TicketPrice: value read from the matching SQL result column.
    public decimal TicketPrice { get; set; }

    // True cancels the screening while retaining its bookings and history.
    public bool IsCancelled { get; set; }

    // Sum of ticket quantities; SQL BIGINT maps to C# long.
    public long TicketsSold { get; set; }

    // Live capacity minus tickets sold; SQL BIGINT maps to C# long.
    public long RemainingSeats { get; set; }

    // Database-managed status change time; null while the screening is not cancelled.
    public DateTime? CancelledOn { get; set; }
}

// JSON body for create/full-replacement update requests.
public class ShowtimeRequest
{
    // MovieID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int MovieId { get; set; }

    // ScreenRoomID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int ScreenRoomId { get; set; }

    // Theater local start time; DATETIME2 stores no time-zone offset.
    public DateTime StartDateTime { get; set; }

    // TicketPrice: value sent to the stored procedure.
    [Range(typeof(decimal), "0", "99999999.99")]
    public decimal TicketPrice { get; set; }

    // True cancels the screening while retaining its bookings and history.
    public bool IsCancelled { get; set; }
}
