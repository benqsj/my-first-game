# Multiplayer — Phase 1: PvE co-op

Implementation spec. Written against the tree at commit `a77f75a`.
Read this whole file before touching anything.

---

## 1. Goal and non-goals

**Goal of this phase:** 2–4 players in one instance of
`res://scenes/world/greybox_world.tscn`, each driving their own knight, each
able to pick a *different* character, all seeing each other move and swing,
all able to kill the same wolves and golems.

**Explicitly OUT of scope for this phase — do not build any of it:**

- PvP. Players cannot damage each other. Do not add player-vs-player hit
  detection, player health, or player death.
- Client-side prediction / reconciliation / rollback. Movement is
  client-authoritative (see §2). Do not write a tick buffer.
- Dedicated servers, matchmaking, NAT punch-through, lobbies with a browser.
  The host is a player (listen server).
- Anti-cheat. A malicious client can lie about its position. That is accepted.
- Bosses. The existing wolves and golems are the content for this phase.
- Arrows / the bow character over the network (see §8, deferred).

**Definition of done:** two editor instances on one machine, one hosting one
joining, different characters chosen in each, both visible to each other,
both able to dismember the same wolf, wolf dies once and is a corpse in both
windows.

---

## 2. Authority model

This project has committed to a **Souls-style, attacker-authoritative** model.
Restated concretely:

| Thing | Who simulates it |
| --- | --- |
| A player's own body and camera | that player's own client |
| Another player's body | nobody — it is interpolated from replicated state |
| Wolves, golems | **the host only** |
| "Did this sword cut this wolf?" | **the host only** |
| Blood, severed limbs, corpses | decided by the host, replayed everywhere |

The host is peer id `1` and is also playing. `multiplayer.is_server()` is the
test for "am I the host".

---

## 3. The key insight — read this before planning anything

**Combat in this codebase is enemy-driven, not player-driven.** The player's
attack code never searches for a target. Instead:

- `scripts/wolf.gd:132` — the wolf calls `_take_hits()` at the end of its own
  `_physics_process`.
- `scripts/wolf.gd:276` `_take_hits()` reads `_player.rig.attack_serial`
  (`scripts/character_rig.gd:302`) to notice a new swing, then asks
  `_player.rig.get_cutting_edge()` (`character_rig.gd:878`) for the blade as a
  line segment, then calls `rig.sever_along_edge()`
  (`scripts/wolf_rig.gd:242`) to decide which limb came off.

The consequence is large and good:

> If wolves only run `_physics_process` on the host, **and** every player's
> swing is replicated so that the host's copy of each remote player plays the
> same swing on its own rig, then hit detection becomes host-authoritative
> **with no change to the combat logic at all.**

So do not rewrite combat. Replicate the *swing*, gate the *enemy think*, and
the existing code lands in the right place by itself.

The one real change combat needs is that `_take_hits()` currently looks at a
single cached `_player`. It must consider every player. See §6.

---

## 4. Blockers in the current tree

Verified line numbers. Each must be addressed.

### 4.1 `scripts/player.gd`

| Line | What | Problem |
| --- | --- | --- |
| 358 `_ready()` | | runs for every player instance |
| 403 | `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` | every spawned player steals the mouse |
| 406 `_unhandled_input()` | mouse look | remote players would be turned by the local mouse |
| 434 `_process()` | drives `camera_rig` and `rig.animate()` | camera part must be local-only, rig part must run for everyone |
| 449 `_physics_process()` | the whole controller | must not run for remote players |
| 495 `_spawn_character()` | reads `/root/Game` for the profile | every peer would spawn with the *local* player's chosen character |
| 271–273 | `camera`, `camera_rig`, `spring_arm` | `Camera3D.current = true` is baked in `player.tscn`; N players fight over it |
| 20 `Input.` call sites | 403, 407, 529, 535, 539, 544, 553, 559, 563, 564, 568, 578, 673, 758, 952, 969, 1245, 1248, 1252, 1551 | all must be inert for remote players |

