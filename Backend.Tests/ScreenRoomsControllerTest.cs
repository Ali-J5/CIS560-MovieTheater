using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class ScreenRoomsControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task GetScreenRoomsShouldReturnSeededRooms()
    {
        // Read room identifiers and capacities from the seeded catalog.
        var rooms = Rows<ScreenRoom>(await new ScreenRoomsController(Configuration).Get(includeInactive: true));
        Assert.IsTrue(rooms.Count >= 10);
        Assert.IsTrue(rooms.Any(room => room.RoomNumber == "01" && room.Capacity > 0));
    }

    [TestMethod]
    public async Task CreateAndUpdateScreenRoomShouldWork()
    {
        // Change the capacity and deactivate the test room through the controller.
        var controller = new ScreenRoomsController(Configuration);
        var request = NewRoom();
        var id = CreatedId(await controller.Create(request), "screenRoomId");
        request.Capacity = 25;
        request.IsActive = false;
        Result<OkObjectResult>(await controller.Update(id, request));

        // The record remains available in the include-inactive list with a timestamp.
        var room = Rows<ScreenRoom>(await controller.Get(includeInactive: true)).Single(row => row.ScreenRoomId == id);
        Assert.AreEqual(request.RoomNumber, room.RoomNumber);
        Assert.AreEqual(request.Capacity, room.Capacity);
        Assert.IsFalse(room.IsActive);
        Assert.IsNotNull(room.DeactivatedOn);
        Assert.IsFalse(Rows<ScreenRoom>(await controller.Get()).Any(row => row.ScreenRoomId == id));
    }
}
