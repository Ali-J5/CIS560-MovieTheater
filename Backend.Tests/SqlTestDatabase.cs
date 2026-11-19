using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

[assembly: DoNotParallelize]

namespace Backend.Tests;

[TestClass]
public sealed class SqlTestDatabase
{
    internal static IConfiguration Configuration { get; private set; } = null!;
    private static long[]? initialCounts;

    [AssemblyInitialize]
    public static async Task InitializeAsync(TestContext context)
    {
        // Locate the source project from the test binary, even when invoked from another folder.
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Backend", "Backend.csproj")))
            directory = directory.Parent;

        if (directory is null)
            throw new InvalidOperationException("Could not locate the Backend project from the test output directory.");

        var backend = Path.Combine(directory.FullName, "Backend");
        // Default to the local development settings, like the backend's launch profile.
        var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
            ?? Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
            ?? "Development";
        Configuration = new ConfigurationBuilder()
            .SetBasePath(backend)
            .AddJsonFile("appsettings.json")
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        // Run the same startup logic once outside any test transaction, including its schema checks.
        await DatabaseInitializer.InitializeAsync(Configuration, backend, NullLogger.Instance);
        var connection = new SqlConnectionStringBuilder(Configuration.GetConnectionString("DefaultConnection"));
        if (!connection.Enlist)
            throw new InvalidOperationException("The test connection must allow ambient transaction enlistment (Enlist=True).");

        initialCounts = await ReadCountsAsync();
        context.WriteLine($"Before tests: {FormatCounts(initialCounts)}");
    }

    [AssemblyCleanup]
    public static async Task VerifyRollbackAsync()
    {
        if (initialCounts is null)
            return;

        // All per-test scopes have been disposed. Read the committed state on a fresh connection.
        var finalCounts = await ReadCountsAsync();
        Console.WriteLine($"After tests: {FormatCounts(finalCounts)}");
        CollectionAssert.AreEqual(initialCounts, finalCounts,
            $"Table counts changed. Before: {FormatCounts(initialCounts)}. After: {FormatCounts(finalCounts)}.");
    }

    private static async Task<long[]> ReadCountsAsync()
    {
        // Open the resolved connection and read one count per project table.
        await using var connection = new SqlConnection(Configuration.GetConnectionString("DefaultConnection"));
        await connection.OpenAsync();
        using var command = new SqlCommand("""
            SELECT (SELECT COUNT_BIG(*) FROM dbo.AgeRating),
                   (SELECT COUNT_BIG(*) FROM dbo.Movie),
                   (SELECT COUNT_BIG(*) FROM dbo.ScreenRoom),
                   (SELECT COUNT_BIG(*) FROM dbo.Customer),
                   (SELECT COUNT_BIG(*) FROM dbo.Showtime),
                   (SELECT COUNT_BIG(*) FROM dbo.Booking),
                   (SELECT COUNT_BIG(*) FROM dbo.Review);
            """, connection);
        using var reader = await command.ExecuteReaderAsync();
        Assert.IsTrue(await reader.ReadAsync());
        return Enumerable.Range(0, reader.FieldCount).Select(reader.GetInt64).ToArray();
    }

    private static string FormatCounts(long[] counts) =>
        string.Join(", ", new[] { "AgeRating", "Movie", "ScreenRoom", "Customer", "Showtime", "Booking", "Review" }
            .Zip(counts, (table, count) => $"{table}={count}"));
}
