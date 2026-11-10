# Windows desktop and deep analysis

User approved C# with Avalonia for a Windows desktop companion to the existing Swift macOS application and requested implementation, agents, Git publication, and startup instructions.

Keep the Swift app. Add the Windows app under `Windows/`, using the existing palette, chess piece artwork and local training resources. Both apps use a separately installed Stockfish UCI process, local storage, and a dedicated deep analysis view with CPU/RAM detection, resource reservations, deeper search, live output and cancellation. Normal play and ordinary review retain their defaults.

Avalonia was selected over Electron to provide a C# desktop implementation without a bundled browser. Native SwiftUI cannot supply the Windows UI. Pixel identity is a visual target; any functionality or platform testing limitations must be documented explicitly.

Hardware profiles use available processors and memory rather than a hardcoded Ryzen model. More threads do not guarantee a particular search depth; show actual progress and allow stopping. Validate engine failures and paths, avoid overwriting saved games, and keep engines independently installed.
