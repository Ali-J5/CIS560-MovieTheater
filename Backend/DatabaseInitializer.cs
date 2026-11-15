using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace Backend;

// First-run setup uses the same raw ADO.NET library as our controllers, with no ORM.
public static class DatabaseInitializer
{
    // Six managed relations and one static lookup make up the complete project schema.
    private static readonly string[] TableNames =
        ["AgeRating", "Movie", "ScreenRoom", "Customer", "Showtime", "Booking", "Review"];

    public static async Task InitializeAsync(IConfiguration configuration, string contentRoot, ILogger logger)
    {
        // Disabling automatic setup leaves an administrator's connection and database untouched.
        if (!configuration.GetValue("AutoInitializeDatabase", true))
        {
            logger.LogInformation("Automatic database initialization is disabled.");
            return;
        }

        // Locate source scripts during development or their copied versions after publishing.
        string[] scriptNames = ["Tables.sql", "Procedures.sql", "Data.sql"];
        string[] folders = [Path.Combine(contentRoot, "..", "Database"),
            Path.Combine(contentRoot, "Database"), Path.Combine(AppContext.BaseDirectory, "Database")];
        string? folder = folders.FirstOrDefault(path => scriptNames.All(name => File.Exists(Path.Combine(path, name))));
        if (folder is null)
            throw new InvalidOperationException("Database scripts were not found. Keep Database/ beside Backend/, or publish the complete backend.");

        // An explicit environment override is authoritative: never silently switch databases.
        string? environmentConnection = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection");
        string configuredConnection = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Set ConnectionStrings:DefaultConnection before starting the backend.");
        List<string> candidates = [environmentConnection ?? configuredConnection];
        if (environmentConnection is null && OperatingSystem.IsWindows())
        {
            // Windows accounts can use LocalDB or SQL Express without a SQL password.
            candidates.Add("Server=(localdb)\\MSSQLLocalDB;Database=MovieTheaterBooking;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;");
            candidates.Add("Server=localhost\\SQLEXPRESS;Database=MovieTheaterBooking;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;");
        }
        if (environmentConnection is null)
        {
            // Keep configured credentials when trying the standard Docker/local TCP endpoint.
            SqlConnectionStringBuilder local = new(configuredConnection) { DataSource = "localhost,1433" };
            candidates.Add(local.ConnectionString);
        }

        // Retry briefly because a freshly started SQL Server container needs time to accept logins.
        SqlConnectionStringBuilder? selected = null;
        for (int attempt = 1; attempt <= 15 && selected is null; attempt++)
        {
            foreach (string candidate in candidates.Distinct())
            {
                SqlConnectionStringBuilder target = new(candidate);
                if (string.IsNullOrWhiteSpace(target.InitialCatalog)) target.InitialCatalog = "MovieTheaterBooking";
                SqlConnectionStringBuilder master = new(target.ConnectionString)
                    { InitialCatalog = "master", ConnectTimeout = 2, Pooling = false };
                try
                {
                    // Open master first, since the application database may not exist yet.
                    using SqlConnection probe = new(master.ConnectionString);
                    await probe.OpenAsync();
                    selected = target;
                    break;
                }
                catch (SqlException)
                {
                    // Do not print connection strings or credentials while trying alternatives.
                }
            }
            if (selected is null && attempt < 15)
            {
                if (attempt == 1) logger.LogInformation("Waiting for SQL Server. Start Docker/SQL Server, or set ConnectionStrings__DefaultConnection.");
                await Task.Delay(2000);
            }
        }
        if (selected is null)
            throw new InvalidOperationException("Cannot connect to SQL Server. Run start.sh/start.bat, start SQL Server or Docker, or set ConnectionStrings__DefaultConnection to a valid login. The login must be able to connect to master.");

        logger.LogInformation("SQL Server connected at {Server}; using database {Database}.", selected.DataSource, selected.InitialCatalog);
        SqlConnectionStringBuilder masterConnection = new(selected.ConnectionString) { InitialCatalog = "master" };
        using (SqlConnection master = new(masterConnection.ConnectionString))
        {
            await master.OpenAsync();
            // Parameterize the database name; QUOTENAME safely quotes the CREATE DATABASE identifier.
            using SqlCommand create = new("""
                IF DB_ID(@DatabaseName) IS NULL
                BEGIN
                    DECLARE @Sql NVARCHAR(MAX) = N'CREATE DATABASE ' + QUOTENAME(@DatabaseName);
                    EXEC sys.sp_executesql @Sql;
                END;
                """, master);
            create.Parameters.Add("@DatabaseName", SqlDbType.NVarChar, 128).Value = selected.InitialCatalog;
            create.CommandTimeout = 120;
            logger.LogInformation("Checking master and creating the application database if needed...");
            await create.ExecuteNonQueryAsync();
        }

        // Publish the detected connection so every existing controller uses the same database.
        configuration["ConnectionStrings:DefaultConnection"] = selected.ConnectionString;
        using SqlConnection connection = new(selected.ConnectionString);
        await connection.OpenAsync();

        // Inspect all seven tables, not just Movie, before deciding that initialization is safe.
        int tableCount = 0;
        bool hasManagedData = false;
        foreach (string table in TableNames)
        {
            using SqlCommand exists = new("SELECT CASE WHEN OBJECT_ID(@TableName, 'U') IS NULL THEN 0 ELSE 1 END;", connection);
            exists.Parameters.Add("@TableName", SqlDbType.NVarChar, 128).Value = $"dbo.{table}";
            if (Convert.ToInt32(await exists.ExecuteScalarAsync()) == 0) continue;
            tableCount++;
            if (table == "AgeRating") continue; // Static codes do not count as user/seed data.
            // Identifiers come only from the fixed TableNames list above, never from user input.
            using SqlCommand rows = new($"SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.[{table}]) THEN 1 ELSE 0 END;", connection);
            hasManagedData |= Convert.ToInt32(await rows.ExecuteScalarAsync()) == 1;
        }

        if (hasManagedData)
        {
            // Tables.sql contains DROP statements: never run it over a populated or partial schema.
            using SqlCommand compatible = new("""
                SELECT CASE WHEN COL_LENGTH('dbo.Movie', 'DeactivatedOn') IS NOT NULL
                    AND COL_LENGTH('dbo.ScreenRoom', 'DeactivatedOn') IS NOT NULL
                    AND COL_LENGTH('dbo.Customer', 'DeactivatedOn') IS NOT NULL
                    AND COL_LENGTH('dbo.Showtime', 'CancelledOn') IS NOT NULL
                    AND EXISTS (SELECT 1 FROM dbo.Movie) THEN 1 ELSE 0 END;
                """, connection);
            if (tableCount != TableNames.Length)
                throw new InvalidOperationException("The database has existing data but is missing project tables. Nothing was reset. Choose a new database in DefaultConnection, or have its owner repair the schema.");
            if (Convert.ToInt32(await compatible.ExecuteScalarAsync()) != 1)
                throw new InvalidOperationException("The populated database uses an older or incomplete schema. Nothing was reset. Choose a new database or migrate its status timestamp columns before starting.");
            logger.LogInformation("Existing schema and data found. Preserving all records.");
            // CREATE OR ALTER safely refreshes procedures without reseeding existing tables.
            await ExecuteScriptAsync(connection, Path.Combine(folder, "Procedures.sql"), logger);
        }
        else
        {
            logger.LogInformation("No managed data found. Creating seven tables, 24 procedures, and demo data...");
            foreach (string name in scriptNames)
                await ExecuteScriptAsync(connection, Path.Combine(folder, name), logger);
        }

        // Verify all required procedure names, rather than accepting an unrelated procedure count.
        string procedures = await File.ReadAllTextAsync(Path.Combine(folder, "Procedures.sql"));
        foreach (Match match in Regex.Matches(procedures, @"CREATE OR ALTER PROCEDURE dbo\.(\w+)", RegexOptions.IgnoreCase))
        {
            using SqlCommand exists = new("SELECT OBJECT_ID(@ProcedureName, 'P');", connection);
            exists.Parameters.Add("@ProcedureName", SqlDbType.NVarChar, 128).Value = $"dbo.{match.Groups[1].Value}";
            if (await exists.ExecuteScalarAsync() is DBNull)
                throw new InvalidOperationException($"Required procedure {match.Groups[1].Value} was not created.");
        }
        foreach (string table in TableNames)
        {
            // Read row counts for friendly startup confirmation; do not assume seed counts after edits.
            using SqlCommand count = new($"SELECT COUNT(*) FROM dbo.[{table}];", connection);
            logger.LogInformation("{Table}: {Count} rows.", table, await count.ExecuteScalarAsync());
        }
        logger.LogInformation("Database verified and seeded! Existing records are preserved on later starts.");
    }

    private static async Task ExecuteScriptAsync(SqlConnection connection, string path, ILogger logger)
    {
        logger.LogInformation("Running {Script}...", Path.GetFileName(path));
        string script = await File.ReadAllTextAsync(path);
        // GO is a client batch separator, not T-SQL. Our scripts put it alone on a line.
        // Splitting preserves CREATE PROCEDURE's requirement to begin a separate batch.
        string[] batches = Regex.Split(script, @"^[ \t]*GO[ \t]*(?:--[^\r\n]*)?\r?$",
            RegexOptions.Multiline | RegexOptions.IgnoreCase);
        for (int index = 0; index < batches.Length; index++)
        {
            if (string.IsNullOrWhiteSpace(batches[index])) continue;
            // Execute each batch on the same connection so session settings remain in effect.
            using SqlCommand command = new(batches[index], connection) { CommandTimeout = 120 };
            try
            {
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                // Include the script/batch for troubleshooting without exposing credentials.
                throw new InvalidOperationException($"{Path.GetFileName(path)} batch {index + 1} failed: {ex.Message}", ex);
            }
        }
    }
}
