# Stockfish separat installieren

Dieses Repository und das mit `make-app.sh` erstellte App-Bundle enthalten keine Stockfish-Engine.

Installiere die Engine selbst mit Homebrew:

    brew install stockfish

Oder lade die passende macOS-Version von https://stockfishchess.org/download/ herunter
und wähle die ausführbare Datei in den Einstellungen der App aus. Die App startet
Stockfish als separaten lokalen Prozess und kommuniziert über UCI. Standardpfade:
`/opt/homebrew/bin/stockfish` und `/usr/local/bin/stockfish`.

Stockfish ist freie Software unter GPLv3. Weitergabe ist grundsätzlich erlaubt;
beim Mitliefern müssen die Lizenz und der zur konkreten Engine-Datei passende
Quellcode beziehungsweise dessen Bezugsstelle verfügbar sein. Eigene Änderungen
an Stockfish fallen ebenfalls unter GPLv3. Ein privates Repository hebt diese
Pflichten nicht auf. Hier wird die Engine deshalb nicht mitverteilt.

Offizielle Hinweise: https://official-stockfish.github.io/docs/stockfish-wiki/Developers.html#terms-of-use
Quellcode und Lizenz: https://github.com/official-stockfish/Stockfish
