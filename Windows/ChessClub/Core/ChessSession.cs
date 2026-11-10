using Chess;
using System.Text.RegularExpressions;
using System.Text;

namespace ChessClub.Core;

public sealed class ChessSession
{
    public const string InitialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    private ChessBoard board = new() { AutoEndgameRules = AutoEndgameRules.All };
    private readonly List<string> positions = new();
    public ChessSession() => positions.Add(board.ToFen());
    public string Fen => board.ToFen();
    public bool WhiteToMove => board.Turn == PieceColor.White;
    public bool IsGameOver => board.IsEndGame;
    public string Status => IsGameOver ? $"Partie beendet: {board.EndGame}" : $"{(WhiteToMove ? "Weiß" : "Schwarz")} am Zug{(board.WhiteKingChecked || board.BlackKingChecked ? " · Schach" : "")}";
    public IReadOnlyList<string> MoveSans => board.MovesToSan;
    public IReadOnlyList<string> Positions => positions;
    public char? PieceAt(string square) => board[square]?.ToFenChar();
    public IEnumerable<string> LegalTargets(string square) => PieceAt(square) is null || IsGameOver ? Array.Empty<string>() : board.Moves(new Position(square)).Select(m => m.NewPosition.ToString()).Distinct().ToArray();
    public bool TryMove(string uci)
    {
        if (IsGameOver || !Regex.IsMatch(uci, "^[a-h][1-8][a-h][1-8][qrbn]?$")) return false;
        var source = uci[..2];
        if (PieceAt(source) is not char piece || char.IsUpper(piece) != WhiteToMove) return false;
        var move = board.Moves(new Position(source)).FirstOrDefault(m => m.NewPosition.ToString() == uci.Substring(2, 2)
            && (!m.IsPromotion ? uci.Length == 4 : char.ToLowerInvariant(m.Promotion!.ToFenChar()) == (uci.Length == 5 ? uci[4] : 'q')));
        if (move is null || !board.Move(move)) return false;
        positions.Add(Fen);
        return true;
    }
    public bool TrySan(string san)
    {
        if (IsGameOver || string.IsNullOrWhiteSpace(san)) return false;
        var move = board.Moves().FirstOrDefault(m => m.San == san);
        if (move is null || !board.Move(move)) return false;
        positions.Add(Fen);
        return true;
    }
    public void Reset() => LoadFen(InitialFen);
    public void LoadFen(string fen)
    {
        ValidateFen(fen);
        var loaded = ChessBoard.LoadFromFen(fen, AutoEndgameRules.All);
        board = loaded;
        positions.Clear(); positions.Add(Fen);
    }
    public void LoadPgn(string pgn)
    {
        if (string.IsNullOrWhiteSpace(pgn) || pgn.Length > 2_000_000) throw new FormatException("Bitte eine einzelne PGN-Partie laden (höchstens 2 MB).");
        var tokens = PgnMoves(pgn);
        var loaded = ChessBoard.LoadFromPgn(pgn, AutoEndgameRules.All);
        static string PlainSan(string value) => value.TrimEnd('+', '#', '!', '?');
        if (tokens.Count != loaded.MovesToSan.Count || !tokens.Select(PlainSan).SequenceEqual(loaded.MovesToSan.Select(PlainSan)))
            throw new FormatException("PGN enthält unbekannte oder ungültige Züge.");
        var initial = loaded.Headers.TryGetValue("FEN", out var fen) ? fen : InitialFen;
        ValidateFen(initial);
        var replay = ChessBoard.LoadFromFen(initial);
        var history = new List<string> { replay.ToFen() };
        foreach (var move in loaded.MovesToSan)
        {
            if (!replay.Move(move)) throw new FormatException("Ungültiger PGN-Zug.");
            history.Add(replay.ToFen());
        }
        board = loaded;
        positions.Clear(); positions.AddRange(history);
    }
    private static List<string> PgnMoves(string pgn)
    {
        // Validate every mainline token: the library otherwise silently ignores unknown text.
        var text = new StringBuilder();
        var variation = 0;
        var comment = false;
        var lineComment = false;
        var movesStarted = false;
        for (var i = 0; i < pgn.Length; i++)
        {
            var c = pgn[i];
            if (lineComment) { if (c == '\n') { lineComment = false; text.Append(' '); } continue; }
            if (comment) { if (c == '}') { comment = false; text.Append(' '); } continue; }
            if (c == '{') { comment = true; text.Append(' '); continue; }
            if (c == ';') { lineComment = true; continue; }
            if (c == '(') { variation++; text.Append(' '); continue; }
            if (c == ')') { if (--variation < 0) throw new FormatException("Ungültige PGN-Variante."); continue; }
            if (variation > 0) continue;
            if (c == '[')
            {
                if (movesStarted) throw new FormatException("Bitte nur eine PGN-Partie gleichzeitig laden.");
                var tag = Regex.Match(pgn[i..], "^\\[\\w+\\s+\"(?:\\\\.|[^\"\\\\])*\"\\]");
                if (!tag.Success) throw new FormatException("Ungültiger PGN-Header.");
                i += tag.Length - 1;
                continue;
            }
            if (!char.IsWhiteSpace(c)) movesStarted = true;
            text.Append(c);
        }
        if (comment || variation != 0) throw new FormatException("Nicht abgeschlossener PGN-Kommentar oder Variante.");
        var mainline = Regex.Replace(text.ToString(), @"\d+\.(?:\.\.)?", " ");
        var tokens = mainline.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        var moves = new List<string>();
        var resultSeen = false;
        foreach (var token in tokens)
        {
            if (resultSeen) throw new FormatException("Text nach dem Partieergebnis oder mehrere Partien.");
            if (token is "1-0" or "0-1" or "1/2-1/2" or "*") { resultSeen = true; continue; }
            if (Regex.IsMatch(token, @"^\$\d+$")) continue;
            if (!Regex.IsMatch(token, @"^(?:O-O(?:-O)?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?)[+#]?[!?]*$"))
                throw new FormatException($"Unbekannter PGN-Zug: {token}");
            moves.Add(token.TrimEnd('!', '?'));
        }
        return moves;
    }
    public string ExportPgn() => board.ToPgn();
    public static void ValidateFen(string fen)
    {
        if (string.IsNullOrWhiteSpace(fen) || fen.Length > 200 || fen.Contains('\r') || fen.Contains('\n')) throw new FormatException("Ungültige FEN-Stellung.");
        var fields = fen.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (fields.Length != 6 || !Regex.IsMatch(fields[1], "^[wb]$") || !Regex.IsMatch(fields[2], "^(-|K?Q?k?q?)$") || !Regex.IsMatch(fields[3], "^(-|[a-h][36])$") || !int.TryParse(fields[4], out var half) || half < 0 || !int.TryParse(fields[5], out var full) || full < 1) throw new FormatException("Ungültige FEN-Felder.");
        var rows = fields[0].Split('/');
        if (rows.Length != 8 || rows.Any(r => r.Any(c => !"prnbqkPRNBQK12345678".Contains(c)) || r.Sum(c => char.IsDigit(c) ? c - '0' : 1) != 8) || fields[0].Count(c => c == 'K') != 1 || fields[0].Count(c => c == 'k') != 1) throw new FormatException("FEN muss acht Reihen und beide Könige enthalten.");
    }
}