### 4.2 `scenes/world/greybox_world.tscn`

- Line **5559** — `[node name="Player" parent="." instance=ExtResource("1_player")]`.
  The player is baked into the level. It must be removed and spawned instead.
- Lines **5541–5556** — `Wolf1`–`Wolf4`, `Golem1`, `Golem2` under an `Enemies`
  node. These are fine to keep as level-placed nodes (they exist on every peer
  already); they only need their thinking gated. Do **not** convert them to
  spawner-driven nodes in this phase.

### 4.3 `scripts/wolf.gd`

- Line **98** — `_player = get_tree().get_first_node_in_group("player")`.
  Assumes exactly one player, cached once at `_ready()`, before any player has
  spawned in the multiplayer flow. Broken twice over.
- Line **276** `_take_hits()` — single-player blade check.
- Line **310** `take_hit()` — mutates `health`, spawns blood, shoves the body.
  Must become host-only, with the result replicated.
- Line **337** `_on_severed()` / line **344** `_die()` — host-only, replicated.

### 4.4 `scripts/golem.gd`

- Line **53** `_ready()`, line **63** `_physics_process()` — AI must be
  host-only. The golem does not currently look up a player at all, so it has no
  group-lookup bug.

### 4.5 `scripts/grass_field.gd`

- Line **124** — `get_first_node_in_group("player")`, cached once. Grass will
  react to one arbitrary player, or to none if it runs before any spawn. Cosmetic
  but should be fixed to track the nearest player.

### 4.6 `scripts/main_menu.gd`

- Line **23** `enum Page { ROOT, MODE, CHARACTERS, SETTINGS }`
- Line **94** `_build_mode()` — the `MULTIPLAYER` button sets `_multiplayer = true`
  and otherwise does nothing.
- Line **190** — prints *"Multiplayer is not wired up yet — this will start a
  solo game."*
- Line **344** `_start()` — `get_tree().change_scene_to_file(WORLD)`, no
  networking.

### 4.7 `scripts/game.gd`

Holds a single `_chosen` character for the whole process. That is correct for
the *local* player's choice; it must not be used to decide what a *remote*
player looks like.

---

## 5. What to build

### 5.1 New autoload: `scripts/net.gd` → `/root/Net`

Register in `project.godot` under `[autoload]` next to `Game`.

```
const PORT := 7777
const MAX_PLAYERS := 4

signal lobby_changed()          # a peer joined or left
signal hosting_failed(why: String)
signal join_failed(why: String)

# peer_id -> character id (StringName, a key of Game.CHARACTERS)
var roster: Dictionary = {}

func host(character: StringName) -> bool
func join(address: String, character: StringName) -> bool
func leave() -> void
func is_online() -> bool          # multiplayer.multiplayer_peer != null
func local_id() -> int            # multiplayer.get_unique_id()
```

Behaviour:

- `host()` creates an `ENetMultiplayerPeer` with `create_server(PORT, MAX_PLAYERS)`,
  assigns it to `multiplayer.multiplayer_peer`, records
  `roster[1] = character`, then changes scene to the world.
- `join()` creates `create_client(address, PORT)`, assigns it, and waits for
  `multiplayer.connected_to_server` before changing scene. On
  `connection_failed`, emit `join_failed` and tear the peer down.
- Connect `multiplayer.peer_connected` / `peer_disconnected` on the host. When a
  peer connects, the host must learn that peer's character choice: the client
  sends it with `@rpc("any_peer", "call_local", "reliable") func announce(character: StringName)`,
  the host writes it into `roster` and pushes the whole roster back out with
  `@rpc("authority", "call_local", "reliable") func sync_roster(r: Dictionary)`.
- Spawning players is the host's job and happens in the world scene (§5.3), not
  here — but only once that peer's character is known, so spawn on receipt of
  `announce`, not on `peer_connected`.

