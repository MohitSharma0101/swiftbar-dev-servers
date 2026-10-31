# Changelog

## 1.1.0 - 2026-10-31

- Settings has a Backup section. Export downloads your settings as a JSON file, and Import reads one back, asking whether to replace everything or only add the repos from the file. An import fills in the form without saving, so you can look it over first.
- Choosing Settings when the window is already open now brings it to the front, instead of opening a second one in a new browser instance. The first time, macOS asks whether Dev Servers may control your browser.
- The settings window opens a little faster. It no longer runs the plugin to read the version or `lsof` to check the helper, which now records the folder it serves in `settings.info`.
- New `make settings`, which runs the settings window against a throwaway config in any browser, so the window can be worked on without SwiftBar.

## 1.0.1 - 2026-10-31

- New `enable` command. After a Homebrew install, `~/.swiftbar/dev-servers.sh enable` points SwiftBar at the plugin folder and starts it, so the icon appears without picking a folder by hand. Homebrew itself can't do this.

## 1.0.0 - 2026-10-30

- One-line install from the latest GitHub release. The installer checks the plugin against the release checksums and only installs a SwiftBar it downloaded if it's signed by SwiftBar's developer. Releases are built by GitHub Actions with build provenance.
- Homebrew install: `brew install --cask mohitsharma0101/tap/dev-servers`, which brings SwiftBar along. Each release updates the cask.
- Notifications come from SwiftBar (its icon instead of Script Editor's), titled "Dev Servers", with more detail: branch, port, URL, how long a server took to start or ran. Clicking "is up" opens the server.
- Folders with spaces in their path now work in every menu action, including a SwiftBar plugin folder with a space in it.
- A server that crashes, or a start that isn't listening after 4 minutes, now stays in the menu as a failed row instead of disappearing.
- Mode names containing / no longer break the start.
- A failed start stays in the menu with its error, the end of its log, Retry and Dismiss.
- Worked around a SwiftBar 2.1.1 bug that left server rows and Start menus greyed out and unexpandable after the menu refreshed.
- Turn off at the bottom of the menu pauses Dev Servers: the icon stays, greyed, with Turn on to resume. Running servers keep running.
- Quit SwiftBar at the bottom of the menu closes SwiftBar. Running servers keep running.
- Starting a server no longer opens its page in the browser. You get an "is up" notification instead, and Open in the menu opens the page.
- Every failed start now sends a notification with the error from its log, including repos without a port range and projects from "Start other project".
- Fixed the "starting…" row vanishing for projects started without a known port.
- A server started from the menu shows up right away as "starting…" with a grey ring, instead of appearing only once its port opens. Stop works while it starts.

## 1.0.0

First release.

- Lists dev servers running inside watched folders, grouped by repo and git worktree, with port, branch, uptime, memory, CPU and a health dot.
- Open, Stop and Restart from the menu.
- Starts a worktree in any configured mode on the first free port in the repo's range, copying missing files from the main checkout.
- URL templates per mode, with a separate URL for the repo's default port.
- Notifications when a server started from the menu crashes or fails to start.
- Warnings for ports held by other apps and full port ranges.
- Optional auto-stop for servers with no browser connected.
- Settings window, installer and uninstaller.
