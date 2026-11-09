using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Backend.Models;

namespace Backend.Controllers;

// ApiController validates JSON bodies/query parameters before an action executes.
[ApiController]
[Route("api/reports")]
public class ReportsController : ControllerBase
{
    // Store configuration only; each action opens and disposes its own SQL connection.
    private readonly string _connectionString;

    public ReportsController(IConfiguration configuration)
    {
        // Read the configured database address; fail clearly if configuration is missing.
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is missing.");
    }

    // Return movie performance with inclusive yyyy-MM-dd dates.
    [HttpGet("movie-performance")]
    [ProducesResponseType(typeof(List<MoviePerformanceResult>), StatusCodes.Status200OK)]
    public async Task<IActionResult> MoviePerformance([FromQuery, Required] DateOnly? firstDate, [FromQuery, Required] DateOnly? lastDate)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_Report_MoviePerformance", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@FirstDate", SqlDbType.Date).Value = (object?)(firstDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@LastDate", SqlDbType.Date).Value = (object?)(lastDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<MoviePerformanceResult>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new MoviePerformanceResult
                {
                    MovieId = (int)reader["MovieID"],
                    Title = (string)reader["Title"],
                    ShowtimeCount = (int)reader["ShowtimeCount"],
                    TicketsSold = (long)reader["TicketsSold"],
                    TotalRevenue = (decimal)reader["TotalRevenue"],
                    AverageTicketsPerShowtime = (decimal)reader["AverageTicketsPerShowtime"],
                });
            }

            // Step 5: Serialize the list as JSON with HTTP 200; no matches returns an empty array.
            return Ok(results);
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Return customer booking activity with inclusive yyyy-MM-dd dates.
    [HttpGet("customer-booking-activity")]
    [ProducesResponseType(typeof(List<CustomerBookingActivityResult>), StatusCodes.Status200OK)]
    public async Task<IActionResult> CustomerBookingActivity([FromQuery, Required] DateOnly? firstDate, [FromQuery, Required] DateOnly? lastDate)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_Report_CustomerBookingActivity", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@FirstDate", SqlDbType.Date).Value = (object?)(firstDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@LastDate", SqlDbType.Date).Value = (object?)(lastDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<CustomerBookingActivityResult>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new CustomerBookingActivityResult
                {
                    CustomerId = (int)reader["CustomerID"],
                    CustomerName = (string)reader["CustomerName"],
                    BookingCount = (int)reader["BookingCount"],
                    TicketsPurchased = (long)reader["TicketsPurchased"],
                    TotalSpent = (decimal)reader["TotalSpent"],
                    SpendingRank = (long)reader["SpendingRank"],
                });
            }

            // Step 5: Serialize the list as JSON with HTTP 200; no matches returns an empty array.
            return Ok(results);
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Return screen room utilization with inclusive yyyy-MM-dd dates.
    [HttpGet("screen-room-utilization")]
    [ProducesResponseType(typeof(List<ScreenRoomUtilizationResult>), StatusCodes.Status200OK)]
    public async Task<IActionResult> ScreenRoomUtilization([FromQuery, Required] DateOnly? firstDate, [FromQuery, Required] DateOnly? lastDate)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_Report_ScreenRoomUtilization", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@FirstDate", SqlDbType.Date).Value = (object?)(firstDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@LastDate", SqlDbType.Date).Value = (object?)(lastDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<ScreenRoomUtilizationResult>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new ScreenRoomUtilizationResult
                {
                    ScreenRoomId = (int)reader["ScreenRoomID"],
                    RoomNumber = (string)reader["RoomNumber"],
                    ShowtimeCount = (int)reader["ShowtimeCount"],
                    TicketsBooked = (long)reader["TicketsBooked"],
                    SeatsOffered = (long)reader["SeatsOffered"],
                    OccupancyRate = (decimal)reader["OccupancyRate"],
                });
            }

            // Step 5: Serialize the list as JSON with HTTP 200; no matches returns an empty array.
            return Ok(results);
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Return movie review summary for movies meeting the minimum review count.
    [HttpGet("movie-review-summary")]
    [ProducesResponseType(typeof(List<MovieReviewSummaryResult>), StatusCodes.Status200OK)]
    public async Task<IActionResult> MovieReviewSummary([FromQuery, Range(0, int.MaxValue)] int minimumReviewCount = 0)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_Report_MovieReviewSummary", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@MinimumReviewCount", SqlDbType.Int).Value = (object?)(minimumReviewCount) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<MovieReviewSummaryResult>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new MovieReviewSummaryResult
                {
                    MovieId = (int)reader["MovieID"],
                    Title = (string)reader["Title"],
                    ReviewCount = (int)reader["ReviewCount"],
                    AverageRating = reader["AverageRating"] == DBNull.Value ? null : (decimal)reader["AverageRating"],
                    HighestRating = reader["HighestRating"] == DBNull.Value ? null : (byte)reader["HighestRating"],
                    LowestRating = reader["LowestRating"] == DBNull.Value ? null : (byte)reader["LowestRating"],
                });
            }

            // Step 5: Serialize the list as JSON with HTTP 200; no matches returns an empty array.
            return Ok(results);
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }
}
