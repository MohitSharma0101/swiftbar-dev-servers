#!/usr/bin/env bash
# End-to-end smoke test. Runs the plugin against a throwaway config, cache and project folder, so it
# never touches your real settings or dev servers. Needs python3 for the stand-in dev server.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/src/dev-servers.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
PROJECT="$WORK/projects/demo-app"
PORT_LO=48201
PORT_HI=48203
failures=0
passes=0

export DEV_SERVERS_CONFIG="$WORK/config.json"
export DEV_SERVERS_CACHE="$WORK/cache"
export DEV_SERVERS_LOGS="$WORK/logs"
export DEV_SERVERS_QUIET=1

cleanup() {
  pkill -f "http.server $PORT_LO" 2>/dev/null
  pkill -f "http.server 4829" 2>/dev/null
  [ -f "$WORK/cache/state/settings.info" ] && kill "$(cut -f1 "$WORK/cache/state/settings.info")" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

check() {
  local name=$1
  shift
  if "$@"; then
    passes=$((passes + 1))
    printf '  \033[32m✓\033[0m %s\n' "$name"
  else
    failures=$((failures + 1))
    printf '  \033[31m✗\033[0m %s\n' "$name"
  fi
}

wait_for_port() {
  local i
  for ((i = 0; i < 100; i++)); do
    lsof -nP -iTCP:"$1" -sTCP:LISTEN > /dev/null 2>&1 && return 0
    sleep 0.2
  done
  return 1
}

wait_for_free_port() {
  local i
  for ((i = 0; i < 50; i++)); do
    lsof -nP -iTCP:"$1" -sTCP:LISTEN > /dev/null 2>&1 || return 0
    sleep 0.2
  done
  return 1
}

mkdir -p "$PROJECT"
jq -n --arg root "$WORK/projects" --arg path "$PROJECT" --arg ports "$PORT_LO-$PORT_HI" '{
  version: 1, roots: [$root], idleStopHours: "", editor: "",
  repos: {"local/demo-app": {name: "demo", path: $path, ports: $ports, modes: [
    {name: "Default", start: "python3 -m http.server {port}", url: "http://localhost:{port}/app"},
    {name: "Alt", start: "python3 -m http.server {port} --bind 127.0.0.1", url: "http://127.0.0.1:{port}", detect: "--bind"},
    {name: "Slow", start: "sleep 30; python3 -m http.server {port}", detect: "sleep"}
  ]}}}' > "$DEV_SERVERS_CONFIG"

echo "Menu"
out=$("$PLUGIN" render)
check "renders with no servers running" grep -q "No dev servers running" <<< "$out"
check "offers to start the configured repo" grep -q "^Start demo" <<< "$out"
check "has a Settings item" grep -q "^Settings…" <<< "$out"
check "has a Turn off item" grep -q "^Turn off | .*param1=off" <<< "$out"
check "has a Quit SwiftBar item" bash -c 'grep "^Quit SwiftBar |" <<< "$1" | grep -q "param1=quit" && ! grep "^Quit SwiftBar |" <<< "$1" | grep -q alternate' _ "$out"

echo "Start, detect, stop"
"$PLUGIN" start local/demo-app "$PROJECT" 0
check "start picks the first port in the range" wait_for_port "$PORT_LO"
out=$("$PLUGIN" render)
check "lists the running server" grep -q "^demo-app  :$PORT_LO  Default" <<< "$out"
check "builds the URL from the template" grep -q "href=http://localhost:$PORT_LO/app" <<< "$out"
check "offers Restart for configured repos" grep -q "param1=restart" <<< "$out"
check "gives submenu parents a no-op action" grep -q "^demo-app  :$PORT_LO  Default.*bash=/usr/bin/true" <<< "$out"
pid=$(lsof -nP -t -iTCP:"$PORT_LO" -sTCP:LISTEN | head -n 1)
"$PLUGIN" stop "$PROJECT" 1 "$pid"
check "stop frees the port" wait_for_free_port "$PORT_LO"

