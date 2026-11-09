// Load appsettings.json, environment variables, and command-line configuration.
var builder = WebApplication.CreateBuilder(args);

// Give the React application a predictable local HTTP address.
builder.WebHost.UseUrls("http://localhost:5000");

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

// Publish the OpenAPI document and browser testing UI at /swagger.
app.UseSwagger();
app.UseSwaggerUI();

// Apply the CORS policy before controller actions handle incoming requests.
app.UseCors();

// Map attribute routes such as GET /api/movies to the corresponding actions.
app.MapControllers();

// Start listening; connections to SQL Server are opened only when an action runs.
app.Run();
