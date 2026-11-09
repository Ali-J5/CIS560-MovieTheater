using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Backend.Models;

namespace Backend.Controllers;

// ApiController validates JSON bodies/query parameters before an action executes.
[ApiController]
[Route("api/showtimes")]
public class ShowtimesController : ControllerBase
{
    // Store configuration only; each action opens and disposes its own SQL connection.
    private readonly string _connectionString;

    public ShowtimesController(IConfiguration configuration)
    {
        // Read the configured database address; fail clearly if configuration is missing.
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is missing.");
    }

    // Read screenings, including dynamically calculated tickets sold and remaining seats.
    [HttpGet]
    [ProducesResponseType(typeof(List<Showtime>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get([FromQuery] int? movieId = null, [FromQuery] DateOnly? firstDate = null,
        [FromQuery] DateOnly? lastDate = null, [FromQuery] bool includeCancelled = false)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_GetShowtimes", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(movieId) ?? DBNull.Value;
            cmd.Parameters.Add("@FirstDate", SqlDbType.Date).Value = (object?)(firstDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@LastDate", SqlDbType.Date).Value = (object?)(lastDate?.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@IncludeCancelled", SqlDbType.Bit).Value = (object?)(includeCancelled) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<Showtime>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new Showtime
                {
                    ShowtimeId = (int)reader["ShowtimeID"],
                    MovieId = (int)reader["MovieID"],
                    Title = (string)reader["Title"],
                    RuntimeMinutes = (int)reader["RuntimeMinutes"],
                    ScreenRoomId = (int)reader["ScreenRoomID"],
                    RoomNumber = (string)reader["RoomNumber"],
                    RoomName = (string)reader["RoomName"],
                    RoomCapacity = (int)reader["RoomCapacity"],
                    StartDateTime = (DateTime)reader["StartDateTime"],
                    TicketPrice = (decimal)reader["TicketPrice"],
                    IsCancelled = (bool)reader["IsCancelled"],
                    TicketsSold = (long)reader["TicketsSold"],
                    RemainingSeats = (long)reader["RemainingSeats"],
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

    // Create a record; the database validates constraints and returns its generated identifier.
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] ShowtimeRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_InsertShowtime", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(request.MovieId) ?? DBNull.Value;
            cmd.Parameters.Add("@ScreenRoomID", SqlDbType.Int).Value = (object?)(request.ScreenRoomId) ?? DBNull.Value;
            cmd.Parameters.Add("@StartDateTime", SqlDbType.DateTime2).Value = (object?)(request.StartDateTime) ?? DBNull.Value;
            SqlParameter ticketPriceParameter = cmd.Parameters.Add("@TicketPrice", SqlDbType.Decimal);
            ticketPriceParameter.Precision = 10;
            ticketPriceParameter.Scale = 2;
            ticketPriceParameter.Value = request.TicketPrice;
            cmd.Parameters.Add("@IsCancelled", SqlDbType.Bit).Value = (object?)(request.IsCancelled) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["ShowtimeID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return StatusCode(StatusCodes.Status201Created, new { showtimeId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Full replacement update; use IsCancelled=true to cancel.
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update([FromRoute, Range(1, int.MaxValue)] int id, [FromBody] ShowtimeRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_UpdateShowtime", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@ShowtimeID", SqlDbType.Int).Value = (object?)(id) ?? DBNull.Value;
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(request.MovieId) ?? DBNull.Value;
            cmd.Parameters.Add("@ScreenRoomID", SqlDbType.Int).Value = (object?)(request.ScreenRoomId) ?? DBNull.Value;
            cmd.Parameters.Add("@StartDateTime", SqlDbType.DateTime2).Value = (object?)(request.StartDateTime) ?? DBNull.Value;
            SqlParameter ticketPriceParameter = cmd.Parameters.Add("@TicketPrice", SqlDbType.Decimal);
            ticketPriceParameter.Precision = 10;
            ticketPriceParameter.Scale = 2;
            ticketPriceParameter.Value = request.TicketPrice;
            cmd.Parameters.Add("@IsCancelled", SqlDbType.Bit).Value = (object?)(request.IsCancelled) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["ShowtimeID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return Ok(new { showtimeId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }
}
