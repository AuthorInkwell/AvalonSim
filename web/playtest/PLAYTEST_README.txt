AVALON: PARADISE ENGINE — WEB PLAYTEST

Godot is not required to play this build.

Windows
1. Extract the entire ZIP.
2. Double-click PLAY_AVALON.bat.
3. If Windows asks which application may use the network, allow local/private
   access. Your browser should open automatically.

macOS or Linux
1. Extract the entire ZIP.
2. Double-click PLAY_AVALON.command, or run it from a terminal.
3. Your browser should open automatically.

The launchers require Python 3, which is commonly preinstalled on macOS and
Linux. On Windows, install Python 3 from python.org if neither "py" nor
"python" is available.

Manual/static hosting
Serve this whole directory over HTTP or HTTPS and open index.html. Do not open
index.html directly as a file: browsers do not permit WebAssembly service
workers from file:// URLs.

The first visit on a generic static host may reload once while the isolation
service worker activates. This is expected for Godot 4.2 Web builds.

Save data is stored by the browser for this site's origin. Clearing site data
or changing the server address/port may make an existing save unavailable.
