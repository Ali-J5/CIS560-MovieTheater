using Backend.Controllers;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Tests;

[TestClass]
public sealed class CustomersControllerTest : SqlControllerTest
{
    [TestMethod]
    public async Task GetCustomersShouldReturnSeededCustomers()
    {
        // Include inactive customers when checking the seed population.
        var customers = Rows<Customer>(await new CustomersController(Configuration).Get(includeInactive: true));
        Assert.IsTrue(customers.Count >= 120);
        Assert.IsTrue(customers.Any(customer => customer.Email == "ava.anderson@example.com"));
    }

    [TestMethod]
    public async Task CreateAndUpdateCustomerShouldWork()
    {
        // Change the customer's profile and deactivate it through the update procedure.
        var controller = new CustomersController(Configuration);
        var request = NewCustomer();
        var id = CreatedId(await controller.Create(request), "customerId");
        request.LastName = "Updated";
        request.IsActive = false;
        Result<OkObjectResult>(await controller.Update(id, request));

        // Read the changed fields and timestamp back from SQL Server.
        var customer = Rows<Customer>(await controller.Get(includeInactive: true)).Single(row => row.CustomerId == id);
        Assert.AreEqual(request.Email, customer.Email);
        Assert.AreEqual(request.PhoneNumber, customer.PhoneNumber);
        Assert.AreEqual(request.LastName, customer.LastName);
        Assert.IsFalse(customer.IsActive);
        Assert.IsNotNull(customer.DeactivatedOn);
    }

    [TestMethod]
    public async Task CreateCustomerWithDuplicateEmailShouldReturnBadRequest()
    {
        // Keep the second phone number unique so the failure isolates the duplicate email rule.
        var controller = new CustomersController(Configuration);
        var first = NewCustomer();
        CreatedId(await controller.Create(first), "customerId");
        var duplicate = NewCustomer();
        duplicate.Email = first.Email;

        // Keep the rejected write last because SQL rolls back the ambient transaction on error.
        BadRequestContains(await controller.Create(duplicate), "email address is already used");
    }
}
