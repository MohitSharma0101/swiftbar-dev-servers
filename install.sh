#!/usr/bin/env bash
# Installs, updates or removes the Dev Servers SwiftBar plugin, installing SwiftBar first if it's
# missing. Run it from a checkout, or straight from the latest release:
#
#   curl -fsSL https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/latest/download/install.sh | bash
#
# See --help for options.
set -euo pipefail

readonly APP_ID="dev-servers"
readonly PLUGIN_NAME="dev-servers.sh"
readonly SWIFTBAR_BUNDLE_ID="com.ameba.SwiftBar"
readonly DEFAULT_PLUGIN_DIR="$HOME/.swiftbar"
readonly REPO="MohitSharma0101/swiftbar-dev-servers"
readonly RELEASE_URL="${DEV_SERVERS_RELEASE_URL:-https://github.com/$REPO/releases}"
readonly SWIFTBAR_TEAM_ID="X93LWC49WV"
ROOT=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
readonly ROOT

plugin_dir=""
version=""
launch=1
uninstall=0
purge=0

say() { printf '%s\n' "$*"; }
step() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  (no options)          install or update, installing SwiftBar first if needed
  --version X.Y.Z       install that release instead of the latest
  --plugin-dir DIR      install into DIR instead of SwiftBar's plugin folder
  --no-launch           don't start or refresh SwiftBar afterwards
  --uninstall           remove the plugin (keeps your settings)
  --uninstall --purge   also remove settings, cache and logs
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --plugin-dir)
        [ $# -ge 2 ] || die "--plugin-dir needs a folder"
        plugin_dir=$2
        shift
        ;;
      --version)
        [ $# -ge 2 ] || die "--version needs a version, like 1.0.0"
        version=${2#v}
        shift
        ;;
      --no-launch) launch=0 ;;
      --uninstall) uninstall=1 ;;
      --purge) purge=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
  done
}

# Prints SwiftBar's app path, or nothing if it isn't installed.
find_swiftbar() {
  local app
  for app in "/Applications/SwiftBar.app" "$HOME/Applications/SwiftBar.app"; do
    [ -d "$app" ] && { echo "$app"; return; }
  done
  mdfind "kMDItemCFBundleIdentifier == '$SWIFTBAR_BUNDLE_ID'" 2>/dev/null | head -n 1
}

# Downloads over HTTPS only, failing on any HTTP error.
fetch() {
  curl --proto '=https,file' --tlsv1.2 -fsSL "$1" -o "$2"
}

# Fails unless the app is intact and signed by SwiftBar's own Apple developer account, so a
# tampered or look-alike download is never installed.
verify_swiftbar() {
  codesign --verify --deep --strict "$1" 2> /dev/null ||
    die "the SwiftBar download isn't validly signed, so it wasn't installed"
  codesign -dv "$1" 2>&1 | grep -qx "TeamIdentifier=$SWIFTBAR_TEAM_ID" ||
    die "the SwiftBar download isn't signed by SwiftBar's developer, so it wasn't installed"
}

# Installs SwiftBar with Homebrew if available, else from its latest GitHub release into
# ~/Applications. Never asks for admin rights.
install_swiftbar() {
  local url tmp
  if command -v brew > /dev/null; then
    step "Installing SwiftBar with Homebrew"
    brew install --cask swiftbar && return
    warn "Homebrew couldn't write to /Applications, installing into ~/Applications instead"
    mkdir -p "$HOME/Applications"
    brew install --cask --appdir="$HOME/Applications" swiftbar
    return
  fi
  step "Downloading SwiftBar from its GitHub releases"
  url=$(curl --proto '=https' --tlsv1.2 -fsSL https://api.github.com/repos/swiftbar/SwiftBar/releases/latest |
    jq -r '[.assets[] | select(.name | test("^SwiftBar.*\\.zip$"))][0].browser_download_url // empty')
  case "$url" in
    https://github.com/swiftbar/SwiftBar/releases/download/*) ;;
    *) die "couldn't find a SwiftBar download. Install it from https://swiftbar.app and run this again." ;;
  esac
  tmp=$(mktemp -d)
  fetch "$url" "$tmp/SwiftBar.zip"
  ditto -x -k "$tmp/SwiftBar.zip" "$tmp/app"
  verify_swiftbar "$tmp/app/SwiftBar.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/SwiftBar.app"
  mv "$tmp/app/SwiftBar.app" "$HOME/Applications/"
  rm -rf "$tmp"
}

# Uses the plugin folder SwiftBar already has. If it has none yet, sets ~/.swiftbar before its
# first launch so SwiftBar doesn't ask.
resolve_plugin_dir() {
  local current
  [ -n "$plugin_dir" ] && { echo "$plugin_dir"; return; }
  current=$(defaults read "$SWIFTBAR_BUNDLE_ID" PluginDirectory 2>/dev/null || true)
  if [ -n "$current" ]; then
    echo "${current/#\~/$HOME}"
    return
  fi
  defaults write "$SWIFTBAR_BUNDLE_ID" PluginDirectory "$DEFAULT_PLUGIN_DIR"
  echo "$DEFAULT_PLUGIN_DIR"
}

