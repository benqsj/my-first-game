#!/bin/sh
# The live two-process check: one Godot hosts, another joins, and both report
# what they can see of the other. One process has one `multiplayer`, so this is
# the only honest way to test that two peers talk to each other.
#
#     sh tools/two_peers.sh
#
# Prints both logs and exits non-zero if either side did not reach OK.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
log=${TMPDIR:-/tmp}/vepxis-two-peers
mkdir -p "$log"

godot --path "$here" --headless --script res://tests/net_host.gd > "$log/host.txt" 2>&1 &
host=$!
sleep 3
godot --path "$here" --headless --script res://tests/net_client.gd > "$log/client.txt" 2>&1 &
client=$!

wait $client; client_code=$?
wait $host; host_code=$?

echo "--- host"; grep -E '^HOST' "$log/host.txt" || tail -5 "$log/host.txt"
echo "--- client"; grep -E '^CLIENT' "$log/client.txt" || tail -5 "$log/client.txt"

# Both sides have to agree about *both* wolves. That is §7.4 items 6, 7 and 8:
# the same limbs missing, the same health, the same corpse — and it has to hold
# for the wolf the client cut as well as the one the host did, because those are
# two different journeys.
echo "--- the wolves"
for who in mywolf theirwolf; do
	h=$(grep -E "^HOST $who " "$log/host.txt" | sed 's/^HOST //')
	# The host's "mywolf" is the client's "theirwolf" and the other way round.
	case $who in mywolf) mirror=theirwolf ;; *) mirror=mywolf ;; esac
	c=$(grep -E "^CLIENT $mirror " "$log/client.txt" | sed "s/^CLIENT $mirror/$who/")
	echo "host:   $h"
	echo "client: $c"
	if [ -z "$h" ] || [ "$h" != "$c" ]; then
		echo "the two windows DISAGREE about $who"
		host_code=1
	fi
	# A wolf nobody scratched means that side's swings never landed.
	case "$h" in *"health 100 lost 0"*)
		echo "$who took no damage at all — that side's swings did not land"
		host_code=1 ;;
	esac
done

# What the client could only have learned over the wire.
ran=$(grep -E '^CLIENT saw them run' "$log/client.txt" | awk '{print $5}')
swings=$(grep -E '^CLIENT saw them swing' "$log/client.txt" | awk '{print $5}')
left=$(grep -E '^HOST bodies_left' "$log/host.txt" | awk '{print $3}')
drew=$(grep -E '^HOST saw them drawing' "$log/host.txt" | awk '{print $6}')
echo "--- what crossed"
echo "the client saw the other knight run ${ran:-no} m and swing ${swings:-no} time(s)"
echo "the host saw the other bow drawn for ${drew:-no} frame(s)"
echo "the host was left with ${left:-?} body(s) after the client closed"
case "${ran:-0}" in ''|*[!0-9.]*) ran=0 ;; esac
if [ "$(echo "${ran:-0} > 5" | bc 2>/dev/null || echo 0)" != "1" ]; then
	echo "movement did not reach the other window"
	host_code=1
fi
if [ "${swings:-0}" -lt 1 ] 2>/dev/null; then
	echo "the swing did not reach the other window"
	host_code=1
fi
if [ "${drew:-0}" -lt 10 ] 2>/dev/null; then
	echo "the draw did not reach the other window — the archer would pop arrows out of nowhere"
	host_code=1
fi
if [ "${left:-0}" != "1" ]; then
	echo "the knight that left is still standing there"
	host_code=1
fi

if [ $host_code -eq 0 ] && [ $client_code -eq 0 ]; then
	echo "two peers: OK"
	exit 0
fi
echo "two peers: FAILED (host $host_code, client $client_code)"
exit 1
