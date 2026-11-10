using System.Globalization;
using System.Text.Json;
using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using ChessClub.Core;

namespace ChessClub;

public sealed class MainWindow : Window
{
    private static IBrush Accent = Brush.Parse("#4D6E3B"), BackgroundColor = Brush.Parse("#F5F2EB"), Surface = Brush.Parse("#FFFDF5");
    private Border? sidebarBorder;
    private ChessSession playGame = new(), analysisGame = new();
    private JsonElement? activeLesson;
    private readonly LocalStore store;
    private ChessSession game = new();
    private readonly ContentControl page = new();
    private readonly TextBlock notice = new() { TextWrapping = TextWrapping.Wrap, Foreground = Accent, Margin = new Thickness(24, 0, 24, 12) };
    private readonly Dictionary<string, Bitmap> bitmaps = new();
    private CancellationTokenSource? work;
    private string section = "Mein Club";
    private string? selected;
    private string? displayFen;
    private bool flipped, botEnabled = true, humanWhite = true;
    private int skill = 5, puzzleIndex, puzzleStep;
    private string[] puzzleMoves = Array.Empty<string>();
    private string? exerciseMove, exerciseId;
    private bool exerciseDone;
    private readonly List<JsonElement> puzzles;
    private readonly List<JsonElement> openings;
    private TextBlock? evaluation;
    private TextBlock? variation;
    private TextBlock? depthLabel;
    private string latestScore = "";
    private EngineUpdate? latestUpdate;
    private int analysisTab, analysisGeneration;
    private readonly Dictionary<string, Button> navigation = new();

    public MainWindow()
    {
        Title = "Dein Schachclub";
        Width = 1250; Height = 850; MinWidth = 1000; MinHeight = 720;
        Background = BackgroundColor;
        try
        {
            store = new LocalStore();
            puzzles = LoadArray("puzzles.json"); openings = LoadArray("openings.json");
        }
        catch (Exception e)
        {
            store = null!; puzzles = new(); openings = new();
            Content = new TextBlock { Text = e.Message, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(40) };
            return;
        }
        var shell = new Grid { ColumnDefinitions = new ColumnDefinitions("220,*") };
        var sidebar = new StackPanel { Spacing = 6, Margin = new Thickness(14) };
        sidebar.Children.Add(new TextBlock { Text = "♞  Dein Schachclub", FontFamily = new FontFamily("Georgia"), FontSize = 16, FontWeight = FontWeight.Bold, Margin = new Thickness(0, 8) });
        sidebar.Children.Add(Label("Ein Zug weiter.", 12));
        foreach (var name in new[] { "Mein Club", "Spielen", "Puzzles", "Lernen", "Eröffnungen", "Endspiele", "Analyse", "Archiv", "Fortschritt", "Einstellungen" })
        {
            if (name is "Spielen" or "Analyse" or "Einstellungen") sidebar.Children.Add(new Separator { Margin = new Thickness(0, 8) });
            var button = Button(name, () => Navigate(name));
            button.HorizontalAlignment = HorizontalAlignment.Stretch;
            button.HorizontalContentAlignment = HorizontalAlignment.Left;
            navigation[name] = button;
            sidebar.Children.Add(button);
        }
        sidebarBorder = new Border { Child = sidebar }; shell.Children.Add(sidebarBorder);
        var right = new DockPanel();
        DockPanel.SetDock(notice, Dock.Bottom); right.Children.Add(notice); right.Children.Add(page);
        Grid.SetColumn(right, 1); shell.Children.Add(right);
        Content = shell;
        ApplyAppearance();
        Closing += (_, args) =>
        {
            try
            {
                var current = section == "Spielen" ? game : playGame;
                if (current.MoveSans.Count > 0 && !store.Games.Any(g => g.Pgn == current.ExportPgn()))
                    store.SaveGame(current.ExportPgn(), $"Partie · {DateTime.Now:g}");
            }
            catch (Exception e) { args.Cancel = true; notice.Text = "Partie konnte nicht gespeichert werden: " + e.Message; }
        };
        Closed += (_, _) => { CancelWork(); foreach (var bitmap in bitmaps.Values) bitmap.Dispose(); };
        Navigate("Mein Club");
    }