"$PLUGIN" start local/demo-app "$PROJECT" 1
wait_for_port "$PORT_LO"
check "detects the mode from the command line" grep -q "^demo-app  :$PORT_LO  Alt" <<< "$("$PLUGIN" render)"
pid=$(lsof -nP -t -iTCP:"$PORT_LO" -sTCP:LISTEN | head -n 1)
"$PLUGIN" stop "$PROJECT" "$pid"
wait_for_free_port "$PORT_LO"

echo "Pending"
"$PLUGIN" start local/demo-app "$PROJECT" 2
out=$("$PLUGIN" render)
check "lists a just-started server as starting" grep -q "^demo-app  :$PORT_LO  Slow  ·  starting…" <<< "$out"
check "counts it in the menu bar" grep -q "^1 | sfimage" <<< "$out"
check "marks its worktree as starting in the Start menu" grep -q "is starting" <<< "$out"
pid=$(cut -d $'\037' -f3 "$WORK/cache/state/pending/$(printf '%s' "$PROJECT" | tr '/' '%')")
"$PLUGIN" stop "$PROJECT" "$pid"
check "Stop cancels a starting server" bash -c "! kill -0 $pid 2>/dev/null"
check "a stopped server leaves the menu" grep -q "No dev servers running" <<< "$("$PLUGIN" render)"

mkdir -p "$WORK/projects/other"
echo '{"scripts":{"dev":"sleep 3 && no-such-tool"}}' > "$WORK/projects/other/package.json"
"$PLUGIN" start-other "$WORK/projects/other" dev
check "lists a project with no port as starting" grep -q "^other  dev  ·  starting…" <<< "$("$PLUGIN" render)"
for ((i = 0; i < 50; i++)); do
  grep -q "other failed to start" "$WORK/cache/notifications.log" 2>/dev/null && break
  sleep 0.2
done
check "reports a failed start with the error from the log" grep -q "other failed to start.*no-such-tool.*not found" "$WORK/cache/notifications.log"
check "keeps the failed project in the menu" grep -q "^other  dev  ·  failed | " <<< "$("$PLUGIN" render)"
"$PLUGIN" dismiss "$WORK/projects/other"

mkdir -p "$WORK/projects/broken"
jq --arg path "$WORK/projects/broken" '.repos["local/broken"] = {name: "broken", path: $path, modes: [{name: "Default", start: "sleep 2 && no-such-server"}]}' \
  "$DEV_SERVERS_CONFIG" > "$WORK/cfg.tmp" && mv "$WORK/cfg.tmp" "$DEV_SERVERS_CONFIG"
"$PLUGIN" start local/broken "$WORK/projects/broken" 0
"$PLUGIN" render > /dev/null
for ((i = 0; i < 50; i++)); do
  grep -q "broken failed to start" "$WORK/cache/notifications.log" 2>/dev/null && break
  sleep 0.2
done
check "reports a failed start for a repo without a port range" grep -q "broken failed to start.*no-such-server" "$WORK/cache/notifications.log"
out=$("$PLUGIN" render)
check "keeps a failed start in the menu" grep -q "^broken  Default  ·  failed | " <<< "$out"
check "shows why it failed" grep -q "^[^-].*no-such-server | .*color=" <<< "$out"
check "offers Retry with the original start" grep -q '^Retry | .*param1=start param2="local/broken" ' <<< "$out"
"$PLUGIN" dismiss "$WORK/projects/broken"
check "Dismiss removes it" bash -c '! grep -q "· *failed" <<< "$1"' _ "$("$PLUGIN" render)"
jq 'del(.repos["local/broken"])' "$DEV_SERVERS_CONFIG" > "$WORK/cfg.tmp" && mv "$WORK/cfg.tmp" "$DEV_SERVERS_CONFIG"

echo "More failures"
mkdir -p "$WORK/projects/my app"
echo '{"scripts":{"dev":"python3 -m http.server 48292"}}' > "$WORK/projects/my app/package.json"
check "quotes folders with spaces in menu actions" grep -q "param2=\"$WORK/projects/my app\" param3=\"dev\"" <<< "$("$PLUGIN" render)"
"$PLUGIN" start-other "$WORK/projects/my app" dev
wait_for_port 48292
"$PLUGIN" render > /dev/null
pkill -f "http.server 48292"
wait_for_free_port 48292
out=$("$PLUGIN" render)
check "a crashed server stays in the menu as failed" grep -q "^my app  dev  ·  failed | " <<< "$out"
check "the crash offers Retry for the same project" grep -q "^Retry | .*param1=start-other param2=\"$WORK/projects/my app\" param3=\"dev\"" <<< "$out"
"$PLUGIN" dismiss "$WORK/projects/my app"