### 5.2 Menu wiring — `scripts/main_menu.gd`

Add a page between MODE and CHARACTERS, or after CHARACTERS (your choice, but
character must be picked before hosting/joining because the choice is sent with
`announce`):

- `HOST GAME` → `Net.host(_chosen)`
- `JOIN GAME` → a `LineEdit` prefilled with `127.0.0.1`, then `Net.join(text, _chosen)`
- Show `Net.join_failed` / `Net.hosting_failed` text in the existing note label.

Delete the "not wired up yet" string at line 190.

`_start()` (line 344) stays as the solo path and must additionally call
`Net.leave()` so a previous session's peer is not still alive.

### 5.3 World scene — `scenes/world/greybox_world.tscn`

1. **Delete** the `Player` node at line 5559.
2. Add `Node3D` named `Players` as a sibling of `Enemies`.
3. Add `MultiplayerSpawner` named `PlayerSpawner`:
   - `spawn_path` → `../Players`
   - add `res://scenes/player/player.tscn` to its `_spawnable_scenes`
   - set a `spawn_function` so the character id can be passed in — the custom
     spawn data is what solves the "each player has their own character"
     problem. Spawn data: `{ "peer": int, "character": StringName, "point": int }`.
     The spawn function instantiates `player.tscn`, sets `name = str(peer)`,
     calls `set_multiplayer_authority(peer)`, assigns
     `profile = load(Game.CHARACTERS[character])` **before** the node enters the
     tree so `_spawn_character()` (player.gd:495) uses it instead of asking
     `/root/Game`.
4. Add `Node3D` named `SpawnPoints` with 4 children spread over the flat ground,
   away from the enemies.
5. New script `scripts/world.gd` on the root:
   - on `_ready()`, if `multiplayer.is_server()`, spawn the host's own player,
     then spawn one for each peer as it announces.
   - despawn on `peer_disconnected`.

### 5.4 `scenes/player/player.tscn`

- `Camera3D` → uncheck `current`. It is turned on in code by the authority only.
- Add `MultiplayerSynchronizer` as a child of `Player`.
  - Replication config, all on the **authority → everyone** direction:

    | Property | Mode |
    | --- | --- |
    | `.:position` | Always |
    | `.:rotation` | Always |
    | `.:velocity` | Always |
    | `.:net_state` | Always |
    | `.:net_blocking` | On Change |
    | `.:net_crouching` | On Change |
    | `.:net_airborne` | On Change |
    | `.:net_stowed` | On Change |

  - `replication_interval` ≈ `0.033` (30 Hz). Leave `delta_interval` at 0.

`net_*` are new plain vars on `Player` (see §5.5). Do **not** try to replicate
the private `_crouching` / `state` fields directly; give them public mirrors so
the intent is visible and the synchronizer config stays readable.

### 5.5 `scripts/player.gd`

Add near the other state vars (~line 287):

```
## Mirrors of internal state, published for the synchronizer. Written by the
## authority at the end of _physics_process, read by everyone else in _process.
var net_state: int = 0
var net_blocking: bool = false
var net_crouching: bool = false
var net_airborne: bool = false
var net_stowed: bool = false
```

**`_ready()` (line 358)** — after `_spawn_character()`, add:

```
var mine := is_multiplayer_authority()
camera.current = mine
set_physics_process(mine)
set_process_unhandled_input(mine)
if mine:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

Move the line-403 `Input.mouse_mode` call inside that `if`. Leave `_process`
enabled for **everyone** — that is what animates remote knights.

Note: `set_physics_process(false)` on remote players is what makes the whole
thing work without touching the 20 `Input.` call sites. They are all reached
from `_physics_process`, so they simply never run. Do not add
`if not is_multiplayer_authority(): return` guards inside `_read_actions()` and
friends; gating the process callback is one line and cannot be forgotten.

**`_process()` (line 434)** — split it:

```
func _process(delta: float) -> void:
    if is_multiplayer_authority():
        # existing camera_rig follow, unchanged
        ...
        _publish_net_state()
    if rig != null:
        # existing rig.animate() call, but sourcing the flags from net_* so
        # that a remote knight animates from replicated state
        ...
