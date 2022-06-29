using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TodoWeb.Models;

[Table("Todo")]
public class Todo 
{

    [Key]
    public int Id { get; set; }

    [MaxLength(200)]
    [Required]
    public string Task { get; set; }

    public bool IsDone { get; set; }
}