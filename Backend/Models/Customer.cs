using System.ComponentModel.DataAnnotations;

namespace Backend.Models;

// Response fields map explicitly to the stored procedure result columns.
public class Customer
{
    // CustomerID: generated row identifier.
    public int CustomerId { get; set; }

    // Email: value read from the matching SQL result column.
    public string Email { get; set; } = string.Empty;

    // PhoneNumber: value read from the matching SQL result column.
    public string PhoneNumber { get; set; } = string.Empty;

    // FirstName: value read from the matching SQL result column.
    public string FirstName { get; set; } = string.Empty;

    // LastName: value read from the matching SQL result column.
    public string LastName { get; set; } = string.Empty;

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; }
}

// JSON body for create/full-replacement update requests.
public class CustomerRequest
{
    // Email: value sent to the stored procedure.
    [Required, StringLength(200)]
    public string Email { get; set; } = string.Empty;

    // PhoneNumber: value sent to the stored procedure.
    [Required, StringLength(25)]
    public string PhoneNumber { get; set; } = string.Empty;

    // FirstName: value sent to the stored procedure.
    [Required, StringLength(50)]
    public string FirstName { get; set; } = string.Empty;

    // LastName: value sent to the stored procedure.
    [Required, StringLength(50)]
    public string LastName { get; set; } = string.Empty;

    // False soft-deletes this record while retaining database history.
    public bool IsActive { get; set; } = true;
}
