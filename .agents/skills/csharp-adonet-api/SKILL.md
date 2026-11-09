---
name: csharp-adonet-api
description: Use whenever writing or modifying C# ASP.NET Core Web API backend code, controllers, models, or database access in the /Backend folder.
---

# C# ASP.NET Core + Raw ADO.NET Backend Skill

## 1. Strict No-ORM Rule
- **ONLY use `Microsoft.Data.SqlClient`**.
- **NEVER** install or reference `Microsoft.EntityFrameworkCore` or `Dapper`.
- Read the SQL Server connection string from `appsettings.json` (`ConnectionStrings:DefaultConnection`).
- Enable CORS in `Program.cs` (`AllowAnyOrigin`, `AllowAnyMethod`, `AllowAnyHeader`) so the React Vite frontend can call the API without CORS errors.

## 2. Clean, Flat Folder Structure (`/Backend`)
Keep the C# project simple and easy to explain in a class presentation:
- `/Backend/Program.cs` — Minimal startup, registers controllers, Swagger, and CORS.
- `/Backend/appsettings.json` — Contains the SQL Server connection string.
- `/Backend/Models/` — Simple plain C# classes (DTOs/POCOs) matching database rows and request bodies.
- `/Backend/Controllers/` — REST API Controllers (`MoviesController.cs`, `ScreenRoomsController.cs`, `ShowtimesController.cs`, `CustomersController.cs`, `BookingsController.cs`, `ReviewsController.cs`, `ReportsController.cs`).

## 3. Standard ADO.NET Coding & Commenting Pattern
Every controller endpoint MUST follow this exact, heavily commented pattern so the student can read and explain every line:

```csharp
// Step 1: Open a connection to SQL Server using the connection string from appsettings.json
using SqlConnection conn = new SqlConnection(_connectionString);
await conn.OpenAsync();

// Step 2: Create a SqlCommand pointing to our Stored Procedure (or parameterized T-SQL query)
using SqlCommand cmd = new SqlCommand("usp_GetActiveMovies", conn);
cmd.CommandType = CommandType.StoredProcedure;

// Step 3: Add SQL parameters safely to prevent SQL injection
cmd.Parameters.AddWithValue("@Genre", (object?)genre ?? DBNull.Value);

// Step 4: Execute the reader and map each database row into our C# list
using SqlDataReader reader = await cmd.ExecuteReaderAsync();
while (await reader.ReadAsync())
{
    // Read columns by name and add to result list...
}
```

## 4. Friendly SQL Error Handling
Catch `SqlException` in `POST`/`PUT`/`DELETE` endpoints (such as overlap errors, capacity errors, or `UNIQUE`/`CHECK` constraint failures) and return `BadRequest(new { error = ex.Message })` so the React frontend can display the exact database rule message in a red banner for the demo!