using Backend;

// Load appsettings.json, environment variables, and command-line configuration.
var builder = WebApplication.CreateBuilder(args);

// The launcher selects a free local port; direct startup keeps the familiar default.
builder.WebHost.UseUrls(builder.Configuration["BackendUrl"] ?? "http://localhost:5000");

// Discover our controller classes and enable JSON request/response handling.
builder.Services.AddControllers();

// Describe controller endpoints and generate the Swagger API document.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Allow the local React frontend to send any method and headers from any origin.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

// Build the application after registering its services.
var app = builder.Build();

// Initialize before accepting requests, so the frontend never sees a half-built database.
try
{
    await DatabaseInitializer.InitializeAsync(builder.Configuration, app.Environment.ContentRootPath, app.Logger);
}
catch (Exception ex) when (ex is InvalidOperationException or Microsoft.Data.SqlClient.SqlException or IOException or ArgumentException)
{
    // Stop with an actionable message instead of serving API requests that cannot reach SQL.
    app.Logger.LogError("Database setup failed: {Message}", ex.Message);
    Environment.ExitCode = 1;
    await app.DisposeAsync();
    return;
}

// Publish the OpenAPI document and browser testing UI at /swagger.
app.UseSwagger();
app.UseSwaggerUI();

// Apply the CORS policy before controller actions handle incoming requests.
app.UseCors();

// Map attribute routes such as GET /api/movies to the corresponding actions.
app.MapControllers();

// Start listening after setup succeeds; each controller opens its own connection per request.
app.Run();
