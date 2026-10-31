"""Settings window backend for the Dev Servers SwiftBar plugin.

Serves the settings page and a small JSON API on 127.0.0.1. Every request must carry the
per-session token and a matching Host header, so other websites can't read or change the config.
The process exits after 15 minutes without requests; the page pings it while it's open.

Usage: server.py CONFIG_PATH PLUGIN_PATH INDEX_HTML INFO_FILE VERSION
Writes "pid<TAB>port<TAB>token<TAB>folder" to INFO_FILE once it's listening, where folder is the
one these files were served from, so the plugin can spot a helper left over from an older build.
"""

import contextlib
import http.server
import json
import os
import re
import secrets
import subprocess
import sys
import threading
import time
import urllib.parse

CONFIG, PLUGIN, INDEX_HTML, INFO_FILE, VERSION = sys.argv[1:6]
TOKEN = secrets.token_urlsafe(24)
IDLE_EXIT_SECS = 900
PORT_RE = re.compile(r"^\d{2,5}$")
HOURS_RE = re.compile(r"^\d+(\.\d+)?$")
last_request = time.monotonic()


def read_config():
    with open(CONFIG) as f:
        return json.load(f)


def write_config(cfg):
    """Writes the config atomically so the plugin never reads a half-written file."""
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    os.replace(tmp, CONFIG)


def validate_ports(label, ports):
    if not ports:
        return []
    lo, _, hi = ports.partition("-")
    if not PORT_RE.match(lo) or (hi and not PORT_RE.match(hi)):
        return [f"{label}: the port range should look like 3001-3009."]
    if hi and int(hi) < int(lo):
        return [f"{label}: the port range ends before it starts."]
    return []


def validate(cfg):
    """Returns human-readable problems; an empty list means the config is safe to save."""
    errors = []
    roots = cfg.get("roots")
    if not isinstance(roots, list) or not all(isinstance(r, str) and r for r in roots):
        errors.append("Watched folders must be a list of folders.")
    if not HOURS_RE.match(str(cfg.get("idleStopHours") or "0")):
        errors.append("Auto-stop needs a number of hours, or Off.")
    repos = cfg.get("repos")
    if not isinstance(repos, dict):
        return errors + ["The repos section is missing."]
    for key, repo in repos.items():
        label = repo.get("name") or key
        if not repo.get("name"):
            errors.append(f"{key}: add a name.")
        ports = repo.get("ports", "")
        errors += validate_ports(label, ports)
        default_port = str(repo.get("defaultPort", ""))
        if default_port and not PORT_RE.match(default_port):
            errors.append(f"{label}: the default port must be a number.")
        modes = repo.get("modes") or []
        if not modes:
            errors.append(f"{label}: add at least one mode.")
        for i, mode in enumerate(modes, start=1):
            if not mode.get("name"):
                errors.append(f"{label}: mode {i} needs a name.")
            if "{port}" in mode.get("start", "") and not ports:
                errors.append(
                    f"{label} · {mode.get('name') or i}: the start command uses {{port}}, so set a port range."
                )
    return errors


def run_plugin(*args):
    """Runs a plugin subcommand (folder picker, repo inspection) and returns its stdout.

    Returns an empty string when the plugin can't be run at all, which only happens in the
    development harness, so the page still loads instead of failing on a request it doesn't need.
    """
    try:
        out = subprocess.run([PLUGIN, *args], check=False, capture_output=True, text=True, timeout=300)
    except OSError:
        return ""
    return out.stdout.strip()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        """Requires the session token and our own Host, which also blocks DNS-rebinding attacks."""
        host_ok = self.headers.get("Host") == f"127.0.0.1:{self.server.server_address[1]}"
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        token = self.headers.get("X-Token") or query.get("t", [""])[0]
        return host_ok and secrets.compare_digest(token, TOKEN)

    def touch(self):
        global last_request
        last_request = time.monotonic()

    def do_GET(self):
        self.touch()
        if not self.authorized():
            return self.send(403, {"error": "Forbidden"})
        path = urllib.parse.urlparse(self.path).path
        if path == "/":
            with open(INDEX_HTML, "rb") as f:
                return self.send(200, f.read(), "text/html; charset=utf-8")
        if path == "/api/config":
            return self.send(
                200,
                {
                    "config": read_config(),
                    "path": CONFIG.replace(os.path.expanduser("~"), "~", 1),
                    "version": VERSION,
                },
            )
        self.send(404, {"error": "Not found"})

    def do_POST(self):
        self.touch()
        if not self.authorized():
            return self.send(403, {"error": "Forbidden"})
        path = urllib.parse.urlparse(self.path).path
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
        except ValueError:
            return self.send(400, {"error": "The request wasn't valid JSON."})
        if path == "/api/config":
            errors = validate(body)
            if errors:
                return self.send(400, {"errors": errors})
            write_config(body)
            return self.send(200, {"ok": True})
        if path == "/api/pick-folder":
            return self.send(200, {"path": run_plugin("pick-folder", body.get("prompt") or "Choose a folder")})
        if path == "/api/inspect":
            out = run_plugin("inspect", body.get("path", ""))
            return self.send(200, json.loads(out) if out else {"error": "That folder couldn't be read."})
        if path == "/api/ping":
            return self.send(200, {"ok": True})
        self.send(404, {"error": "Not found"})


def exit_when_idle():
    while True:
        time.sleep(30)
        if time.monotonic() - last_request > IDLE_EXIT_SECS:
            with contextlib.suppress(OSError):
                os.remove(INFO_FILE)
            os._exit(0)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(INFO_FILE + ".tmp", "w") as f:
        f.write(f"{os.getpid()}\t{server.server_address[1]}\t{TOKEN}\t{os.getcwd()}\n")
    os.replace(INFO_FILE + ".tmp", INFO_FILE)
    threading.Thread(target=exit_when_idle, daemon=True).start()
    server.serve_forever()


if __name__ == "__main__":
    main()
