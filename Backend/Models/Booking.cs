using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class Booking
{
    // BookingID: generated row identifier.
    public int BookingId { get; set; }

    // CustomerID: generated row identifier.
    public int CustomerId { get; set; }

    // ShowtimeID: generated row identifier.
    public int ShowtimeId { get; set; }

    // Database-generated local date and time when the booking was created.
    public DateTime BookingDate { get; set; }

    // NumberOfTickets: value read from the matching SQL result column.
    public int NumberOfTickets { get; set; }

    // Stored historical total, calculated by SQL rather than supplied by the client.
    public decimal TotalPrice { get; set; }

    // MovieID: generated row identifier.
    public int MovieId { get; set; }

    // Title: value read from the matching SQL result column.
    public string Title { get; set; } = string.Empty;

    // Theater local start time; DATETIME2 stores no time-zone offset.
    public DateTime StartDateTime { get; set; }

    // TicketPrice: value read from the matching SQL result column.
    public decimal TicketPrice { get; set; }

    // True cancels the screening while retaining its bookings and history.
    public bool IsCancelled { get; set; }

    // ScreenRoomID: generated row identifier.
    public int ScreenRoomId { get; set; }

    // RoomNumber: value read from the matching SQL result column.
    public string RoomNumber { get; set; } = string.Empty;

    // RoomName: value read from the matching SQL result column.
    public string RoomName { get; set; } = string.Empty;
}

// JSON body for create/full-replacement update requests.
public class BookingRequest
{
    // CustomerID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int CustomerId { get; set; }

    // ShowtimeID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int ShowtimeId { get; set; }

    // NumberOfTickets: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int NumberOfTickets { get; set; }
}

// JSON body for create/full-replacement update requests.
public class BookingUpdateRequest
{
    // NumberOfTickets: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int NumberOfTickets { get; set; }
}