```

For a remote player `is_on_floor()` is stale (no physics ticks), so the
`airborne` argument to `rig.animate()` must come from `net_airborne`, and the
dash flag from `net_state == State.DASHING`, and `is_blocking` from
`net_blocking`. `planar` is computed from the replicated `velocity`, which
already works.

`_publish_net_state()` copies `state`, `is_blocking`, `_crouching`,
`not is_on_floor()`, `weapons_stowed()` into the `net_*` vars.

**`_spawn_character()` (line 495)** — change the fallback so it only asks
`/root/Game` when `profile` is still null *and* we are offline. When the
spawner has already assigned `profile`, it must be left alone. The current
first four lines already do this correctly (`if profile == null:`), so the only
requirement is that the spawn function assigns `profile` before the node is
added to the tree. Verify this holds.

**`_attack()` (line 1727)** — this is the one piece of combat that must go over
the wire. At the end, where it currently does:

```
if rig != null:
    rig.attack(CharacterRig.AttackStyle.OVERHEAD if airborne else -1)
```

replace with a call to a new replicated method:

```
@rpc("any_peer", "call_local", "reliable")
func net_attack(style: int) -> void:
    if rig != null:
        rig.attack(style)
```

and in `_attack()`: `net_attack.rpc(CharacterRig.AttackStyle.OVERHEAD if airborne else -1)`.

`call_local` is required — the attacker must also play its own swing.
`reliable` is required — a dropped swing is a missed kill.

**Why this single RPC is enough:** it advances `attack_serial` on every peer
including the host, and it drives the same procedural swing on the host's copy
of the attacker. The host's wolf then reads a real blade position out of
`get_cutting_edge()` and the existing severing code does the rest.

### 5.6 Add the player to the `player` group

`player.tscn` root already has `groups=["player"]`. Keep it. §6 depends on it.

---

## 6. Enemies — `scripts/wolf.gd`, `scripts/golem.gd`

### 6.1 Gate the thinking

In both `_ready()`:

```
set_physics_process(multiplayer.is_server())
```

`_process()` stays on everywhere — it drives `rig.animate()` and the health bar
position from replicated `velocity` / `health`.

### 6.2 Replicate the body

Add a `MultiplayerSynchronizer` to `scenes/enemies/wolf.tscn` and
`scenes/enemies/golem.tscn`, authority = server (default, since the node is
level-placed and owned by peer 1):

| Property | Mode |
| --- | --- |
| `.:position` | Always |
| `.:rotation` | Always |
| `.:velocity` | Always |
| `.:health` | On Change |
| `.:is_dead` | On Change |
| `.:state` | On Change |

`replication_interval` ≈ `0.033`.

### 6.3 Fix the single-player assumption

`scripts/wolf.gd:98` — delete the cached `_player` lookup from `_ready()`.
Replace with a helper that is called each think tick:

```
func _nearest_player() -> Node3D:
    var best: Node3D = null
    var best_d := INF
    for node in get_tree().get_nodes_in_group("player"):
        var who := node as Node3D
        if who == null:
            continue
        var d := global_position.distance_squared_to(who.global_position)
        if d < best_d:
            best_d = d
            best = who
    return best
```

Use it in `_think()` for chasing. It also naturally handles "no players spawned
yet", which the cached version could not.

`scripts/wolf.gd:276` `_take_hits()` — must loop over **all** players, not one:

```
func _take_hits() -> void:
    if is_dead:
        return
    for node in get_tree().get_nodes_in_group("player"):
        var knight := node as Player
        if knight == null or knight.rig == null:
            continue
        # ... existing body, but _last_hit_serial must become a per-attacker
        #     dictionary keyed by the knight's node name, not a single int,
        #     or one player's swing will mask another's.
