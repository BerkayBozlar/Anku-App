namespace AnkuApp.Api.Models;

// SKS'nin kampüslerde sunulan ortak öğle menüsü; akşam/vejetaryen menüleri bu kapsamda değildir.
public class MealMenu
{
    public int Id { get; set; }
    public DateOnly MenuDate { get; set; }
    public string[] Dishes { get; set; } = [];
    public int? TotalCalories { get; set; }
    public string SourceName { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public DateTime RetrievedAt { get; set; }
    public bool IsManual { get; set; }
}
