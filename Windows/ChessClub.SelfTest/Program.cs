using ChessClub.Core;
using ChessClub;
using System.Text.Json;

var checks = 0;
void Check(bool value, string label) { if (!value) throw new Exception(label); checks++; }
var game = new ChessSession();
Check(game.LegalTargets("e2").Order().SequenceEqual(new[] { "e3", "e4" }), "pawn legal moves");
Check(!game.TryMove("e2e5") && game.MoveSans.Count == 0, "illegal move unchanged");
Check(!game.TryMove("e7e5"), "wrong side rejected");
foreach (var move in new[] { "e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "e1g1" }) Check(game.TryMove(move), move);
Check(game.PieceAt("g1") == 'K' && game.PieceAt("f1") == 'R', "castling");
var exported = game.ExportPgn();
var imported = new ChessSession(); imported.LoadPgn(exported);
Check(imported.Fen == game.Fen && imported.Positions.Count == 8, "PGN roundtrip and replay positions");
foreach (var invalidPgn in new[] { "garbage", "1. e4 garbage *", "1. e4 e5 *\n\n[Event \"Second\"]\n1. d4 d5 *", "1. e4 {unterminated", "1. e4 (e5" })
{
    var before = imported.Fen;
    try { imported.LoadPgn(invalidPgn); throw new Exception("Malformed PGN accepted: " + invalidPgn); }
    catch (FormatException) { Check(imported.Fen == before, "Malformed PGN transactional"); }
}
var annotated = new ChessSession(); annotated.LoadPgn("[Event \"Test\"]\n1.e4 {good} e5 (1...c5 2.Nf3) 2.Nf3!? $1 Nc6 *");
Check(annotated.MoveSans.Count == 4, "annotated PGN mainline");
var unchanged = imported.Fen;
try { imported.LoadFen("invalid"); } catch (FormatException) { }
Check(imported.Fen == unchanged, "invalid load transactional");
game.LoadFen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1");
Check(game.TryMove("e5d6") && game.PieceAt("d5") is null, "en passant");
game.LoadFen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1");
Check(game.TryMove("a7a8n") && game.PieceAt("a8") == 'N', "underpromotion");
game.LoadPgn("1. f3 e5 2. g4 Qh4# 0-1");
Check(game.IsGameOver && !game.TryMove("e2e4"), "checkmate");
var ryzen = HardwareProfile.ForHardware(16, 32768);
Check(ryzen.Threads == 14 && ryzen.HashMB == 4096 && ryzen.Depth == 30, "Ryzen profile");
var low = HardwareProfile.ForHardware(1, 512);
Check(low.Threads == 1 && low.HashMB == 16 && low.Depth == 24, "low memory fallback");
var unknown = HardwareProfile.ForHardware(0, 0);
Check(unknown.Threads == 1 && unknown.HashMB == 16, "unknown hardware safe");
var update = UciEngine.ParseInfo("info depth 24 score cp 125 nps 400000 pv e7e5 g1f3", false)!;
Check(update.Score == "-1.25" && update.Depth == 24 && update.Nps == 400000 && update.PV == "e7e5 g1f3", "UCI black score normalized");
Check(UciEngine.ParseInfo("info depth 30 score mate -3 pv g1g2", false)!.Score == "Matt +3", "mate normalization");
Check(UciEngine.ParseInfo("info string hello", true) is null, "UCI commentary ignored");
var stockfishPath = args.FirstOrDefault() ?? Environment.GetEnvironmentVariable("STOCKFISH_PATH");
if (!string.IsNullOrWhiteSpace(stockfishPath))
{
    var engine = stockfishPath;
    game.Reset();
    var best = await UciEngine.BestMoveAsync(engine, game.Fen, 10, CancellationToken.None);
    Check(game.TryMove(best), "real Stockfish legal move");
    var reported = 0;
    await UciEngine.AnalyzeAsync(engine, game.Fen, HardwareProfile.ForHardware(2, 2048), false, _ => reported++, CancellationToken.None);
    Check(reported > 0, "real Stockfish analysis streaming");
    using var cancel = new CancellationTokenSource(TimeSpan.FromMilliseconds(300));
    try { await UciEngine.AnalyzeAsync(engine, game.Fen, ryzen, true, _ => { }, cancel.Token); throw new Exception("Cancellation ignored"); }
    catch (OperationCanceledException) { checks++; }
    var restarted = await UciEngine.BestMoveAsync(engine, game.Fen, 10, CancellationToken.None);
    Check(game.TryMove(restarted), "real Stockfish restart after cancellation");
}
if (!OperatingSystem.IsWindows())
{
    var fakePath = Path.Combine(Path.GetTempPath(), $"chess-fake-{Guid.NewGuid():N}.sh");
    try
    {
        await File.WriteAllTextAsync(fakePath, "#!/bin/sh\nexit 0\n");
        File.SetUnixFileMode(fakePath, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        try { await UciEngine.BestMoveAsync(fakePath, ChessSession.InitialFen, 10, CancellationToken.None); throw new Exception("Engine exit ignored"); }
        catch (IOException) { checks++; }
        await File.WriteAllTextAsync(fakePath, "#!/bin/sh\nwhile read line; do case \"$line\" in uci) echo uciok;; isready) echo readyok;; quit) exit 0;; esac; done\n");
        using var cancel = new CancellationTokenSource(TimeSpan.FromMilliseconds(100));
        try { await UciEngine.BestMoveAsync(fakePath, ChessSession.InitialFen, 10, cancel.Token); throw new Exception("Silent engine cancellation ignored"); }
        catch (OperationCanceledException) { checks++; }
    }
    finally { File.Delete(fakePath); }
}
var storeDirectory = Path.Combine(Path.GetTempPath(), $"chess-store-{Guid.NewGuid():N}");
try
{
    var store = new LocalStore(storeDirectory);
    store.Settings.EnginePath = "engine path with spaces";
    store.Settings.Completed.Add("p001"); store.SaveSettings();
    store.SaveGame(exported, "Testpartie");
    var reloaded = new LocalStore(storeDirectory);
    Check(reloaded.Settings.EnginePath == "engine path with spaces" && reloaded.Settings.Completed.Contains("p001"), "settings persist");
    Check(reloaded.Games.Count == 1 && reloaded.Games[0].Pgn == exported, "archive persists");
    Check(!File.Exists(Path.Combine(storeDirectory, "games.json.tmp")), "atomic save temporary consumed");
    var corruptPath = Path.Combine(storeDirectory, "settings.json");
    await File.WriteAllTextAsync(corruptPath, "{corrupt");
    try { _ = new LocalStore(storeDirectory); throw new Exception("Corrupt storage accepted"); }
    catch (InvalidDataException) { Check(await File.ReadAllTextAsync(corruptPath) == "{corrupt", "corrupt data preserved"); }
    foreach (var invalid in new[] { "null", "{\"Completed\":null}", "{\"EnginePath\":null}" })
    {
        await File.WriteAllTextAsync(corruptPath, invalid);
        try { _ = new LocalStore(storeDirectory); throw new Exception("Invalid settings accepted"); }
        catch (InvalidDataException) { Check(await File.ReadAllTextAsync(corruptPath) == invalid, "invalid settings preserved"); }
    }
    File.Delete(corruptPath);
    var gamesPath = Path.Combine(storeDirectory, "games.json");
    foreach (var invalid in new[] { "null", "[null]", "[{}]" })
    {
        await File.WriteAllTextAsync(gamesPath, invalid);
        try { _ = new LocalStore(storeDirectory); throw new Exception("Invalid archive accepted"); }
        catch (InvalidDataException) { Check(await File.ReadAllTextAsync(gamesPath) == invalid, "invalid archive preserved"); }
    }
}
finally { Directory.Delete(storeDirectory, recursive: true); }
var dataDirectory = Path.Combine(AppContext.BaseDirectory, "Data");
using (var puzzles = JsonDocument.Parse(File.ReadAllText(Path.Combine(dataDirectory, "puzzles.json"))))
{
    foreach (var puzzle in puzzles.RootElement.EnumerateArray())
    {
        var session = new ChessSession(); session.LoadFen(puzzle.GetProperty("fen").GetString()!);
        var moves = puzzle.GetProperty("moves").EnumerateArray().Select(m => m.GetString()!).ToArray();
        Check(moves.Length > 0, "puzzle contains solution");
        foreach (var move in moves) Check(session.TryMove(move), $"puzzle {puzzle.GetProperty("id")} move {move}");
    }
}
foreach (var lessonPath in Directory.GetFiles(Path.Combine(dataDirectory, "lessons"), "*.json"))
{
    using var course = JsonDocument.Parse(File.ReadAllText(lessonPath));
    foreach (var chapter in course.RootElement.GetProperty("chapters").EnumerateArray())
    foreach (var lesson in chapter.GetProperty("lessons").EnumerateArray())
    {
        if (!lesson.TryGetProperty("fen", out var fen)) continue;
        var session = new ChessSession(); session.LoadFen(fen.GetString()!);
        Check(session.Positions.Count == 1, "lesson FEN loads");
        if (lesson.TryGetProperty("exercise", out var exercise))
            Check(session.TryMove(exercise.GetProperty("solutionMove").GetString()!), $"lesson {lesson.GetProperty("id")} solution");
    }
}
using (var openings = JsonDocument.Parse(File.ReadAllText(Path.Combine(dataDirectory, "openings.json"))))
{
    var entries = openings.RootElement.EnumerateArray().ToArray();
    // Cover the entire file at fixed intervals, both endpoints and the longest line.
    var samples = entries.Where((_, i) => i % 100 == 0).Append(entries[^1]).Append(entries.MaxBy(e => e.GetProperty("moves").GetArrayLength())).ToArray();
    foreach (var opening in samples)
    {
        var session = new ChessSession();
        foreach (var san in opening.GetProperty("moves").EnumerateArray())
            Check(session.TrySan(san.GetString()!), $"opening {opening.GetProperty("name")} move {san}");
        var importedOpening = new ChessSession(); importedOpening.LoadPgn(session.ExportPgn());
        Check(importedOpening.Fen == session.Fen, "opening PGN roundtrip");
    }
    Console.WriteLine($"Data: all puzzles and lessons; {samples.Length} representative openings of {entries.Length}.");
}
Console.WriteLine($"PASS: {checks} chess, hardware, UCI and persistence checks.");
