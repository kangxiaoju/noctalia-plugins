# Command Output Bar

Noctalia bar plugin that runs a shell command and displays the command's stdout.

## Files

- `manifest.json`: plugin manifest
- `BarWidget.qml`: bar widget that executes the command
- `Settings.qml`: settings page for command, shell path, refresh interval, text length, marquee, and color mode
- `scripts/default-output.sh`: optional example script if you still want to call a script from your command

## Usage

1. Enable the plugin in Noctalia.
2. Add the widget to the bar if needed.
3. Open plugin settings and set:
   - `Command`: shell command to run
   - `Shell Path`: usually `/bin/sh` or `/bin/bash`
   - `Refresh Interval`: rerun frequency in seconds
   - `Maximum Text Length`: visible text budget
   - `Enable Marquee`: scroll long text
   - `Follow Theme Color`: use Noctalia text color or a custom one
   - `Text Color`: custom bar text color when theme following is disabled
4. Left-click the widget to run the command immediately, or right-click it and open `Settings`.

The widget shows stdout. If the command exits with an error and writes to stderr, stderr is shown instead. Right-click the widget for a quick refresh/settings menu.
