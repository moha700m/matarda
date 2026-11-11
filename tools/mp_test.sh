#!/usr/bin/env bash
# Headless dedicated server plus two real client processes (ENet).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
PORT="${PORT:-7777}"
WORKDIR="${WORKDIR:-/tmp/matarda}"
OUT="${ROOT}/docs/test_results"
mkdir -p "$WORKDIR" "$OUT"
rm -f "$WORKDIR"/*.json "$WORKDIR"/*.log

SERVER_JSON="$WORKDIR/server.json"
CRIM_JSON="$WORKDIR/criminal.json"
POL_JSON="$WORKDIR/police.json"
CRIM2_JSON="$WORKDIR/criminal2.json"
PIDS=""

cleanup() {
	for pid in $PIDS; do
		kill "$pid" 2>/dev/null || true
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT

echo "== MATARDA import =="
"$GODOT" --headless --path "$ROOT" --import --quit

echo "== MATARDA selftest =="
"$GODOT" --headless --path "$ROOT" --log-file "$WORKDIR/selftest.log" -- --selftest
cp "$WORKDIR/selftest.log" "$OUT/selftest.log" || true

echo "== MATARDA dedicated server =="
"$GODOT" --headless --path "$ROOT" --log-file "$WORKDIR/server.log" -- --server --test-mode --port "$PORT" --result "$SERVER_JSON" &
PIDS="$!"
ready=0
for _i in $(seq 1 80); do
	if [ -f "$SERVER_JSON" ]; then
		ready=1
		break
	fi
	sleep 0.25
done
if [ "$ready" -ne 1 ]; then
	echo "server failed to open"
	cat "$WORKDIR/server.log" || true
	exit 1
fi

echo "== MATARDA clients =="
"$GODOT" --headless --path "$ROOT" --log-file "$WORKDIR/police.log" -- --autoplay --role police --ip 127.0.0.1 --port "$PORT" --player-id police-test-0001 --name Sami --outfit 1 --result "$POL_JSON" &
PIDS="$PIDS $!"
"$GODOT" --headless --path "$ROOT" --log-file "$WORKDIR/criminal.log" -- --autoplay --role criminal --ip 127.0.0.1 --port "$PORT" --player-id criminal-test-01 --name Noir --outfit 2 --exit-after carry --result "$CRIM_JSON" &
PIDS="$PIDS $!"

python3 - "$SERVER_JSON" << 'PY'
import json, sys, time
path = sys.argv[1]
need = ("robbery_start", "hit", "loot")
deadline = time.time() + 75
last = ""
while time.time() < deadline:
    try:
        data = json.load(open(path))
    except Exception:
        time.sleep(0.35)
        continue
    text = " ".join(data.get("events", []))
    last = text
    if all(item in text for item in need):
        print("phase1 events", text)
        sys.exit(0)
    time.sleep(0.4)
print("timeout phase1", last)
sys.exit(1)
PY

python3 - "$SERVER_JSON" << 'PY'
import json, sys, time
path = sys.argv[1]
deadline = time.time() + 20
while time.time() < deadline:
    data = json.load(open(path))
    if any(str(event) == "disconnect:criminal-test-01" for event in data.get("events", [])):
        sys.exit(0)
    time.sleep(0.3)
print("no disconnect")
sys.exit(1)
PY

echo "== MATARDA reconnect =="
"$GODOT" --headless --path "$ROOT" --log-file "$WORKDIR/criminal2.log" -- --autoplay --role criminal --expect-restore --ip 127.0.0.1 --port "$PORT" --player-id criminal-test-01 --name Noir --outfit 2 --exit-after win --result "$CRIM2_JSON" &
PIDS="$PIDS $!"

python3 - "$SERVER_JSON" << 'PY'
import json, sys, time
path = sys.argv[1]
deadline = time.time() + 75
last = ""
while time.time() < deadline:
    data = json.load(open(path))
    text = " ".join(data.get("events", []))
    last = text
    restored = any("restored=true" in event for event in data.get("events", []))
    if restored and "criminal_win" in text:
        print("phase2", text)
        sys.exit(0)
    time.sleep(0.4)
print("timeout phase2", last)
sys.exit(1)
PY

cp "$WORKDIR"/*.json "$OUT"/ || true
cp "$WORKDIR"/*.log "$OUT"/ || true

python3 - "$SERVER_JSON" "$CRIM_JSON" "$POL_JSON" "$CRIM2_JSON" << 'PY'
import json, sys
server, crim, pol, crim2 = [json.load(open(path)) for path in sys.argv[1:]]
errors = []
if server.get("net_errors", 1) != 0:
    errors.append("server net_errors=%s" % server.get("net_errors"))
if crim.get("net_errors", 1) != 0:
    errors.append("criminal net_errors")
if pol.get("net_errors", 1) != 0:
    errors.append("police net_errors")
if crim2.get("net_errors", 1) != 0:
    errors.append("reconnect net_errors")
if not crim.get("ok"):
    errors.append("criminal failed %s" % crim.get("reason"))
if not crim.get("carrying"):
    errors.append("criminal was not carrying loot")
if int(crim.get("live_score", 0)) < 100:
    errors.append("loot score missing")
if not pol.get("ok"):
    errors.append("police hit was not observed (seen_health=%s)" % pol.get("seen_health"))
if not crim2.get("ok"):
    errors.append("reconnect run failed %s" % crim2.get("reason"))
if not crim2.get("restored"):
    errors.append("session was not restored")
if int(crim2.get("team", -2)) != 1:
    errors.append("team was not restored")
if int(crim2.get("welcome_score", 0)) < 100:
    errors.append("score was not restored")
text = " ".join(server.get("events", []))
for key in ("robbery_start", "hit", "loot", "disconnect:", "restored=true", "criminal_win"):
    if key not in text:
        errors.append("missing " + key)
print(json.dumps({"server_events": server.get("events"), "net_errors": server.get("net_errors"), "errors": errors}, indent=2))
sys.exit(1 if errors else 0)
PY
echo "MATARDA multiplayer test passed"
