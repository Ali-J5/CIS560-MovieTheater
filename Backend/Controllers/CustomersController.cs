using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Backend.Models;

namespace Backend.Controllers;

// ApiController validates JSON bodies/query parameters before an action executes.
[ApiController]
[Route("api/customers")]
public class CustomersController : ControllerBase
{
    // Store configuration only; each action opens and disposes its own SQL connection.
    private readonly string _connectionString;

    public CustomersController(IConfiguration configuration)
    {
        // Read the configured database address; fail clearly if configuration is missing.
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is missing.");
    }

    // Read active records by default; includeInactive=true also returns deactivated rows.
    [HttpGet]
    [ProducesResponseType(typeof(List<Customer>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get([FromQuery] bool includeInactive = false)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_GetCustomers", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@IncludeInactive", SqlDbType.Bit).Value = (object?)(includeInactive) ?? DBNull.Value;

            // Step 4: Execute the procedure and read each result row into a plain C# object.
            var results = new List<Customer>();
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // Map by exact SQL column name; nullable columns need an explicit DBNull check.
                results.Add(new Customer
                {
                    CustomerId = (int)reader["CustomerID"],
                    Email = (string)reader["Email"],
                    PhoneNumber = (string)reader["PhoneNumber"],
                    FirstName = (string)reader["FirstName"],
                    LastName = (string)reader["LastName"],
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
    public async Task<IActionResult> Create([FromBody] CustomerRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_InsertCustomer", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 200).Value = (object?)request.Email ?? DBNull.Value;
            cmd.Parameters.Add("@PhoneNumber", SqlDbType.VarChar, 25).Value = (object?)request.PhoneNumber ?? DBNull.Value;
            cmd.Parameters.Add("@FirstName", SqlDbType.NVarChar, 50).Value = (object?)request.FirstName ?? DBNull.Value;
            cmd.Parameters.Add("@LastName", SqlDbType.NVarChar, 50).Value = (object?)request.LastName ?? DBNull.Value;
            cmd.Parameters.Add("@IsActive", SqlDbType.Bit).Value = (object?)(request.IsActive) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["CustomerID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return StatusCode(StatusCodes.Status201Created, new { customerId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }

    // Full replacement update; use IsActive=false to soft-delete.
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update([FromRoute, Range(1, int.MaxValue)] int id, [FromBody] CustomerRequest request)
    {
        try
        {
            // Step 1: Open a SQL Server connection using DefaultConnection from configuration.
            // using disposes the connection (returning it to the connection pool), even on an error.
            using SqlConnection conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            // Step 2: Name the exact database procedure and mark this command as a procedure call.
            using SqlCommand cmd = new SqlCommand("dbo.usp_UpdateCustomer", conn);
            cmd.CommandType = CommandType.StoredProcedure;

            // Step 3: Bind values separately from SQL text to prevent SQL injection.
            // Explicit SQL types and lengths match the procedure; DBNull.Value represents SQL NULL.
            cmd.Parameters.Add("@CustomerID", SqlDbType.Int).Value = (object?)(id) ?? DBNull.Value;
            cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 200).Value = (object?)request.Email ?? DBNull.Value;
            cmd.Parameters.Add("@PhoneNumber", SqlDbType.VarChar, 25).Value = (object?)request.PhoneNumber ?? DBNull.Value;
            cmd.Parameters.Add("@FirstName", SqlDbType.NVarChar, 50).Value = (object?)request.FirstName ?? DBNull.Value;
            cmd.Parameters.Add("@LastName", SqlDbType.NVarChar, 50).Value = (object?)request.LastName ?? DBNull.Value;
            cmd.Parameters.Add("@IsActive", SqlDbType.Bit).Value = (object?)(request.IsActive) ?? DBNull.Value;

            // Step 4: Read the identifier returned by the write procedure.
            using SqlDataReader reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            int savedId = (int)reader["CustomerID"];
            // Consume the remaining results so SQL completes COMMIT and reports any later error.
            while (await reader.NextResultAsync()) { }

            // Step 5: Return the saved identifier; SQL has already enforced the business rules.
            return Ok(new { customerId = savedId });
        }
        catch (SqlException ex)
        {
            // Pass through THROW, UNIQUE, CHECK, and other SQL errors for the React error banner.
            return BadRequest(new { error = ex.Message });
        }
    }
}
