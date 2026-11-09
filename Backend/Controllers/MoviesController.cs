using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Backend.Models;

namespace Backend.Controllers;

// ApiController validates JSON bodies/query parameters before an action executes.
[ApiController]
[Route("api/movies")]
public class MoviesController : ControllerBase
{
    // Store configuration only; each action opens and disposes its own SQL connection.
    private readonly string _connectionString;

    public MoviesController(IConfiguration configuration)
    {
        // Read the configured database address; fail clearly if configuration is missing.
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is missing.");
    }

    // GET /api/movies supports optional title, genre, ageRating, and includeInactive filters.
    [HttpGet]
    [ProducesResponseType(typeof(List<Movie>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get([FromQuery] string? title = null, [FromQuery] string? genre = null,
        [FromQuery] string? ageRating = null, [FromQuery] bool includeInactive = false)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_GetMovies", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@Title", SqlDbType.NVarChar, 200).Value = (object?)title ?? DBNull.Value;
            cmd.Parameters.Add("@Genre", SqlDbType.NVarChar, 50).Value = (object?)genre ?? DBNull.Value;
            cmd.Parameters.Add("@AgeRating", SqlDbType.NVarChar, 10).Value = (object?)ageRating ?? DBNull.Value;
            cmd.Parameters.Add("@IncludeInactive", SqlDbType.Bit).Value = (object?)(includeInactive) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<Movie>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new Movie
                {
                    MovieId = (int)reader["MovieID"],
                    Title = (string)reader["Title"],
                    ReleaseDate = DateOnly.FromDateTime((DateTime)reader["ReleaseDate"]),
                    Genre = (string)reader["Genre"],
                    RuntimeMinutes = (int)reader["RuntimeMinutes"],
                    AgeRating = (string)reader["AgeRating"],
                    Description = reader["Description"] == DBNull.Value ? null : (string)reader["Description"],
                    IsActive = (bool)reader["IsActive"],
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
    public async Task<IActionResult> Create([FromBody] MovieRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_InsertMovie", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@Title", SqlDbType.NVarChar, 200).Value = (object?)request.Title ?? DBNull.Value;
            cmd.Parameters.Add("@ReleaseDate", SqlDbType.Date).Value = (object?)(request.ReleaseDate.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@Genre", SqlDbType.NVarChar, 50).Value = (object?)request.Genre ?? DBNull.Value;
            cmd.Parameters.Add("@RuntimeMinutes", SqlDbType.Int).Value = (object?)(request.RuntimeMinutes) ?? DBNull.Value;
            cmd.Parameters.Add("@AgeRating", SqlDbType.NVarChar, 10).Value = (object?)request.AgeRating ?? DBNull.Value;
            cmd.Parameters.Add("@Description", SqlDbType.NVarChar, -1).Value = (object?)request.Description ?? DBNull.Value;
            cmd.Parameters.Add("@IsActive", SqlDbType.Bit).Value = (object?)(request.IsActive) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["MovieID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return StatusCode(StatusCodes.Status201Created, new { movieId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Full replacement update; use IsActive=false to soft-delete.
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update([FromRoute, Range(1, int.MaxValue)] int id, [FromBody] MovieRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_UpdateMovie", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(id) ?? DBNull.Value;
            cmd.Parameters.Add("@Title", SqlDbType.NVarChar, 200).Value = (object?)request.Title ?? DBNull.Value;
            cmd.Parameters.Add("@ReleaseDate", SqlDbType.Date).Value = (object?)(request.ReleaseDate.ToDateTime(TimeOnly.MinValue)) ?? DBNull.Value;
            cmd.Parameters.Add("@Genre", SqlDbType.NVarChar, 50).Value = (object?)request.Genre ?? DBNull.Value;
            cmd.Parameters.Add("@RuntimeMinutes", SqlDbType.Int).Value = (object?)(request.RuntimeMinutes) ?? DBNull.Value;
            cmd.Parameters.Add("@AgeRating", SqlDbType.NVarChar, 10).Value = (object?)request.AgeRating ?? DBNull.Value;
            cmd.Parameters.Add("@Description", SqlDbType.NVarChar, -1).Value = (object?)request.Description ?? DBNull.Value;
            cmd.Parameters.Add("@IsActive", SqlDbType.Bit).Value = (object?)(request.IsActive) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["MovieID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return Ok(new { movieId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }
}
