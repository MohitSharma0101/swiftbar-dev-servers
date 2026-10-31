#!/usr/bin/env bash
# <xbar.title>Dev Servers</xbar.title>
# <xbar.version>dev</xbar.version>
# <xbar.desc>See every local dev server by repo and worktree, check its health, and start, restart or stop it from the menu bar.</xbar.desc>
# <xbar.dependencies>bash,jq,python3,curl,lsof</xbar.dependencies>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

readonly VERSION="dev"
readonly APP_ID="dev-servers"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
readonly SELF
readonly CONFIG="${DEV_SERVERS_CONFIG:-$HOME/.config/$APP_ID/config.json}"
readonly CACHE_DIR="${DEV_SERVERS_CACHE:-$HOME/Library/Caches/$APP_ID}"
readonly LOG_DIR="${DEV_SERVERS_LOGS:-$HOME/Library/Logs/$APP_ID}"
readonly SUPPORT_DIR="${DEV_SERVERS_SUPPORT:-$HOME/Library/Application Support/$APP_ID}"
readonly STATE_DIR="$CACHE_DIR/state"
readonly START_MENU_TTL=300
readonly PENDING_TIMEOUT="${DEV_SERVERS_PENDING_TIMEOUT:-240}"
readonly SERVER_COMMS_RE='^(node|bun|bunx|deno|npm|npx|pnpm|yarn|vite|next|next-server.*|nodemon|tsx|ts-node)$'
readonly DEFAULT_ROOTS=(Projects Developer code src dev workspace)
readonly EDITORS=(cursor code zed subl)
readonly GRAY="color=#8E8E93"
readonly ORANGE="#FF9F0A"
readonly RED="#FF3B30"
readonly GREEN="#34C759"
# Health dots as Retina PNGs (28px at 144 dpi, shown at 14pt). Tinted SF Symbols render muted in menus.
readonly DOT_GREEN="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAACXBIWXMAABYlAAAWJQFJUiTwAAAAnElEQVR4nO3WsRGAIAwFUIZyGSt2Yg72cI3sQaEUeMdxBGLMfS0ofmPhO34AdduxO2Sg2ALb+JyYQzmphMozbwn68uJzEpLAMywIoDZBC2qwKTqqUYvd6dbLgZKZSWYqAi1Wx66yB0ZDMEpAizrZWntgMgTTL0F4pfBNAz8W8IP/ydUGv7zfoOrPU12vZKbE1fgUrGHIL4ZpFmieC1f+SjA04KCeAAAAAElFTkSuQmCC"
readonly DOT_ORANGE="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAACXBIWXMAABYlAAAWJQFJUiTwAAAAmklEQVR4nO3WMQ6AIAwFUGYvyZ24gBfgUL0HAzJgQgiFWpuvA8NfHHzhF1CXz8MhA8U22MeXxBIqSTVUn3lL0NcX50VIAq+wIID6BC2owZborEYtdmdYLwdKZiaZqQi0WB27yhEYDcEoAS3qZGsdgckQTL8E4ZXCNw38WMAP/idXG/zyfoOqP09tvZKZElfjU7CFIb8YptmgeS5PJEt/jRpnqAAAAABJRU5ErkJggg=="
readonly DOT_RED="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAACXBIWXMAABYlAAAWJQFJUiTwAAAAmklEQVR4nO3WMQ6AIAwFUI7k7mG4E+fgUL0HAzJgQgiFWpuvA8NfHHzhF1CXz8MhA8U22MeXxBIqSTVUn3lL0NcX50VIAq+wIID6BC2owZborEYtdmdYLwdKZiaZqQi0WB27yhEYDcEoAS3qZGsdgckQTL8E4ZXCNw38WMAP/idXG/zyfoOqP09tvZKZElfjU7CFIb8YptmgeS7Yu42Qq2Mq/wAAAABJRU5ErkJggg=="
readonly DOT_PENDING="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAABygAwAEAAAAAQAAABwAAAAADpcdpAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAj9JREFUSA3tVs1KI0EQ7ppMDirj4kpgPbvCgicv+hLrgtEH8JTbRkhwg4eFgAeJYsD4Aj6ARNj1JfQuCOrZBVlFh+jByZRdM5ZdmR7j7GEFwYFQ1fXzff1TXR2l3r+3vgOQZQH1et0dGhopOg58A1DTSsFYnIfniOowDPFXp3PV1nHBS3gvEjabW3OIsAEA4/3AEPEMAJcrlaW9fnHPEurZOp43sgbg/OgHkPQhhuu+f7Wi88Okj8ZOmpFsNhleKIU/gyCYurn569GPdLLpn/bFH02QcnmclKkrpG3Uc2mbYGzf398t1mo139iM1mg0vHx+YEefbdFYw2La9lqEVCCe9/HYnBm2K5XyggZCA5aqQbPZ2mVSOlPfv/ySLCRrSz1vdF6QXdDKMpDRDDCOjbeXMKiyySE/i1DnzYqA1nPbKGKeVIrVFb3NBrpGrLNMIYQZdgZBd5/1rLLbDX6bWIPFNotQX+xP7Ly9vT5lPauUORKL8y1CdvwvaRHqVvWHyQYHP3xmPavszcHzZJ5FqIvmgINcN/eV9awyl3Ofio76bDLPIqRGLILKdKnFuK9KsbqffuegBFZktghPTo726NLGSVCIO4iyGgSDCgmP3aZANsKgF0T4IzUV6FVbG89oc3Or0ftSRB2kRXeTS58K5PGcy7qlRSujfHoxqtWlGmNJ6cqB1OmJ0V1fGdIIcNV13dXh4VEZ2qPz89RjFIPULRV+9WoPsCQtlUr5iYnJubg3wozpIP/+F0PivutvcwceAIvu+x2fF4lPAAAAAElFTkSuQmCC"
readonly ICON_STOP="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAABygAwAEAAAAAQAAABwAAAAADpcdpAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAX9JREFUSA3tVjtOAzEQfV6gCC0sn5ou9FBQ5QAgJZxlQXRpITehCBIHAFoi6nTUQRBaKrTGL6ZZz+wn1jaR4m7s97FnZ8cG1mPVM2CaHOAZ2NxDOkhgLyxwAphDz7MzJzDJYR4/8TXuAb91erWGU+z0gWTkgEdVYm4j70CedfH9UIVLyhaHzmWK3VuDZFxnRg1iiCWHXM5po/SE3sxcaaS6OQt718X8WsOphkwjd6sRms5Z5AMtveLoLBB+s6bC5bhk5LWKCGG4j/SyyTcrysiIGqzscEUYGtjzEBQb8zcKucLQwpyGoNhY0xKGTvwg1kDhCS3NUOG1N6UZfrQnb2ehljB0RfMagmJjV6mTkCsM2YhDUGysaQlDdn3fiGNtPI8a1ApVhGFvccXkWQhcPs4zr1VkCkMusweyARehzSPfvPVraqNMJsXP0zG2OwbmrAyjzdPsHvObF8BlVQ5XSNWj7Qu41pDbeQO2Okj7/omxaH3/HWT5J0b18darq5CBP65AaO4TbnrVAAAAAElFTkSuQmCC"
readonly ICON_STOP_ALL="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAABygAwAEAAAAAQAAABwAAAAADpcdpAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAM9JREFUSA3tlcEJg1AQRPcLacBbID3YglVZRBpJG7ZgD4HcbCAQs0O+IPxZk+8es17U3Z15OoIrEkckUJlAsuYnaS8naa7a75OkszW3rS+yPPR+fMpr6GS+b3vrNQVm2KSgdh2sOSt4VmjHoA0zwpsdhcEP2pxOYU+BOtUXk/UF6kGBv36zvWewPChwz8jbC6A3wUIfkRaReAt/Gmn+67vSszysSEcX7SOmHhSIfYYVcxSa19PA9BSIPYZ9psKbFQ0zwyw01i5kmqhFAl8TeAN2EzqJwPOZVAAAAABJRU5ErkJggg=="

QSELF=""
ROOTS=()
TMP=""
LAUNCH_PID=""
WAKE=""

# Quotes a value for a SwiftBar menu parameter, so paths with spaces survive. SwiftBar strips the
# surrounding quotes and doesn't decode escapes, so a value containing " is wrapped in ' instead.
q() { case "$1" in *\"*) printf "'%s'" "$1" ;; *) printf '"%s"' "$1" ;; esac; }

# SF Symbol colour for SwiftBar's sfconfig (base64 JSON); SwiftBar ignores sfcolor in menus.
sfc() { printf '{"renderingMode":"Palette","colors":["%s"]}' "$1" | base64; }

tilde() {
  local t="~"
  printf '%s\n' "${1/#$HOME/$t}"
}

untilde() { printf '%s\n' "${1/#\~/$HOME}"; }

# Creates a scratch dir for this run and removes it on exit.
use_tmp() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
}

