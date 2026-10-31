<div align="center">

# Dev Servers

**Every local dev server in your menu bar. Start, open, restart and stop them from there.**

[![Latest release](https://img.shields.io/github/v/release/MohitSharma0101/swiftbar-dev-servers?label=release)](https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest)
[![CI](https://github.com/MohitSharma0101/swiftbar-dev-servers/actions/workflows/ci.yml/badge.svg)](https://github.com/MohitSharma0101/swiftbar-dev-servers/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/MohitSharma0101/swiftbar-dev-servers)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)

</div>

<!-- Drop a screenshot of the open menu at docs/menu.png and uncomment the next line.
![The menu](docs/menu.png)
-->

Three worktrees, a couple of side projects, an agent running tests on another branch, and suddenly
you are running `lsof -i :3004` to find out what is on that port and which branch it belongs to.

Dev Servers answers that at a glance. It also starts a branch on the next free port, with the right
URL, so you stop juggling ports by hand.

## Install

```bash
brew install mohitsharma0101/tap/dev-servers
```

Homebrew cannot start SwiftBar for you, so finish with:

```bash
dev-servers enable
```

The icon appears in your menu bar. Update with `brew upgrade`, remove with
`brew uninstall --cask dev-servers`, and add `--zap` to also remove settings, cache and logs.

<details>
<summary>Other ways to install</summary>

**Install script.** Use this if SwiftBar already uses a plugin folder other than `~/.swiftbar`. It
finds your folder.

```bash
curl -fsSL https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest/download/install.sh | bash
```

It installs SwiftBar if it is missing, with Homebrew when you have it, otherwise from SwiftBar's own
GitHub release, which it only installs if the app is signed by SwiftBar's developer. It never asks
for an admin password. Then it downloads the plugin, checks it against the release's `SHA256SUMS`,
copies it into your plugin folder and refreshes SwiftBar. It also links a `dev-servers` command
when it finds a folder on your PATH it can write to. Run the same command again to update, or
add `bash -s -- --version 1.0.0` for a specific release. To remove it, add `bash -s -- --uninstall`,
plus `--purge` to take settings, cache and logs with it.

**From source.** `git clone` this repo, then `./install.sh` in the folder. It builds from your
checkout.

**By hand.** Download `dev-servers.sh` from the
[latest release](https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest), drop it
into your SwiftBar plugin folder and run `chmod +x` on it. It is one file with everything inside.

**If Homebrew cannot find it.** Older Homebrew versions need to be told this is a cask:

```bash
brew install --cask mohitsharma0101/tap/dev-servers
```

**Read it before you run it.** Every release is built by GitHub Actions from a tagged commit here,
with a signed build provenance record. To confirm a file came from that build, use the
[GitHub CLI](https://cli.github.com):

```bash
gh attestation verify install.sh --repo MohitSharma0101/swiftbar-dev-servers
```

</details>

> [!NOTE]
> Needs macOS 13 or later, [SwiftBar](https://swiftbar.app) 2.0 or later, `jq` (which ships with
> macOS 15, otherwise `brew install jq`), and `python3` from Apple's command line tools for the
> settings window. If you installed SwiftBar from its website, run
> `brew install --cask --adopt swiftbar` first so Homebrew takes it over.

## What you get

- **Every server, grouped by repo and worktree,** with its port, branch, uptime, memory and CPU.
- **A health dot** that is green when the server answers, orange while it is busy compiling, and red
  when it returns 5xx errors.
- **Start on the next free port.** Pick a worktree and a mode, and Dev Servers takes the first free
  port in that repo's range and builds the right URL.
- **Files carried into worktrees.** Things like `.env.local` are copied from your main checkout
  before a fresh worktree starts.
- **A server that is still starting** appears at once with a grey ring, so you can see it coming and
  stop it before its port opens.
- **Failures you can act on.** A crash, a failed start, or a start still not listening after four
  minutes stays in the menu with the error, the end of its log, Retry and Dismiss.
- **Warnings that matter**, when another app holds a port in one of your ranges, or a range has no
  free ports left.
- **Idle auto-stop** for servers no browser has touched in hours. Off unless you turn it on.

## Getting started

You do not have to set anything up to see your servers. On first run Dev Servers watches whichever
of `~/Projects`, `~/Developer`, `~/code`, `~/src`, `~/dev` and `~/workspace` exist, and lists
anything running inside them with a `localhost` link.

Start buttons and real URLs need a little setup per repo:

1. Choose **Settings…** from the menu. A server that is not set up yet also has a **Set up this
   repo…** item that jumps straight there.
2. Click **+ Add repo…** and pick the repo, or any of its worktrees. The name and a start command
   come from your `package.json`.
3. Set a port range if you want Dev Servers to choose ports, and put `{port}` in the start command
   where the port goes, like `PORT={port} npm run dev`.
4. Set the URL template. `{port}` becomes the server's port, and the line under the field shows the
   result.
5. Save. The menu picks it up within a couple of seconds.

## Settings

![The settings window](docs/settings.png)

A repo can have as many modes as you like, for example "Local" and "Staging API", each with its own
start command and URL. **Export** and **Import** in the Backup section move your whole setup to
another Mac: an import asks whether to replace everything or only add the repos from the file, and
fills in the form without saving so you can look it over first.

<details>
<summary>Every setting</summary>

**General**

| Setting | What it does |
|---|---|
| Watched folders | A server is listed when it runs from inside one of these folders. |
| Auto-stop idle servers | Stops a server once no browser has been connected to it for this many hours. Off by default. |
| Editor | Opens a server's folder from its submenu. Leave it empty to use the first one found: Cursor, VS Code, Zed, Sublime Text. Or type a command, like `code`. |

**Per repo**

| Setting | What it does |
|---|---|
| Name | The label used in the menu. |
| Main checkout | Where worktrees are listed from, and where missing files are copied from. |
| Port range | Start picks the first free port in this range. Leave it empty if your server chooses its own port. |
| Default port | The port your main checkout usually runs on. A server on this port uses "URL on default port" instead of the template. |
| Copy into worktrees | Files copied from the main checkout into a worktree before it starts, if the worktree does not have them yet. |

**Per mode**

| Setting | What it does |
|---|---|
| Start command | Runs from the worktree root. `{port}` becomes the chosen port. |
| URL | The link for the server. `{port}` becomes its port. |
| URL on default port | The link used when the server runs on the repo's default port. |
| Detect by | Text in the server's command line that identifies this mode, such as `dev:staging`. Leave it empty on the mode that should be the fallback. |

Settings live in `~/.config/dev-servers/config.json`. Repos are matched by their git `origin`
remote, so all worktrees of a repo share one entry.

</details>

## How it works

The plugin is one bash file that runs as a streaming SwiftBar plugin. Every two seconds it takes a
cheap look at which TCP ports are listening, and only rebuilds the menu when that changes, or every
10 seconds while servers run so health and usage stay fresh. The menu is always ready before you
click it.

A server is anything listening on a TCP port whose working directory sits inside a watched folder,
according to `lsof`. The health check is a request for a static asset with a two second timeout, so
checking never makes a dev server compile a page.

Stop sends SIGTERM to the server and to the `npm`, `pnpm`, `yarn`, `bun` or `node` processes that
launched it, waits five seconds, then SIGKILL to anything left. It only touches processes whose
working directory is inside that worktree, and it never kills your shell or terminal.

The settings window is a small Python server bound to `127.0.0.1` on a random port. Every request
needs a token that changes each session, so other websites cannot read or change your settings. It
quits by itself 15 minutes after you close the window.

<details>
<summary>Troubleshooting</summary>

**The icon does not show up.** On MacBooks with a notch, a crowded menu bar hides new icons behind
it. Hide a few icons in System Settings, Menu Bar, then hold ⌘ and drag the Dev Servers icon where
you want it.

**A server I started in a terminal is missing.** Its folder is probably not inside a watched folder.
Add the folder in Settings.

**Open goes to the wrong URL for one mode.** Give that mode some Detect by text that only appears in
its own start command, such as `dev:staging`.

**Settings will not open.** It needs `python3`. Run `xcode-select --install`.

**I want to pause it.** Choose **Turn off** at the bottom of the menu. The icon stays, greyed out,
and Dev Servers stops checking ports, sending notifications and auto-stopping servers until you
click **Turn on**. Your servers keep running either way, and it stays off after a restart.

**I want to close it completely.** Choose **Quit SwiftBar**. That closes SwiftBar and every plugin
it runs, and your servers keep running.

Logs for servers started from the menu are in `~/Library/Logs/dev-servers/`.

</details>

## Development

```bash
make lint      # shellcheck and ruff
make test      # end-to-end smoke test in a throwaway folder
make build     # builds the single-file plugin into dist/
make settings  # opens the settings window against a throwaway config
```

The plugin is `src/dev-servers.sh` and the settings window is in `src/settings/`. `make build`
embeds the settings files in the plugin so it ships as a single file. `make settings` needs neither
SwiftBar nor macOS, so the window can be worked on anywhere. The smoke test uses its own temporary
config, cache and project folder, and ports 48201 to 48290, so it leaves your real setup alone.

## License

MIT, copyright 2026 Mohit Sharma
([MohitSharma0101](https://github.com/MohitSharma0101)). See [LICENSE](LICENSE).
