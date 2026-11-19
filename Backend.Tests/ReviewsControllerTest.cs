using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class ReviewsControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task CreateUpdateAndDeleteReviewShouldWork()
    {
        // Create an isolated review, then read the stored rating and comment.
        var controller = new ReviewsController(Configuration);
        var request = await NewReviewAsync();
        var id = CreatedId(await controller.Create(request), "reviewId");
        var review = Rows<Review>(await controller.Get(request.MovieId)).Single();
        Assert.AreEqual(id, review.ReviewId);
        Assert.AreEqual(request.CustomerId, review.CustomerId);
        Assert.AreEqual(request.Rating, review.Rating);
        Assert.AreEqual(request.ReviewText, review.ReviewText);

        // Edit the existing review and verify the persisted replacement values.
        request.Rating = 5;
        request.ReviewText = "Updated SQL test review";
        Result<OkObjectResult>(await controller.Update(id, request));
        review = Rows<Review>(await controller.Get(request.MovieId)).Single();
        Assert.AreEqual(request.Rating, review.Rating);
        Assert.AreEqual(request.ReviewText, review.ReviewText);

        // Confirm the physical delete removes the review from the movie.
        Result<NoContentResult>(await controller.Delete(id));
        Assert.AreEqual(0, Rows<Review>(await controller.Get(request.MovieId)).Count);
    }

    [TestMethod]
    public async Task CreateDuplicateReviewForSameCustomerAndMovieShouldReturnBadRequest()
    {
        // Use the same customer and movie twice to exercise the SQL duplicate guard.
        var controller = new ReviewsController(Configuration);
        var request = await NewReviewAsync();
        CreatedId(await controller.Create(request), "reviewId");
        BadRequestContains(await controller.Create(request), "already reviewed this movie");
    }

    private async Task<ReviewRequest> NewReviewAsync()
    {
        // New parent IDs let these tests leave the seeded movie and customer untouched.
        var movie = await new MoviesController(Configuration).Create(NewMovie());
        var customer = await new CustomersController(Configuration).Create(NewCustomer());
        return new ReviewRequest
        {
            MovieId = CreatedId(movie, "movieId"),
            CustomerId = CreatedId(customer, "customerId"),
            Rating = 3,
            ReviewText = "SQL test review"
        };
    }
}