# Writes the starter config on first run: watch the usual code folders that exist, no repos yet.
ensure_config() {
  local roots=() r
  [ -f "$CONFIG" ] && return
  for r in "${DEFAULT_ROOTS[@]}"; do
    [ -d "$HOME/$r" ] && roots+=("$(tilde "$HOME/$r")")
  done
  [ ${#roots[@]} -eq 0 ] && roots=("$(tilde "$HOME/Projects")")
  mkdir -p "$(dirname "$CONFIG")"
  jq -n --args '{version: 1, roots: $ARGS.positional, idleStopHours: "", editor: "", repos: {}}' "${roots[@]}" > "$CONFIG"
}

# Flattens the config into tab-separated rows ("-" marks an empty value) so awk can read it.
load_config() {
  local r
  ensure_config
  jq -r '
    def v: if . == null or . == "" then "-" else tostring end;
    def home: if type == "string" then sub("^~"; env.HOME) else . end;
    "opt\tidleStopHours\t\(.idleStopHours | v)",
    "opt\teditor\t\(.editor | v)",
    ((.roots // [])[] | "root\t\(home)"),
    (.repos // {} | to_entries[] | .key as $k | .value as $r |
      "repo\t\($k)\t\($r.name // $k | v)\t\($r.path | home | v)\t\($r.ports | v)\t\($r.defaultPort | v)\t\($r.copyIfMissing | v)",
      ($r.modes // [] | to_entries[] |
        "mode\t\($k)\t\(.key)\t\(.value.name | v)\t\(.value.start | v)\t\(.value.url | v)\t\(.value.detect | v)\t\(.value.defaultPortUrl | v)"))
  ' "$CONFIG" > "$TMP/cfg" 2> "$TMP/cfg.err"
  ROOTS=()
  while IFS= read -r r; do ROOTS+=("$r"); done < <(awk -F'\t' '$1 == "root" { print $2 }' "$TMP/cfg")
}

cfg_opt() { awk -F'\t' -v k="$1" '$1 == "opt" && $2 == k { print ($3 == "-" ? "" : $3) }' "$TMP/cfg"; }

# Snapshot of every process as "pid ppid etime %cpu rss-kb name args", taken once per run.
# The name is the basename of the first argument, because ps truncates its comm column.
snapshot_ps() {
  ps -axo pid=,ppid=,etime=,pcpu=,rss=,comm=,args= | awk '{
    n = split($7, c, "/"); $6 = c[n]; print }' > "$TMP/ps"
}

ps_field() { awk -v p="$1" -v f="$2" '$1 == p { print $f; exit }' "$TMP/ps"; }

ps_args() { awk -v p="$1" '$1 == p { for (i = 1; i <= 6; i++) $i = ""; sub(/^ +/, ""); print; exit }' "$TMP/ps"; }

# Prints "pid<TAB>port<TAB>cwd" for every listening TCP socket whose process runs inside a watched
# folder. Also leaves every listener ("pid<TAB>port") in $TMP/raw for port-conflict checks.
list_listeners() {
  local pids pid port cwd r
  lsof -nP -iTCP -sTCP:LISTEN -Fpn 2>/dev/null | awk '
    /^p/ { pid = substr($0, 2) }
    /^n/ { n = split($0, a, ":"); print pid "\t" a[n] }' | sort -u > "$TMP/raw"
  [ -s "$TMP/raw" ] || return 0
  pids=$(cut -f1 "$TMP/raw" | sort -u | paste -sd, -)
  lsof -a -p "$pids" -d cwd -Fpn 2>/dev/null | awk '
    /^p/ { pid = substr($0, 2) }
    /^n/ { print pid "\t" substr($0, 2) }' > "$TMP/cwd"
  while IFS=$'\t' read -r pid port; do
    cwd=$(awk -F'\t' -v p="$pid" '$1 == p { print $2; exit }' "$TMP/cwd")
    for r in "${ROOTS[@]}"; do
      case "$cwd" in "$r"/*) printf '%s\t%s\t%s\n' "$pid" "$port" "$cwd"; break ;; esac
    done
  done < "$TMP/raw"
}

repo_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || echo "$1"; }

main_checkout() {
  local c
  if c=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    dirname "$c"
  else
    echo "$1"
  fi
}

# Identifies a repo by its origin remote ("owner/repo"), so every worktree shares one settings entry.
remote_key() {
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null)
  if [ -n "$url" ]; then
    printf '%s\n' "$url" | sed -E 's#\.git$##; s#^.*[:/]([^/:]+/[^/:]+)$#\1#'
  else
    echo "local/$(basename "$(main_checkout "$1")")"
  fi
}

branch_of() {
  git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$1" rev-parse --short HEAD 2>/dev/null
}

# File-name-safe id for a worktree path, used for per-server state files.
sid() { printf '%s' "$1" | tr '/' '%'; }

# Walks up from a listening process through runtime and package-manager parents (node, bun, npm,
# ...), so stopping it also ends wrappers like `npm run dev`. Shells, terminals and apps are never
# included.
find_top() {
  local p=$1 pp name
  while :; do
    pp=$(ps_field "$p" 2)
    { [ -z "$pp" ] || [ "$pp" -le 1 ]; } && break
    name=$(ps_field "$pp" 6)
    [[ "$name" =~ $SERVER_COMMS_RE ]] || break
    p=$pp
  done
  echo "$p"
}

# Command lines of up to 4 parents, used only to detect a server's mode (e.g. `npm run start:qa`
# often sits above the `sh -c` wrapper that find_top stops at).
ancestor_args() {
  awk -v p="$1" '
    { ppid[$1] = $2; a = $0; for (i = 1; i <= 6; i++) sub(/^ *[^ ]+/, "", a); args[$1] = a }
    END { for (i = 0; i < 4 && (p = ppid[p]) > 1; i++) print args[p] }' "$TMP/ps"
}

descendants() {
  awk -v root="$1" '
    { kids[$2] = kids[$2] " " $1 }
    END {
      queue = root
      while (queue != "") {
        split(queue, q, " "); queue = ""
        for (i in q) { print q[i]; queue = queue kids[q[i]] }
      }
    }' "$TMP/ps"
}

# Sends SIGTERM to a process tree, then SIGKILL to anything still alive after 5 seconds.
kill_tree() {
  local pids i
  pids=$(descendants "$1" | sort -u)
  # shellcheck disable=SC2086
  kill -TERM $pids 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do
    # shellcheck disable=SC2086
    kill -0 $pids 2>/dev/null || return 0
    sleep 0.5
  done
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null
}

# Stops a worktree's server and marks the exit as expected, so it isn't reported as a crash.
# Only kills PIDs whose working directory is inside that worktree.
stop_root() {
  local root=$1 pid cwd
  shift
  mkdir -p "$STATE_DIR/expected"
  touch "$STATE_DIR/expected/$(sid "$root")"
  for pid in "$@"; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    case "$cwd" in "$root" | "$root"/*) kill_tree "$(find_top "$pid")" ;; esac
  done
  rm -f "$STATE_DIR/pending/$(sid "$root")" "$STATE_DIR/failed/$(sid "$root")"
  wake_menu
}

# Records a server that was just launched, so the menu can list it as starting before its port opens.
# Fields are separated by \037 rather than tabs, because read merges empty tab-separated fields.
mark_pending() {
  local dir=$1 label=$2 port=$3 pid=$4
  mkdir -p "$STATE_DIR/pending"
  rm -f "$STATE_DIR/failed/$(sid "$dir")"
  printf '%s\037%s\037%s\037%s\n' "$label" "$port" "$pid" "$(date +%s)" > "$STATE_DIR/pending/$(sid "$dir")"
  wake_menu
}

# Records a server started from the menu, so a later crash can be reported with its log and a
# Retry. The remaining arguments are the plugin command that starts it again.
mark_managed() {
  local dir=$1 label=$2 log=$3
  shift 3
  mkdir -p "$STATE_DIR/managed"
  rm -f "$STATE_DIR/managed/$(sid "$dir").seen" "$STATE_DIR/expected/$(sid "$dir")"
  (IFS=$'\037' && printf '%s\n' "$label$IFS$log$IFS$*") > "$STATE_DIR/managed/$(sid "$dir")"
}

# Records a start or a server that failed, for the menu's failed row: the error, the PID if it's
# still running, and the plugin command that retries it (the remaining arguments).
record_failure() {
  local dir=$1 label=$2 log=$3 err=$4 pid=$5
  shift 5
  mkdir -p "$STATE_DIR/failed"
  (IFS=$'\037' && printf '%s\n' "$label$IFS$log$IFS$err$IFS$pid$IFS$*") > "$STATE_DIR/failed/$(sid "$dir")"
  rm -f "$STATE_DIR/managed/$(sid "$dir")" "$STATE_DIR/pending/$(sid "$dir")"
  wake_menu
}

# Log file for a start, named after the folder and the port or mode, kept safe for file names.
log_path() { printf '%s/%s-%s.log\n' "$LOG_DIR" "$(basename "$1")" "${2//[^A-Za-z0-9._-]/-}"; }

# Asks the running menu loop to re-render now instead of on its next tick. Checks the PID still
# belongs to this plugin first, since USR1 would terminate an unrelated process.
wake_menu() {
  local pid
  pid=$(cat "$STATE_DIR/stream.pid" 2>/dev/null)
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  case "$(ps -p "$pid" -o args= 2>/dev/null)" in *"/${SELF##*/}") kill -USR1 "$pid" 2>/dev/null ;; esac
  return 0
}

# Shows a notification titled "Dev Servers" with a subtitle ($1), body ($2) and an optional link
# opened on click ($3). Goes through SwiftBar, so it carries SwiftBar's icon rather than Script
# Editor's, and falls back to AppleScript only if SwiftBar can't take the request. DEV_SERVERS_QUIET=1 turns
# notifications and the Settings window off and appends them to $CACHE_DIR/notifications.log
# instead, for tests.
notify() {
  if [ -n "${DEV_SERVERS_QUIET:-}" ]; then
    mkdir -p "$CACHE_DIR" && printf '%s\t%s\n' "$1" "$2" >> "$CACHE_DIR/notifications.log"
    return 0
  fi
  open -g "swiftbar://notify?$(jq -rn --arg p "${SELF##*/}" --arg s "$1" --arg b "$2" --arg h "${3:-}" \
    '"plugin=\($p | @uri)&title=Dev%20Servers&subtitle=\($s | @uri)&body=\($b | @uri)" + (if $h != "" then "&href=\($h | @uri)" else "" end)')" \
    2> /dev/null && return 0
  osascript - "$1" "$2" > /dev/null 2>&1 <<'EOF'
on run argv
  display notification (item 2 of argv) with title "Dev Servers" subtitle (item 1 of argv)
end run
EOF
}

# One line about a running server for stop notifications: "branch · :ports · was up 2h5m".
# Needs the process snapshot ($TMP/ps); the PIDs are the server's listening processes.
server_brief() {
  local root=$1 ports up
  shift
  [ $# -gt 0 ] || { branch_of "$root"; return; }
  ports=$(lsof -nP -a -p "$(printf '%s,' "$@" | sed 's/,$//')" -iTCP -sTCP:LISTEN -Fn 2>/dev/null |
    sed -nE 's/^n.*:([0-9]+)$/:\1/p' | sort -u | paste -sd' ' -)
  up=$(server_stats "$(find_top "$1")" 0 "" | cut -d $'\037' -f4)
  echo "$(branch_of "$root")${ports:+ · $ports}${up:+ · was up $up}"
}

# Shows the native folder picker; prints the chosen path, or nothing if cancelled.
pick_folder() {
  osascript - "$1" 2>/dev/null <<'EOF'
on run argv
  activate
  return POSIX path of (choose folder with prompt (item 1 of argv))
end run
EOF
}

# Last non-empty log line without colour codes, for crash notifications.
log_tail() {
  [ -f "$1" ] || return 0
  tail -n 20 "$1" | LC_ALL=C sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g' | awk '
    NF { last = $0 }
    /[Ee]rror|ERR!|not found|[Cc]annot|[Ff]ailed/ && !/script ".*" exited with code/ { err = $0 }
    END { if (err != "") last = err; sub(/^[ \t]+/, "", last); print substr(last, 1, 140) }'
}

port_busy() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

# Picks the first free port from a range like "3001-3009" (or a single port).
free_port() {
  local lo=${1%-*} hi=${1#*-} p
  for ((p = lo; p <= hi; p++)); do
    port_busy "$p" || { echo "$p"; return; }
  done
}

# Quick HTTP check against a static-asset path, so frameworks like Next.js answer without compiling
# a page. Prints the status code, or 000 when the server doesn't answer within 2s (usually busy).
probe() {
  curl -s --noproxy '*' -o /dev/null -I -m 2 -w '%{http_code}' "http://localhost:$1/_next/static/dev-servers-health" 2>/dev/null
}

pkg_manager() {
  if [ -f "$1/bun.lock" ] || [ -f "$1/bun.lockb" ]; then echo bun
  elif [ -f "$1/pnpm-lock.yaml" ]; then echo pnpm
  elif [ -f "$1/yarn.lock" ]; then echo yarn
  else echo npm; fi
}

# The editor command to open folders with: the configured one, else the first one installed.
editor_cmd() {
  local e configured
  configured=$(cfg_opt editor)
  if [ -n "$configured" ]; then
    command -v "$configured" 2>/dev/null
    return
  fi
  for e in "${EDITORS[@]}"; do
    command -v "$e" 2>/dev/null && return
  done
}

editor_label() {
  case "$(basename "$1")" in
    code) echo "VS Code" ;;
    cursor) echo "Cursor" ;;
    zed) echo "Zed" ;;
    subl) echo "Sublime Text" ;;
    *) basename "$1" ;;
  esac
}

