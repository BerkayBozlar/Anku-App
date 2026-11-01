
using Microsoft.AspNetCore.Identity;

namespace AnkuApp.Api.Models;

public class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = string.Empty;
}
