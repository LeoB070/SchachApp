using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Themes.Fluent;

namespace ChessClub;

internal static class Program
{
    [STAThread]
    public static void Main(string[] args) => AppBuilder.Configure<ClubApp>()
        .UsePlatformDetect().WithInterFont().LogToTrace().StartWithClassicDesktopLifetime(args);
}

public sealed class ClubApp : Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
        RequestedThemeVariant = Avalonia.Styling.ThemeVariant.Light;
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            desktop.MainWindow = new MainWindow();
        base.OnFrameworkInitializationCompleted();
    }
}