# Runs a command detached in a login zsh (so PATH and version managers load), logging to LOG_DIR.
# Uses the repo's .nvmrc through nvm when nvm is installed. Sets LAUNCH_PID to the wrapper process.
launch() {
  local dir=$1 cmd=$2 log=$3
  mkdir -p "$LOG_DIR"
  : > "$log"
  cd "$dir" || return 1
  nohup /bin/zsh -lc "export NVM_DIR=\"\${NVM_DIR:-\$HOME/.nvm}\"; if [ -s \"\$NVM_DIR/nvm.sh\" ]; then . \"\$NVM_DIR/nvm.sh\"; [ -f .nvmrc ] && nvm use --silent >/dev/null 2>&1; fi; $cmd" \
    >> "$log" 2>&1 < /dev/null &
  LAUNCH_PID=$!
  disown
}

# True when something inside the folder is listening on a TCP port.
dir_listening() {
  local pid cwd
  for pid in $(lsof -nP -t -iTCP -sTCP:LISTEN 2>/dev/null | sort -u); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    case "$cwd" in "$1" | "$1"/*) return 0 ;; esac
  done
  return 1
}

# Watches a start until it's listening, then says so. With a known port it checks that port;
# without one, the menu clears the pending entry once it sees the server listening. If the process
# exits first, or nothing listens within PENDING_TIMEOUT, it records a failed row and notifies.
# The URL ($6) is linked from the "is up" notification. The remaining arguments are the plugin
# command that retries the start.
watch_start() {
  local name=$1 pid=$2 log=$3 dir=$4 port=$5 url=$6 pending label err began deadline mins
  shift 6
  pending="$STATE_DIR/pending/$(sid "$dir")"
  label=$(cut -d $'\037' -f1 "$pending" 2>/dev/null)
  began=$(date +%s)
  deadline=$((began + PENDING_TIMEOUT))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -n "$port" ] && port_busy "$port"; then
      notify "$name is up" "${label:+$label · }${url:-:$port} · ready in $(($(date +%s) - began))s" "$url"
      return
    fi
    [ -f "$pending" ] || return
    if ! kill -0 "$pid" 2>/dev/null; then
      [ -z "$port" ] && dir_listening "$dir" && return
      err=$(log_tail "$log")
      err=${err:-Exited before opening a port}
      record_failure "$dir" "$label" "$log" "$err" "" "$@"
      notify "$name failed to start" "$err"
      return
    fi
    sleep 1
  done
  [ -f "$pending" ] || return
  mins=$((PENDING_TIMEOUT / 60))
  record_failure "$dir" "$label" "$log" "Not up after $mins minutes" "$pid" "$@"
  notify "$name isn't up after $mins minutes" "${label:+$label · }still running. Stop or retry it from the menu."
}

# Starts a configured repo's worktree in a mode. An explicit port (used by Restart) wins over the range.
cmd_start() {
  local key=$1 dir=$2 idx=$3 want_port=$4 row name path ports dport copy mname start url defurl port log f
  use_tmp
  load_config
  row=$(awk -F'\t' -v k="$key" -v i="$idx" '
    $1 == "repo" && $2 == k { r = $3 "\037" $4 "\037" $5 "\037" $6 "\037" $7 }
    $1 == "mode" && $2 == k && $3 == i { m = $4 "\037" $5 "\037" $6 "\037" $8 }
    END { if (r != "" && m != "") print r "\037" m }' "$TMP/cfg")
  [ -z "$row" ] && { notify "Can't start ${dir##*/}" "No settings found for $key"; exit 1; }
  IFS=$'\037' read -r name path ports dport copy mname start url defurl <<< "$row"
  [ "$start" = - ] && { notify "Can't start ${dir##*/}" "Add a start command for $name · $mname in Settings"; exit 1; }

  port=""
  if [ -n "$want_port" ]; then
    port_busy "$want_port" && { notify "Can't start ${dir##*/}" ":$want_port is still in use"; exit 1; }
    port=$want_port
  elif [ "$ports" != - ]; then
    port=$(free_port "$ports")
    [ -z "$port" ] && { notify "Can't start ${dir##*/}" "No free port: $ports are all in use"; exit 1; }
  elif [[ "$start" == *"{port}"* ]]; then
    notify "Can't start ${dir##*/}" "The start command uses {port}, but $name has no port range"
    exit 1
  fi

  if [ "$copy" != - ] && [ "$path" != - ]; then
    IFS=',' read -ra files <<< "$copy"
    for f in "${files[@]}"; do
      f=$(printf '%s' "$f" | xargs)
      [ -n "$f" ] && [ ! -e "$dir/$f" ] && [ -e "$path/$f" ] && cp "$path/$f" "$dir/$f"
    done
  fi

  log=$(log_path "$dir" "${port:-$mname}")
  launch "$dir" "${start//\{port\}/$port}" "$log"
  mark_pending "$dir" "$mname" "$port" "$LAUNCH_PID"
  mark_managed "$dir" "$mname" "$log" start "$key" "$dir" "$idx"
  if [ -z "$port" ]; then url=""
  elif [ "$port" = "$dport" ] && [ "$defurl" != - ]; then url=$defurl
  elif [ "$url" != - ]; then url=${url//\{port\}/$port}
  else url="http://localhost:$port"; fi
  notify "Starting ${dir##*/}" "$mname${port:+ on :$port} · $(branch_of "$dir")"
  watch_start "${dir##*/}" "$LAUNCH_PID" "$log" "$dir" "$port" "$url" start "$key" "$dir" "$idx" > /dev/null 2>&1 < /dev/null &
  disown
}

