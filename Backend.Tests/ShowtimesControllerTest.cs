using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class ShowtimesControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task GetShowtimesShouldReturnRemainingSeats()
    {
        // Find a seeded screening with bookings and verify the capacity arithmetic.
        var controller = new ShowtimesController(Configuration);
        var rows = Rows<Showtime>(await controller.Get());
        Assert.IsTrue(rows.Any(row => row.TicketsSold > 0));
        foreach (var row in rows)
            Assert.AreEqual(row.RoomCapacity - row.TicketsSold, row.RemainingSeats);
    }

    [TestMethod]
    public async Task ScheduleAndCancelShowtimeShouldWork()
    {
        // Schedule a film in its own room, then cancel using the regular update action.
        var controller = new ShowtimesController(Configuration);
        var request = await NewShowtimeAsync();
        var id = CreatedId(await controller.Create(request), "showtimeId");
        request.IsCancelled = true;
        Result<OkObjectResult>(await controller.Update(id, request));

        // Read the cancelled row and verify that the default list hides it.
        var showtime = Rows<Showtime>(await controller.Get(movieId: request.MovieId, includeCancelled: true)).Single();
        Assert.AreEqual(id, showtime.ShowtimeId);
        Assert.IsTrue(showtime.IsCancelled);
        Assert.IsNotNull(showtime.CancelledOn);
        Assert.AreEqual(0, Rows<Showtime>(await controller.Get(movieId: request.MovieId)).Count);
    }

    [DataTestMethod]
    [DataRow(30, "Showtime overlaps")]
    [DataRow(0, "already has a screening at that start time")]
    public async Task ScheduleOverlappingShowtimeInSameRoomShouldReturnBadRequest(int minutesLater, string message)
    {
        // Exercise both SQL guards: a runtime overlap (50001) and an identical start (50007).
        var controller = new ShowtimesController(Configuration);
        var request = await NewShowtimeAsync();
        CreatedId(await controller.Create(request), "showtimeId");
        request.StartDateTime = request.StartDateTime.AddMinutes(minutesLater);

        // The controller maps the SQL exception to HTTP 400 and exposes its message.
        BadRequestContains(await controller.Create(request), message);
    }
}
