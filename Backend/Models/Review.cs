using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class Review
{
    // ReviewID: generated row identifier.
    public int ReviewId { get; set; }

    // CustomerID: generated row identifier.
    public int CustomerId { get; set; }

    // MovieID: generated row identifier.
    public int MovieId { get; set; }

    // FirstName: value read from the matching SQL result column.
    public string FirstName { get; set; } = string.Empty;

    // LastName: value read from the matching SQL result column.
    public string LastName { get; set; } = string.Empty;

    // Rating: value read from the matching SQL result column.
    public byte Rating { get; set; }

    // Optional written feedback; null is stored as SQL NULL.
    public string? ReviewText { get; set; }

    // Database-generated local date and time when the review was created.
    public DateTime ReviewDate { get; set; }
}

// JSON body for create/full-replacement update requests.
public class ReviewRequest
{
    // CustomerID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int CustomerId { get; set; }

    // MovieID: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int MovieId { get; set; }

    // Rating: value sent to the stored procedure.
    [Range(1, 5)]
    public byte Rating { get; set; }

    // Optional written feedback; null is stored as SQL NULL.
    public string? ReviewText { get; set; }
}