# Starts a project that isn't set up in Settings with its package.json dev or start script.
cmd_start_other() {
  local dir=$1 script=$2 name pm log
  name=$(basename "$dir")
  pm=$(pkg_manager "$dir")
  log=$(log_path "$dir" "$script")
  launch "$dir" "$pm run $script" "$log"
  mark_pending "$dir" "$script" "" "$LAUNCH_PID"
  mark_managed "$dir" "$script" "$log" start-other "$dir" "$script"
  notify "Starting $name" "$pm run $script · $(branch_of "$dir")"
  watch_start "$name" "$LAUNCH_PID" "$log" "$dir" "" "" start-other "$dir" "$script" > /dev/null 2>&1 < /dev/null &
  disown
}

cmd_stop() {
  local root=$1 brief
  shift
  use_tmp
  snapshot_ps
  brief=$(server_brief "$root" "$@")
  stop_root "$root" "$@"
  notify "Stopped ${root##*/}" "$brief"
}

cmd_stop_idle() {
  local root=$1 hours=$2 brief
  shift 2
  use_tmp
  snapshot_ps
  brief=$(server_brief "$root" "$@")
  stop_root "$root" "$@"
  notify "Stopped idle ${root##*/}" "No browser for ${hours}h · $brief"
}

# Stops a server, waits for its port to free up, then starts it again with the same port and mode.
cmd_restart() {
  local root=$1 key=$2 idx=$3 port=$4 i
  [[ "$idx" =~ ^[0-9]+$ && "$port" =~ ^[0-9]+$ ]] || exit 1
  shift 4
  TMP=$(mktemp -d)
  snapshot_ps
  stop_root "$root" "$@"
  rm -rf "$TMP"
  for ((i = 0; i < 20; i++)); do
    port_busy "$port" || break
    sleep 0.5
  done
  exec "$SELF" start "$key" "$root" "$idx" "$port"
}

cmd_stop_all() {
  local pid port cwd f root names=""
  use_tmp
  load_config
  snapshot_ps
  while IFS=$'\t' read -r pid port cwd; do
    root=$(repo_root "$cwd")
    kill -0 "$pid" 2>/dev/null && stop_root "$root" "$pid" && names="$names${root##*/}"$'\n'
  done < <(list_listeners)
  for f in "$STATE_DIR"/pending/*; do
    [ -f "$f" ] || continue
    root=$(basename "$f" | tr '%' '/')
    stop_root "$root" "$(cut -d $'\037' -f3 "$f")"
    names="$names${root##*/}"$'\n'
  done
  names=$(printf '%s' "$names" | sort -u | paste -sd, - | sed 's/,/, /g')
  [ -n "$names" ] && notify "Stopped $(printf '%s\n' "$names" | tr ',' '\n' | wc -l | tr -d ' ') servers" "$names"
}

# Turns the plugin off or on. While off the icon stays, greyed, and the loop sleeps until woken:
# no scanning, health checks, notifications or idle auto-stop. Servers keep running either way.
cmd_power() {
  mkdir -p "$STATE_DIR"
  if [ "$1" = off ]; then touch "$STATE_DIR/off"; else rm -f "$STATE_DIR/off"; fi
  wake_menu
}

# Removes a failed start from the menu.
cmd_dismiss() {
  rm -f "$STATE_DIR/failed/$(sid "$1")"
  wake_menu
}

