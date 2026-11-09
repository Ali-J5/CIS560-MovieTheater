using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Backend.Models;

namespace Backend.Controllers;

// ApiController validates JSON bodies/query parameters before an action executes.
[ApiController]
[Route("api/reviews")]
public class ReviewsController : ControllerBase
{
    // Store configuration only; each action opens and disposes its own SQL connection.
    private readonly string _connectionString;

    public ReviewsController(IConfiguration configuration)
    {
        // Read the configured database address; fail clearly if configuration is missing.
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is missing.");
    }

    // GET /api/reviews?movieId=1 returns the movie’s reviews and reviewer names.
    [HttpGet]
    [ProducesResponseType(typeof(List<Review>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get([FromQuery, Required, Range(1, int.MaxValue)] int? movieId)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_GetReviewsForMovie", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(movieId) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<Review>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new Review
                {
                    ReviewId = (int)reader["ReviewID"],
                    CustomerId = (int)reader["CustomerID"],
                    MovieId = (int)reader["MovieID"],
                    FirstName = (string)reader["FirstName"],
                    LastName = (string)reader["LastName"],
                    Rating = (byte)reader["Rating"],
                    ReviewText = reader["ReviewText"] == DBNull.Value ? null : (string)reader["ReviewText"],
                    ReviewDate = (DateTime)reader["ReviewDate"],
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
    public async Task<IActionResult> Create([FromBody] ReviewRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_InsertReview", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@CustomerID", SqlDbType.Int).Value = (object?)(request.CustomerId) ?? DBNull.Value;
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(request.MovieId) ?? DBNull.Value;
            cmd.Parameters.Add("@Rating", SqlDbType.TinyInt).Value = (object?)(request.Rating) ?? DBNull.Value;
            cmd.Parameters.Add("@ReviewText", SqlDbType.NVarChar, -1).Value = (object?)request.ReviewText ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["ReviewID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return StatusCode(StatusCodes.Status201Created, new { reviewId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Update the existing review.
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update([FromRoute, Range(1, int.MaxValue)] int id, [FromBody] ReviewRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_UpdateReview", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@ReviewID", SqlDbType.Int).Value = (object?)(id) ?? DBNull.Value;
            cmd.Parameters.Add("@CustomerID", SqlDbType.Int).Value = (object?)(request.CustomerId) ?? DBNull.Value;
            cmd.Parameters.Add("@MovieID", SqlDbType.Int).Value = (object?)(request.MovieId) ?? DBNull.Value;
            cmd.Parameters.Add("@Rating", SqlDbType.TinyInt).Value = (object?)(request.Rating) ?? DBNull.Value;
            cmd.Parameters.Add("@ReviewText", SqlDbType.NVarChar, -1).Value = (object?)request.ReviewText ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["ReviewID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return Ok(new { reviewId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Permanently remove this review.
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete([FromRoute, Range(1, int.MaxValue)] int id)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_DeleteReview", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@ReviewID", SqlDbType.Int).Value = (object?)(id) ?? DBNull.Value;

            // Step 4: Execute the delete; the procedure throws if the identifier does not exist.
            // Do not interpret the affected-row count: our procedures use SET NOCOUNT ON.
            await cmd.ExecuteNonQueryAsync();

            // Step 5: HTTP 204 confirms cancellation/removal without a response body.
            return NoContent();
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }
}
