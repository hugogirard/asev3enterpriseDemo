using Microsoft.EntityFrameworkCore;

namespace TodoWeb.Models;

public class TodoContext : DbContext
{
    public DbSet<Todo> Todoes { get; set; }

    public TodoContext(DbContextOptions options) : base(options)
    {
    }
}