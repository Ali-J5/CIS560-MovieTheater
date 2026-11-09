using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class ScreenRoom
{
    // ScreenRoomID: generated row identifier.
    public int ScreenRoomId { get; set; }

    // RoomNumber: value read from the matching SQL result column.
    public string RoomNumber { get; set; } = string.Empty;

    // Name: value read from the matching SQL result column.
    public string Name { get; set; } = string.Empty;

    // ScreenType: value read from the matching SQL result column.
    public string ScreenType { get; set; } = string.Empty;

    // Capacity: value read from the matching SQL result column.
    public int Capacity { get; set; }

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; }
}

// JSON body for create/full-replacement update requests.
public class ScreenRoomRequest
{
    // RoomNumber: value sent to the stored procedure.
    [Required, StringLength(100)]
    public string RoomNumber { get; set; } = string.Empty;

    // Name: value sent to the stored procedure.
    [Required, StringLength(100)]
    public string Name { get; set; } = string.Empty;

    // ScreenType: value sent to the stored procedure.
    [Required, StringLength(50)]
    public string ScreenType { get; set; } = string.Empty;

    // Capacity: value sent to the stored procedure.
    [Range(1, int.MaxValue)]
    public int Capacity { get; set; }

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; } = true;
}