# Downloads the plugin from a GitHub release and checks it against that release's SHA256SUMS,
# then prints its path.
download_plugin() {
  local base tmp
  if [ -n "$version" ]; then
    base="$RELEASE_URL/download/v$version"
  else
    base="$RELEASE_URL/latest/download"
  fi
  tmp=$(mktemp -d)
  step "Downloading Dev Servers${version:+ v$version}" >&2
  fetch "$base/$PLUGIN_NAME" "$tmp/$PLUGIN_NAME" || die "couldn't download $base/$PLUGIN_NAME"
  fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || die "couldn't download $base/SHA256SUMS"
  (cd "$tmp" && grep "  $PLUGIN_NAME\$" SHA256SUMS | shasum -a 256 -c - > /dev/null 2>&1) ||
    die "the download doesn't match its checksum, so it wasn't installed"
  echo "$tmp/$PLUGIN_NAME"
}

# Prints the path of the plugin to install: a fresh build when run from a source checkout, else
# the plugin from the GitHub release.
plugin_source() {
  if [ -z "$version" ] && [ -n "$ROOT" ] && [ -f "$ROOT/src/$PLUGIN_NAME" ] && [ -x "$ROOT/scripts/build.sh" ]; then
    "$ROOT/scripts/build.sh" > /dev/null
    echo "$ROOT/dist/$PLUGIN_NAME"
  else
    download_plugin
  fi
}

check_requirements() {
  [ "$(uname -s)" = Darwin ] || die "Dev Servers only runs on macOS"
  if ! command -v jq > /dev/null; then
    if command -v brew > /dev/null; then
      step "Installing jq"
      brew install jq
    else
      die "jq is required. It ships with macOS 15 and later, or install it with Homebrew: brew install jq"
    fi
  fi
  xcode-select -p > /dev/null 2>&1 ||
    warn "the Settings window needs python3 from Apple's command line tools. Install them with: xcode-select --install"
}

refresh_swiftbar() {
  [ "$launch" = 1 ] || return 0
  if pgrep -x SwiftBar > /dev/null; then
    open -g "swiftbar://refreshallplugins"
  else
    open -a "$1"
  fi
}

# Prints a folder already on the PATH where the dev-servers command can be linked, if there is one
# we can write to without asking for a password.
command_dir() {
  local candidates=() dir
  command -v brew > /dev/null && candidates+=("$(brew --prefix)/bin")
  candidates+=(/usr/local/bin)
  for dir in "${candidates[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
      printf '%s
' "$dir"
      return 0
    fi
  done
  return 0
}

# Links the plugin as a plain dev-servers command, so it can be run without typing its full path.
link_command() {
  local bin
  bin=$(command_dir)
  [ -n "$bin" ] || return 0
  ln -sf "$1" "$bin/$APP_ID" 2> /dev/null || return 0
  printf '%s
' "$bin/$APP_ID"
}

do_install() {
  local app dir src link
  check_requirements
  app=$(find_swiftbar)
  if [ -z "$app" ]; then
    install_swiftbar
    app=$(find_swiftbar)
    [ -n "$app" ] || die "SwiftBar didn't install. Get it from https://swiftbar.app and run this again."
  fi
  dir=$(resolve_plugin_dir)
  src=$(plugin_source)
  mkdir -p "$dir"
  install -m 0755 "$src" "$dir/$PLUGIN_NAME"
  link=$(link_command "$dir/$PLUGIN_NAME")
  refresh_swiftbar "$app"
  say ""
  say "Installed Dev Servers $("$dir/$PLUGIN_NAME" version) into $dir"
  [ -n "$link" ] && say "You can run it as: $APP_ID" || true
  say "Look for the server icon in your menu bar, and open Settings… from its menu to add your repos."
  say "If the icon doesn't appear, your menu bar may be full: hide a few icons or hold ⌘ and drag it into view."
}

do_uninstall() {
  local dir info pid bin
  dir=${plugin_dir:-$(defaults read "$SWIFTBAR_BUNDLE_ID" PluginDirectory 2>/dev/null || echo "$DEFAULT_PLUGIN_DIR")}
  dir=${dir/#\~/$HOME}
  info="$HOME/Library/Caches/$APP_ID/state/settings.info"
  if [ -f "$info" ]; then
    pid=$(cut -f1 "$info")
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$dir/$PLUGIN_NAME"
  bin=$(command_dir)
  if [ -n "$bin" ] && [ "$(readlink "$bin/$APP_ID" 2> /dev/null)" = "$dir/$PLUGIN_NAME" ]; then
    rm -f "$bin/$APP_ID"
  fi
  say "Removed the plugin from $dir"
  if [ "$purge" = 1 ]; then
    rm -rf "$HOME/.config/$APP_ID" "$HOME/Library/Caches/$APP_ID" "$HOME/Library/Logs/$APP_ID" \
      "$HOME/Library/Application Support/$APP_ID"
    say "Removed settings, cache and logs"
  else
    say "Your settings are still in ~/.config/$APP_ID (run with --purge to remove them)"
  fi
  [ "$launch" = 1 ] && pgrep -x SwiftBar > /dev/null && open -g "swiftbar://refreshallplugins"
  return 0
}

main() {
  parse_args "$@"
  if [ "$uninstall" = 1 ]; then
    do_uninstall
  else
    do_install
  fi
}

main "$@"