mkdir -p "$WORK/projects/hang"
jq --arg path "$WORK/projects/hang" '.repos["local/hang"] = {name: "hang", path: $path, modes: [{name: "qa/slow", start: "sleep 60"}]}' \
  "$DEV_SERVERS_CONFIG" > "$WORK/cfg.tmp" && mv "$WORK/cfg.tmp" "$DEV_SERVERS_CONFIG"
DEV_SERVERS_PENDING_TIMEOUT=3 "$PLUGIN" start local/hang "$WORK/projects/hang" 0
check "writes a log for a mode with / in its name" test -f "$WORK/logs/hang-qa-slow.log"
for ((i = 0; i < 50; i++)); do
  grep -q "hang isn't up" "$WORK/cache/notifications.log" 2>/dev/null && break
  sleep 0.2
done
out=$("$PLUGIN" render)
check "a start that never opens a port becomes a failed row" grep -q "^hang  qa/slow  ·  failed | " <<< "$out"
check "the timed-out start can still be stopped" grep -q '^Stop | .*param1=stop param2=".*/projects/hang" param3=[0-9]' <<< "$out"
pid=$(grep '^Stop | .*/projects/hang"' <<< "$out" | sed -E 's/.*param3=([0-9]+).*/\1/')
"$PLUGIN" stop "$WORK/projects/hang" "$pid"
check "stopping it clears the failed row" bash -c '! grep -q "^hang .*failed" <<< "$1"' _ "$("$PLUGIN" render)"
jq 'del(.repos["local/hang"])' "$DEV_SERVERS_CONFIG" > "$WORK/cfg.tmp" && mv "$WORK/cfg.tmp" "$DEV_SERVERS_CONFIG"

echo "Off and on"
"$PLUGIN" off
out=$("$PLUGIN" render)
check "turning off shows only the off menu" grep -q "^Dev Servers is off" <<< "$out"
check "the off menu offers Turn on" grep -q "^Turn on | .*param1=on" <<< "$out"
check "the off menu hides servers and Start menus" bash -c '! grep -q "^Start" <<< "$1"' _ "$out"
"$PLUGIN" on
check "turning on brings the full menu back" grep -q "^Start demo" <<< "$("$PLUGIN" render)"

echo "Safety"
(cd "$WORK" && exec python3 -m http.server 48290 > /dev/null 2>&1) &
outsider=$!
wait_for_port 48290
"$PLUGIN" stop "$PROJECT" "$outsider"
check "stop never kills processes outside the worktree" kill -0 "$outsider"
kill "$outsider" 2>/dev/null
wait "$outsider" 2>/dev/null

echo "Settings"
check "inspect describes a folder" grep -q '"key": "local/demo-app"' <<< "$("$PLUGIN" inspect "$PROJECT")"
DEV_SERVERS_QUIET=1 "$PLUGIN" settings > /dev/null 2>&1 &
for ((i = 0; i < 100; i++)); do
  [ -s "$WORK/cache/state/settings.info" ] && break
  sleep 0.1
done
IFS=$'\t' read -r _ port token < "$WORK/cache/state/settings.info"
base="http://127.0.0.1:$port"
check "settings API rejects requests without the token" \
  test "$(curl -s -o /dev/null -w '%{http_code}' "$base/api/config")" = 403
check "settings API returns the config with the token" \
  grep -q '"demo"' <<< "$(curl -s -H "X-Token: $token" "$base/api/config")"
check "settings API rejects an invalid config" grep -q '"errors"' <<< "$(curl -s -H "X-Token: $token" \
  -X POST -d '{"roots":[],"repos":{"x/y":{"name":"","ports":"9-1","modes":[]}}}' "$base/api/config")"

echo "Broken config"
echo "{ not json" > "$DEV_SERVERS_CONFIG"
check "shows a warning instead of failing" grep -q "Settings couldn't be read" <<< "$("$PLUGIN" render)"

echo ""
echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
