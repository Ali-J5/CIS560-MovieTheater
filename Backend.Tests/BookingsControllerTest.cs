using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class BookingsControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task CreateUpdateAndDeleteBookingShouldWork()
    {
        // Create an isolated customer and screening, then book two tickets.
        var showtimes = new ShowtimesController(Configuration);
        var bookings = new BookingsController(Configuration);
        var customerId = CreatedId(await new CustomersController(Configuration).Create(NewCustomer()), "customerId");
        var showtime = await NewShowtimeAsync();
        var showtimeId = CreatedId(await showtimes.Create(showtime), "showtimeId");
        var id = CreatedId(await bookings.Create(new BookingRequest
        {
            CustomerId = customerId,
            ShowtimeId = showtimeId,
            NumberOfTickets = 2
        }), "bookingId");

        // Read both views to check server-side pricing and remaining capacity.
        var booking = Rows<Booking>(await bookings.Get(customerId)).Single();
        Assert.AreEqual(id, booking.BookingId);
        Assert.AreEqual(2, booking.NumberOfTickets);
        Assert.AreEqual(2 * showtime.TicketPrice, booking.TotalPrice);
        var screening = Rows<Showtime>(await showtimes.Get(movieId: showtime.MovieId)).Single();
        Assert.AreEqual(screening.RoomCapacity - 2L, screening.RemainingSeats);

        // Change the quantity and verify the recalculated price and seat count.
        Result<OkObjectResult>(await bookings.Update(id, new BookingUpdateRequest { NumberOfTickets = 4 }));
        booking = Rows<Booking>(await bookings.Get(customerId)).Single();
        Assert.AreEqual(4, booking.NumberOfTickets);
        Assert.AreEqual(4 * showtime.TicketPrice, booking.TotalPrice);
        screening = Rows<Showtime>(await showtimes.Get(movieId: showtime.MovieId)).Single();
        Assert.AreEqual(screening.RoomCapacity - 4L, screening.RemainingSeats);

        // A physical delete removes the reservation and makes its seats available again.
        Result<NoContentResult>(await bookings.Delete(id));
        Assert.AreEqual(0, Rows<Booking>(await bookings.Get(customerId)).Count);
        screening = Rows<Showtime>(await showtimes.Get(movieId: showtime.MovieId)).Single();
        Assert.AreEqual((long)screening.RoomCapacity, screening.RemainingSeats);
    }

    [TestMethod]
    public async Task CreateBookingExceedingRoomCapacityShouldReturnBadRequest()
    {
        // Start with an empty room and request one more seat than the room can hold.
        var customerId = CreatedId(await new CustomersController(Configuration).Create(NewCustomer()), "customerId");
        var showtimes = new ShowtimesController(Configuration);
        var showtime = await NewShowtimeAsync();
        var showtimeId = CreatedId(await showtimes.Create(showtime), "showtimeId");
        var screening = Rows<Showtime>(await showtimes.Get(movieId: showtime.MovieId)).Single();

        // Check the SQL business-rule message carried in the controller's HTTP 400.
        var response = await new BookingsController(Configuration).Create(new BookingRequest
        {
            CustomerId = customerId,
            ShowtimeId = showtimeId,
            NumberOfTickets = screening.RoomCapacity + 1
        });
        BadRequestContains(response, "Not enough remaining seats");
    }
}