```

`_last_hit_serial: int` becomes `_last_hit_serial: Dictionary` — `{ attacker_name: serial }`.
This is a real correctness bug in multiplayer, not a nicety: two players
swinging in the same tick currently collapse into one hit.

Also gate the whole call at `wolf.gd:132` — it is inside `_physics_process`,
which is already server-only after §6.1, so no extra guard is needed. Confirm
this rather than assuming it.

### 6.4 Replicate the consequences of a hit

`take_hit()` (line 310), `_on_severed()` (337) and `_die()` (343) now run only
on the host. Their *visible* effects must reach clients:

- **Severing.** `wolf_rig.gd:242 sever_along_edge()` returns the part name and
  `wolf_rig.gd:304` emits `severed`. On the host, after a successful sever,
  broadcast it:

  ```
  @rpc("authority", "call_local", "reliable")
  func net_sever(part: String, at: Vector3, blow: Vector3) -> void
  ```

  On a client this calls into the rig to remove the same part and spawn the
  same `severed_limb` + blood, **without** re-running the geometric test (the
  client's blade is in a slightly different place; re-testing would disagree).
  This likely means splitting `wolf_rig.sever_along_edge()` into "decide which
  part" (host) and "detach this named part" (everyone). Do that split.

- **Blood.** `Blood.splatter()` inside `take_hit()` — move it into `net_sever`
  so it plays on every peer. Blood is purely cosmetic; `reliable` is fine at
  this volume but `unreliable` is acceptable if it proves noisy.

- **Death.** `_die()` sets `is_dead`, hides the bar, clears `collision_layer`,
  emits `died`. `is_dead` is replicated (§6.2), so make the client react to the
  *change* of `is_dead` rather than adding a second RPC: give `is_dead` a setter
  that runs the cosmetic half of `_die()` on non-hosts.

- **Health bar.** `health` is replicated; have `_process()` push
  `health / max_health` into `_bar` each frame instead of only inside
  `take_hit()`.

### 6.5 `scripts/grass_field.gd:124`

Replace the cached `_player` with the same nearest-player helper, evaluated
every few frames rather than every frame (grass reaction does not need 60 Hz
accuracy). Purely cosmetic; do it last.

---

## 7. Local testing — two windows, two characters, one machine

This is the primary acceptance path and must work before anything is called
done.

### 7.1 Command-line driven auto-connect

`scripts/game.gd` already reads `OS.get_cmdline_user_args()` to pick a
character. Extend it to also understand:

```
--host            start hosting immediately, skip the menu
--join <address>  connect immediately, skip the menu (default 127.0.0.1)
```

so the two instances can be launched straight into the world. Keep the existing
bare character-name argument working — it is how the two windows get *different*
knights:

```
godot --path . -- --host tariel
godot --path . -- --join 127.0.0.1 avtandil
```

### 7.2 In the editor

`Debug → Run Multiple Instances → Run 2 Instances`, then
`Debug → Customize Run Instances...` and give:

- instance 1 arguments: `--host tariel`
- instance 2 arguments: `--join 127.0.0.1 avtandil`

Press F5. Two windows, two different knights, one world.

### 7.3 Known annoyance

Both windows call `Input.mouse_mode = MOUSE_MODE_CAPTURED` for their own local
player, so whichever window has focus grabs the mouse. `Escape` releases it via
`scripts/pause_menu.gd:49` (`ui_cancel`), which sets `MOUSE_MODE_VISIBLE` at
line 66. This is expected; do not try to "fix" it.

Note that the same Escape also **pauses the tree** — see the pause-menu item in
§8. During two-window testing, pausing one window will stall that peer's
networking. Do the pause fix early if it gets in the way of testing.

### 7.4 Acceptance checklist

1. Two windows open, each showing a *different* character model.
2. Each window's camera follows only its own knight.
3. Moving in window A moves that knight in window B, smoothly, within ~100 ms.
4. Swinging in window A plays the swing animation in window B.
5. A wolf chases whichever player is nearest, and re-evaluates as they move.
6. A swing from window A severs a leg; **the same leg** is missing in window B.
7. The wolf's health bar reads the same in both windows.
8. The wolf dies once, and is a corpse in both windows.
9. Two players swinging at the same wolf in the same tick both land.
10. Closing window B removes that knight from window A.

---

## 8. Deferred to a later phase — do not implement now

- **The bow.** `player.gd:1618` instantiates `res://scenes/props/arrow.tscn`
  locally. Over the network arrows need host-authoritative spawning and their
  own synchronizer. Until that exists, either restrict multiplayer to
  sword characters, or accept that arrows are cosmetic-only on remote clients
  and say so in a comment. Do not silently leave it broken.