# Closes the settings backend and quits SwiftBar, which ends this plugin and any others it runs.
cmd_quit() {
  local pid
  pid=$(cut -f1 "$STATE_DIR/settings.info" 2>/dev/null)
  [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null
  rm -f "$STATE_DIR/settings.info" "$STATE_DIR/stream.pid"
  [ -n "${DEV_SERVERS_QUIET:-}" ] && return 0
  osascript -e 'tell application "SwiftBar" to quit' > /dev/null 2>&1
}

# >>> settings-assets
# Writes the settings window's files into $1. In the repo they're copied from src/settings;
# the release build replaces this function with embedded copies (see scripts/build.sh).
write_assets() {
  cp "$(dirname "$SELF")/settings/server.py" "$(dirname "$SELF")/settings/index.html" "$1/"
}
# <<< settings-assets

# Makes sure the settings files for this copy of the plugin exist and prints their folder. The
# folder is keyed by the plugin's contents, so an update refreshes them even without a new version.
ensure_assets() {
  local dir
  if [ "$VERSION" = dev ]; then dir="$SUPPORT_DIR/settings-dev"; else dir="$SUPPORT_DIR/settings-$(md5 -q "$SELF")"; fi
  if [ "$VERSION" = dev ] || [ ! -f "$dir/server.py" ] || [ ! -f "$dir/index.html" ]; then
    mkdir -p "$dir"
    write_assets "$dir"
  fi
  echo "$dir"
}

# Prints SwiftBar's app folder, looking where Homebrew and a manual install put it before asking
# Spotlight.
find_swiftbar() {
  local app
  for app in "/Applications/SwiftBar.app" "$HOME/Applications/SwiftBar.app"; do
    [ -d "$app" ] && { echo "$app"; return; }
  done
  mdfind "kMDItemCFBundleIdentifier == 'com.ameba.SwiftBar'" 2>/dev/null | head -n 1
}

# Points SwiftBar at the folder this plugin sits in and starts it, so the menu bar icon appears
# without the user picking a folder by hand. Used after a Homebrew install, which cannot do this
# itself.
cmd_enable() {
  local app dir current
  app=$(find_swiftbar)
  [ -n "$app" ] || {
    echo "SwiftBar isn't installed. Install it with: brew install --cask swiftbar" >&2
    exit 1
  }
  dir=${SELF%/*}
  [ -x "$SELF" ] || chmod +x "$SELF"
  current=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
  current=${current/#\~/$HOME}
  if [ -z "$current" ]; then
    defaults write com.ameba.SwiftBar PluginDirectory "$dir"
    echo "Set SwiftBar's plugin folder to $(tilde "$dir")"
  elif [ "$current" != "$dir" ]; then
    echo "SwiftBar already uses $(tilde "$current"), so this copy in $(tilde "$dir") stays unused." >&2
    echo "Either copy dev-servers.sh into that folder, or point SwiftBar at this one in its settings." >&2
    exit 1
  fi
  if pgrep -x SwiftBar > /dev/null; then
    open -g "swiftbar://refreshallplugins"
    echo "Refreshed SwiftBar"
  else
    open -a "$app"
    echo "Started SwiftBar"
  fi
  echo "Look for the server icon in your menu bar, then open Settings… from its menu to add your repos."
  echo "If the icon doesn't appear, your menu bar may be full: hide a few icons or hold ⌘ and drag it into view."
}

# Opens the settings window, starting its local backend if needed. With a folder argument the page
# adds that repo, or jumps to it if it's already set up.
cmd_settings() {
  local info="$STATE_DIR/settings.info" pid="" port="" token="" adir="" url assets i
  command -v python3 > /dev/null || {
    notify "Settings needs python3" "Install Apple's command line tools: xcode-select --install"
    exit 1
  }
  ensure_config
  mkdir -p "$STATE_DIR"
  [ -f "$info" ] && IFS=$'\t' read -r pid port token adir < "$info"
  assets=$(ensure_assets)
  if [ -n "$pid" ] && [ "$adir" != "$assets" ]; then
    kill "$pid" 2>/dev/null
    pid=""
  fi
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$info"
    (cd "$assets" && nohup python3 -I server.py "$CONFIG" "$SELF" index.html "$info" "$VERSION" > /dev/null 2>&1 < /dev/null &)
    for ((i = 0; i < 200; i++)); do
      [ -s "$info" ] && break
      sleep 0.05
    done
    IFS=$'\t' read -r pid port token adir < "$info" || { notify "Settings didn't open" "The settings helper failed to start"; exit 1; }
  fi
  for i in "$SUPPORT_DIR"/settings-*; do
    [ "$i" = "$assets" ] || rm -rf "$i"
  done
  url="http://127.0.0.1:$port/?t=$token"
  if [ -n "$1" ]; then
    open_app_window "$url&add=$(jq -rn --arg v "$(tilde "$1")" '$v | @uri')"
  else
    open_app_window "$url" "http://127.0.0.1:$port/"
  fi
}

# Brings a window of browser $1 whose page starts with $2 to the front, and fails when there is no
# such window or the browser won't answer. Asking an already running browser is much quicker than
# starting another copy of it, which is what opening an app window otherwise costs.
raise_window() {
  local answer
  answer=$(osascript - "$1" "$2" 2>/dev/null <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  set target to item 2 of argv
  if not (application appName is running) then return "no"
  tell application appName
    repeat with w in windows
      repeat with t in tabs of w
        if URL of t starts with target then
          set index of w to 1
          activate
          return "yes"
        end if
      end repeat
    end repeat
  end tell
  return "no"
end run
APPLESCRIPT
  ) || return 1
  [ "$answer" = yes ]
}

# Opens a URL as a standalone app window in a Chromium browser if one is installed, else in the
# default browser. With a page prefix in $2, a window already showing that page is raised instead.
open_app_window() {
  local app match="${2:-}"
  [ -n "${DEV_SERVERS_QUIET:-}" ] && return 0
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    if [ -d "/Applications/$app.app" ] || [ -d "$HOME/Applications/$app.app" ]; then
      if [ -n "$match" ] && raise_window "$app" "$match"; then return; fi
      open -na "$app" --args --app="$1" --window-size=820,860
      return
    fi
  done
  open "$1"
}

# Describes a folder for the settings window: repo key, main checkout, name and a suggested start.
cmd_inspect() {
  local dir main script
  dir=$(untilde "$1")
  [ -d "$dir" ] || { echo '{"error":"Folder not found"}'; return; }
  main=$(main_checkout "$dir")
  script=$(jq -r '.scripts | if has("dev") then "dev" elif has("start") then "start" else "dev" end' "$main/package.json" 2>/dev/null)
  jq -n --arg key "$(remote_key "$dir")" --arg path "$(tilde "$main")" --arg name "$(basename "$main")" \
    --arg start "$(pkg_manager "$main") run ${script:-dev}" '{key: $key, path: $path, name: $name, start: $start}'
}

# Prints a repo's worktrees, skipping ones git marks as prunable (deleted folders). A folder that
# isn't a git repo is listed as itself.
live_worktrees() {
  git -C "$1" worktree list --porcelain 2>/dev/null | awk '
    /^worktree / { if (p != "") print p; p = substr($0, 10) }
    /^prunable/ { p = "" }
    END { if (p != "") print p }' | grep . || echo "$1"
}

# Builds start-menu rows: "repo<TAB>key<TAB>dir<TAB>branch" for worktrees of configured repos, and
# "other<TAB>-<TAB>dir<TAB>script" for other package.json projects in watched folders. Cached.
build_start_targets() {
  local key path wt root dir s
  : > "$TMP/known"
  while IFS=$'\t' read -r key path; do
    [ "$path" = - ] && continue
    while read -r wt; do
      [ -d "$wt" ] || continue
      echo "$wt" >> "$TMP/known"
      printf 'repo\t%s\t%s\t%s\n' "$key" "$wt" "$(git -C "$wt" symbolic-ref --short -q HEAD 2>/dev/null || echo detached)"
    done < <(live_worktrees "$path")
  done < <(awk -F'\t' '$1 == "repo" { print $2 "\t" $4 }' "$TMP/cfg")
  for root in "${ROOTS[@]}"; do
    for dir in "$root"/*/; do
      dir=${dir%/}
      [ -f "$dir/package.json" ] || continue
      grep -qxF "$dir" "$TMP/known" && continue
      s=$(jq -r '.scripts | if has("dev") then "dev" elif has("start") then "start" else empty end' "$dir/package.json" 2>/dev/null)
      [ -n "$s" ] && printf 'other\t-\t%s\t%s\n' "$dir" "$s"
    done
  done
}

start_targets() {
  local f="$CACHE_DIR/start-targets.tsv" age
  mkdir -p "$CACHE_DIR"
  age=$(($(date +%s) - $(stat -f %m "$f" 2>/dev/null || echo 0)))
  if [ "$age" -gt "$START_MENU_TTL" ] || [ "$CONFIG" -nt "$f" ]; then
    build_start_targets > "$f.$$" && mv "$f.$$" "$f"
  fi
  cat "$f"
}

# Picks the main port and mode for a running server and builds its URL from the repo's settings.
# Prints "port \037 mode-label \037 url \037 configured(0|1) \037 mode-index \037 has-start(0|1)".
resolve_server() {
  awk -F'\t' -v k="$1" -v ports="$2" -v argsf="$TMP/args" '
    function repl(s, p,   i) { while ((i = index(s, "{port}")) > 0) s = substr(s, 1, i - 1) p substr(s, i + 6); return s }
    function inrange(p, r,   a, n) { if (r == "-") return 0; n = split(r, a, "-"); return p + 0 >= a[1] + 0 && p + 0 <= a[n] + 0 }
    BEGIN { while ((getline l < argsf) > 0) args = args " " l }
    $1 == "repo" && $2 == k { found = 1; range = $5; dport = $6 }
    $1 == "mode" && $2 == k { nm++; midx[nm] = $3; mname[nm] = $4; mstart[nm] = $5; murl[nm] = $6; mdet[nm] = $7; mdef[nm] = $8 }
    END {
      np = split(ports, pl, " "); main = pl[1]
      for (i = 1; i <= np; i++) if (pl[i] == dport || inrange(pl[i], range)) { main = pl[i]; break }
      if (!found || nm == 0) { printf "%s\037\037http://localhost:%s\037%d\037\0370\n", main, main, found; exit }
      m = 0
      for (i = 1; i <= nm; i++) if (mdet[i] != "-" && index(args, mdet[i]) > 0) { m = i; break }
      if (!m) for (i = 1; i <= nm; i++) if (mdet[i] == "-") { m = i; break }
      if (!m) m = 1
      if (main == dport && mdef[m] != "-") url = mdef[m]
      else if (murl[m] != "-") url = repl(murl[m], main)
      else url = "http://localhost:" main
      printf "%s\037%s\037%s\0371\037%s\037%d\n", main, (nm > 1 ? mname[m] : ""), url, midx[m], (mstart[m] != "-")
    }' "$TMP/cfg"
}

# Compact usage text for a server's whole process tree, plus raw totals for the summary line.
# Prints "text \037 cpu% \037 rss-kb \037 uptime".
server_stats() {
  awk -v root="$1" -v idle="$2" -v status="$3" '
    function esecs(t,   d, p, n) {
      d = 0
      if (index(t, "-")) { d = substr(t, 1, index(t, "-") - 1); t = substr(t, index(t, "-") + 1) }
      n = split(t, p, ":")
      return d * 86400 + (n == 3 ? p[1] * 3600 + p[2] * 60 + p[3] : p[1] * 60 + p[2])
    }
    function dur(s,   m) {
      if (s < 60) return "<1m"
      if (s < 3600) return int(s / 60) "m"
      if (s < 86400) { m = int(s % 3600 / 60); return int(s / 3600) "h" (m ? m "m" : "") }
      return int(s / 86400) "d"
    }
    function mem(kb) { return kb >= 1048576 ? sprintf("%.1fG", kb / 1048576) : sprintf("%dM", kb / 1024) }
    { kids[$2] = kids[$2] " " $1; cpu[$1] = $4; rss[$1] = $5; et[$1] = $3 }
    END {
      q = root
      while (q != "") { split(q, a, " "); q = ""; for (i in a) { c += cpu[a[i]]; r += rss[a[i]]; q = q kids[a[i]] } }
      s = mem(r) " · " int(c + 0.5) "%"
      if (status != "") s = s " · " status
      if (idle >= 900) s = s " · idle " dur(idle)
      printf "%s\037%d\037%d\037%s\n", s, c + 0.5, r, dur(esecs(et[root]))
    }' "$TMP/ps"
}

# Short warnings: no free port left in a repo's range, ports in a range held by other apps, and
# servers running outside their repo's range.
port_warnings() {
  awk -F'\t' -v psf="$TMP/ps" -v srvf="$TMP/srv" -v rawf="$TMP/raw" '
    function inrange(p, lo, hi) { return p + 0 >= lo + 0 && p + 0 <= hi + 0 }
    BEGIN {
      while ((getline l < psf) > 0) { split(l, f, " "); comm[f[1]] = f[6] }
      while ((getline l < srvf) > 0) {
        split(l, f, "\t"); devpid[f[1]] = 1
        if (!(f[2] in seen)) { seen[f[2]] = 1; sname[++ns] = f[2]; skey[ns] = f[3]; sport[ns] = f[4] }
      }
      while ((getline l < rawf) > 0) { split(l, f, "\t"); busy[f[2]] = f[1] }
    }
    $1 == "repo" && $5 != "-" {
      nr++; key[nr] = $2; name[nr] = $3; dport[nr] = $6
      n = split($5, a, "-"); lo[nr] = a[1]; hi[nr] = a[n]
    }
    END {
      for (i = 1; i <= nr; i++) {
        used = 0
        for (p = lo[i]; p <= hi[i]; p++) if (p in busy) {
          used++
          if (!(busy[p] in devpid)) print ":" p " is held by " comm[busy[p]] " (" name[i] " range)"
        }
        if (used == hi[i] - lo[i] + 1) print "No free port left in " lo[i] "-" hi[i]
        for (s = 1; s <= ns; s++)
          if (skey[s] == key[i] && sport[s] != dport[i] && !inrange(sport[s], lo[i], hi[i]))
            print sname[s] " is on :" sport[s] ", outside " lo[i] "-" hi[i]
      }
    }' "$TMP/cfg"
}

# Reports servers started from the menu that disappeared without a Stop, as a notification and a
# failed row with a Retry, and clears state for servers that are gone.
crash_check() {
  local f id root label log a1 a2 a3 a4 err
  mkdir -p "$STATE_DIR/managed" "$STATE_DIR/expected" "$STATE_DIR/active"
  for f in "$STATE_DIR"/managed/*; do
    [ -f "$f" ] || continue
    case "$f" in *.seen) continue ;; esac
    id=$(basename "$f")
    root=$(printf '%s' "$id" | tr '%' '/')
    if grep -qxF "$root" "$TMP/roots"; then
      touch "$f.seen"
    elif [ -f "$f.seen" ]; then
      if [ ! -f "$STATE_DIR/expected/$id" ]; then
        IFS=$'\037' read -r label log a1 a2 a3 a4 < "$f"
        err=$(log_tail "$log")
        # shellcheck disable=SC2086
        record_failure "$root" "$label" "$log" "Stopped unexpectedly${err:+: $err}" "" "$a1" "$a2" "$a3" ${a4:+"$a4"}
        notify "$(basename "$root") stopped unexpectedly" "$err"
      fi
      rm -f "$f" "$f.seen"
    elif [ -n "$(find "$f" -mmin +5 2>/dev/null)" ]; then
      rm -f "$f"
    fi
  done
  for f in "$STATE_DIR"/expected/* "$STATE_DIR"/active/*; do
    [ -f "$f" ] || continue
    root=$(basename "$f" | tr '%' '/')
    grep -qxF "$root" "$TMP/roots" || rm -f "$f"
  done
}

# Prints the menu entry for a server that was launched from the menu and isn't listening yet.
pending_entry() {
  local root=$1 label=$2 port=$3 pid=$4 editor=$5 branch qr
  branch=$(branch_of "$root")
  qr=$(q "$root")
  echo "${root##*/}  ${port:+:$port  }$label  ·  starting… | image=$DOT_PENDING tooltip=\"Starting, waiting for the port to open\""
  echo "--Reveal in Finder | bash=/usr/bin/open param1=$qr terminal=false sfimage=folder"
  [ -n "$editor" ] && echo "--Open in $(editor_label "$editor") | bash=$(q "$editor") param1=$qr terminal=false sfimage=chevron.left.forwardslash.chevron.right"
  echo "-----"
  echo "--$(tilde "$root") | size=11 $GRAY"
  echo "--${branch:-no git}  ·  pid $pid | size=11 $GRAY"
  if [ -n "$port" ]; then echo "Waiting for :$port | sfimage=hourglass size=12"; else echo "Waiting for a port | sfimage=hourglass size=12"; fi
  echo "Stop | bash=$QSELF param1=stop param2=$qr param3=$pid terminal=false image=$ICON_STOP size=12"
}

# Writes menu entries for servers that are still starting to $TMP/prows, and their worktrees to
# $TMP/proots. Drops entries once the server is listening, or a minute after watch_start should have
# reported a timeout. Hides entries whose process exited, leaving them for watch_start to report.
render_pending() {
  local now=$1 editor=$2 f root label port pid started
  : > "$TMP/prows"
  : > "$TMP/proots"
  for f in "$STATE_DIR"/pending/*; do
    [ -f "$f" ] || continue
    root=$(basename "$f" | tr '%' '/')
    IFS=$'\037' read -r label port pid started < "$f"
    if grep -qxF "$root" "$TMP/roots" || [ $((now - started)) -gt $((PENDING_TIMEOUT + 60)) ]; then
      rm -f "$f"
      continue
    fi
    kill -0 "$pid" 2>/dev/null || continue
    echo "$root" >> "$TMP/proots"
    [ -s "$TMP/prows" ] && echo "---" >> "$TMP/prows"
    pending_entry "$root" "$label" "$port" "$pid" "$editor" >> "$TMP/prows"
  done
}

# Writes menu entries for starts and servers that failed to $TMP/frows: the error, the end of the
# log in a submenu, and Retry and Dismiss, or Stop while a start that timed out is still running.
# An entry stays until it's dismissed, stopped, or the folder starts again.
render_failed() {
  local f root qr label log err pid a1 a2 a3 a4 line
  : > "$TMP/frows"
  for f in "$STATE_DIR"/failed/*; do
    [ -f "$f" ] || continue
    root=$(basename "$f" | tr '%' '/')
    if grep -qxF "$root" "$TMP/roots" || grep -qxF "$root" "$TMP/proots"; then
      rm -f "$f"
      continue
    fi
    IFS=$'\037' read -r label log err pid a1 a2 a3 a4 < "$f"
    err=${err//|/¦}
    err=${err//\"/}
    qr=$(q "$root")
    [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && pid=""
    {
      [ -s "$TMP/frows" ] && echo "---"
      echo "${root##*/}  ${label:+$label  }·  failed | image=$DOT_RED tooltip=\"$err\""
      if [ -f "$log" ]; then
        tail -n 40 "$log" | LC_ALL=C sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g' | awk 'NF' | tail -n 8 | while IFS= read -r line; do
          line=${line//|/¦}
          echo "--${line:0:100} | size=11 font=Menlo $GRAY"
        done
        echo "-----"
      fi
      echo "--Reveal in Finder | bash=/usr/bin/open param1=$qr terminal=false sfimage=folder"
      echo "${err:0:70} | size=11 color=$RED"
      if [ -n "$pid" ]; then
        echo "Stop | bash=$QSELF param1=stop param2=$qr param3=$pid terminal=false image=$ICON_STOP size=12"
      else
        echo "Retry | bash=$QSELF param1=$a1 param2=$(q "$a2") param3=$(q "$a3") ${a4:+param4=$(q "$a4") }terminal=false sfimage=arrow.clockwise size=12"
      fi
      echo "Dismiss | bash=$QSELF param1=dismiss param2=$qr terminal=false sfimage=xmark size=12"
    } >> "$TMP/frows"
  done
}

