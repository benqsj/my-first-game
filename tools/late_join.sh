#!/bin/sh
# Joining a game that is already going. The host kills one wolf and maims
# another *before* the client arrives; the client finds the host by listening on
# the network (as a friend on the same Wi-Fi would), joins, and must see the
# dead wolf gone and the other one missing the same parts.
#
#     sh tools/late_join.sh
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
log=${TMPDIR:-/tmp}/vepxis-late-join
mkdir -p "$log"

godot --path "$here" --headless --script res://tests/net_late_host.gd > "$log/host.txt" 2>&1 &
host=$!
sleep 6
godot --path "$here" --headless --script res://tests/net_late_client.gd > "$log/client.txt" 2>&1
wait $host

grep -E '^LHOST' "$log/host.txt"
grep -E '^LCLIENT' "$log/client.txt"
ok=0
grep -q '^LCLIENT wolf1 gone' "$log/client.txt" || { echo "the dead wolf is still standing for the late player"; ok=1; }
grep -q '^LCLIENT wolf2 lost \["left leg", "tail"\] health 42' "$log/client.txt" \
	|| { echo "the maimed wolf does not look the same to the late player"; ok=1; }
[ $ok -eq 0 ] && echo "late join: OK" || echo "late join: FAILED"
exit $ok
