#!/bin/sh
# Two windows, one world: does the client see the monsters attack and die?
# Host: tests/net_monsters_host.gd. Client: tests/net_monsters_client.gd.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
G=${GODOT:-godot}
log=${TMPDIR:-/tmp}/vepxis-two-peers-monsters
mkdir -p "$log"
"$G" --path "$here" --headless --script res://tests/net_monsters_host.gd > "$log/host.txt" 2>&1 &
host=$!
sleep 3
"$G" --path "$here" --headless --script res://tests/net_monsters_client.gd > "$log/client.txt" 2>&1 &
client=$!
wait $client; wait $host
grep -E '^HOST' "$log/host.txt"
grep -E '^CLIENT' "$log/client.txt"
code=0
sw=$(grep -E '^CLIENT wolf swipes seen' "$log/client.txt" | awk '{print $5}')
[ "${sw:-0}" -ge 1 ] 2>/dev/null || { echo "the client never saw the wolf attack"; code=1; }
grep -qE '^CLIENT wolf died True fell -1\.[3-9]' "$log/client.txt" || grep -qE '^CLIENT wolf died true fell -1\.[3-9]' "$log/client.txt" || { echo "the client never saw the wolf fall over"; code=1; }
grep -qE '^CLIENT other .* sank -[0-9]*\.[0-9]*[1-9]' "$log/client.txt" || { echo "no other monster was seen to go down"; code=1; }
[ $code -eq 0 ] && echo "monsters over the network: OK" || echo "monsters over the network: FAILED"
exit $code