    private static List<JsonElement> LoadArray(string name) => JsonSerializer.Deserialize<List<JsonElement>>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", name))) ?? new();
    private static TextBlock Label(string text, double size = 15) => new() { Text = text, FontSize = size, TextWrapping = TextWrapping.Wrap, VerticalAlignment = VerticalAlignment.Center };
    private static Button Button(string text, Action action)
    {
        var b = new Button { Content = text, Padding = new Thickness(12, 9), CornerRadius = new CornerRadius(8) };
        b.Click += (_, _) => action(); return b;
    }
    private Button AsyncButton(string text, Func<Task> action) => Button(text, () => _ = Guard(action));
    private async Task Guard(Func<Task> action)
    {
        try { await action(); }
        catch (OperationCanceledException) { notice.Text = "Berechnung angehalten."; }
        catch (Exception e) { notice.Text = e.Message; }
    }
    private static StackPanel Stack(params Control[] children)
    {
        var panel = new StackPanel { Spacing = 14 };
        foreach (var child in children) panel.Children.Add(child);
        return panel;
    }
    private static WrapPanel Row(params Control[] children)
    {
        var row = new WrapPanel { Orientation = Orientation.Horizontal };
        foreach (var child in children) { child.Margin = new Thickness(0, 0, 8, 8); row.Children.Add(child); }
        return row;
    }
    private static Border Card(Control child) => new() { Child = child, Background = Surface, CornerRadius = new CornerRadius(12), Padding = new Thickness(18), BorderBrush = Brush.Parse("#CCD2BF"), BorderThickness = new Thickness(1) };
    private static TextBlock TitleText(string title) => new() { Text = title, FontFamily = new FontFamily("Georgia"), FontSize = 30, FontWeight = FontWeight.Bold, Margin = new Thickness(0, 0, 0, 8) };
    private void SetPage(Control content) => page.Content = new ScrollViewer { Content = content, Padding = new Thickness(24), HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
    private void CancelWork() { analysisGeneration++; work?.Cancel(); work = null; }
    private void Navigate(string name)
    {
        CancelWork();
        if (section == "Spielen") playGame = game;
        if (section == "Analyse") analysisGame = game;
        selected = null; displayFen = null; exerciseMove = null; activeLesson = null; exerciseId = null; section = name; notice.Text = "";
        game = name == "Spielen" ? playGame : name == "Analyse" ? analysisGame : new ChessSession();
        foreach (var (key, b) in navigation) { b.Background = key == name ? Accent : Brushes.Transparent; b.Foreground = key == name ? (IsDark ? Brushes.Black : Brushes.White) : (IsDark ? Brushes.WhiteSmoke : Brushes.Black); }
        Render();
    }
    private void Render()
    {
        if (activeLesson is JsonElement lesson) { LessonBoard(lesson); return; }
        switch (section)
        {
            case "Mein Club": Home(); break;
            case "Spielen": Play(); break;
            case "Analyse": Analysis(); break;
            case "Puzzles": Puzzle(); break;
            case "Lernen": Lessons(false); break;
            case "Endspiele": Lessons(true); break;
            case "Eröffnungen": Openings(); break;
            case "Archiv": Archive(); break;
            case "Fortschritt": Progress(); break;
            default: Settings(); break;
        }
    }

    private bool IsDark => store.Settings.Appearance == "Dunkel" || (store.Settings.Appearance == "System" && Application.Current!.PlatformSettings?.GetColorValues().ThemeVariant == Avalonia.Platform.PlatformThemeVariant.Dark);
    private void ApplyAppearance()
    {
        Application.Current!.RequestedThemeVariant = store.Settings.Appearance switch { "Hell" => Avalonia.Styling.ThemeVariant.Light, "Dunkel" => Avalonia.Styling.ThemeVariant.Dark, _ => Avalonia.Styling.ThemeVariant.Default };
        Accent = Brush.Parse(IsDark ? "#A5C967" : "#4D6E3B");
        BackgroundColor = Brush.Parse(IsDark ? "#1F211B" : "#F5F2EB");
        Surface = Brush.Parse(IsDark ? "#2E3027" : "#FFFDF5");
        Background = BackgroundColor;
        Foreground = IsDark ? Brushes.WhiteSmoke : Brush.Parse("#262A22");
        notice.Foreground = Accent;
        if (sidebarBorder != null) sidebarBorder.Background = Brush.Parse(IsDark ? "#24271D" : "#E8E8D9");
    }
    private void LessonBoard(JsonElement lesson)
    {
        BoardPage(lesson.GetProperty("title").GetString()!, Card(Stack(Label(exerciseDone ? "Geschafft!" : lesson.GetProperty("exercise").GetProperty("task").GetString()!, 20),
            Label(lesson.GetProperty("text").GetString()!), Button("Zurück zur Übersicht", () => { activeLesson = null; exerciseMove = null; Lessons(section == "Endspiele"); }))));
    }
    private void Home()
    {
        var hero = new Grid { ColumnDefinitions = new ColumnDefinitions("*,180"), ColumnSpacing = 18 };
        var heading = TitleText("Zeit für eine gute Partie."); heading.Foreground = Brushes.White;
        var intro = Label("Emil ist bereit. Spiel entspannt, probiere etwas aus und finde deinen eigenen Plan."); intro.Foreground = Brushes.WhiteSmoke;
        var start = Button("▶  Ans Brett", () => { skill = 0; Navigate("Spielen"); }); start.Background = Brush.Parse("#B4D570"); start.Foreground = Brushes.Black;
        hero.Children.Add(Stack(heading, intro, start, new TextBlock { Text = "Dein Tempo. Dein Schach.", Foreground = Brushes.WhiteSmoke, Margin = new Thickness(0, 8) }));
        var portrait = Stack(PixelAvatar("emil"), new TextBlock { Text = "Emil", Foreground = Brushes.White, FontWeight = FontWeight.Bold, FontSize = 18, HorizontalAlignment = HorizontalAlignment.Center }, new TextBlock { Text = "Dein Spielpartner", Foreground = Brushes.WhiteSmoke, HorizontalAlignment = HorizontalAlignment.Center });
        Grid.SetColumn(portrait, 1); hero.Children.Add(portrait);
        var eyebrow = Label("DEIN SCHACHCLUB", 13); eyebrow.Foreground = Accent;
        SetPage(Stack(eyebrow, TitleText("Schön, dass du da bist."), Label("Ein guter Zug. Eine neue Idee. Dein nächster Schritt."),
            new Border { Child = hero, Padding = new Thickness(28), CornerRadius = new CornerRadius(22), Margin = new Thickness(0, 12), Background = new LinearGradientBrush { StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative), EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative), GradientStops = { new GradientStop(Color.Parse("#3B5030"), 0), new GradientStop(Color.Parse("#1F3325"), 1) } } },
            Card(Stack(Label("Dein nächster Trainingsschritt", 23), Label($"{store.Games.Count} archivierte Partien · {store.Settings.Completed.Count} gelöste Übungen"),
                Row(Button("Ein Muster nach dem anderen", () => Navigate("Puzzles")), Button("Partie verstehen", () => Navigate("Analyse"))))),
            Row(Card(Stack(Label("Schach verstehen", 20), Label("Grundlagen und Ideen am Brett."), Button("Lernen", () => Navigate("Lernen")))), Card(Stack(Label("Bis zum letzten Zug", 20), Label("Endspiele gezielt ausprobieren."), Button("Endspiele", () => Navigate("Endspiele"))))),
            Label("Offline spielen · lokale Stockfish-Analyse · deine Partien bleiben auf diesem Rechner.", 13)));
    }
    private static Control PixelAvatar(string id)
    {
        uint state = 2166136261;
        foreach (var c in System.Text.Encoding.UTF8.GetBytes(id)) state = unchecked((state ^ c) * 16777619);
        var pixels = new Grid { Width = 126, Height = 126, RowDefinitions = new RowDefinitions("*,*,*,*,*,*,*"), ColumnDefinitions = new ColumnDefinitions("*,*,*,*,*,*,*") };
        for (int row = 0; row < 7; row++) for (int col = 0; col < 4; col++)
        {
            state = unchecked(state * 1664525 + 1013904223);
            if ((state >> 24 & 1) != 1 && !(row == 3 && col == 3)) continue;
            foreach (var column in col == 3 ? new[] { col } : new[] { col, 6 - col })
            {
                var pixel = new Border { Background = Brush.Parse("#82B8C9") }; Grid.SetRow(pixel, row); Grid.SetColumn(pixel, column); pixels.Children.Add(pixel);
            }
        }
        return new Border { Background = Brush.Parse("#293B47"), CornerRadius = new CornerRadius(18), Padding = new Thickness(18), Child = pixels, HorizontalAlignment = HorizontalAlignment.Center };
    }

    private void BoardPage(string title, Control side)
    {
        var layout = new Grid { ColumnDefinitions = new ColumnDefinitions("*,300"), ColumnSpacing = 20 };
        var left = Stack(Label(flipped ? "Weiß" : "Schwarz", 17), Board(), Label(flipped ? "Schwarz" : "Weiß", 17));
        layout.Children.Add(left); Grid.SetColumn(side, 1); layout.Children.Add(side);
        SetPage(Stack(TitleText(title), layout));
    }
    private Control Board()
    {
        var fen = displayFen ?? game.Fen;
        var pieces = new Dictionary<string, char>();
        int rank = 7, file = 0;
        foreach (var c in fen.Split(' ')[0])
        {
            if (c == '/') { rank--; file = 0; }
            else if (char.IsDigit(c)) file += c - '0';
            else { pieces[$"{(char)('a' + file)}{rank + 1}"] = c; file++; }
        }
        var legal = selected == null || displayFen != null ? new HashSet<string>() : game.LegalTargets(selected).ToHashSet();
        var grid = new Grid { RowDefinitions = new RowDefinitions("*,*,*,*,*,*,*,*"), ColumnDefinitions = new ColumnDefinitions("*,*,*,*,*,*,*,*") };
        var (light, dark) = store.Settings.BoardTheme switch
        {
            "Blau" => ("#E6EDFA", "#739CB5"), "Holz" => ("#F0DEBF", "#B58866"), "Walnuss" => ("#E3CCAB", "#7A5440"), "Schiefer" => ("#E0E6E8", "#6B7882"), _ => ("#EBE8D1", "#789469")
        };
        for (int row = 0; row < 8; row++) for (int col = 0; col < 8; col++)
        {
            int f = flipped ? 7 - col : col, r = flipped ? row : 7 - row;
            string square = $"{(char)('a' + f)}{r + 1}";
            var content = new Grid();
            if (pieces.TryGetValue(square, out var piece))
            {
                string filename = $"chessnut-{store.Settings.PieceTheme}-{(char.IsUpper(piece) ? 'w' : 'b')}{char.ToUpperInvariant(piece)}.png";
                if (!bitmaps.TryGetValue(filename, out var bitmap))
                {
                    bitmap = new Bitmap(AssetLoader.Open(new Uri($"avares://DeinSchachclub/Assets/{filename}")));
                    bitmaps[filename] = bitmap;
                }
                content.Children.Add(new Image { Source = bitmap, Margin = new Thickness(3), Stretch = Stretch.Uniform });
            }
            if (col == 0) content.Children.Add(new TextBlock { Text = $"{r + 1}", FontSize = 10, Foreground = Brushes.Black, Margin = new Thickness(3), VerticalAlignment = VerticalAlignment.Top });
            if (row == 7) content.Children.Add(new TextBlock { Text = $"{(char)('a' + f)}", FontSize = 10, Foreground = Brushes.Black, Margin = new Thickness(3), VerticalAlignment = VerticalAlignment.Bottom, HorizontalAlignment = HorizontalAlignment.Right });
            if (legal.Contains(square)) content.Children.Add(new Border { Width = 15, Height = 15, CornerRadius = new CornerRadius(8), Background = Brush.Parse("#88506535"), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, IsHitTestVisible = false });
            var b = new Button { Content = content, Padding = new Thickness(0), HorizontalContentAlignment = HorizontalAlignment.Stretch, VerticalContentAlignment = VerticalAlignment.Stretch,
                HorizontalAlignment = HorizontalAlignment.Stretch, VerticalAlignment = VerticalAlignment.Stretch, CornerRadius = new CornerRadius(0), BorderThickness = new Thickness(selected == square ? 3 : 0), BorderBrush = Accent,
                Background = Brush.Parse((f + r) % 2 == 0 ? dark : light), MinHeight = 0, MinWidth = 0 };
            AutomationProperties.SetName(b, square + (pieces.ContainsKey(square) ? $" {pieces[square]}" : " leer"));
            b.Click += (_, _) => _ = Guard(() => SquareClicked(square)); Grid.SetRow(b, row); Grid.SetColumn(b, col); grid.Children.Add(b);
        }
        return new Viewbox { Child = new Border { Child = grid, Width = 560, Height = 560, CornerRadius = new CornerRadius(5), ClipToBounds = true }, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Stretch, MaxHeight = 560 };
    }

    private async Task SquareClicked(string square)
    {
        if (displayFen != null || work != null || game.IsGameOver || (section == "Spielen" && botEnabled && game.WhiteToMove != humanWhite)) return;
        if (selected == null) { selected = square; Render(); return; }
        string from = selected; selected = null;
        string uci = from + square;
        char? piece = game.PieceAt(from);
        if ((piece is 'P' or 'p') && (square[1] == '1' || square[1] == '8'))
        {
            var promotion = await ChoosePromotion();
            if (promotion == null) { Render(); return; }
            uci += promotion;
        }
        if (section == "Puzzles" && puzzleMoves.Length > 0 && !exerciseDone)
        {
            if (uci != puzzleMoves[puzzleStep]) { notice.Text = "Noch nicht die richtige Idee. Versuche einen anderen Zug."; Render(); return; }
        }
        if (exerciseMove != null && !exerciseDone && uci != exerciseMove) { notice.Text = "Versuche die beschriebene Idee."; Render(); return; }
        if (!game.TryMove(uci)) { selected = square; Render(); return; }
        notice.Text = game.Status;
        if (section == "Puzzles" && !exerciseDone)
        {
            puzzleStep++;
            if (puzzleStep < puzzleMoves.Length) { game.TryMove(puzzleMoves[puzzleStep]); puzzleStep++; }
            if (puzzleStep >= puzzleMoves.Length) CompleteExercise();
        }
        else if (exerciseMove != null && !exerciseDone) CompleteExercise();
        Render();
        if (section == "Spielen" && botEnabled && !game.IsGameOver) await BotMove();
    }
    private void CompleteExercise()
    {
        exerciseDone = true;
        if (exerciseId != null) { store.Settings.Completed.Add(exerciseId); store.SaveSettings(); }
        notice.Text = "Geschafft! Die Idee sitzt. Probiere die nächste Übung.";
    }
    private async Task<string?> ChoosePromotion()
    {
        var dialog = new Window { Title = "Bauernumwandlung", Width = 380, Height = 150, CanResize = false, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        dialog.Content = new StackPanel { Margin = new Thickness(20), Children = { Label("In welche Figur umwandeln?"), Row(Button("Dame", () => dialog.Close("q")), Button("Turm", () => dialog.Close("r")), Button("Läufer", () => dialog.Close("b")), Button("Springer", () => dialog.Close("n"))) } };
        return await dialog.ShowDialog<string?>(this);
    }
    private async Task BotMove()
    {
        if (string.IsNullOrWhiteSpace(store.Settings.EnginePath)) { notice.Text = "Bitte wähle Stockfish unter Einstellungen. Danach kannst du den Botzug starten."; return; }
        var cts = work = new CancellationTokenSource();
        var targetGame = game;
        notice.Text = "Dein Spielpartner denkt …";
        try
        {
            var move = await UciEngine.BestMoveAsync(store.Settings.EnginePath, game.Fen, skill, cts.Token);
            cts.Token.ThrowIfCancellationRequested();
            if (work != cts || game != targetGame) return;
            if (!game.TryMove(move)) throw new InvalidDataException("Die Engine hat keinen legalen Zug geliefert.");
            notice.Text = game.Status;
        }
        finally { if (work == cts) { work = null; Render(); } cts.Dispose(); }
    }
    private void Play()
    {
        var mode = new CheckBox { Content = "Gegen Stockfish", IsChecked = botEnabled };
        mode.IsCheckedChanged += (_, _) => botEnabled = mode.IsChecked == true;
        var strength = new ComboBox { ItemsSource = new[] { "Einsteiger", "Hobby", "Fortgeschritten", "Meister" }, SelectedIndex = skill == 0 ? 0 : skill == 5 ? 1 : skill == 12 ? 2 : 3, HorizontalAlignment = HorizontalAlignment.Stretch };
        strength.SelectionChanged += (_, _) => skill = new[] { 0, 5, 12, 20 }[Math.Max(0, strength.SelectedIndex)];
        var color = new ComboBox { ItemsSource = new[] { "Du spielst Weiß", "Du spielst Schwarz" }, SelectedIndex = humanWhite ? 0 : 1, HorizontalAlignment = HorizontalAlignment.Stretch };
        color.SelectionChanged += (_, _) => { humanWhite = color.SelectedIndex == 0; flipped = !humanWhite; };
        BoardPage("Deine nächste Partie", Card(Stack(Label(game.Status, 20), mode, strength, color,
            AsyncButton("Neue Partie", async () => { await PreserveGame(); CancelWork(); game = new(); playGame = game; flipped = !humanWhite; Render(); if (botEnabled && !humanWhite) await BotMove(); }),
            AsyncButton("Botzug starten", async () => { if (botEnabled && game.WhiteToMove != humanWhite && !game.IsGameOver) await BotMove(); }),
            Button("Brett drehen", () => { flipped = !flipped; Render(); }),
            AsyncButton("Partie archivieren", SaveGame), AsyncButton("PGN exportieren", ExportPgn),
            AsyncButton("Diese Partie analysieren", async () => { await PreserveGame(); analysisGame = new ChessSession(); analysisGame.LoadPgn(game.ExportPgn()); Navigate("Analyse"); }),
            Label("Züge", 18), MoveList(), Label("Ohne Uhr. Die Botstufen sind Trainingsstärken, keine offiziellen Elo-Zahlen.", 12))));
    }
    private Control MoveList()
    {
        var moves = game.MoveSans;
        return new TextBlock { Text = string.Join(" ", moves.Select((s, i) => (i % 2 == 0 ? $"{i / 2 + 1}. " : "") + s)), TextWrapping = TextWrapping.Wrap, MaxHeight = 180 };
    }
    private Task PreserveGame() => game.MoveSans.Count > 0 && (section == "Spielen" || section == "Analyse") ? SaveGame() : Task.CompletedTask;
    private Task SaveGame()
    {
        if (game.MoveSans.Count == 0) { notice.Text = "Noch keine Züge zum Archivieren."; return Task.CompletedTask; }
        if (!store.Games.Any(g => g.Pgn == game.ExportPgn())) store.SaveGame(game.ExportPgn(), $"Partie · {DateTime.Now:g}"); notice.Text = "Partie im Archiv gespeichert."; return Task.CompletedTask;
    }
    private void Analysis()
    {
        var profile = HardwareProfile.Detect();
        evaluation = Label(latestScore.Length > 0 ? latestScore : "Noch keine Bewertung", 25);
        variation = Label(latestUpdate == null ? "Hauptvariante erscheint während der Berechnung." : "Hauptvariante: " + latestUpdate.PV);
        depthLabel = Label(latestUpdate == null ? "Bereit." : $"Tiefe {latestUpdate.Depth} · {latestUpdate.Nps:N0} Knoten/s", 13);
        var tabs = new TabControl { SelectedIndex = analysisTab };
        tabs.SelectionChanged += (_, _) => analysisTab = tabs.SelectedIndex;
        Control AnalysisPanel(bool deep) => Stack(Label(deep ? "Mehr Rechenzeit für deine Stellung" : "Schneller Überblick", 19),
            Label(deep ? $"Automatisch erkannt: {profile.LogicalProcessors} logische Prozessoren · {profile.MemoryMB / 1024.0:F1} GB nutzbarer RAM\nStockfish: {profile.Threads} Threads · {profile.HashMB} MB Hash · Zieltiefe {profile.Depth}" : "Normale Analyse bis Tiefe 16 mit reduziertem Ressourcenbedarf.", 13),
            AsyncButton(deep ? "Tiefanalyse starten" : "Analyse starten", () => Analyze(deep)), Button("Anhalten", CancelWork));
        tabs.ItemsSource = new[] { new TabItem { Header = "Analyse", Content = AnalysisPanel(false) }, new TabItem { Header = "Tiefanalyse", Content = AnalysisPanel(true) } };
        var fenInput = new TextBox { Text = displayFen ?? game.Fen, Watermark = "FEN-Stellung", AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 70 };
        var index = new Slider { Minimum = 0, Maximum = Math.Max(1, game.Positions.Count - 1), Value = displayFen == null ? game.Positions.Count - 1 : Math.Max(0, game.Positions.ToList().IndexOf(displayFen)), TickFrequency = 1, IsSnapToTickEnabled = true };
        index.ValueChanged += (_, _) => { CancelWork(); latestScore = ""; latestUpdate = null; displayFen = game.Positions[Math.Clamp((int)index.Value, 0, game.Positions.Count - 1)]; selected = null; Render(); };
        BoardPage("Eine Stellung verstehen", Card(Stack(tabs, evaluation, depthLabel, variation, Label("Partieverlauf", 16), index,
            Row(Button("Aktuelle Stellung", () => { CancelWork(); displayFen = null; Render(); }), Button("Brett drehen", () => { flipped = !flipped; Render(); })),
            fenInput, AsyncButton("FEN laden", () => { CancelWork(); game.LoadFen(fenInput.Text ?? ""); displayFen = null; latestScore = ""; latestUpdate = null; Render(); return Task.CompletedTask; }),
            AsyncButton("PGN importieren", ImportPgn), AsyncButton("PGN exportieren", ExportPgn), MoveList())));
    }
    private async Task Analyze(bool deep)
    {
        CancelWork();
        if (string.IsNullOrWhiteSpace(store.Settings.EnginePath)) throw new InvalidOperationException("Wähle zuerst die Stockfish-Datei unter Einstellungen.");
        var cts = work = new CancellationTokenSource();
        string fen = displayFen ?? game.Fen;
        int generation = analysisGeneration;
        var token = cts.Token;
        depthLabel!.Text = "Stockfish startet …";
        try
        {
            await UciEngine.AnalyzeAsync(store.Settings.EnginePath, fen, HardwareProfile.Detect(), deep, update =>
                Dispatcher.UIThread.Post(() =>
                {
                    if (generation != analysisGeneration || token.IsCancellationRequested) return;
                    latestUpdate = update; latestScore = update.Score;
                    evaluation!.Text = update.Score + " · aus Sicht von Weiß";
                    depthLabel!.Text = $"Tiefe {update.Depth} · {update.Nps:N0} Knoten/s";
                    variation!.Text = "Hauptvariante: " + update.PV;
                }), cts.Token);
            if (work == cts) notice.Text = "Analyse abgeschlossen.";
        }
        finally { if (work == cts) work = null; cts.Dispose(); }
    }
    private async Task<bool> ImportPgn()
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions { Title = "Partie importieren", AllowMultiple = false, FileTypeFilter = new[] { new FilePickerFileType("Schachpartie") { Patterns = new[] { "*.pgn" } } } });
        if (files.Count == 0) return false;
        using var stream = await files[0].OpenReadAsync();
        if (stream.CanSeek && stream.Length > 5_000_000) throw new InvalidDataException("Bitte importiere eine einzelne Partie unter 5 MB.");
        using var reader = new StreamReader(stream);
        string pgn = await reader.ReadToEndAsync();
        var loaded = new ChessSession(); loaded.LoadPgn(pgn);
        CancelWork(); await PreserveGame(); game = loaded; if (section == "Analyse") analysisGame = loaded; displayFen = null; selected = null; latestScore = ""; latestUpdate = null; Render(); notice.Text = "Partie importiert. Mit dem Regler kannst du die Stellungen durchgehen."; return true;
    }
    private async Task ExportPgn()
    {
        var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions { Title = "PGN exportieren", SuggestedFileName = "Schachpartie.pgn", DefaultExtension = "pgn", FileTypeChoices = new[] { new FilePickerFileType("PGN") { Patterns = new[] { "*.pgn" } } } });
        if (file == null) return;
        await using var stream = await file.OpenWriteAsync();
        stream.SetLength(0);
        await using var writer = new StreamWriter(stream); await writer.WriteAsync(game.ExportPgn());
        notice.Text = "PGN exportiert.";
    }
    private void Archive()
    {
        var list = Stack(TitleText("Dein Archiv"), Label("Gespeicherte Partien öffnen, analysieren und als PGN mitnehmen."), AsyncButton("PGN importieren", async () => { if (await ImportPgn()) { analysisGame = game; Navigate("Analyse"); } }));
        foreach (var archived in store.Games)
        {
            list.Children.Add(Card(Row(Label($"{archived.Title}\n{archived.Date:g}"), AsyncButton("Analysieren", async () =>
            {
                var loaded = new ChessSession(); loaded.LoadPgn(archived.Pgn); CancelWork(); await PreserveGame(); game = loaded; analysisGame = loaded; latestScore = ""; latestUpdate = null; Navigate("Analyse");
            }))));
        }
        if (store.Games.Count == 0) list.Children.Add(Card(Label("Noch keine Partie gespeichert. Spiele eine Partie oder importiere eine PGN-Datei.")));
        SetPage(list);
    }
    private void Puzzle()
    {
        if (puzzles.Count == 0) { SetPage(Label("Keine Aufgaben vorhanden.")); return; }
        var puzzle = puzzles[puzzleIndex % puzzles.Count];
        if (exerciseId != puzzle.GetProperty("id").GetString()) LoadPuzzle();
        BoardPage("Ein Muster nach dem anderen", Card(Stack(Label($"Aufgabe {puzzleIndex + 1} von {puzzles.Count}", 22),
            Label($"Niveau {puzzle.GetProperty("rating").GetInt32()} · {string.Join(", ", puzzle.GetProperty("themes").EnumerateArray().Select(x => x.GetString()))}"),
            Label(exerciseDone ? "Gelöst!" : $"Finde den besten Zug für {(game.WhiteToMove ? "Weiß" : "Schwarz")}."),
            Button("Hinweis", () => { if (puzzleStep < puzzleMoves.Length) notice.Text = "Die richtige Figur steht auf " + puzzleMoves[puzzleStep][..2] + "."; }),
            Button("Lösung zeigen", () => { notice.Text = string.Join(" → ", puzzleMoves.Skip(puzzleStep)); }),
            Row(Button("Zurück", () => { puzzleIndex = (puzzleIndex + puzzles.Count - 1) % puzzles.Count; exerciseId = null; LoadPuzzle(); Render(); }),
                Button("Nächste Aufgabe", () => { puzzleIndex = (puzzleIndex + 1) % puzzles.Count; exerciseId = null; LoadPuzzle(); Render(); })),
            Label("Die erste Fortsetzung der Ausgangsstellung wird automatisch gespielt. Danach bist du dran.", 12))));
    }
    private void LoadPuzzle()
    {
        CancelWork(); var p = puzzles[puzzleIndex % puzzles.Count];
        game.LoadFen(p.GetProperty("fen").GetString()!);
        puzzleMoves = p.GetProperty("moves").EnumerateArray().Select(x => x.GetString()!).ToArray();
        puzzleStep = 0; exerciseDone = false; exerciseId = p.GetProperty("id").GetString(); selected = null;
        if (puzzleMoves.Length > 1) { game.TryMove(puzzleMoves[0]); puzzleStep = 1; }
        flipped = !game.WhiteToMove;
    }
    private void Lessons(bool endgames)
    {
        var list = Stack(TitleText(endgames ? "Endspiele zum Ausprobieren" : "Schach verstehen"));
        foreach (var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "Data", "lessons"), "*.json").OrderBy(x => x))
        {
            if (endgames != (Path.GetFileName(file) == "endgame.json")) continue;
            using var doc = JsonDocument.Parse(File.ReadAllText(file));
            var lesson = doc.RootElement;
            list.Children.Add(Label(lesson.GetProperty("title").GetString()!, 23));
            foreach (var chapter in lesson.GetProperty("chapters").EnumerateArray()) foreach (var entry in chapter.GetProperty("lessons").EnumerateArray())
            {
                var e = entry.Clone();
                var body = Stack(Label((store.Settings.Completed.Contains(e.GetProperty("id").GetString()!) ? "✓ " : "") + e.GetProperty("title").GetString(), 18), Label(e.GetProperty("text").GetString()!));
                if (e.TryGetProperty("fen", out _) && e.TryGetProperty("exercise", out _)) body.Children.Add(Button("Am Brett üben", () =>
                {
                    CancelWork(); game.LoadFen(e.GetProperty("fen").GetString()!); exerciseId = e.GetProperty("id").GetString(); exerciseMove = e.GetProperty("exercise").GetProperty("solutionMove").GetString(); exerciseDone = false; flipped = !game.WhiteToMove; selected = null;
                    activeLesson = e; LessonBoard(e);
                }));
                list.Children.Add(Card(body));
            }
        }
        SetPage(list);
    }
    private void Openings()
    {
        var search = new TextBox { Watermark = "Name oder ECO suchen" };
        var results = Stack();
        void Filter()
        {
            results.Children.Clear();
            var query = search.Text ?? "";
            foreach (var opening in openings.Where(o => (o.GetProperty("name").GetString() + " " + o.GetProperty("eco").GetString()).Contains(query, StringComparison.OrdinalIgnoreCase)).Take(80))
            {
                var o = opening;
                results.Children.Add(Card(Stack(Label($"{o.GetProperty("eco").GetString()} · {o.GetProperty("name").GetString()}", 18),
                    Label(string.Join(" ", o.GetProperty("moves").EnumerateArray().Select(x => x.GetString()))),
                    Button("Auf dem Brett ansehen", () =>
                    {
                        var loaded = new ChessSession();
                        foreach (var move in o.GetProperty("moves").EnumerateArray()) if (!loaded.TrySan(move.GetString()!)) throw new InvalidDataException("Ungültiger Zug im Eröffnungsbuch.");
                        CancelWork(); game = loaded; analysisGame = loaded; latestScore = ""; latestUpdate = null; Navigate("Analyse");
                    }))));
            }
        }
        search.TextChanged += (_, _) => Filter(); Filter();
        SetPage(Stack(TitleText("Dein Eröffnungsbuch"), Label($"{openings.Count:N0} Varianten. Wähle eine Eröffnung und gehe ihre Züge in der Analyse durch. Es werden höchstens 80 Treffer angezeigt."), search, results));
    }
    private void Progress()
    {
        SetPage(Stack(TitleText("Dein Fortschritt"), Card(Stack(Label($"{store.Settings.Completed.Count} Übungen gelöst", 25), Label($"{store.Games.Count} Partien im Archiv", 22))),
            Label("Gelöste Aufgaben und Lektionen werden auf diesem Rechner gespeichert. Die erweiterten Trainingsstatistiken der Mac-App sind in dieser Windows-Version noch nicht enthalten."), Label("Datenordner: " + store.DirectoryPath, 12)));
    }
    private void Settings()
    {
        var path = new TextBox { Text = store.Settings.EnginePath, Watermark = "Pfad zu stockfish.exe" };
        var board = new ComboBox { ItemsSource = new[] { "Grün", "Blau", "Holz", "Walnuss", "Schiefer" }, SelectedItem = store.Settings.BoardTheme };
        board.SelectionChanged += (_, _) => { if (board.SelectedItem is string theme) { store.Settings.BoardTheme = theme; store.SaveSettings(); } };
        var piece = new ComboBox { ItemsSource = new[] { "classic", "walnut", "ocean" }, SelectedItem = store.Settings.PieceTheme };
        piece.SelectionChanged += (_, _) => { if (piece.SelectedItem is string theme) { store.Settings.PieceTheme = theme; store.SaveSettings(); } };
        var appearance = new ComboBox { ItemsSource = new[] { "System", "Hell", "Dunkel" }, SelectedItem = store.Settings.Appearance };
        appearance.SelectionChanged += (_, _) => { if (appearance.SelectedItem is string value) { store.Settings.Appearance = value; store.SaveSettings(); ApplyAppearance(); Navigate("Einstellungen"); } };
        SetPage(Stack(TitleText("Dein Schachclub, dein Stil"), Card(Stack(Label("Lokale Stockfish-Engine", 22),
            Label("Lade Stockfish von stockfishchess.org herunter und entpacke das ZIP. Für deinen Ryzen 7 5700X eignet sich die Windows-x64-AVX2-Version. Wähle die ausführbare Datei, nicht das ZIP. Stockfish wird separat installiert."), path,
            Row(AsyncButton("Engine-Datei auswählen", async () =>
            {
                var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions { Title = "Stockfish auswählen", AllowMultiple = false });
                if (files.Count == 0) return;
                path.Text = files[0].TryGetLocalPath() ?? throw new InvalidOperationException("Bitte wähle eine lokale Datei.");
            }), AsyncButton("Engine-Pfad speichern", () =>
            {
                var filename = (path.Text ?? "").Trim().Trim('"');
                if (!File.Exists(filename)) throw new FileNotFoundException("Die Engine-Datei wurde nicht gefunden.");
                CancelWork(); store.Settings.EnginePath = filename; store.SaveSettings(); notice.Text = "Engine-Pfad gespeichert."; return Task.CompletedTask;
            })))),
            Card(Stack(Label("Brett und Figuren", 22), Label("Darstellung"), appearance, Label("Brettfarben"), board, Label("Figurensatz (Originalgrafiken der Mac-App)"), piece)),
            Card(Stack(Label("Speicherung", 22), Label("Partien und Fortschritt bleiben lokal. Für den Austausch zwischen Mac und Windows nutze PGN-Export und -Import. Es gibt keine automatische Synchronisierung."), Label(store.DirectoryPath, 12))),
            Label("Tiefanalyse reserviert Prozessor- und RAM-Kapazität für das System. Hohe Zieltiefen können je nach Stellung lange dauern; du kannst jederzeit anhalten.", 13)));
    }
}
