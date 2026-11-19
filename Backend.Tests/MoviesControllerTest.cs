using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class MoviesControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task GetMoviesShouldReturnSeededMovies()
    {
        // Read the full catalog, including the seed's inactive films.
        var movies = Rows<Movie>(await new MoviesController(Configuration).Get(includeInactive: true));
        Assert.IsTrue(movies.Count >= 110);
        Assert.IsTrue(movies.Any(movie => movie.Title == "The Shawshank Redemption"));
    }

    [TestMethod]
    public async Task CreateAndUpdateMovieShouldWork()
    {
        // Save a new film, then soft-delete it through the same update action the UI uses.
        var controller = new MoviesController(Configuration);
        var request = NewMovie();
        var id = CreatedId(await controller.Create(request), "movieId");
        request.Description = "Updated test description";
        request.IsActive = false;
        Result<OkObjectResult>(await controller.Update(id, request));

        // Include inactive records so we can read the SQL-managed timestamp.
        var movie = Rows<Movie>(await controller.Get(title: request.Title, includeInactive: true)).Single();
        Assert.AreEqual(id, movie.MovieId);
        Assert.AreEqual(request.Description, movie.Description);
        Assert.IsFalse(movie.IsActive);
        Assert.IsNotNull(movie.DeactivatedOn);
        Assert.AreEqual(0, Rows<Movie>(await controller.Get(title: request.Title)).Count);
    }

    [TestMethod]
    public async Task CreateMovieWithInvalidAgeRatingShouldReturnBadRequest()
    {
        // Send an unknown rating to exercise SQL lookup validation through the controller.
        var request = NewMovie();
        request.AgeRating = "INVALID";
        BadRequestContains(await new MoviesController(Configuration).Create(request), "supported age rating");
    }
}
