using System.Text.Json;

namespace ChessClub;

public sealed class ClubSettings
{
    public string Appearance { get; set; } = "System";
    public string EnginePath { get; set; } = "";
    public string BoardTheme { get; set; } = "Grün";
    public string PieceTheme { get; set; } = "classic";
    public HashSet<string> Completed { get; set; } = new();
}

public sealed record ArchivedGame(string Id, string Title, DateTimeOffset Date, string Pgn);

public sealed class LocalStore
{
    public string DirectoryPath { get; }
    public ClubSettings Settings { get; }
    public List<ArchivedGame> Games { get; }

    public LocalStore(string? directory = null)
    {
        DirectoryPath = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeinSchachclub");
        Directory.CreateDirectory(DirectoryPath);
        Settings = Read<ClubSettings>("settings.json") ?? new();
        Games = Read<List<ArchivedGame>>("games.json") ?? new();
        if (Settings.EnginePath is null || Settings.BoardTheme is null || Settings.PieceTheme is null || Settings.Appearance is null || Settings.Completed is null || Settings.Completed.Any(x => x is null))
            throw new InvalidDataException($"Die Einstellungen in {DirectoryPath} enthalten ungültige Werte. Die Originaldatei bleibt erhalten.");
        if (Games.Any(g => g is null || g.Id is null || g.Title is null || g.Pgn is null))
            throw new InvalidDataException($"Das Partienarchiv in {DirectoryPath} enthält ungültige Werte. Die Originaldatei bleibt erhalten.");
    }

    private T? Read<T>(string filename)
    {
        var path = Path.Combine(DirectoryPath, filename);
        if (!File.Exists(path)) return default;
        // Preserve corrupt data for recovery instead of silently overwriting it.
        try { return JsonSerializer.Deserialize<T>(File.ReadAllText(path)) ?? throw new JsonException("JSON darf nicht null sein."); }
        catch (JsonException e) { throw new InvalidDataException($"Die Datei {path} ist beschädigt. Bitte sichere oder repariere sie vor dem nächsten Start.", e); }
    }

    private void Write<T>(string filename, T value)
    {
        var path = Path.Combine(DirectoryPath, filename);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(value, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temporary, path, true);
    }

    public void SaveSettings() => Write("settings.json", Settings);
    public void SaveGame(string pgn, string title)
    {
        Games.Insert(0, new(Guid.NewGuid().ToString("N"), title, DateTimeOffset.Now, pgn));
        try { Write("games.json", Games); }
        catch { Games.RemoveAt(0); throw; }
    }
}