- **Player health and death.** Players are currently immortal — `health` exists
  only on `wolf.gd`. Wolves can bite but nothing happens. Leave it that way for
  this phase.
- **Pause menu over the network.** `scripts/pause_menu.gd` handles `ui_cancel`
  at line 49 and pauses the tree; it restores the mouse at lines 66 / 73 / 80.
  A paused tree stops that peer's `MultiplayerSynchronizer` and its ENet polling,
  so one player pausing freezes their knight for everyone and may time the
  connection out. Either give the pause menu `process_mode = PROCESS_MODE_ALWAYS`
  and leave the tree unpaused while `Net.is_online()`, or disable the menu
  entirely when online. The mouse-release half must keep working either way —
  it is the only way out of mouse capture.
- **Scene-load handshake.** A client that joins while the host is mid-level-load
  can miss spawns. For two people on one machine this does not occur. Do not
  build a readiness protocol yet.

---

## 9. Order of work

Each step should leave the game runnable.

1. `scripts/net.gd` + autoload registration + menu Host/Join buttons.
   Test: two windows connect, log "peer connected". World still solo-spawns.
2. Remove the baked `Player` (tscn:5559), add `Players` / `SpawnPoints` /
   `PlayerSpawner` + `scripts/world.gd`. Test: solo play still works, spawned
   rather than baked.
3. Authority gating in `player.gd` `_ready()` + `Camera3D.current` off in the
   scene. Test: two windows, two knights, correct cameras, **no movement sync
   yet**.
4. `MultiplayerSynchronizer` on `player.tscn` + `net_*` mirrors + the `_process`
   split. Test: acceptance items 1–3.
5. `net_attack` RPC. Test: acceptance item 4.
6. Enemy gating + enemy synchronizers. Test: acceptance items 5, 7.
7. `_nearest_player()` + per-attacker `_last_hit_serial`. Test: items 5, 9.
8. Sever split + `net_sever` RPC + `is_dead` setter. Test: items 6, 8.
9. `--host` / `--join` command-line args. Test: §7.2 flow end to end.
10. `grass_field.gd` nearest-player. Cosmetic.

---

## 10. Constraints

- Godot **4.7**, Forward+. No addons — do not add netfox or any other plugin in
  this phase; the built-in high-level API is sufficient for 4 players.
- GDScript, statically typed, matching the existing style: `##` doc comments on
  every public function, `#region` grouping, tabs for indentation.
- Do not reformat or restructure files beyond what the change requires.
- Do not touch `scripts/character_rig.gd`'s animation maths. The only change it
  may receive is the sever split described in §6.4, and only in `wolf_rig.gd`.
- `tests/smoke_test.gd` and `tests/combat_test.gd` must still pass in solo:
  ```
  godot --path . --headless --script res://tests/smoke_test.gd
  godot --path . --script res://tests/combat_test.gd -- /tmp
  ```
