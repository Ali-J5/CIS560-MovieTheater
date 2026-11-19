using System.Transactions;
using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Text.Json;

namespace Backend.Tests;

public abstract class SqlControllerTest
{
    private TransactionScope? transaction;

    protected IConfiguration Configuration
    {
        get
        {
            // Fail before opening a controller connection if the runner lost the test scope.
            Assert.IsNotNull(Transaction.Current, "Controller calls require an ambient rollback transaction.");
            return SqlTestDatabase.Configuration;
        }
    }

    [TestInitialize]
    public void BeginTransaction()
    {
        // ADO.NET enlists its connections automatically. Keep the transaction across await.
        transaction = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);
    }

    [TestCleanup]
    public void CleanupTest()
    {
        // No call to Complete: disposal rolls back all successful writes in this test.
        transaction?.Dispose();
    }

    protected static string TestString() => Guid.NewGuid().ToString("N");

    protected static MovieRequest NewMovie() => new()
    {
        Title = $"Test film {TestString()}",
        ReleaseDate = new DateOnly(2020, 1, 1),
        Genre = "Drama",
        RuntimeMinutes = 100,
        AgeRating = "PG"
    };

    protected static ScreenRoomRequest NewRoom() => new()
    {
        RoomNumber = TestString(),
        Name = "Test screening room",
        ScreenType = "Standard",
        Capacity = 20
    };

    protected static CustomerRequest NewCustomer() => new()
    {
        FirstName = "Test",
        LastName = "Customer",
        Email = $"{TestString()}@example.test",
        // The database accepts text up to 25 characters for a phone number.
        PhoneNumber = TestString()[..24]
    };

    protected async Task<ShowtimeRequest> NewShowtimeAsync()
    {
        // Create independent parent rows so no seeded movie or room needs to be edited.
        var movie = await new MoviesController(Configuration).Create(NewMovie());
        var room = await new ScreenRoomsController(Configuration).Create(NewRoom());
        return new ShowtimeRequest
        {
            MovieId = CreatedId(movie, "movieId"),
            ScreenRoomId = CreatedId(room, "screenRoomId"),
            StartDateTime = DateTime.Today.AddDays(30).AddHours(18),
            TicketPrice = 12.50m
        };
    }

    protected static int CreatedId(IActionResult action, string property)
    {
        // The controller returns an anonymous JSON payload with the generated key.
        var result = Result<ObjectResult>(action);
        Assert.AreEqual(StatusCodes.Status201Created, result.StatusCode, JsonSerializer.Serialize(result.Value));
        var id = JsonSerializer.SerializeToElement(result.Value).GetProperty(property).GetInt32();
        Assert.IsTrue(id > 0);
        return id;
    }

    protected static List<T> Rows<T>(IActionResult action)
    {
        var result = Result<OkObjectResult>(action);
        return result.Value as List<T> ?? throw new AssertFailedException($"Expected a list of {typeof(T).Name}.");
    }

    protected static T Result<T>(IActionResult action) where T : IActionResult
    {
        // Include the SQL error payload when an unexpected action result is returned.
        if (action is T result)
            return result;

        var payload = (action as ObjectResult)?.Value;
        throw new AssertFailedException($"Expected {typeof(T).Name}, got {action.GetType().Name}: {JsonSerializer.Serialize(payload)}");
    }

    protected static void BadRequestContains(IActionResult action, string message)
    {
        // Controllers expose the SQL message but do not expose the SQL error number.
        var result = Result<BadRequestObjectResult>(action);
        var error = JsonSerializer.SerializeToElement(result.Value).GetProperty("error").GetString();
        StringAssert.Contains(error, message);
    }
}