# Adds servers started since the last full render ($STATE_DIR/rendered) to the previous menu, so a
# Start shows up at once while the slower full render runs. Bumps the count, turns the icon orange
# unless it's red, and puts the new entries at the top of the server list. Skips the editor item,
# which needs the config, since the full render replaces this within a second or two. Fails when
# there's nothing new to add, or when the previous menu already lists the new entries.
splice_pending() {
  local prev=$1 f root label port pid started k=0
  TMP=$(mktemp -d)
  for f in "$STATE_DIR"/pending/*; do
    [ -f "$f" ] && [ -n "$(find "$f" -newer "$STATE_DIR/rendered" 2>/dev/null)" ] || continue
    root=$(basename "$f" | tr '%' '/')
    IFS=$'\037' read -r label port pid started < "$f"
    case "$prev" in *"param1=stop param2=$(q "$root") param3=$pid "*) continue ;; esac
    [ -s "$TMP/quick" ] && echo "---" >> "$TMP/quick"
    pending_entry "$root" "$label" "$port" "$pid" "" >> "$TMP/quick"
    k=$((k + 1))
  done
  if [ "$k" -gt 0 ]; then
    printf '%s\n' "$prev" | awk -v k="$k" -v quick="$TMP/quick" -v orange="$(sfc "$ORANGE")" -v red="$(sfc "$RED")" -v gray="$GRAY" '
      { line[NR] = $0 }
      END {
        n = line[1] ~ /^[0-9]+ / ? line[1] + k : k
        printf "%d | sfimage=server.rack sfconfig=%s\n%s\n", n, (index(line[1], red) ? red : orange), line[2]
        empty = line[3] ~ /^No dev servers running/
        print (empty ? k " starting | size=11 " gray : line[3])
        for (i = 4; i <= NR && line[i] ~ /exclamationmark\.triangle/; i++) print line[i]
        while ((getline l < quick) > 0) print l
        if (!empty) print "---"
        for (; i <= NR; i++) print line[i]
      }'
  fi
  rm -rf "$TMP"
  [ "$k" -gt 0 ]
}

# Prints "param3=pid param4=pid ..." numbered from $1, for SwiftBar actions that take PIDs.
pid_params() {
  local i=$1 p
  shift
  for p in "$@"; do
    printf 'param%d=%s ' "$i" "$p"
    i=$((i + 1))
  done
}

render_start_menus() {
  start_targets | awk -F'\t' -v self="$QSELF" -v groups="$TMP/groups" -v pending="$TMP/proots" -v cfg="$TMP/cfg" -v gray="$GRAY" '
    function q(v) { return index(v, "\"") ? "\047" v "\047" : "\"" v "\"" }
    BEGIN {
      while ((getline l < groups) > 0) { split(l, g, "\t"); running[g[1]] = "running" }
      while ((getline l < pending) > 0) running[l] = "starting"
      while ((getline l < cfg) > 0) {
        split(l, c, "\t")
        if (c[1] == "repo") { nr++; rk[nr] = c[2]; rn[c[2]] = c[3] }
        if (c[1] == "mode") { j = ++nm[c[2]]; mn[c[2], j] = c[4]; mi[c[2], j] = c[3]; ms[c[2], j] = c[5] }
      }
    }
    {
      n = split($3, parts, "/"); name = parts[n]
      if ($1 == "repo") {
        k = $2
        if ($3 in running) { out[k] = out[k] "--" name " (" $4 ") is " running[$3] " | " gray "\n"; next }
        out[k] = out[k] "--" name "  (" $4 ")\n"
        for (j = 1; j <= nm[k]; j++)
          out[k] = out[k] "----" mn[k, j] "  ·  " ms[k, j] " | bash=" self " param1=start param2=" q(k) " param3=" q($3) " param4=" mi[k, j] " terminal=false\n"
      } else if (!($3 in running)) {
        other = other "--" name " (" $4 ") | bash=" self " param1=start-other param2=" q($3) " param3=" q($4) " terminal=false\n"
      }
    }
    END {
      for (i = 1; i <= nr; i++) if (out[rk[i]] != "") printf "Start %s | sfimage=play.circle\n%s", rn[rk[i]], out[rk[i]]
      if (other != "") printf "Start other project | sfimage=play.circle\n%s", other
    }'
}

# Gives every submenu parent a no-op action. SwiftBar 2.1.1 reuses menu items by position on each
# refresh, and a reused item that loses its action while gaining a submenu stays greyed out and
# unexpandable until SwiftBar restarts (swiftbar/SwiftBar#515, fixed in 2.1.2). AppKit never runs a
# parent's action, so the no-op only keeps SwiftBar's state consistent.
mark_parents() {
  awk '
    function level(l,   n) {
      if (l ~ /^(--)*---$/) return (length(l) - 3) / 2
      n = 0
      while (substr(l, 2 * n + 1, 2) == "--") n++
      return n
    }
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        l = line[i]
        if (i < NR && l !~ /^(--)*---$/ && l !~ /^~~~$/ && level(line[i + 1]) > level(l) && l !~ /(bash|href)=/)
          l = l (index(l, " | ") ? " " : " | ") "bash=/usr/bin/true terminal=false"
        print l
      }
    }'
}

render_off() {
  echo " | sfimage=server.rack sfconfig=$(sfc "#8E8E93")"
  echo "---"
  echo "Dev Servers is off | size=11 $GRAY"
  echo "Turn on | bash=$QSELF param1=on terminal=false sfimage=power"
  echo "Quit SwiftBar | bash=$QSELF param1=quit terminal=false sfimage=xmark.circle tooltip=\"Closes SwiftBar and every plugin it runs. Running servers keep running.\""
}

render() {
  local now idle_hours idle_limit count i n editor root pids ports top p
  local worst=0 tot_cpu=0 tot_rss=0 pcount fcount total code status dot tip active idle stats cpu rss uptime name host id restart stop_params qr
  local -a R_ROOT R_PIDS R_PORTS R_TOP R_BRANCH R_KEY R_PORT R_MODE R_URL R_CONF R_IDX R_CANSTART
  if [ -f "$STATE_DIR/off" ]; then
    render_off
    return
  fi
  use_tmp
  load_config
  snapshot_ps
  list_listeners > "$TMP/listeners"
  while IFS=$'\t' read -r p port cwd; do
    printf '%s\t%s\t%s\n' "$(repo_root "$cwd")" "$p" "$port"
  done < "$TMP/listeners" | sort -t$'\t' -k1,1 -k3,3n > "$TMP/groups"
  cut -f1 "$TMP/groups" | sort -u > "$TMP/roots"
  lsof -nP -iTCP -sTCP:ESTABLISHED -Fn 2>/dev/null | sed -nE 's/^n.*:([0-9]+)->.*/\1/p' > "$TMP/est"

  now=$(date +%s)
  idle_hours=$(cfg_opt idleStopHours)
  idle_limit=$(awk -v h="${idle_hours:-0}" 'BEGIN { print int(h * 3600) }')
  editor=$(editor_cmd)
  mkdir -p "$STATE_DIR/active"

  : > "$TMP/srv"
  i=0
  while read -r root; do
    [ -z "$root" ] && continue
    pids=$(awk -F'\t' -v r="$root" '$1 == r { print $2 }' "$TMP/groups" | sort -un | tr '\n' ' ')
    ports=$(awk -F'\t' -v r="$root" '$1 == r { print $3 }' "$TMP/groups" | sort -un | tr '\n' ' ')
    top=$(find_top "${pids%% *}")
    {
      for p in $(descendants "$top"); do ps_args "$p"; done
      ancestor_args "$top"
    } > "$TMP/args"
    R_ROOT[i]=$root
    R_PIDS[i]=${pids% }
    R_PORTS[i]=${ports% }
    R_TOP[i]=$top
    R_BRANCH[i]=$(branch_of "$root")
    R_KEY[i]=$(remote_key "$root")
    IFS=$'\037' read -r "R_PORT[i]" "R_MODE[i]" "R_URL[i]" "R_CONF[i]" "R_IDX[i]" "R_CANSTART[i]" <<< "$(resolve_server "${R_KEY[i]}" "$ports")"
    for p in $pids; do printf '%s\t%s\t%s\t%s\n' "$p" "$(basename "$root")" "${R_KEY[i]}" "${R_PORT[i]}"; done >> "$TMP/srv"
    probe "${R_PORT[i]}" > "$TMP/health.$i" &
    i=$((i + 1))
  done < "$TMP/roots"
  count=$i
  wait

  crash_check

  : > "$TMP/rows"
  for ((n = 0; n < count; n++)); do
    root=${R_ROOT[n]}
    name=$(basename "$root")
    id=$(sid "$root")
    code=$(cat "$TMP/health.$n" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = 000 ]; then
      status="busy"
      dot=$DOT_ORANGE
      tip="Not answering yet, probably compiling"
      [ "$worst" -lt 1 ] && worst=1
    elif [ "$code" -ge 500 ]; then
      status="HTTP $code"
      dot=$DOT_RED
      tip="Server error (HTTP $code)"
      worst=2
    else
      status=""
      dot=$DOT_GREEN
      tip="Ready"
    fi

    if grep -qx "${R_PORT[n]}" "$TMP/est" || [ ! -f "$STATE_DIR/active/$id" ]; then
      echo "$now" > "$STATE_DIR/active/$id"
    fi
    active=$(cat "$STATE_DIR/active/$id")
    idle=$((now - active))
    if [ "$idle_limit" -gt 0 ] && [ "$idle" -ge "$idle_limit" ]; then
      echo "$now" > "$STATE_DIR/active/$id"
      # shellcheck disable=SC2086
      "$SELF" stop-idle "$root" "$idle_hours" ${R_PIDS[n]} > /dev/null 2>&1 < /dev/null &
      disown
    fi

    IFS=$'\037' read -r stats cpu rss uptime <<< "$(server_stats "${R_TOP[n]}" "$idle" "$status")"
    tot_cpu=$((tot_cpu + cpu))
    tot_rss=$((tot_rss + rss))
    host=${R_URL[n]#*://}
    host=${host%%/*}
    # shellcheck disable=SC2086
    qr=$(q "$root")
    stop_params="param1=stop param2=$qr $(pid_params 3 ${R_PIDS[n]})terminal=false"
    restart=""
    # shellcheck disable=SC2086
    [ "${R_CANSTART[n]}" = 1 ] && restart="Restart | bash=$QSELF param1=restart param2=$qr param3=$(q "${R_KEY[n]}") param4=${R_IDX[n]} param5=${R_PORT[n]} $(pid_params 6 ${R_PIDS[n]})terminal=false sfimage=arrow.clockwise"

    {
      [ "$n" -gt 0 ] && echo "---"
      echo "$name  :${R_PORT[n]}${R_MODE[n]:+  ${R_MODE[n]}}  ·  $stats | image=$dot tooltip=\"$tip\""
      [ -n "$restart" ] && echo "--$restart"
      echo "--Copy URL | bash=$QSELF param1=copy param2=$(q "${R_URL[n]}") terminal=false sfimage=doc.on.doc"
      echo "--Reveal in Finder | bash=/usr/bin/open param1=$qr terminal=false sfimage=folder"
      [ -n "$editor" ] && echo "--Open in $(editor_label "$editor") | bash=$(q "$editor") param1=$qr terminal=false sfimage=chevron.left.forwardslash.chevron.right"
      [ "${R_CONF[n]}" = 1 ] || echo "--Set up this repo… | bash=$QSELF param1=settings param2=$qr terminal=false sfimage=gearshape"
      echo "-----"
      echo "--$(tilde "$root") | size=11 $GRAY"
      echo "--${R_BRANCH[n]:-no git}  ·  up $uptime | size=11 $GRAY"
      echo "--ports ${R_PORTS[n]}  ·  pid ${R_PIDS[n]} | size=11 $GRAY"
      echo "Open $host | href=${R_URL[n]} sfimage=safari size=12"
      echo "Stop | bash=$QSELF $stop_params image=$ICON_STOP size=12"
    } >> "$TMP/rows"
  done

  render_pending "$now" "$editor"
  pcount=$(wc -l < "$TMP/proots" | tr -d ' ')
  [ "$pcount" -gt 0 ] && [ "$worst" -lt 1 ] && worst=1
  total=$((count + pcount))
  render_failed
  fcount=$(grep -c '· *failed | ' "$TMP/frows")
  [ "$fcount" -gt 0 ] && worst=2

  if [ "$total" -gt 0 ]; then
    case "$worst" in
      2) echo "$total | sfimage=server.rack sfconfig=$(sfc "$RED")" ;;
      1) echo "$total | sfimage=server.rack sfconfig=$(sfc "$ORANGE")" ;;
      *) echo "$total | sfimage=server.rack sfconfig=$(sfc "$GREEN")" ;;
    esac
  elif [ "$fcount" -gt 0 ]; then
    echo " | sfimage=server.rack sfconfig=$(sfc "$RED")"
  else
    echo " | sfimage=server.rack"
  fi
  echo "---"
  if [ "$count" -gt 0 ]; then
    awk -v n="$count" -v p="$pcount" -v f="$fcount" -v kb="$tot_rss" -v c="$tot_cpu" -v g="$GRAY" 'BEGIN {
      m = kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024)
      printf "%d running%s%s  ·  %s  ·  %d%% CPU | size=11 %s\n", n, (p > 0 ? sprintf(", %d starting", p) : ""),
        (f > 0 ? sprintf(", %d failed", f) : ""), m, c, g }'
  elif [ "$pcount" -gt 0 ] || [ "$fcount" -gt 0 ]; then
    awk -v p="$pcount" -v f="$fcount" -v g="$GRAY" 'BEGIN {
      s = p > 0 ? p " starting" : ""
      if (f > 0) s = s (s != "" ? ", " : "") f " failed"
      print s " | size=11 " g }'
  else
    echo "No dev servers running | size=11 $GRAY"
  fi
  [ -s "$TMP/cfg.err" ] && echo "Settings couldn't be read, open Settings to fix | color=$RED size=12 bash=$QSELF param1=settings terminal=false sfimage=exclamationmark.triangle.fill sfconfig=$(sfc "$RED")"
  port_warnings | while IFS= read -r w; do
    echo "$w | size=11 color=$ORANGE sfimage=exclamationmark.triangle.fill sfconfig=$(sfc "$ORANGE")"
  done
  awk 'FNR == 1 && NR > 1 && shown { print "---" } { print; shown = 1 }' "$TMP/prows" "$TMP/frows" "$TMP/rows"

  echo "---"
  render_start_menus
  [ "$total" -gt 0 ] && echo "Stop all | bash=$QSELF param1=stop-all terminal=false image=$ICON_STOP_ALL"
  echo "Settings… | bash=$QSELF param1=settings terminal=false sfimage=gearshape"
  echo "Turn off | bash=$QSELF param1=off terminal=false sfimage=power tooltip=\"Pauses Dev Servers. Running servers keep running.\""
  echo "Quit SwiftBar | bash=$QSELF param1=quit terminal=false sfimage=xmark.circle tooltip=\"Closes SwiftBar and every plugin it runs. Running servers keep running.\""
}

# Stops a menu loop left over from an earlier launch. Refreshing SwiftBar twice in quick succession
# can orphan the first copy, which would otherwise keep polling in the background.
stop_old_stream() {
  local pid
  pid=$(cat "$STATE_DIR/stream.pid" 2>/dev/null)
  [[ "$pid" =~ ^[0-9]+$ ]] && [ "$pid" != "$$" ] || return 0
  case "$(ps -p "$pid" -o args= 2>/dev/null)" in
    *"/${SELF##*/}") pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ;;
  esac
  return 0
}

# Keeps the menu pre-rendered so it opens instantly. A cheap socket check runs every 2s; a full
# render runs when sockets or settings change, and every 10s while servers run (health, usage,
# idle time) or 30s when none do. SIGUSR1 (see wake_menu) cuts the wait short and forces a render.
# While turned off it shows the off menu and sleeps until woken. Exits once orphaned: SwiftBar 2.1.1
# sometimes launches a plugin twice on refresh and leaves one copy without a parent.
stream() {
  local last="" fp out="" quick n=0 every=15 nap
  ensure_config
  mkdir -p "$STATE_DIR"
  stop_old_stream
  echo "$$" > "$STATE_DIR/stream.pid"
  trap 'WAKE=1' USR1
  while :; do
    [ "$(ps -o ppid= -p $$ | tr -d ' ')" = 1 ] && exit 0
    if [ -f "$STATE_DIR/off" ]; then
      if [ "$last" != off ] || [ -n "$WAKE" ]; then
        printf '~~~\n%s\n' "$(render_off)"
        last=off
        WAKE=""
      fi
      sleep 3600 &
      nap=$!
      wait "$nap" 2>/dev/null
      kill "$nap" 2>/dev/null
      continue
    fi
    if [ -n "$WAKE" ] && [ -n "$out" ] && quick=$(splice_pending "$out" | mark_parents); then
      printf '~~~\n%s\n' "$quick"
    fi
    fp=$({
      lsof -nP -iTCP -sTCP:LISTEN -Fpn 2>/dev/null
      stat -f %m "$CONFIG"
    } | md5)
    if [ "$fp" != "$last" ] || [ "$n" -ge "$every" ] || [ -n "$WAKE" ]; then
      WAKE=""
      touch "$STATE_DIR/rendered"
      out=$(render | mark_parents)
      printf '~~~\n%s\n' "$out"
      case "$out" in " |"*) every=15 ;; *) every=5 ;; esac
      last=$fp
      n=0
    fi
    n=$((n + 1))
    [ -n "$WAKE" ] && continue
    sleep 2 &
    wait $! 2>/dev/null
  done
}

main() {
  case "${1:-}" in
    start) cmd_start "$2" "$3" "$4" "${5:-}" ;;
    start-other) cmd_start_other "$2" "$3" ;;
    stop) shift; cmd_stop "$@" ;;
    stop-idle) shift; cmd_stop_idle "$@" ;;
    restart) shift; cmd_restart "$@" ;;
    stop-all) cmd_stop_all ;;
    off | on) cmd_power "$1" ;;
    dismiss) cmd_dismiss "$2" ;;
    quit) cmd_quit ;;
    copy) printf '%s' "$2" | pbcopy ;;
    settings) cmd_settings "${2:-}" ;;
    enable) cmd_enable ;;
    pick-folder) p=$(pick_folder "$2") && tilde "${p%/}" ;;
    inspect) cmd_inspect "$2" ;;
    render) render | mark_parents ;;
    version) echo "$VERSION" ;;
    "") stream ;;
    *) echo "Unknown command: $1" >&2; exit 2 ;;
  esac
}

QSELF=$(q "$SELF")
main "$@"
