using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class Movie
{
    // MovieID: generated row identifier.
    public int MovieId { get; set; }

    // Title: value read from the matching SQL result column.
    public string Title { get; set; } = string.Empty;

    // Calendar release date, represented as yyyy-MM-dd in JSON.
    public DateOnly ReleaseDate { get; set; }

    // Genre: value read from the matching SQL result column.
    public string Genre { get; set; } = string.Empty;

    // RuntimeMinutes: value read from the matching SQL result column.
    public int RuntimeMinutes { get; set; }

    // AgeRating: value read from the matching SQL result column.
    public string AgeRating { get; set; } = string.Empty;

    // Optional movie description; null is stored as SQL NULL.
    public string? Description { get; set; }

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; }
}

// JSON body for create/full-replacement update requests.
public class MovieRequest
{
    // Title: value sent to the stored procedure.
    [Required, StringLength(200)]
    public string Title { get; set; } = string.Empty;

    // Calendar release date, represented as yyyy-MM-dd in JSON.
    public DateOnly ReleaseDate { get; set; }

    // Genre: value sent to the stored procedure.
    [Required, StringLength(50)]
    public string Genre { get; set; } = string.Empty;

    // RuntimeMinutes: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int RuntimeMinutes { get; set; }

    // AgeRating: value sent to the stored procedure.
    [Required, StringLength(10)]
    public string AgeRating { get; set; } = string.Empty;

    // Optional movie description; null is stored as SQL NULL.
    public string? Description { get; set; }

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; } = true;
}
