import SwiftUI
import ChessAppKit

/// Navigations-Root: Sidebar mit den Hauptbereichen, Detailansicht rechts.
struct RootView: View {
    @LocalState private var selection: SidebarItem? = .home
    @StateObject private var playViewModel = PlayViewModel()
    @LocalState private var puzzleSource: PuzzleSource = .all
    @LocalState private var selectedBotID: String? = nil


    init(selection: SidebarItem = .home) {
        _selection = LocalState(wrappedValue: selection)
    }

    var body: some View {
        // Keep feature layouts scoped to their content instead of installing window-wide split controllers.
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    PieceView(color: .white, type: .knight, side: 26)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(SwiftUI.Color(red: 0.25, green: 0.33, blue: 0.22)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Dein Schachclub").font(.system(size: 16, weight: .bold, design: .serif))
                        Text("Ein Zug weiter.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                List(selection: $selection) {
                    Section { row(.home) }
                    Section("Am Brett") {
                        ForEach([SidebarItem.play, .puzzles, .lessons, .openings, .endgames]) { row($0) }
                    }
                    Section("Auswerten") {
                        ForEach([SidebarItem.analysis, .archive, .stats]) { row($0) }
                    }
                    Section { row(.settings) }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .frame(width: 220)
            .background(AppTheme.sidebar)
            .navigationTitle("ChessApp")
            Divider()
            Group {
                switch selection {
                case .home:
                    HomeView(playViewModel: playViewModel, navigate: { selection = $0 }, openPersonalPuzzles: {
                        puzzleSource = .personal; selection = .puzzles
                    }, chooseBot: { bot in
                        selectedBotID = bot.id; selection = .play
                    })
                case .play: PlayView(viewModel: playViewModel, initialBotID: selectedBotID)
                case .analysis: ReviewView()
                case .puzzles: PuzzleView(initialSource: puzzleSource).id(puzzleSource)
                case .lessons: LessonListView()
                case .openings: OpeningTrainingView()
                case .endgames: EndgameTrainingView()
                case .archive: GameArchiveView()
                case .stats: StatsView()
                case .settings: SettingsView()
                case .none: EmptyView()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(AppTheme.background)
        .tint(AppTheme.accent)
        .onChange(of: selection) { old, new in
            if old == .puzzles && new != .puzzles { puzzleSource = .all }
            if old == .play && new != .play { selectedBotID = nil }
        }
    }

    private func row(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.icon)
            .foregroundStyle(selection == item ? SwiftUI.Color.white : SwiftUI.Color.primary)
            .listRowBackground(selection == item ? AppTheme.accent : SwiftUI.Color.clear)
            .tag(item)
    }

    enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
        case home, play, analysis, puzzles, lessons, openings, endgames, archive, stats, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return "Mein Club"
            case .play: return "Spielen"
            case .analysis: return "Analyse"
            case .puzzles: return "Puzzles"
            case .lessons: return "Lernen"
            case .openings: return "Eröffnungen"
            case .endgames: return "Endspiele"
            case .archive: return "Archiv"
            case .stats: return "Statistik"
            case .settings: return "Einstellungen"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .play: return "checkerboard.rectangle"
            case .analysis: return "chart.xyaxis.line"
            case .puzzles: return "puzzlepiece.extension"
            case .lessons: return "graduationcap"
            case .openings: return "book.closed"
            case .endgames: return "flag.checkered"
            case .archive: return "tray.full"
            case .stats: return "chart.bar.xaxis"
            case .settings: return "gearshape"
            }
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.title2).bold()
            Text(hint).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
