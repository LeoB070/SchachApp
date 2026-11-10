using System.Diagnostics;
using System.Globalization;

namespace ChessClub.Core;

public sealed record EngineUpdate(int Depth, string Score, string PV, long Nps);

public static class UciEngine
{
    public static async Task AnalyzeAsync(string path, string fen, HardwareProfile profile, bool deep, Action<EngineUpdate> report, CancellationToken ct)
    {
        await SearchAsync(path, fen, deep ? profile.Threads : Math.Min(4, profile.Threads), deep ? profile.HashMB : Math.Min(256, profile.HashMB), 20,
            $"go depth {(deep ? profile.Depth : 16)}", line =>
            {
                var info = ParseInfo(line, fen.Split(' ')[1] == "w");
                if (info is not null) report(info);
            }, ct, deep ? TimeSpan.FromMinutes(30) : TimeSpan.FromMinutes(2));
    }
    public static Task<string> BestMoveAsync(string path, string fen, int skill, CancellationToken ct) =>
        SearchAsync(path, fen, Math.Min(4, Math.Max(1, Environment.ProcessorCount - 2)), 128, Math.Clamp(skill, 0, 20), "go movetime 1000", _ => { }, ct, TimeSpan.FromSeconds(20));

    public static EngineUpdate? ParseInfo(string line, bool whiteToMove)
    {
        if (!line.StartsWith("info ", StringComparison.Ordinal)) return null;
        var words = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        int At(string key) => Array.IndexOf(words, key);
        int Number(string key) => At(key) is var i && i >= 0 && i + 1 < words.Length && int.TryParse(words[i + 1], out var n) ? n : 0;
        var depth = Number("depth");
        var scoreIndex = At("score");
        if (depth <= 0 || scoreIndex < 0 || scoreIndex + 2 >= words.Length || !int.TryParse(words[scoreIndex + 2], out var score)) return null;
        if (!whiteToMove) score = -score;
        var scoreText = words[scoreIndex + 1] == "mate" ? $"Matt {(score >= 0 ? "+" : "")}{score}" : (score / 100d).ToString("+0.00;-0.00;0.00", CultureInfo.InvariantCulture);
        var pv = At("pv");
        return new(depth, scoreText, pv >= 0 ? string.Join(" ", words.Skip(pv + 1)) : "", Number("nps"));
    }

    private static async Task<string> SearchAsync(string path, string fen, int threads, int hash, int skill, string go, Action<string> report, CancellationToken ct, TimeSpan timeout)
    {
        ChessSession.ValidateFen(fen);
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) throw new FileNotFoundException("Stockfish nicht gefunden. Bitte die ausführbare Engine-Datei in Einstellungen wählen.", path);
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
        deadline.CancelAfter(timeout);
        using var process = new Process { StartInfo = new ProcessStartInfo(path) { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true } };
        try
        {
            if (!process.Start()) throw new IOException("Stockfish konnte nicht gestartet werden.");
            // Drain stderr immediately so a noisy engine cannot block on a full pipe.
            process.ErrorDataReceived += (_, _) => { };
            process.BeginErrorReadLine();
            async Task Send(string command) { await process.StandardInput.WriteLineAsync(command); await process.StandardInput.FlushAsync(); }
            async Task<string> Read() => await process.StandardOutput.ReadLineAsync(deadline.Token) ?? throw new IOException("Stockfish wurde unerwartet beendet.");
            async Task WaitFor(string marker)
            {
                using var handshake = CancellationTokenSource.CreateLinkedTokenSource(deadline.Token);
                handshake.CancelAfter(TimeSpan.FromSeconds(10));
                while (true)
                {
                    var line = await process.StandardOutput.ReadLineAsync(handshake.Token) ?? throw new IOException("Engine antwortet nicht.");
                    if (line == marker) return;
                }
            }
            await Send("uci"); await WaitFor("uciok");
            await Send($"setoption name Threads value {threads}");
            await Send($"setoption name Hash value {hash}");
            await Send($"setoption name Skill Level value {skill}");
            await Send("setoption name UCI_LimitStrength value false");
            await Send("setoption name MultiPV value 1");
            await Send("isready"); await WaitFor("readyok");
            await Send("ucinewgame");
            await Send($"position fen {fen}"); await Send(go);
            while (true)
            {
                var line = await Read();
                if (line.StartsWith("bestmove ", StringComparison.Ordinal)) return line.Split(' ', StringSplitOptions.RemoveEmptyEntries)[1];
                report(line);
            }
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new TimeoutException("Die Engine hat das Zeitlimit erreicht. Die zuletzt angezeigte Bewertung bleibt erhalten.");
        }
        finally
        {
            try
            {
                if (!process.HasExited)
                {
                    await process.StandardInput.WriteLineAsync("stop");
                    await process.StandardInput.WriteLineAsync("quit");
                    await process.StandardInput.FlushAsync();
                    using var shutdown = new CancellationTokenSource(TimeSpan.FromSeconds(1));
                    try { await process.WaitForExitAsync(shutdown.Token); }
                    catch (OperationCanceledException) { process.Kill(entireProcessTree: true); await process.WaitForExitAsync(); }
                }
            }
            catch (InvalidOperationException) { }
            catch (IOException) { try { if (!process.HasExited) process.Kill(true); } catch (InvalidOperationException) { } }
        }
    }
}
