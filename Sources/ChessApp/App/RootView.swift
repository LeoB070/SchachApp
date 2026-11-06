import SwiftUI

/// Navigations-Root: Sidebar mit den Hauptbereichen, Detailansicht rechts.
struct RootView: View {
    @LocalState private var selection: SidebarItem? = .play
    @StateObject private var playViewModel = PlayViewModel()

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("ChessApp")
        } detail: {
            Group {
                switch selection {
                case .play: PlayView(viewModel: playViewModel)
                case .analysis: ReviewView()
                case .puzzles: PuzzleView()
                case .lessons: LessonListView()
                case .archive: GameArchiveView()
                case .stats: StatsView()
                case .settings: SettingsView()
                case .none: EmptyView()
                }
            }
        }
    }

    enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
        case play, analysis, puzzles, lessons, archive, stats, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .play: return "Spielen"
            case .analysis: return "Analyse"
            case .puzzles: return "Puzzles"
            case .lessons: return "Lernen"
            case .archive: return "Archiv"
            case .stats: return "Statistik"
            case .settings: return "Einstellungen"
            }
        }

        var icon: String {
            switch self {
            case .play: return "play.circle"
            case .analysis: return "waveform.path.ecg"
            case .puzzles: return "puzzlepiece"
            case .lessons: return "book"
            case .archive: return "archivebox"
            case .stats: return "chart.bar"
            case .settings: return "gear"
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
