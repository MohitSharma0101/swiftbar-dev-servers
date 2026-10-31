# CLAUDE.md

Guidance for AI coding agents working on Dev Servers. Read this file fully before changing anything.
For how this project got here (decisions, rejected ideas, what the owner asked for), also read
`../HANDOFF.md` if it exists next to this repo.

## What this is

Dev Servers is a SwiftBar plugin for macOS. It lists every local dev server (anything listening on a
TCP port whose working directory is inside a watched folder), grouped by repo and git worktree, and
lets the user start, open, restart and stop them from the menu bar. It ships as one bash file.

- Owner's GitHub account: `MohitSharma0101`. Planned repo: `MohitSharma0101/swiftbar-dev-servers`.
  Planned Homebrew tap repo: `MohitSharma0101/homebrew-tap`.
- Version: `VERSION` file (currently `1.0.0`, not released yet).
- Menu bar icon: SF Symbol `server.rack`. The owner chose to keep it; don't change it.
- Name: "Dev Servers" is a working name the owner parked. Don't rename without asking.

## Layout

| Path | What it is |
|---|---|
| `src/dev-servers.sh` | The plugin (about 1,230 lines of bash). Streamable SwiftBar plugin plus every menu action as a subcommand. |
| `src/settings/server.py` | Settings window backend: Python stdlib HTTP server on `127.0.0.1`, random port, per-session token. |
| `src/settings/index.html` | Settings window UI. Always dark mode (owner's request). |
| `scripts/build.sh` | Builds `dist/dev-servers.sh`: stamps the version and embeds the settings files as heredocs between `# >>> settings-assets` and `# <<< settings-assets`. |
| `scripts/settings-dev.sh` | Runs the settings backend against a throwaway config and prints its URL, so the window can be opened in any browser on any machine. `make settings`. |
| `scripts/cask.sh` | Prints the Homebrew cask for a version and SHA-256. Used by the release workflow. |
| `install.sh` | Installer. Works from a checkout (builds from source) or piped from the release (`curl ... | bash`, downloads the plugin). Installs SwiftBar if missing. |
| `tests/smoke.sh` | End-to-end smoke test, 47 checks, in a throwaway config/cache/project. Ports 48201 to 48290. |
| `.github/workflows/release.yml` | On a `v*` tag: lint, test, build, SHA256SUMS, build provenance attestation, GitHub release, then update the Homebrew tap. |
| `docs/settings.png` | Screenshot used in the README (sample `acme/storefront` data). |
| `dist/` | Build output, git-ignored. |

## Commands

```bash
make lint      # shellcheck --severity=warning on all shell files, ruff check + ruff format --check on src/settings
make test      # tests/smoke.sh
make check     # both
make build     # dist/dev-servers.sh
make settings  # settings window against a throwaway config, no SwiftBar needed
./install.sh --no-launch          # build and install into SwiftBar's plugin folder without refreshing
./install.sh --plugin-dir DIR     # install somewhere else (use a temp dir for tests)
./install.sh --uninstall [--purge]
```

Tools needed: `shellcheck`, `ruff`, `jq`, `python3`, `lsof`, `curl` (all via Homebrew or macOS).
Always run `make check` before saying a change is done.

## Runtime files (on the user's Mac)

| Path | Contents |
|---|---|
| `~/.config/dev-servers/config.json` | Settings (`version`, `roots`, `idleStopHours`, `editor`, `repos` keyed by `owner/repo` from the git origin remote, each with `name`, `path`, `ports` like `4200-4209`, `defaultPort`, `copyIfMissing`, and `modes[]` with `name`, `start`, `url`, `defaultPortUrl`, `detect`). |
| `~/Library/Caches/dev-servers/state/` | Runtime state, see below. |
| `~/Library/Logs/dev-servers/` | Logs of servers started from the menu. |
| `~/Library/Application Support/dev-servers/settings-<md5 of plugin>/` | Settings window files written out by the built plugin. |

Every path can be overridden for tests: `DEV_SERVERS_CONFIG`, `DEV_SERVERS_CACHE`, `DEV_SERVERS_LOGS`,
`DEV_SERVERS_SUPPORT`. Other env vars: `DEV_SERVERS_PENDING_TIMEOUT` (seconds, default 240),
`DEV_SERVERS_QUIET=1` (notifications go to `$CACHE_DIR/notifications.log` instead of macOS; tests
use it), `DEV_SERVERS_RELEASE_URL` (installer only: release base URL, tests pass `file://`).

### State directory

`sid` is a worktree path with `/` replaced by `%`. Fields are separated by `\037` (unit separator),
not tabs: bash `read` merges empty tab-separated fields, which once made pending rows vanish.

| File | Fields |
|---|---|
| `pending/<sid>` | label, port, pid, started epoch |
| `failed/<sid>` | label, log, error, pid, retry args... |
| `managed/<sid>` | label, log, retry args... (servers started from the menu, used for crash detection) |
| `expected`, `active` | Listener snapshots used to decide when to re-render. |
| `off` | Exists while the user has chosen Turn off. |
| `stream.pid` | PID of the streaming process. |
| `rendered` | Last full menu output, used by `splice_pending`. |
| `settings.info` | PID, port, token and the folder the helper serves, separated by tabs. |

## How the plugin works

- With no arguments it runs `stream`: every 2 s it snapshots listening ports, and re-renders when they
  change or every 10 s while servers run. Blocks are separated by `~~~` (SwiftBar streamable format).
- With an argument, `main` dispatches a menu action: `start`, `start-other`, `stop`, `stop-idle`,
  `restart`, `stop-all`, `off`/`on`, `dismiss`, `quit`, `copy`, `settings`, `pick-folder`,
  `inspect`, `render` (one render to stdout, useful for debugging), `version`, `enable`.
- `enable` is the only one meant to be typed by a person. The cask links the plugin into Homebrew's
  `bin` as `dev-servers`, and the installer does the same when it finds a writable folder on the
  PATH, so the command is `dev-servers enable`. `SELF` resolves symlinks for that reason: without it
  `cmd_enable` would point SwiftBar's plugin folder at the folder holding the link. Homebrew cannot start SwiftBar or set its
  plugin folder, because Homebrew 7 runs install steps in a sandbox with a fake HOME, so the cask's
  caveats ask the user to run it. It points SwiftBar at the folder the plugin sits in, then starts
  or refreshes SwiftBar. It refuses when SwiftBar already uses a different plugin folder. There is
  no smoke test for it: it writes real SwiftBar settings and launches the app.
- Start flow: `cmd_start` picks the first free port in the range, copies `copyIfMissing` files from the
  main checkout, launches the command with `launch` (`nohup /bin/zsh -lc`, loading nvm and `.nvmrc`
  when present, output to the log), writes `pending/`, calls `wake_menu`, and runs
  `watch_start` in the background. `watch_start` waits until the port is listening (notifies "X is
  up" with the URL and start time) or the process exits or `PENDING_TIMEOUT` passes (writes `failed/`
  through `record_failure` and notifies).
- `wake_menu` sends `USR1` to the stream. The stream traps it (`WAKE=1`) and calls `splice_pending`,
  which inserts pending rows into the last rendered output at once, then does a full render.
- `crash_check` turns a `managed/` server that stopped listening without a Stop into a `failed/` row.
- `render_failed` shows the error in red, the end of the log in the submenu, Stop if the PID is alive
  else Retry, and Dismiss.
- Stop (`kill_tree`/`stop_root`): SIGTERM to the server and its launcher processes inside that
  worktree, 5 s wait, then SIGKILL. Never touches shells or terminals.
- The settings window gets the plugin version as a command line argument, so loading the page costs
   no subprocess. Export and import live in the page: export downloads the config as JSON, import
   reads a file back, asks whether to replace everything or only merge the repos, and fills in the
   form without saving.
- Health check: request to a static asset path, 2 s timeout. Green = answers, orange = slow/busy,
  red = 5xx.
- Turn off writes `state/off`; the stream then renders a greyed icon with Turn on and sleeps.
  Quit SwiftBar runs `cmd_quit`. Both items are visible at the bottom of the menu.
- Notifications use `open -g "swiftbar://notify?plugin=dev-servers.sh&title=Dev%20Servers&subtitle=...&body=...[&href=...]"`
  so they show SwiftBar's icon. Falls back to `osascript` only if `open` fails.

## SwiftBar gotchas (learned the hard way)

1. **SwiftBar 2.1.1 bug (#515):** a submenu parent reused across refreshes loses its action and gets
   greyed out. `mark_parents` adds `bash=/usr/bin/true terminal=false` to every parent row. Fixed in
   SwiftBar 2.1.2 beta; keep the workaround until 2.1.2 is the minimum.
2. **Double launch:** SwiftBar 2.1.1 sometimes starts the plugin twice and orphans one.
   `stop_old_stream` kills the previous stream, and the stream exits when its parent PID becomes 1.
3. **Parameter quoting:** values with spaces must be quoted. Use `q()`. SwiftBar strips the quotes
   but doesn't decode escapes, so a value containing `"` is wrapped in `'` instead.
4. **Icons:** menu images are base64 PNGs, 28 px at 144 dpi (shown at 14 pt). Tinted SF Symbols render
   muted in menus, so the health dots and Stop icons are PNGs (`DOT_*`, `ICON_STOP`, `ICON_STOP_ALL`).
   Stop is a solid dark red (`#D70015`) circle, by owner request.
5. **Finding the stream PID:** match the process args by plugin file name suffix
   (`*"/${SELF##*/}"`), not the full path, since SwiftBar may use a relative or symlinked path.
6. **Don't gate notifications on `pgrep -x SwiftBar`.** It failed when SwiftBar ran the plugin and
   made notifications fall back to Script Editor's icon.
7. **BSD `pkill`/`pgrep` differ from GNU.** `pkill -f pattern -n` treats `-n` as a pattern. Never use
   broad `pkill -f` patterns; one once killed the user's live stream.
8. **Settings asset cache is keyed by the plugin's md5,** not the version. Keying by version served a
   stale (light mode) window after a rebuild. A helper left over from an older build is spotted by
   comparing the folder it recorded in `settings.info`.
9. Splicing pending rows must not call `editor_cmd`: it needs `$TMP/cfg`, which doesn't exist there.

## Distribution design

- **Install script (works for any plugin folder):**
  `curl -fsSL https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest/download/install.sh | bash`
  - When piped, `BASH_SOURCE[0]` is empty, so `ROOT` is empty and the plugin is downloaded.
  - The plugin download is verified against the release's `SHA256SUMS`.
  - SwiftBar: `brew install --cask swiftbar` if Homebrew exists; otherwise the latest GitHub release zip,
    installed into `~/Applications` only if `codesign --verify --deep --strict` passes and
    `TeamIdentifier` is `X93LWC49WV` (SwiftBar's team, read from the official v2.1.1 release).
  - Plugin folder: SwiftBar's `PluginDirectory` default, or `~/.swiftbar` set before first launch.
  - `--version X.Y.Z`, `--plugin-dir`, `--no-launch`, `--uninstall [--purge]`.
- **Homebrew:** `brew install mohitsharma0101/tap/dev-servers`. The README leads with that form,
  since Homebrew resolves a token with no matching formula as a cask, and keeps the explicit
  `--cask` spelling further down as a fallback.
  - Cask depends on the `swiftbar` cask and the `jq` formula, macOS Ventura or later.
  - Homebrew 7 replaced `postflight` with declarative `*_steps` blocks that run in a sandbox with a fake
    HOME, so the cask cannot read SwiftBar's plugin folder setting. It uses
    `artifact "dev-servers.sh", target: "~/.swiftbar/dev-servers.sh"` plus
    `preflight_steps { set_permissions "dev-servers.sh", "0755", base: :staged_path }`
    (without it the plugin lands as 0644 and SwiftBar can't run it).
  - `binary "#{Dir.home}/.swiftbar/dev-servers.sh", target: "dev-servers"` links the command. The
    source has to be a real absolute path: Homebrew resolves a `binary` source as
    `staged_path.join(source)`, and only the target gets `~` expanded. Generic `artifact` sorts
    before `binary`, so the file is already at the target when the link is made.
  - Users with a SwiftBar installed outside Homebrew need `brew install --cask --adopt swiftbar` first.
    Users with an existing plugin file need `--adopt`.
  - Tested on Homebrew 7.0.11 with a throwaway local tap: install, adopt, uninstall and reinstall all
    worked, and `brew style` was clean. `brew audit` wasn't run because Homebrew blocks it until the
    Command Line Tools are updated.
- **Release workflow:** push tag `vX.Y.Z` matching `VERSION`. The `release` job (macos-latest) runs the
  checks and publishes `dev-servers.sh`, `install.sh` and `SHA256SUMS`, with notes taken from the
  `## X.Y.Z` section of `CHANGELOG.md`. The `release` job stops at its second step if the
  `HOMEBREW_TAP_TOKEN` secret is missing, so nothing is published without a cask. The `homebrew` job
  (ubuntu-latest) commits `Casks/dev-servers.rb` to `MohitSharma0101/homebrew-tap`.
  Users can check provenance with `gh attestation verify <file> --repo MohitSharma0101/swiftbar-dev-servers`.

## Where things stand

Done and tested locally: all features, the settings window, the installer (from source, piped latest,
piped `--version`, tampered plugin refused, missing release error, tampered or re-signed SwiftBar
refused), and the cask. Lint is clean and 42/42 smoke tests pass.

Not done yet, in order:

1. `docs/settings.png` is out of date: the Editor field now shows placeholder "Automatic" and the
   hint "Opens a server's folder from its submenu. Leave empty to use the first one found: Cursor,
   VS Code, Zed, Sublime Text. Or type a command, like `code`." Retake it with sample data only.
2. In `CHANGELOG.md`, rename `## Unreleased` to `## 1.0.0 - <date>`. The release workflow needs that
   heading for the notes.
3. First commit (ask the owner first, see rules below). Git is already initialized on `main`.
4. `gh repo create MohitSharma0101/swiftbar-dev-servers --public --source . --push`.
5. `gh repo create MohitSharma0101/homebrew-tap --public`. Then create a fine-grained token with Contents
   read and write on that repo only, and save it as the `HOMEBREW_TAP_TOKEN` secret in
   `swiftbar-dev-servers`.
6. `git tag v1.0.0 && git push origin v1.0.0`. Then check the workflow run, the release assets,
   `gh attestation verify`, a clean `curl ... | bash` install, and `brew install --cask mohitsharma0101/tap/dev-servers`.
7. Check that the workflow action versions (`actions/checkout@v4`, `actions/attest-build-provenance@v2`)
   are still current.
8. Optional: add topics (`swiftbar`, `swiftbar-plugin`, `macos`, `menubar`, `developer-tools`). Open a
   PR to `swiftbar/swiftbar-plugins` (Dev Tools folder). Add a one-click link to the README:
   `swiftbar://addplugin?src=https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest/download/dev-servers.sh`.

Open review items the owner hasn't decided on:

- Stop all stops servers one after another; it could stop them in parallel.
- The start-target cache (`START_MENU_TTL=300`) isn't refreshed when worktrees are added or removed,
  so a new worktree can take up to 5 minutes to show up in Start.

## Removed on purpose (don't bring back)

The owner asked for these to be removed completely:

- Pinned repos / quick launch.
- The View log menu item. The end of the log in a failed row's submenu is the only log view.
- Opening the URL automatically when a server comes up. The "is up" notification links to it instead.
- ⌥ (Option) alternate menu items and any hidden "hold Option" behaviour.
- Raising the settings window that is already open. It needed AppleScript to the browser, which made
  macOS ask for permission to control Chrome. The owner would rather have a second window than that
  prompt. Choosing Settings again opens a new window, which is fine.

## Owner's rules

- **Never use em dashes** in any text: code comments, docs, UI copy, commit messages, chat.
- **Comments go on functions only**, never inside function bodies, including tests. Explain why in one
  or two plain sentences.
- **Never commit, push, tag or publish without the owner's explicit OK** for that action.
- Plain words in UI copy and docs, no jargon. Docs explain the feature and how it works, without
  ticket numbers or "pending" notes.
- Write URLs as markdown links with a short label and the full exact URL.
- Final answers are short: what changed, why, rejected alternatives, tradeoffs.
- The owner doesn't share their screen. Verify things yourself with commands and logs, and ask them
  to check only what you can't, like how a notification looks.
- Match the existing style: bash with `set` conventions as in the files, 2-space indent, shellcheck
  clean; Python formatted by ruff, line length 120.
