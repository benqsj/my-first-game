class_name OgreFighter
extends PackBrute

## The ogre (Polysplit's Biped Creatures, CREATURES_PACK.md): a great club,
## slow and heavy (the user's picks, 2026-10-07; its fight made over in
## Elden Ring's way, 2026-10-08: "it does the same combo again and again").
##
## * **Strings, light and heavy.** Its swings are of two kinds: quick light
##   ones (a sweep, a chop, a backhand, a low sweep, a wide one round to the
##   side), that only stagger him, and heavy ones (an overhead smash, a
##   cleave, a leaping slam, a whirl brought down) that throw him down by
##   themselves (Elden Ring's rule, the user's word 2026-10-09: "not every
##   second blow should knock you down"). Each swing may run on into another
##   (`FOLLOW`, weighed; never the same twice running), up to `string_most`
##   of them, each turned a little after him; the close of a long one
##   (`finisher_from`) fells him too, light or not, if all of it found him.
##   Then it stands to get its breath (`recover`) — the opening.
## * **Where he stands chooses.** Off to its side it sweeps round at him; at
##   its back, the backhand; hugging it, a kick that beats a raised shield
##   aside; 4.5-8 m off, a lunge; the opener it began with last time is
##   seldom the next.
## * **Delayed swings** ([PackBrute] `_holds`): a heavy one, now and then,
##   held at the top of its wind-up before it comes down; him backed out of
##   its reach meanwhile, it slides at him fast as it lets go and follows him
##   round to the blow (`slide_*`): running does not beat it, a roll does.
##   And the roll-catch
##   (`CATCH`): him rolled out from under a blow, the next comes held a
##   beat, timed for the end of a roll made too early.
## * **Tracking, then committed** (Elden Ring's): each swing and leap turns
##   after him up to a late point before its blow (`commit_lead`), and is
##   locked from there — it is the timing of a roll that beats it, not
##   running from it.
## * **Its gait** (the user's word, 2026-10-09): a heavy walk of long strides
##   about its ground, a lumbering trot (`trot_clip`) coming at him, and a
##   real run (`run_speed`) when he plainly runs from it; each clip played at
##   the pace its feet keep to the ground.
## * **From afar** (the distance ladder): 4.5-8 m the sword dash (`LUNGE`);
##   8-14 m a great leap with the club overhead, brought down on him
##   (`LEAP_SLAM`); 12-22 m it runs at him, springs high and comes down club
##   first (`RUN_SLAM`). Both fell him; they follow him till they leave the
##   ground and are locked a little after.
## * **Aftershock**: a single heavy blow or a slam that strikes the ground is
##   followed a beat later by a second burst of earth ahead of it — the one
##   who comes back in too soon is caught (a jump or a roll clears it).
## * **The ground struck** (`CR_GroundPound`): the club brought down on the
##   ground sends a shock out round it ([PackBrute._quake], `pound_radius`):
##   whoever is on the ground as it passes is thrown down. Jump it, or roll.
## * **The great blow** (`CR_Heavy2`): the club raised slowly overhead, glowing
##   hotter as it goes (`heavy_slow`), and brought down: no shield holds it
##   (a "crush": the guard is beaten down and most of it lands), and it
##   throws him down. Get out from under it.
## * **The fallen trodden.** Him down within `stomp_reach`: the club brought
##   down on him where he lies ("stomp"). Roll out, or get up quick.
## * **Its stance** ([PackBrute]): no blow stops it or pushes it about, but
##   enough of them, heavy ones above all, put it down on a knee, open.
## * **Rage** ([PackBrute]): at half its health — and its strings run longer,
##   with the pound and the great blow in them.
## * **Combos** (`COMBOS`, the user's word 2026-10-10: a new combo, Elden
##   Ring's way): besides the strings weighed swing by swing, a few combos
##   made by hand, always the same moves in the same order, so they can be
##   learnt — Mixamo's great axe and great sword swings on its club. Their
##   last blow (`fells` in each) throws him down by itself; the ones before
##   only stagger. Some hold the closing blow at the top a beat (the delayed
##   finisher). Opened now and then instead of a string (`combo_chance`).
##   Some read him before their close (`branch`: he rolled, he is far off),
##   enraged most run longer (`rage`) and two come only then (`rage_only`);
##   hugging it, it headbutts, stamps or swipes him off (`close`), and at a
##   raised shield it swings its free hand at it first (`guard`).
## * **A held blow shows** (the user's word, 2026-10-10): the moment a swing
##   stops at the top of its wind-up, a glint off the club and a growl
##   ([method _glint]) — the delay can be learnt, not only guessed.

@export_group("Pound")
@export var pound_clip: StringName = &"CR_GroundPound"
@export var pound_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var pound_radius: float = 5.5
@export var pound_share: float = 0.85
## The pound three times (the user's word, 2026-10-11): a slam, a second one
## quick on it, and a third held overhead a beat and brought down hardest —
## each sends rock out further (m, at its size: 5, 10, 20 — 40 was too far,
## the user's word), no ring.
@export var pound_reaches: Vector3 = Vector3(5.0, 10.0, 20.0)

@export var pound_from: float = 1.5
@export var pound_to: float = 5.0
@export var pound_cooldown: Vector2 = Vector2(9.0, 14.0)

@export_group("Great blow")
@export var heavy_clip: StringName = &"CR_Heavy2"
@export var heavy_part: Vector3 = Vector3(0.95, 0.0, 0.9)
## How many times slower its wind-up is played, and how long before the blow
## it comes back to its own pace.
@export var heavy_slow: float = 2.4
@export var heavy_lead: float = 0.18
@export var heavy_share: float = 1.5
@export var heavy_cooldown: Vector2 = Vector2(8.0, 13.0)
## The great blow does not miss him by his walking off (the user's word,
## 2026-10-11): it turns after where he will be through its glowing wind-up
## till `heavy_commit` s before the blow, and him out of its reach it closes on
## him over its last `heavy_close` s (`heavy_close_most` m at most; a roll
## still beats it).
@export var heavy_commit: float = 0.12
@export var heavy_close: float = 0.5
@export var heavy_close_most: float = 8.0
## ...and the ground it strikes bursts up in rock all round (rows of stone
## out from the club to `heavy_rock_length` m, [RockWave]), and the
## blow goes through the ground to everyone on it within `heavy_quake_radius`
## m (at its size): they are thrown down (jump it, or roll).
@export var heavy_rock_length: float = 20.0
@export var heavy_quake_radius: float = 20.0
## How fast its rock runs out over the ground (m/s): the blow through the
## ground goes out with it.
@export var rock_pace: float = 22.0
@export var heavy_quake_share: float = 0.8

@export_group("Stomp")
@export var stomp_clip: StringName = &"CR_Heavy2"
@export var stomp_part: Vector3 = Vector3(1.3, 0.0, 0.85)
@export var stomp_reach: float = 3.4
@export var stomp_share: float = 0.6
@export var stomp_cooldown: float = 5.0
## The share of the times it treads on him down rather than wait for him.
@export var stomp_chance: float = 0.6

@export_group("Strings")
## The most swings in one string, calm and enraged.
@export var string_most: int = 3
## How soon after a swing's last blow the next of its string begins (s).
@export var string_follow_after: float = 0.32
@export var string_most_raging: int = 5
## Its breath got back after a string ends (s), calm and enraged.
## (the user's word 2026-10-12: a breath between strings — 0.9–1.2 s, raging
## 0.6–0.85 s)
@export var recover: Vector2 = Vector2(0.9, 1.2)
@export var recover_raging: Vector2 = Vector2(0.6, 0.85)
## Between its strings (and over him while he is down) it does not stand dead
## still (the user's word, 2026-10-10: it stood about a third of a fight): it
## prowls round him at this pace (m/s at its size), keeping to its reach,
## facing him, and now and then turns the other way.
@export var prowl_speed: float = 0.8
@export var prowl_turn_every: Vector2 = Vector2(1.0, 2.2)
## ...never further round him than this (deg) from where it last came at him:
## it does not end up behind him (the camera's side).
@export var prowl_arc: float = 30.0
## How far it turns after him between two swings of a string (degrees).
@export var string_turn: float = 55.0
@export var lunge_from: float = 4.5
@export var lunge_to: float = 8.0
@export var lunge_cooldown: Vector2 = Vector2(6.0, 10.0)
@export var kick_cooldown: float = 4.0
@export_group("Spacing")
## Between its strings it keeps its distance a while, as Elden Ring's great
## ones do (the user's word, 2026-10-11): it walks round him, backs off a
## few steps, or stands and watches him — and now and then beats its chest
## and roars at him — then comes at him all at once. How long (s), calm and
## enraged; 0 for none.
@export var spacing_time: Vector2 = Vector2(0.9, 2.0)
@export var spacing_time_raging: Vector2 = Vector2(0.4, 1.0)
## How it keeps its distance: round him, back off, stand watching, roar.
@export var spacing_weights: Vector4 = Vector4(0.45, 0.25, 0.15, 0.15)
## Walking round him (m/s at its size), and how much further out than its
## reach it keeps meanwhile (m).
@export var spacing_prowl_speed: float = 1.15
@export var spacing_keep: float = 0.7
## Backing off: its pace (m/s) and the furthest off it backs to (m).
@export var back_off_speed: float = 1.8
@export var back_off_to: float = 5.0
## The roar at him: its wait between two (s); only with him this far off.
@export var taunt_cooldown: Vector2 = Vector2(14.0, 24.0)
@export var taunt_from: float = 4.0
## Seconds into it that the roar comes.
@export var taunt_roar_at: float = 0.75
## Its spacing broken off all at once (per second, once it has kept its
## distance `burst_after` s): then in at him at its run, or a lunge or a
## leap from where it is.
@export var burst_rate: float = 1.2
@export var burst_after: float = 0.35
## Him walking into its reach while it keeps its distance: at him at once,
## this often.
@export var punish_close: float = 0.7
## Its name on the great enemy's bar at the bottom of his view ([PlayerHud]);
## with one it has no bar over its head.
@export var boss_name: String = "Mountain Ogre"
@export_group("Looks")
## No two alike (round 2 of the old plan, the user's word 2026-10-11): one of
## four skins, blood round the mouth on about a third, and in its hand its
## club or one of the pack's other arms — picked from its name, so every peer
## sees the same ogre. Off for a test that wants the plain one.
@export var varied: bool = true
@export var bloody_share: float = 0.34
## The skins (the pack's `color1` on its body): the pack's own, dark ochre,
## olive, green-grey.
const SKINS := [Color(0.7799, 0.6072, 0.3507), Color(0.55, 0.40, 0.25), Color(0.50, 0.50, 0.36),
		Color(0.42, 0.47, 0.36)]
## Its arms: [name in `ARMS_FILE` ("" = its own club), scale, the weapon's
## end out along the club's bone (`weapon_tip` x), how often]. The pack's
## weapons have their head along +Z (Blender's -Y); turned onto the club's +X.
const ARMS_FILE := "res://assets/creatures/ogre_arms.glb"
const ARMS := [["", 1.0, 0.92, 0.4], ["MorningStar", 1.2, 0.87, 0.2], ["GreatHammer", 0.95, 0.7, 0.2],
		["BoneMace", 1.1, 0.84, 0.2]]
@export_group("Death")
## Its death heavy and slow (the user's word, 2026-10-11): down on its knees,
## then over on its face (`CR_MG_Death`) at this rate; the ground takes it
## this far into the clip (share) — a thud, earth thrown up, the view shaken.
## Lying there, it goes to ash and embers as it sinks.
@export var heavy_death_clip: StringName = &"CR_MG_Death"
@export var death_rate: float = 0.6
@export var death_lands: float = 0.62
@export_group("Second phase")
## Its rage made a second phase (the user's word, 2026-10-11): the roar
## staggers whoever stands near it — not off his feet (the user's word, later
## that night) — the view shaken hard and long; and from then on its club
## burns and molten cracks run through its skin. Seconds into the rage that
## the roar comes; how far it reaches; its worth (a stagger, barely a wound).
@export var rage_roar_at: float = 0.75
@export var rage_push_radius: float = 6.0
@export var rage_push_share: float = 0.02
## The roar's shake: how hard (m of the view's offset) and how long (s).
@export var roar_shake: Vector2 = Vector2(0.32, 1.7)
## After the roar (the user's word, 2026-10-12: no colour on its skin — its
## club driven once into the ground and the stone coming up onto it): the
## clip of that blow and its part ([rate, from, to] shares), how many stones
## end up set in its club, how big (share of the club's length), and how
## much harder it hits from then on (over the pack's own `rage_harder`).
@export var arm_clip: StringName = &"CR_Heavy2"
@export var arm_part: Vector3 = Vector3(0.95, 0.0, 0.9)
@export var arm_stones: int = 20
@export var arm_stone_size: float = 0.15
@export var rage_damage: float = 1.5
@export_group("Get off me")
## (the user's word, 2026-10-12: greed must cost — souls-like) cut at
## `getoff_hits` times in `getoff_window` s, or stood under it `getoff_under`
## s (within `getoff_under_gap` m at 1.6), it stamps the ground round itself
## as soon as it is free: a grunt and its foot up first (the tell), then the
## ground bursting out to `getoff_radius` (m at 1.6) — a stagger worth
## `getoff_share` of `hit_damage`, never a fall. Then not again for
## `getoff_cooldown` s.
@export var getoff_hits: int = 3
@export var getoff_window: float = 2.0
@export var getoff_under: float = 1.2
@export var getoff_under_gap: float = 1.25
@export var getoff_radius: float = 3.0
@export var getoff_share: float = 0.3
@export var getoff_rate: float = 0.9
@export var getoff_cooldown: Vector2 = Vector2(7.0, 11.0)
## (the same: a giant winds up slowly) a string's first swing comes no
## sooner than this many seconds after it starts it — its wind-up drawn out,
## the blow as quick as ever; the swings it runs on into are as they were.
@export var opener_least: float = 0.6
## (the same, phase 2 a fight of its own) enraged, its overhead blows break the
## ground where they land: rock bursting up round it out to `rage_ground_radius`
## (m at 1.6), worth `rage_ground_share` — a roll or a jump clears it, standing
## off at middle reach no longer does.
@export var rage_ground_radius: float = 4.0
@export var rage_ground_share: float = 0.45
## (the same) where its body is struck: a cut low on its legs fills its stance
## `legs_stance` times as much; one high on its head bites `head_damage`
## times as deep. Shares of its height: legs under `legs_below`, the head over
## `head_above`.
@export var legs_stance: float = 1.5
@export var head_damage: float = 1.3
@export var legs_below: float = 0.35
@export var head_above: float = 0.78
## (the same) two fighting it: its health grown by this share for each hero
## past the first near it (Elden Ring's), back to its own at home.
@export var party_health: float = 0.6
## (the same) between the camera and him, it fades so he is seen.
@export var fade_between: float = 0.55
@export_group("Punish")
## Him casting near it, or drawing his bow / gathering a bolt (the user's
## word, 2026-10-11: Elden Ring's punish of the flask and the spell): it is
## at him at once — a swing in reach, a lunge, a leap, a run and spring —
## from as far as this (m at its size); a draw held this long first (s); and
## not again for so long (s).
@export var punish_reach: float = 22.0
@export var punish_draw_after: float = 0.45
@export var punish_wait_time: float = 2.5
@export_group("Grab")
## Its free hand swung down on him (the user's word, 2026-10-11/12: Elden
## Ring's grabs; then, the lift never sat right in its hand — "just swing that
## arm down and smash him into the ground"): a tell first — its free left arm
## drawn back, its hand lit cold blue like a spell being cast — then from up
## to 10 m it slides in on him like a skill and brings the arm down on him,
## into the ground, stone bursting up. No shield holds it; only a roll beats
## it. Mixamo's mutant swipe: the arm drawn back by `grab_cock.x` (clip s),
## held there `grab_cock.y` s while it slides in (the clip creeping to
## `grab_cock.z`), then swept down.
@export var grab_clip: StringName = &"CR_OG_Mutant_Swipe"
@export var grab_rate: float = 1.0
@export var grab_cock: Vector3 = Vector3(1.0, 0.45, 1.1)
## How fast it slides in on him at most (m/s at its size), how long the
## slide takes (s: planted till then, its hand lit — then at him at once, the
## user's word 2026-10-12: "0.2 s and it is on me"), and how far out in front
## of it its hand comes down (m).
@export var grab_dash: float = 60.0
@export var grab_dash_time: float = 0.2
@export var grab_hand_out: float = 1.55
## Clip seconds of the swipe: its hand at him (he is struck in that window),
## and its hand into the ground.
@export var grab_catch: Vector2 = Vector2(1.18, 1.36)
@export var grab_smash_at: float = 1.4
## Leaning into the swipe ([LeanModifier]), degrees at full.
@export var grab_bend: float = 26.0
## Its hand's light through the tell.
@export var grab_glow: Color = Color(0.35, 0.62, 1.0)
## From how far it comes at him (m at its size; it slides in on him).
@export var grab_from: float = 10.0
## How far its hand may be from him and still strike him (m).
@export var grab_radius: float = 1.0
## How often it does it when it could — more behind a raised shield.
@export var grab_chance: float = 0.4
@export var grab_chance_guarded: float = 0.7
@export var grab_cooldown: Vector2 = Vector2(9.0, 15.0)
## The blow's worth (a share of `hit_damage`).
@export var grab_share: float = 1.8
@export_group("Gait")
## Its trot coming at him (the walk is `walk_clip`, the run `run_clip`); the
## paces it changes from walk to trot and from trot to run (m/s).
@export var trot_clip: StringName = &"CR_OgreTrot"
@export var trot_above: float = 2.9
@export var run_gait_above: float = 4.9
## No trot (the user's word, 2026-10-11: the jog out, its quick run in its
## place): coming at him it runs, at `run_speed`, as it did only when he ran.
@export var runs_after: bool = true
## Its run, when he runs from it: the gap opening this fast (m/s) for this
## long (s) with him this far off.
@export var run_speed: float = 6.0
@export var flee_rate: float = 1.2
@export var flee_time: float = 0.6
@export var flee_from: float = 5.0

@export_group("From afar")
## (2026-10-12, the user's word: its leap came too quick to answer — it
## sprang at once off a standing swing and was on him in a third of a
## second) Mixamo's mutant jump: down into a crouch first (the tell, half a
## second, with a roar), then a high leap of a second's flight, the club
## brought down with it, and a long stoop after as it gets up.
@export var leap_slam_clip: StringName = &"CR_OG_Mutant_Jump"
@export var leap_slam_part: Vector3 = Vector3(1.0, 0.0, 0.78)
## (the user's word, the same evening: so long in the air he had time to
## think; and it came down on nothing) its landing breaks the ground: rock
## bursting up round it out to `leap_land_radius` (m at 1.6), worth
## `leap_land_share` of `hit_damage` to whoever stands on it.
@export var leap_land_radius: float = 5.0
@export var leap_land_share: float = 0.9
@export var leap_rock_length: float = 6.0
## Share of `leap_slam_clip` its club comes down on the ground.
@export var leap_slam_lands: float = 0.45
@export var leap_slam_from: float = 8.0
@export var leap_slam_to: float = 14.0
@export var leap_slam_cooldown: Vector2 = Vector2(8.0, 12.0)
@export var leap_slam_share: float = 1.3
@export var run_slam_clip: StringName = &"CR_RunJumpSlam"
@export var run_slam_part: Vector3 = Vector3(1.0, 0.218, 1.0)
@export var run_slam_from: float = 12.0
@export var run_slam_to: float = 22.0
## It springs off its run this far from him.
@export var run_slam_takeoff: float = 9.5
@export var run_slam_cooldown: Vector2 = Vector2(10.0, 16.0)
@export var run_slam_share: float = 1.5

@export_group("Elden Ring")
## How long before a blow it stops turning after him (s): light, heavy.
@export var commit_lead: Vector2 = Vector2(0.28, 0.36)
## The roll-catch's hold, and how often it answers a roll with it.
@export var catch_hold: Vector2 = Vector2(0.42, 0.55)
@export var catch_chance: float = 0.65
## How often a heavy swing (and the great blow) is held at the top of its
## wind-up, and a sweep from the side (the user's word, 2026-10-11: more).
@export var held_chance: float = 0.5
@export var held_side_chance: float = 0.3
## The aftershock: how long after the blow, how far ahead of the club, how
## wide, and its worth (a share of `hit_damage`; it staggers, never fells).
@export var aftershock_after: float = 0.4
@export var aftershock_ahead: float = 1.1
@export var aftershock_radius: float = 2.6
@export var aftershock_share: float = 0.45
## Whether its blows into the ground answer a beat later with that second,
## unseen burst ahead of the club. Off (the user's word, 2026-10-11): it read
## as a hit out of nowhere, small stones and a stagger with nothing to warn
## of it; the rock of the great blow and the pound stays. Its stamping foot
## still uses the burst (seen coming).
@export var aftershocks_follow: bool = false
## A held swing (the user's word, 2026-10-09): planted through its wind-up
## and its hold — no stepping in or backing off, so no glide and no rocking
## to and fro as he moves round it; let go with him out of its reach (by
## more than `slide_slack` m), it slides at him at once from the end of the
## hold to its blow, turning after him all the way — only a roll beats it.
## It slides no further than `slide_most` (m at its size).
@export var slide_most: float = 11.0
@export var slide_slack: float = 0.15
## Running does not beat a held swing, a jump slam or a leap (the user's
## word, 2026-10-10: running fast he kept out of its reach — only a roll
## must): they go for where he will be when the blow lands, his run carried
## on (`chase_lead_most` s of it at most), and turn after him until
## `chase_commit` s before the blow (a leap: `chase_flight_commit` of its
## flight). The jump slam closes on him over its last `jump_slam_close` s,
## `jump_slam_most` m at most.
@export var chase_lead_most: float = 1.2
@export var chase_commit: float = 0.12
@export var chase_flight_commit: float = 0.85
@export var jump_slam_close: float = 0.55
@export var jump_slam_most: float = 7.0
## The whirl that slides ([constant OG_SPIN_SLIDE], the user's word 2026-10-11:
## fast, as Tariel's and the assassin's glide at a foe, and from 15-20 m too):
## him off out of its reach, it shoots at him at `spin_dash_speed` (m/s at its
## size), timed to get there as the club comes round — far off, the slide
## starts in its wind-up and the turn comes on the way; near, it turns and
## shoots in at the end. No further than `spin_slide_most` m.
@export var spin_dash_speed: float = 20.0
@export var spin_slide_most: float = 24.0
## Its combos' moves played this much quicker than the clips (the user's word,
## 2026-10-11: they were too slow): light, heavy.
@export var combo_pace: Vector2 = Vector2(1.5, 1.32)

@export_group("Combos")
## How often it opens a combo of its own (`COMBOS`) rather than a string, he
## in front and in reach of its first move: calm, enraged.
@export var combo_chance: Vector2 = Vector2(0.4, 0.55)
## Hugging it (him closer than its kick's reach), how often it answers with one
## of its close combos (a headbutt, a stamp, a swipe of its free hand) rather
## than the kick.
@export var close_combo_chance: float = 0.6
## A combo reads him before a `branch`: he is "far" past its next move's reach
## by this much (m at its size).
@export var branch_far: float = 1.5

@export_group("Strings")
## The closing swing of a string this long or longer (calm, enraged) throws
## him down even if it is a light one — if every blow of the string before
## it found him ([Player.receive_blow]). Shorter strings end on a stagger.
@export var finisher_from: Vector2i = Vector2i(3, 4)

@export_group("Co-op")
## (the user's word, 2026-10-28: two, three or four must not kill it easily —
## it must strike them all, project doc claude/boss_coop_plan.md) only with
## more than one hero at it; one alone fights it as before. Ranges in m at
## `visual_scale` 1.6, grown with it.
## Round itself: two or more within `ring_reach`, one of them at its side or
## back — its whirl, or its stamp into the whirl; then not for
## `ring_cooldown` s (that wait runs `ring_quicker` faster for each hero over
## two).
@export var ring_reach: float = 3.4
@export var ring_cooldown: Vector2 = Vector2(7.0, 11.0)
@export var ring_quicker: float = 0.25
## At its back: one who is not its quarry and cuts it from behind
## `rear_hits` times in `rear_window` s, or stands there `rear_stand` s
## (within `rear_reach`), is turned on — it wheels round at him into its
## backhand and the club down on him (`turn_back`); then not for
## `rear_cooldown` s.
@export var rear_hits: int = 2
@export var rear_window: float = 4.0
@export var rear_stand: float = 2.5
@export var rear_reach: float = 4.2
@export var rear_cooldown: Vector2 = Vector2(5.0, 8.0)
## Turned round onto another mid-act, it tracks this many times quicker than
## its own (and commits no sooner than `wheel_commit` s before the blow).
@export var wheel_rate: float = 2.6
@export var wheel_commit: float = 0.14
## Through a string: its quarry down, out of its reach or round its back, the
## next blow goes onto another in its reach (within `switch_turn` degrees of
## where it faces); and now and then (`switch_chance`) when another stands
## clearly nearer before it. At most `switch_most` times a string.
@export var switch_chance: float = 0.3
@export var switch_turn: float = 120.0
@export var switch_most: int = 2
## From afar: one off past `far_from` who hurts it from there `far_hits`
## times in `far_window` s, or casts there, is gone for — its leap onto him,
## or its run and spring from further; then not for `far_cooldown` s.
@export var far_from: float = 7.0
@export var far_hits: int = 3
@export var far_window: float = 6.0
@export var far_cooldown: Vector2 = Vector2(9.0, 14.0)
## The anger a turn of its own puts on the one it turns on ([method Threat.turn_to]).
@export var coop_anger: float = 40.0

const SOUNDS := "res://sounds/ogre/"
const WHOOSH_HEAVY := SOUNDS + "whoosh_heavy.wav"
const WHOOSH_LIGHT := SOUNDS + "whoosh_light.wav"
const ROAR_SOUND := SOUNDS + "roar.wav"
const ROAR_SHORT_SOUND := SOUNDS + "roar_short.wav"
const GRUNTS := [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_2.wav", SOUNDS + "grunt_3.wav"]
const CLUB_GROUND := [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_3.wav",
		SOUNDS + "club_ground_4.wav"]
const STEPS := [SOUNDS + "step_1.wav", SOUNDS + "step_2.wav", SOUNDS + "step_3.wav"]
## A rising creak and rush of air as a held swing is about to come down
## (vepxis-art/tools/ogre_strain.py).
const STRAIN_SOUND := SOUNDS + "strain_rise.wav"

const POUND := 113
const HEAVY := 114
const STOMP := 115
## Its light swings.
const SWEEP := 130
const CHOP := 131
const BACKHAND := 132
const WIDE := 133
const LOW := 134
## Its heavy ones.
const SMASH := 135
const CLEAVE := 136
const JUMP_SLAM := 137
const WHIRL := 138
## A kick at him hugging it, and a lunge from further off.
const KICK := 139
const LUNGE := 140
## Its leaps from afar, and the roll-catch.
const LEAP_SLAM := 141
const RUN_SLAM := 143
const CATCH := 144
## The combos' own moves (Mixamo's great axe and great sword, 2026-10-10).
const OG_HORIZ := 150
const OG_BACK := 151
const OG_DOWN := 152
const OG_SPIN := 153
const OG_TWIN := 154
const OG_DOUBLE := 155
const OG_TRIPLE := 156
const OG_JUMP := 157
const OG_DOWN_HELD := 158
const OG_JUMP_HELD := 159
## ...and fresh from Mixamo (vepxis-art/mixamo_ogre): its two-handed club
## combo, the one-handed one, the club down into the ground two-handed, and
## a great leap down on him.
const OG_CLUB2H := 160
const OG_CLUB1H := 161
const OG_GROUND := 162
const OG_MJUMP := 163
## The whirl closing the run of three, drawn out (the user's word, 10-10
## 19:29): slower, and him off out of its reach it slides at him through the
## turn, so it comes round on him as it gets to him, not slid up and then
## turned ([constant FLIGHTS], no lift).
const OG_SPIN_SLIDE := 164
## Hugging it: a headbutt, a stamp of its foot (the ground bursting up round
## it, [method _aftershock]) and its free hand swung at him (beats a raised
## shield aside, "guard").
const OG_HEADBUTT := 165
const OG_STOMP_FOOT := 166
const OG_SWIPE := 167
## The pound's second (quick) and third (held overhead, then brought down).
const POUND_2 := 168
const POUND_3 := 169
## Its roar at him while it keeps its distance (`CR_OG_Battlecry`).
const TAUNT := 170
## Its grab ([member grab_clip]).
const GRAB := 171
## Enraged, after the roar: its club driven into the ground, stone coming up
## onto it ([member arm_clip]).
const RAGE_ARM := 174
## Its stamp round itself, when he is greedy or under it ([member getoff_hits]).
const GETOFF := 175
## what -> [clip, [rate, from, to], heavy, share of `hit_damage`, its blows'
## moments (shares of the clip; empty: where the club reaches furthest),
## name ([member BLOW_NAMES]), held at the top [shortest, longest, s before
## the blow] or [] (always held, when given)].
## (the spins and the double sped up, their slow start cut — the user's word
## 2026-10-12: the spinning close came so slowly a late roll still cleared it)
const COMBO_MOVES := {
	OG_HORIZ: [&"CR_OG_Attack_Horizontal", Vector3(0.95, 0.1, 0.8), false, 0.6, [], &"og_horiz", []],
	OG_BACK: [&"CR_OG_Attack_Backhand", Vector3(0.95, 0.08, 0.62), false, 0.6, [], &"og_back", []],
	OG_DOWN: [&"CR_OG_Attack_Downward", Vector3(0.9, 0.05, 0.75), true, 1.1, [], &"og_down", []],
	OG_SPIN: [&"CR_OG_Attack_360", Vector3(1.25, 0.12, 0.7), true, 1.2, [], &"og_spin", []],
	OG_TWIN: [&"CR_OG_Combo_3", Vector3(0.95, 0.12, 0.9), false, 0.5, [0.372, 0.617], &"og_twin", []],
	OG_DOUBLE: [&"CR_OG_Combo_1", Vector3(1.15, 0.1, 0.85), false, 0.5, [0.372, 0.639], &"og_double", []],
	OG_TRIPLE: [&"CR_OG_Combo_2", Vector3(0.95, 0.08, 0.85), false, 0.45, [0.217, 0.406, 0.617], &"og_triple", []],
	OG_JUMP: [&"CR_OG_Jump_Attack", Vector3(0.9, 0.05, 0.85), true, 1.25, [], &"og_jump", []],
	OG_DOWN_HELD: [&"CR_OG_Attack_Downward", Vector3(0.9, 0.05, 0.75), true, 1.15, [], &"og_down", [0.7, 1.0, 0.22]],
	OG_JUMP_HELD: [&"CR_OG_Jump_Attack", Vector3(0.9, 0.05, 0.85), true, 1.3, [], &"og_jump", [0.5, 0.75, 0.3]],
	OG_CLUB2H: [&"CR_OG_Club_Combo2H", Vector3(1.0, 0.36, 0.85), false, 0.5, [0.517, 0.728], &"og_club", []],
	OG_CLUB1H: [&"CR_OG_Club_Combo1H", Vector3(1.0, 0.22, 0.85), false, 0.45, [0.35, 0.594, 0.739], &"og_club", []],
	OG_GROUND: [&"CR_OG_Zombie_Overhead", Vector3(0.95, 0.05, 0.6), true, 1.2, [], &"og_ground", []],
	OG_MJUMP: [&"CR_OG_Mutant_Jump", Vector3(0.95, 0.02, 0.8), true, 1.35, [], &"og_mjump", []],
	OG_SPIN_SLIDE: [&"CR_OG_Attack_360", Vector3(1.3, 0.12, 0.7), true, 1.25, [], &"og_spin", []],
	# [.., limbs that strike (as `attack_limbs`), the kind of blow]
	OG_HEADBUTT: [&"CR_OG_Headbutt", Vector3(1.0, 0.1, 0.7), false, 0.4, [], &"og_headbutt", [],
			"head_joint>head_joint@0.11,0.13,0:0.24", &"guard"],
	OG_STOMP_FOOT: [&"CR_OG_Stomp", Vector3(1.0, 0.05, 0.75), false, 0.3, [], &"og_stomp", [],
			"R_knee_joint>R_toe_joint:0.16", &""],
	OG_SWIPE: [&"CR_OG_Mutant_Swipe", Vector3(1.0, 0.2, 0.8), false, 0.45, [], &"og_swipe", [],
			"L_elbow_joint>L_midFinger_joint3:0.18", &"guard"],
}
## Its combos made by hand: name, its moves in order, which of them throw
## him down by themselves (by their place; the others only stagger), and how
## often it picks it.
const COMBOS := [
	{"name": &"three", "moves": [OG_HORIZ, OG_BACK, OG_DOWN], "fells": [2], "weight": 1.0,
			"rage": [OG_SPIN_SLIDE]},
	{"name": &"delayed_leap", "moves": [OG_TWIN, OG_JUMP_HELD], "fells": [1], "weight": 0.8,
			"rage": [OG_GROUND]},
	{"name": &"five_spin", "moves": [OG_TRIPLE, OG_SPIN], "fells": [1], "weight": 0.7},
	{"name": &"feint", "moves": [OG_BACK, OG_HORIZ, OG_DOWN_HELD], "fells": [2], "weight": 0.8,
			"rage": [OG_JUMP_HELD]},
	{"name": &"club_ground", "moves": [OG_CLUB2H, OG_GROUND], "fells": [1], "weight": 0.8},
	{"name": &"club_leap", "moves": [OG_CLUB1H, OG_MJUMP], "fells": [1], "weight": 0.6},
	{"name": &"five_spin_slide", "moves": [OG_TRIPLE, OG_SPIN_SLIDE], "fells": [1], "weight": 0.7,
			"rage": [OG_MJUMP]},
	# Reading him (the user's pick, 10-10): the same opening, its close by what
	# he did — rolled out under it: the overhead held for the end of his roll;
	# backed off: the whirl sliding at him, or a leap; stood: as it was.
	{"name": &"three_read", "moves": [OG_HORIZ, OG_BACK, OG_DOWN], "fells": [2], "weight": 0.9,
			"branch": {2: [[&"rolled", OG_DOWN_HELD], [&"far", OG_JUMP_HELD]]}},
	{"name": &"five_read", "moves": [OG_TRIPLE, OG_SPIN], "fells": [1], "weight": 0.9,
			"branch": {1: [[&"far", OG_SPIN_SLIDE], [&"rolled", OG_DOWN_HELD]]}},
	# Hugging it.
	{"name": &"headbutt", "moves": [OG_HEADBUTT, OG_DOWN], "fells": [1], "weight": 1.0, "close": true},
	{"name": &"stamp", "moves": [OG_STOMP_FOOT, OG_SPIN], "fells": [1], "weight": 0.8, "close": true},
	{"name": &"shove", "moves": [OG_SWIPE, OG_CLUB2H], "fells": [1], "weight": 0.8, "close": true,
			"guard": true},
	# At a raised shield, from its reach: the free hand beats it aside first.
	{"name": &"shield_break", "moves": [OG_SWIPE, OG_HORIZ, OG_DOWN], "fells": [2], "weight": 0.4,
			"guard": true},
	# Enraged only.
	{"name": &"fury", "moves": [OG_CLUB2H, OG_SPIN_SLIDE, OG_GROUND], "fells": [2], "weight": 1.0,
			"rage_only": true},
	{"name": &"storm", "moves": [OG_HORIZ, OG_BACK, OG_HORIZ, OG_BACK, OG_DOWN_HELD], "fells": [4],
			"weight": 0.8, "rage_only": true},
	# One at its back (co-op, [member rear_hits]): wheeled round at him into
	# the backhand, the club down on him (never weighed: opened only so).
	{"name": &"turn_back", "moves": [OG_BACK, OG_DOWN], "fells": [1], "weight": 0.0,
			"rage": [OG_SPIN]},
	# The pound three times, its rock further each time (opened when its pound
	# is due, never weighed among the others).
	{"name": &"triple_pound", "moves": [POUND, POUND_2, POUND_3], "fells": [], "weight": 0.0,
			"relentless": true},
]
## A leap's flight drawn out: act -> [clip s it leaves the ground, clip s it
## lands, how many times slower the flight is played], and how high the
## body is lifted on top of the clip's own jump (m at its size).
const FLIGHTS := {
	# (2026-10-11, the user's word: quicker through the air at him — the
	# flights played quicker than the clips, not drawn out)
	# (2026-10-12, the user's word: no time to answer the leap) both now at
	# the clips' own pace through the air: the leap out of its crouch
	LEAP_SLAM: [0.5, 1.62, 0.6, 0.25],
	RUN_SLAM: [0.87, 1.62, 1.0, 0.55],
}

## what -> [clip, [rate, from, to], heavy, share of `hit_damage`, how often
## it opens with it, how it does from his side (`_side_weight`), whether it
## fells him (1: it does, by itself; 99: not — but the closing blow of a long
## string does, [member finisher_from])].
const SWINGS := {
	SWEEP: [&"CR_Slash1", Vector3(0.85, 0.0, 0.9), false, 0.55, 1.0, &"front", 99],
	CHOP: [&"CR_Slash4", Vector3(0.85, 0.0, 0.9), false, 0.6, 1.0, &"front", 99],
	BACKHAND: [&"CR_RegB", Vector3(0.8, 0.0, 0.92), false, 0.6, 0.35, &"behind", 99],
	WIDE: [&"CR_Slash3", Vector3(0.82, 0.0, 0.92), false, 0.65, 0.6, &"side", 99],
	LOW: [&"CR_LightD", Vector3(0.85, 0.0, 0.9), false, 0.55, 0.7, &"side", 99],
	SMASH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.9, &"front", 1],
	CLEAVE: [&"CR_Heavy3", Vector3(1.0, 0.0, 0.92), true, 1.0, 0.8, &"front", 1],
	JUMP_SLAM: [&"CR_Heavy4", Vector3(1.0, 0.0, 0.92), true, 1.2, 0.5, &"front", 1],
	# (2026-10-11, the user's word: the sword pack's spin bobbed up and down
	# on the spot, its hips rising 0.37 m and dropping; the club's own 360,
	# low and grounded, in its place, played heavier)
	WHIRL: [&"CR_OG_Attack_360", Vector3(1.0, 0.06, 0.88), true, 1.35, 0.3, &"front", 1],
	KICK: [&"CR_Kick", Vector3(0.95, 0.0, 0.85), false, 0.35, 0.0, &"front", 99],
	LUNGE: [&"CR_SwordDash", Vector3(0.9, 0.0, 0.9), false, 0.7, 0.0, &"front", 99],
	# The smash, held a beat for the end of his roll: never an opener.
	CATCH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.0, &"front", 1],
}

## What a swing may run on into: [what, weight]; -1 is the string's end.
const FOLLOW := {
	SWEEP: [[BACKHAND, 0.45], [CHOP, 0.25], [SMASH, 0.2], [CATCH, 0.12], [-1, 0.2]],
	BACKHAND: [[SMASH, 0.35], [LOW, 0.2], [WHIRL, 0.15], [-1, 0.25]],
	CHOP: [[SWEEP, 0.3], [CLEAVE, 0.3], [CATCH, 0.12], [-1, 0.25]],
	LOW: [[CLEAVE, 0.35], [BACKHAND, 0.2], [-1, 0.25]],
	WIDE: [[SMASH, 0.3], [BACKHAND, 0.25], [CATCH, 0.1], [-1, 0.3]],
	CATCH: [[WIDE, 0.25], [SWEEP, 0.15], [-1, 0.6]],
	LEAP_SLAM: [[WIDE, 0.25], [BACKHAND, 0.15], [-1, 0.6]],
	RUN_SLAM: [[-1, 1.0]],
	SMASH: [[CLEAVE, 0.3], [WIDE, 0.2], [-1, 0.4]],
	CLEAVE: [[WHIRL, 0.2], [SWEEP, 0.2], [-1, 0.5]],
	JUMP_SLAM: [[WIDE, 0.35], [SMASH, 0.2], [-1, 0.35]],
	WHIRL: [[-1, 1.0]],
	KICK: [[SMASH, 0.45], [SWEEP, 0.35], [-1, 0.2]],
	LUNGE: [[BACKHAND, 0.35], [SMASH, 0.3], [CHOP, 0.2], [-1, 0.15]],
	POUND: [[SWEEP, 0.25], [-1, 0.75]],
	HEAVY: [[-1, 1.0]],
}
## Enraged, on top: the pound and the great blow come into its strings.
const FOLLOW_RAGING := {
	SMASH: [[JUMP_SLAM, 0.25]],
	CLEAVE: [[POUND, 0.3]],
	WHIRL: [[POUND, 0.5], [-1, -0.5]],
	POUND: [[HEAVY, 0.4], [JUMP_SLAM, 0.3]],
	HEAVY: [[POUND, 0.4], [-1, -0.4]],
	JUMP_SLAM: [[WHIRL, 0.25]],
}

var _pound_wait: float = 3.0
var _heavy_wait: float = 2.0
var _stomp_wait: float = 0.0
var _lunge_wait: float = 3.0
var _kick_wait: float = 0.0
## Which way round him it prowls (1 to its right), and when it turns.
var _prowl_side: float = 1.0
var _prowl_turn: float = 0.0
## Where round him it was when it last came at him (flat, from him), and
## how far round from there it has prowled (deg).
var _prowl_home := Vector3.ZERO
var _prowl_was: float = 0.0
## Act seconds the club meets the ground in the pound and the stomp.
var _pound_at: float = 0.5
var _stomp_at: float = 0.5
var _pounded: bool = false
## Host: how many swings into this string, the swing it opened with last, and
## the moves it has made (for a test).
var _string_count: int = 0
var _last_opener: int = -1
var _lunge_speed: float = 0.0
## The held swing sliding at him: the act serial it is on, and its speed.
var _slide_serial: int = -1
var _slide_speed: float = 0.0
## The jump slam's speed closing on him.
var _jump_speed: float = 0.0
## How many held swings slid at him (for the tests).
var slides_made: int = 0
var moves_made: Array[int] = []
## Host: this swing closes its string (and fells him), and the blows of the
## string so far by their kind (each kind is a combo of its own to him).
var _closing: bool = false
var _kind_blows: Dictionary = {}
var finishers_made: int = 0
## Host: the combo it is on (`COMBOS`, -1 none), the place in it, the one to
## open with next ([method start_combo]), the last it made; counts.
var _combo: int = -1
var _combo_step: int = 0
var _combo_pending: int = -1
var _last_combo: int = -1
var combos_made: Array[int] = []
## Host: the combo's moves as they run this time (its rage tail on, its
## branches taken) and which of them fell him; the last one's, for a test.
var _combo_moves: Array = []
var _combo_fells_at: Array = []
var last_combo_moves: Array = []
## How many branches it took, by the reading (for a test).
var branches_taken: Dictionary = {}
## Every peer: the held swing it last showed the glint of.
var _glint_serial: int = -1
## Host: the leaps' waits and speed, the run-up at him, whether he is running
## from it (and how long the gap has been opening), the gap a tick ago.
var _leap_slam_wait: float = 4.0
var _run_slam_wait: float = 5.0
var _flight_speed: float = 0.0
var _charging: bool = false
var _charge_time: float = 0.0
var running_after: bool = false
var _opening: float = 0.0
var _last_gap: float = -1.0
var _trot_speed: float = 3.8
## Host: he rolled under this swing's blow; the aftershocks to come
## ([at, seconds left, id]); counts for a test.
var _saw_roll: bool = false
var _shocks: Array = []
var _shock_look: Vector2 = Vector2(-1, 0)
var aftershocks_made: int = 0
## Host: keeping its distance between strings ([member spacing_time]): how
## (&"prowl", &"back", &"watch"; &"" not), how long still, how long so far;
## the roar's wait; the dash in after it; counts for a test.
var _spacing: StringName = &""
var _spacing_left: float = 0.0
var _spacing_held: float = 0.0
var _taunt_wait: float = 8.0
var _rush_left: float = 0.0
var spacings_made: Dictionary = {}
## Host: the grab — its wait, the act it last tried to catch him in, whom it
## holds; counts for a test.
var _grab_wait: float = 4.0
var _grab_serial: int = -1
## Every peer: the grab act in which its hand closed on him (its clock is
## warped from then: [method _clip_time]).
var _smashed_serial: int = -1
## Every peer: its hand's light and sparks through the tell.
var _glow_hand: OmniLight3D
var _glow_sparks: GPUParticles3D
var _glow_core: MeshInstance3D
## Every peer: its waist bent over him ([LeanModifier]).
var _lean: LeanModifier
## Whether the swing now is the first of its string (drawn-out wind-up,
## [member opener_least]); every peer has it with `act`.
var act_opens: bool = false
## Host: when his cuts landed lately, how long he has stood under it, and
## the stamp's due, its wait, and how many it has made.
var _cut_times: Array = []
var _under_for: float = 0.0
var _getoff_due: bool = false
var _getoff_wait: float = 0.0
var getoffs_made: int = 0
## Its stance share from where the cut now landed (legs), for [method _stance_weight].
var _part_stance: float = 1.0
## Its own health before more heroes came ([member party_health]).
var _own_health: float = -1.0
## How faded it is now (every peer, his own camera's).
var _faded: float = 0.0
var rage_grounds: int = 0
var grabs_made: int = 0
var grab_rolls: int = 0
var grab_dashes: int = 0
var _grab_dashed: bool = false
var _grab_passed: int = 0
## Host: his casts seen so far (by hero), how long he has drawn, the punish
## due and its wait; a count for a test.
var _seen_casts: Dictionary = {}
var _drawn_for: float = 0.0
var _punish_left: float = 0.0
var _punish_wait: float = 0.0
var punishes_made: int = 0
## Host: the rage roar's throw done (its act serial); a count for a test.
## Every peer: the burning club and the cracks.
var _rage_pushed: int = -1
var rage_throws: int = 0
var _club_fire: GPUParticles3D
## Every peer: the stones set in its club once enraged; a count for a test.
var _club_stones: BoneAttachment3D
var clubs_armed: int = 0
var _armed_serial: int = -1
## Its looks, as picked ([member varied]): skin, blood, arm (index of each).
var skin_index: int = 0
var bloody: bool = false
var arm_index: int = 0
## Every peer: the ground's thud and the ash heard/shown once.
var _death_landed: bool = false
var _ashed: bool = false
var _cracks: ShaderMaterial
var grabs_caught: int = 0
var grab_throws: int = 0
var bursts_made: int = 0
var taunts_made: int = 0
var catches_made: int = 0
## Every peer: the body lifted through a leap.
var _lifted: bool = false
## Every peer: the move shown and its clock, which of its blows have been
## heard, and the feet (down or not) for the footfalls.
var _heard_serial: int = -1
var _heard_clock: float = 0.0
var _heard: int = 0
var _ankles: PackedInt32Array = PackedInt32Array()
var _foot_down: Array[bool] = [true, true]
## Every peer: the body at rest (x, z), whether it trembles now, and the held
## swing whose strain was last heard.
var _body_rest_xz := Vector2.ZERO
var _trembling: bool = false
var _strain_serial: int = -1

## Host, co-op ([member ring_reach] and on): its own clock, the waits, the
## cuts from behind and from afar by hero id (clock times), how long each has
## stood at its back, the casts seen, the far one it goes for next, its turns
## onto another in this string, and the act it wheels round in.
var _coop_clock: float = 0.0
var _ring_wait: float = 3.0
var _rear_wait: float = 2.0
var _far_wait: float = 4.0
var _rear_cuts: Dictionary = {}
var _far_cuts: Dictionary = {}
var _behind_for: Dictionary = {}
var _far_casts: Dictionary = {}
var _far_due: Node3D = null
var _switches: int = 0
var _wheel_next: bool = false
var _wheel_serial: int = -1
var rings_made: int = 0
var rears_made: int = 0
var switches_made: int = 0
var fars_made: int = 0


## Its ranges in metres, written for an ogre at `visual_scale` 1.6 and grown
## with it (the rest scale where they are used, by `visual_scale / 1.6`).
const SIZED_RANGES := [&"pound_from", &"pound_to", &"stomp_reach", &"lunge_from", &"lunge_to",
		&"back_off_to", &"taunt_from", &"flee_from", &"leap_slam_from", &"leap_slam_to",
		&"run_slam_from", &"run_slam_to", &"run_slam_takeoff"]


func _ready() -> void:
	var s := visual_scale / 1.6
	for what: StringName in SIZED_RANGES:
		set(what, float(get(what)) * s)
	_pick_looks()
	super()
	_wear_looks()
	_special(POUND, pound_clip, pound_part)
	_special(POUND_2, pound_clip, Vector3(pound_part.x * 1.6, 0.25, pound_part.z))
	_special(POUND_3, pound_clip, pound_part)
	# the club itself on him in each (it only staggers: the rock throws him)
	for p: int in [POUND_2, POUND_3]:
		_special_strike(p, "", pound_share * 0.6, 99)
	# the third held overhead a beat, glinting ([method _watch_hold])
	_holds[POUND_3] = [1.0, 0.55, 0.75, 0.25]
	_special(HEAVY, heavy_clip, heavy_part)
	_special_strike(HEAVY, "", heavy_share, 1)
	_kinds[HEAVY] = &"crush"
	_windups[HEAVY] = [heavy_slow, heavy_lead]
	_special(STOMP, stomp_clip, stomp_part)
	_special(TAUNT, &"CR_OG_Battlecry", Vector3(1.0, 0.0, 0.96))
	_special(GETOFF, &"CR_OG_Stomp", Vector3(getoff_rate, 0.05, 0.75))
	_special(GRAB, grab_clip, Vector3(grab_rate, 0.0, 0.97))
	_kinds[GRAB] = &"smash"
	_make_grab_glow()
	if _anim != null and _anim.clip_length(arm_clip) > 0.0:
		_special(RAGE_ARM, arm_clip, arm_part)
	if _skeleton != null:
		_lean = LeanModifier.new()
		_lean.bend = grab_bend
		_skeleton.add_child(_lean)
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		_special(what, sw[0], sw[1])
		# A heavy one fells him by itself, a light one never (but as the close
		# of a long string, [method _begin_move]).
		_special_strike(what, "", float(sw[3]), int(sw[6]))
		if bool(sw[2]):
			_holds[what] = [held_chance, 0.3, 0.75, 0.22]
	for what: int in COMBO_MOVES:
		_combo_move(what)
	_holds.erase(CATCH)
	_holds[HEAVY] = [held_chance, 0.25, 0.6, 0.2]
	# its sweeps round from the side held too, now and then (and slid round
	# at him on letting go, as the heavy ones)
	for side: int in [WIDE, LOW]:
		_holds[side] = [held_side_chance, 0.3, 0.6, 0.2]
	# The roll-catch is always held, a roll's length.
	_holds[CATCH] = [1.0, catch_hold.x, catch_hold.y, 0.3]
	_special(LEAP_SLAM, leap_slam_clip, leap_slam_part)
	_special_strike(LEAP_SLAM, "", leap_slam_share, 1)
	# its blow where it lands, not where the club is out furthest in the air
	var ls: Array = _strikes_table[LEAP_SLAM]
	_strikes_table[LEAP_SLAM] = [ls[0], ls[1], ls[2], ls[3], 0.6, PackedFloat32Array([leap_slam_lands])]
	if _anim != null:
		var lands_from := _gap_that_lands(LEAP_SLAM, _moves_table[LEAP_SLAM], leap_slam_lands)
		if lands_from > 0.0:
			_strike_from[LEAP_SLAM] = lands_from
	_special(RUN_SLAM, run_slam_clip, run_slam_part)
	_special_strike(RUN_SLAM, "", run_slam_share, 1)
	# Down on him club first out of the run: no shield holds it.
	_kinds[RUN_SLAM] = &"crush"
	_trot_speed = chase_speed
	_leap_slam_wait = _rng.randf_range(3.0, leap_slam_cooldown.x)
	_run_slam_wait = _rng.randf_range(3.0, run_slam_cooldown.x)
	# The kick beats a raised shield aside, as the orc's does.
	_kinds[KICK] = &"guard"
	_pound_at = _club_down(POUND)
	_stomp_at = _club_down(STOMP)
	_pound_wait = _rng.randf_range(2.0, pound_cooldown.x)
	_heavy_wait = _rng.randf_range(1.0, heavy_cooldown.x)
	# Fresh to the fight it walks in first; the lunge comes later.
	_lunge_wait = _rng.randf_range(3.5, lunge_cooldown.x)
	if _skeleton != null:
		for bone in foot_bones:
			_ankles.append(_skeleton.find_bone(bone))
	_fit_stoops()
	Sfx.warm([WHOOSH_HEAVY, WHOOSH_LIGHT, ROAR_SOUND, ROAR_SHORT_SOUND, STRAIN_SOUND] + GRUNTS + CLUB_GROUND + STEPS)
	if body != null:
		_body_rest_xz = Vector2(body.position.x, body.position.z)


## One of the combos' moves: its clip, its blows (where the club reaches
## furthest, or at the moments given), held at the top if it is so made.
func _combo_move(what: int) -> void:
	var c: Array = COMBO_MOVES[what]
	var part: Vector3 = c[1]
	part.x *= combo_pace.y if bool(c[2]) else combo_pace.x
	_special(what, c[0], part)
	var at: Array = c[4]
	if c.size() > 7 and not String(c[7]).is_empty():
		_special_strike(what, String(c[7]), float(c[3]), 99)
		if c.size() > 8 and not StringName(c[8]).is_empty():
			_kinds[what] = c[8]
	elif at.is_empty():
		_special_strike(what, "", float(c[3]), 99)
	else:
		var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
		var limbs: Array = []
		for i in at.size():
			limbs.append("weapon")
		_strikes_table[what] = [bones, limbs, float(c[3]), 99, 0.5, PackedFloat32Array(at)]
		if _anim != null:
			var from := _gap_that_lands(what, _moves_table[what], float(at[0]))
			if from > 0.0:
				_strike_from[what] = from
	var held: Array = c[6]
	if not held.is_empty():
		_holds[what] = [1.0, float(held[0]), float(held[1]), float(held[2])]


## Act seconds of the pound's slam (`what` one of the three), its hold put in.
func _pound_time(what: int) -> float:
	var t := _club_down(what)
	var sh := _shape(what)
	if sh.is_empty():
		return t
	var k := float(sh[0])
	var slow := float(sh[1])
	return t * slow if t <= k else t + k * (slow - 1.0) + float(sh[2])


## Act seconds of a move when its club is lowest, in front.
func _club_down(what: int) -> float:
	var m: Array = _moves_table[what]
	if _anim == null or _weapon < 0:
		return _move_length(what) * 0.5
	var at := _anim.measure_reach(m[0], String(weapon_bone), weapon_tip, reach_forward, float(m[2]), float(m[3]))
	if at < 0.0:
		return _move_length(what) * 0.5
	return (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)


func _leaps() -> Array:
	return [LEAP, LUNGE, LEAP_SLAM, RUN_SLAM]


#region Choosing
func _own_move(delta: float) -> bool:
	_pound_wait = maxf(_pound_wait - delta, 0.0)
	_heavy_wait = maxf(_heavy_wait - delta, 0.0)
	_stomp_wait = maxf(_stomp_wait - delta, 0.0)
	_lunge_wait = maxf(_lunge_wait - delta, 0.0)
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	if _getoff(_distance_to(_quarry)):
		return true
	if _coop_answer(delta):
		return true
	_leap_slam_wait = maxf(_leap_slam_wait - delta, 0.0)
	_run_slam_wait = maxf(_run_slam_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	_watch_flight(gap, delta)
	if drill_combo >= 0:
		return _ogre_drill(gap, delta)
	# Running at him to spring off the run.
	if _charging:
		_charge_time += delta
		if _quarry_down() or _charge_time > 4.5 or gap > run_slam_to + 8.0:
			_charging = false
		elif gap <= run_slam_takeoff:
			_charging = false
			if gap >= run_slam_takeoff * 0.55 and stamina >= attack_cost:
				mode = Mode.FIGHT
				_face(_quarry.global_position - global_position, 1.0, 50.0)
				_open(RUN_SLAM)
				return true
		else:
			mode = Mode.CHASE
			_move_towards(_quarry.global_position, _pace(run_speed), delta)
			return true
	# Him down in reach: the club on him where he lies.
	if _quarry_down():
		if gap <= stomp_reach and _stomp_wait <= 0.0:
			if _rng.randf() > stomp_chance:
				_stomp_wait = stomp_cooldown * 0.5
				return false
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_open(STOMP)
			return true
		if gap > stomp_reach * 0.8:
			_move_towards(_quarry.global_position, chase_speed, delta)
			return true
		return _prowl(gap, delta, stomp_reach * 0.7)
	_taunt_wait = maxf(_taunt_wait - delta, 0.0)
	# (its swipe may break off its spacing, as soon as its breath is back)
	if _punish(gap, delta):
		return true
	if _try_grab(gap):
		return true
	if _spacing != &"" and _keep_distance(gap, delta):
		return true
	if _from_afar(gap, delta):
		return true
	if _pound_wait <= 0.0 and gap >= pound_from and gap <= pound_to and stamina >= attack_cost:
		mode = Mode.FIGHT
		start_combo(_combo_named(&"triple_pound"))
		return true
	var want := float(_strike_from.get(HEAVY, strike_off))
	# (from as far as it keeps its distance between strings: the great blow
	# closes on him over its last half second)
	if _heavy_wait <= 0.0 and _cooldown <= 0.0 and gap <= want + 1.2 and gap >= want - 1.2 \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(HEAVY)
		return true
	if (_cooldown > 0.0 or stamina < attack_cost) and _prowl(gap, delta, strike_off):
		return true
	if attacks.is_empty() or _cooldown > 0.0 or stamina < attack_cost:
		return super(delta)
	if _lunge_wait <= 0.0 and gap >= lunge_from and gap <= lunge_to:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LUNGE)
		return true
	if _try_combo(gap):
		return true
	var pick := _pick_opener(gap)
	if pick >= 0:
		mode = Mode.FIGHT
		if SWINGS[pick][5] == &"front":
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(pick)
		return true
	if _rush_left > 0.0:
		_rush_left -= delta
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, _pace(run_speed), delta)
		return true
	return super(delta)


## Host: him casting, or drawing a while, near it: at him at once, by the
## gap — a swing in reach, a lunge, a leap, a run and spring (true if it
## went).
func _punish(gap: float, delta: float) -> bool:
	_punish_wait = maxf(_punish_wait - delta, 0.0)
	var hero := _quarry as Player
	if hero == null or hero.is_dead:
		return false
	var key := hero.get_instance_id()
	var casts := hero.net_casts
	if casts != int(_seen_casts.get(key, casts)):
		_punish_left = 1.0
	_seen_casts[key] = casts
	_drawn_for = _drawn_for + delta if hero.drawing() else 0.0
	if _drawn_for >= punish_draw_after:
		_punish_left = maxf(_punish_left, 0.3)
	_punish_left = maxf(_punish_left - delta, 0.0)
	var s := visual_scale / 1.6
	if _punish_left <= 0.0 or _punish_wait > 0.0 or stamina < attack_cost or gap > punish_reach * s \
			or hero.state == Player.State.DOWNED:
		return false
	_punish_left = 0.0
	_punish_wait = punish_wait_time
	_drawn_for = 0.0
	punishes_made += 1
	_spacing = &""
	_cooldown = 0.0
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	if gap >= run_slam_from:
		_charging = true
		_charge_time = 0.0
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, _pace(run_speed), delta)
		return true
	if gap >= leap_slam_from:
		_open(LEAP_SLAM)
		return true
	if gap >= lunge_from:
		_open(LUNGE)
		return true
	var pick := _pick_opener(gap)
	if pick >= 0:
		_open(pick)
		return true
	_rush_left = 1.2
	return false


## Host: the rage roar — everyone on the ground near it thrown back off his
## feet.
func _rage_throw() -> void:
	var r := rage_push_radius * visual_scale / 1.6
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
			continue
		var rel := who.global_position - global_position
		if absf(rel.y) > 2.0 or Vector2(rel.x, rel.z).length() > r:
			continue
		rage_throws += 1
		# a stagger, never a fall (99 blows to fell)
		who.call(&"receive_blow", hit_damage * rage_push_share, self, 0, 99, act_serial * 1000 + 93, false, &"ground")
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_rage_blast.rpc()
	else:
		net_rage_blast()


## Every peer: the roar's blast — dust and grit driven out along the ground
## all round (no ring), the view shaken hard.
@rpc("authority", "call_local", "reliable")
func net_rage_blast() -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	SkillFx.particles(into, global_position + Vector3.UP * 0.3, {
		"amount": 90, "life": 0.9, "one_shot": true, "explosiveness": 0.95, "add": false,
		"speed": Vector2(6.0, 11.0) * s, "dir": Vector3(1, 0.15, 0), "spread": 180.0,
		"gravity": Vector3(0, -2.0, 0), "damping": 6.0, "size": Vector2(0.4, 0.9) * s, "grow": 0.6,
		"sphere": 0.6 * s,
		"colors": [Color(0.55, 0.5, 0.45, 0.0), Color(0.5, 0.45, 0.4, 0.45), Color(0.45, 0.42, 0.4, 0.0)],
	})
	GroundFx.eruption(into, global_position + Vector3.UP * 0.05, 1.1 * s, false)
	_roar_shake()


## Every peer: the roar's shake — the view jolted at once and rumbling on
## through the roar, dying away; harder the nearer he is.
func _roar_shake() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var near := clampf(1.0 - cam.global_position.distance_to(global_position) / 28.0, 0.0, 1.0)
	if near <= 0.0:
		return
	ImpactFx.knock(cam, Vector3.DOWN, 0.1 * near, 0.12, 0.5)
	_shake_tween(cam, roar_shake.x * near, roar_shake.y)


## Every peer: a hard jolt of the view and its rumble dying away (`kick`, the
## knock down at once), harder the nearer he is.
func _shake_view(strength: float, time: float, kick: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var near := clampf(1.0 - cam.global_position.distance_to(global_position) / 28.0, 0.0, 1.0)
	if near <= 0.0:
		return
	ImpactFx.knock(cam, Vector3.DOWN, kick * near, 0.08, 0.4)
	_shake_tween(cam, strength * near, time)


func _shake_tween(cam: Camera3D, strength: float, time: float) -> void:
	var tw := cam.create_tween()
	var steps := 34
	var step := time / float(steps)
	for i in steps:
		var u := float(i) / float(steps)
		# up hard in the first tenth, then the rumble dying away
		var k := strength * (minf(u / 0.08, 1.0) * pow(1.0 - u, 1.4))
		tw.tween_property(cam, "h_offset", randf_range(-k, k), step)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k) * 0.8, step)
	tw.tween_property(cam, "h_offset", 0.0, 0.1)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.1)


## Enraged: no colour on its skin, no fire (the user's word, 2026-10-12) —
## its rage shows in its club armed with stone ([method net_club_armed]),
## its roar and its pace.
func _glow_on() -> void:
	pass


## Enraged it hits harder still (`rage_damage`, the user's word 2026-10-12).
func _blow_worth(_what: int) -> float:
	return rage_damage if raging else 1.0


## Host, its club driven into the ground after the roar: earth and stone
## burst up there and stone sets in its club.
func _arm_club() -> void:
	var tip := _weapon_tip_at()
	var at := Vector3(tip.x, global_position.y, tip.z)
	clubs_armed += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_club_armed.rpc(at)
	else:
		net_club_armed(at)


## Every peer: the club in the ground — rock bursting up round it, the crack
## and the jolt — and stones flying up out of the ground onto the club, set
## in it from now on.
@rpc("authority", "call_local", "reliable")
func net_club_armed(at: Vector3) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	RockWave.spawn(into, at, 3.0 * s, 0.85 * s, 14.0, act_serial * 5 + 11)
	GroundFx.eruption(into, at + Vector3.UP * 0.05, 1.4 * s, false)
	ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
	_sound_at(CLUB_GROUND, at, 0.62, 6.0)
	_sound_at(CLUB_GROUND, at, 0.85, 2.0)
	_shake_view(0.38, 0.9, 0.14)
	# grit and chips thrown up round the club as the stone comes onto it
	SkillFx.particles(into, at + Vector3.UP * 0.1, {
		"amount": 40, "life": 0.7, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(2.5, 6.0) * s, "dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, -9.0, 0),
		"damping": 0.5, "size": Vector2(0.08, 0.2) * s, "sphere": 0.4 * s,
		"colors": [Color(0.42, 0.4, 0.37, 1.0), Color(0.38, 0.36, 0.33, 1.0), Color(0.33, 0.31, 0.29, 0.0)],
	})
	_set_stones()


## Every peer: stones set into its club along its far half — each flying in
## a moment (from small, turned) as the ground lets go of it.
func _set_stones() -> void:
	if _skeleton == null or _weapon < 0 or _club_stones != null:
		return
	_club_stones = BoneAttachment3D.new()
	_club_stones.name = "ClubStones"
	_club_stones.bone_name = String(weapon_bone)
	_skeleton.add_child(_club_stones)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + 77
	var length := weapon_tip.x
	var count := maxi(arm_stones, 0)
	# plain grey stone (the ground's crags are red-hot underneath)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.44, 0.41)
	stone.roughness = 0.95
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in count:
		var mi := MeshInstance3D.new()
		mi.name = "Stone%d" % i
		mi.mesh = RockWave._crag_mesh(i % RockWave.SHAPES)
		mi.material_override = stone
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var along := lerpf(0.32, 0.98, (float(i) + rng.randf()) / float(count)) * length
		var turn := float(i) * 2.39996 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(0.0, cos(turn), sin(turn))
		var size := arm_stone_size * length * rng.randf_range(0.7, 1.25)
		# set in the wood: most of it standing out of the club
		var spot := Vector3(along, 0.0, 0.0) + out * (length * 0.05 + size * 0.55)
		# its top (+Y of the crag) out from the club, turned a bit at random
		var up := out
		var side := Vector3.RIGHT.cross(up).normalized()
		var basis := Basis(side, up, side.cross(up)).rotated(up, rng.randf() * TAU)
		mi.transform = Transform3D(basis.scaled(Vector3(size, size * 0.9, size)), spot)
		_club_stones.add_child(mi)
		var full := mi.transform
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * size * 0.05), spot - out * length * 0.5)
		var tw := mi.create_tween()
		tw.tween_interval(0.05 + 0.03 * float(i))
		tw.tween_property(mi, "transform", full, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



## Host: its grab, if it is due and he is near enough (one roll each time it
## could; a raised shield makes it likelier).
func _try_grab(gap: float) -> bool:
	if _grab_wait > 0.0 or _cooldown > 0.0 or stamina < attack_cost or not (_quarry is Player):
		return false
	var s := visual_scale / 1.6
	if gap > grab_from * s or gap < 0.8 * s:
		return false
	var hero := _quarry as Player
	if hero.is_dead or hero.state == Player.State.DOWNED:
		return false
	grab_rolls += 1
	# each time it lets him off, likelier the next
	var chance := (grab_chance_guarded if hero.guarding() else grab_chance) + 0.2 * _grab_passed
	if _rng.randf() >= chance:
		_grab_passed += 1
		_grab_wait = _rng.randf_range(1.2, 2.2)
		return false
	_grab_passed = 0
	_grab_wait = _rng.randf_range(grab_cooldown.x, grab_cooldown.y) * (0.7 if raging else 1.0)
	grabs_made += 1
	mode = Mode.FIGHT
	_spacing = &""
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_grab_dashed = false
	_begin(GRAB)
	return true


## Every peer: where its grip is — its left wrist, a little out in front.
func grab_point() -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 2.0 * visual_scale / 1.6
	var b := _skeleton.find_bone("L_midFinger_joint1")
	if b < 0:
		b = _skeleton.find_bone("L_wrist_joint")
	if b < 0:
		return global_position + Vector3.UP * 2.0 * visual_scale / 1.6
	# its palm (the root of its middle finger)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin


## Every peer: the way its grip faces out (from its elbow to its palm, along
## the ground): he hangs out past its hand that way, not in its forearm.
func grab_out() -> Vector3:
	var out := _forward()
	if _skeleton != null:
		var e := _skeleton.find_bone("L_elbow_joint")
		if e >= 0:
			var d := grab_point() - _skeleton.global_transform * _skeleton.get_bone_global_pose(e).origin
			d.y = 0.0
			if d.length_squared() > 0.0001:
				out = d.normalized()
	return out


## Host, through the swipe: struck in its window if its hand is at him (not
## rolling, not down) — a crushing blow that throws him down; its hand into the
## ground at `grab_smash_at`, hit or miss.
func _grab_run() -> void:
	var ct := _clip_time(GRAB, _act_time)
	var hero := _quarry as Player
	if _grab_serial != act_serial and ct >= grab_catch.x and ct <= grab_catch.y \
			and hero != null and _can_catch(hero):
		_grab_serial = act_serial
		grabs_caught += 1
		hero.receive_blow(hit_damage * grab_share * _blow_worth(GRAB), self, 0, 1, act_serial * 1000 + 91, false, &"smash")
	if _smashed_serial != act_serial and ct >= grab_smash_at:
		_smashed_serial = act_serial
		grab_throws += 1
		var hand := grab_point()
		var at := Vector3(hand.x, global_position.y, hand.z)
		var hit := _grab_serial == act_serial
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_grab_throw.rpc(at, hit)
		else:
			net_grab_throw(at, hit)


func _can_catch(hero: Player) -> bool:
	if hero.is_dead or hero.is_invulnerable or hero.state != Player.State.GROUNDED \
			and hero.state != Player.State.AIRBORNE:
		return false
	var hand := grab_point()
	var rel := hero.global_position - hand
	var up := -rel.y
	rel.y = 0.0
	return rel.length() <= grab_radius * visual_scale / 1.6 and up >= -0.3 and up <= 3.4 * visual_scale / 1.6


## Its looks picked from its name (before the blows are measured: the arm's
## length is the club's reach).
func _pick_looks() -> void:
	if not varied:
		return
	# (each from a hash of its own: one generator seeded from like names drew
	# like skins)
	skin_index = posmod(hash(String(name) + "/skin"), SKINS.size())
	bloody = float(posmod(hash(String(name) + "/blood"), 1000)) / 1000.0 < bloody_share
	var r := float(posmod(hash(String(name) + "/arm"), 1000)) / 1000.0
	arm_index = 0
	for i in ARMS.size():
		r -= float((ARMS[i] as Array)[3])
		if r < 0.0:
			arm_index = i
			break
	if arm_index > 0:
		weapon_tip = Vector3(float((ARMS[arm_index] as Array)[2]), 0.0, 0.0)


## Every peer: the skin on its body, the arm in its hand, the blood on it.
func _wear_looks() -> void:
	if not varied or body == null:
		return
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).begins_with("Ogre_Body"):
			continue
		if mi.material_override is ShaderMaterial:
			var mo := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			mo.set_shader_parameter(&"color1", SKINS[skin_index])
			mi.material_override = mo
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i) as ShaderMaterial
			if m != null:
				var mm := m.duplicate() as ShaderMaterial
				mm.set_shader_parameter(&"color1", SKINS[skin_index])
				mi.set_surface_override_material(i, mm)
	if arm_index > 0 and _skeleton != null:
		var arm: Array = ARMS[arm_index]
		var scene := load(ARMS_FILE) as PackedScene
		var src: Node = scene.instantiate() if scene != null else null
		var mesh := src.find_child(String(arm[0]), true, false) as MeshInstance3D if src != null else null
		if mesh != null:
			var club := _skeleton.find_child("Ogre_Club", true, false) as Node3D
			if club != null:
				club.visible = false
			var hold := BoneAttachment3D.new()
			hold.bone_name = String(weapon_bone)
			_skeleton.add_child(hold)
			var held := MeshInstance3D.new()
			held.name = "Arm"
			held.mesh = mesh.mesh
			held.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * float(arm[1])), Vector3.ZERO)
			hold.add_child(held)
		if src != null:
			src.free()
	if bloody:
		_bloody_mouth.call_deferred()
		_bloody_arm.call_deferred()


## Every peer: blood round its mouth and down its chin (a [Decal] on its head,
## marking only itself: [constant Blood.WOUND_LAYER]).
func _bloody_mouth() -> void:
	if _skeleton == null or not is_inside_tree():
		return
	var head := _skeleton.find_bone("head_joint")
	if head < 0:
		return
	if not has_meta(&"wound_layer"):
		set_meta(&"wound_layer", true)
		for m in find_children("*", "GeometryInstance3D", true, false):
			var g := m as GeometryInstance3D
			if not (g is GPUParticles3D) and not (g is Label3D):
				g.layers |= Blood.WOUND_LAYER
	var hold := BoneAttachment3D.new()
	hold.bone_name = "head_joint"
	_skeleton.add_child(hold)
	var s := visual_scale / 1.6
	var fwd := _forward()
	# its -Y into the face from in front; its +Z (the runs of blood) down
	var y := fwd
	var z := Vector3.DOWN
	var x := y.cross(z).normalized()
	var decal := Decal.new()
	decal.name = "Gore"
	decal.texture_albedo = Blood.wound_texture()
	decal.modulate = Color(0.32, 0.015, 0.012)
	decal.albedo_mix = 0.9
	decal.normal_fade = 0.3
	decal.cull_mask = Blood.WOUND_LAYER
	decal.size = Vector3(0.5, 1.2, 0.7) * s
	hold.add_child(decal)
	# laid in the head bone's frame (the attachment follows it from the next
	# frame on)
	var bone := _skeleton.global_transform * _skeleton.get_bone_global_pose(head)
	# (back up on its mouth: lower it went down its throat — the user's word)
	var want := Transform3D(Basis(x, y, z), bone.origin + fwd * 0.3 * s + Vector3.DOWN * 0.06 * s)
	decal.transform = bone.affine_inverse() * want
	# its lower teeth bloodied too, plainly (painted whatever way they face)
	var teeth := decal.duplicate() as Decal
	teeth.name = "GoreTeeth"
	teeth.normal_fade = 0.0
	teeth.albedo_mix = 1.0
	teeth.modulate = Color(0.42, 0.02, 0.015)
	teeth.size = Vector3(0.34, 0.5, 0.14) * s
	hold.add_child(teeth)
	teeth.transform = bone.affine_inverse() * Transform3D(Basis(x, y, z),
			bone.origin + fwd * 0.22 * s + Vector3.DOWN * 0.1 * s)
	# and down its chest, from where it drools and from what it ate
	var chest := _skeleton.find_bone("chest_joint")
	if chest >= 0:
		var on_chest := BoneAttachment3D.new()
		on_chest.bone_name = "chest_joint"
		_skeleton.add_child(on_chest)
		var smear := decal.duplicate() as Decal
		smear.name = "GoreChest"
		smear.size = Vector3(0.75, 1.2, 0.85) * s
		on_chest.add_child(smear)
		var cb := _skeleton.global_transform * _skeleton.get_bone_global_pose(chest)
		smear.transform = cb.affine_inverse() * Transform3D(Basis(x, y, z),
				cb.origin + fwd * 0.3 * s + Vector3.UP * 0.12 * s)


## Every peer: its weapon's head bloodied (a [Decal] round it, painting it
## all round: no normal fade; kept out past its fist).
func _bloody_arm() -> void:
	if _skeleton == null or _weapon < 0 or not is_inside_tree():
		return
	for m in find_children("*", "GeometryInstance3D", true, false):
		var g := m as GeometryInstance3D
		if not (g is GPUParticles3D) and not (g is Label3D):
			g.layers |= Blood.WOUND_LAYER
	var hold := BoneAttachment3D.new()
	hold.bone_name = String(weapon_bone)
	_skeleton.add_child(hold)
	var reach := weapon_tip.x
	for k in 2:
		var decal := Decal.new()
		decal.name = "ArmGore"
		decal.texture_albedo = Blood.wound_texture()
		decal.modulate = Color(0.3, 0.012, 0.01)
		decal.albedo_mix = 0.92
		decal.normal_fade = 0.0
		decal.cull_mask = Blood.WOUND_LAYER
		decal.upper_fade = 0.1
		decal.lower_fade = 0.1
		# along the club's head, the runs of blood down it toward the fist;
		# one from each side
		decal.size = Vector3(0.5, 0.55, reach * 0.5)
		hold.add_child(decal)
		var y := Vector3(0, 0, 1) * (1.0 if k == 0 else -1.0)
		var z := Vector3(-1, 0, 0)
		decal.transform = Transform3D(Basis(y.cross(z), y, z), Vector3(reach * 0.84, 0.0, 0.0))


## Every peer: its death played heavy and slow — a last groan as it goes.
func _play_act() -> void:
	if act == Act.DEAD and not heavy_death_clip.is_empty() and _anim != null:
		_anim.play(heavy_death_clip, 0.2, death_rate, 1.0, true)
		Sfx.play(self, ROAR_SOUND, self, Vector3.ZERO, 0.62, -3.0)
		return
	super()


## Every peer, dead: the thud as it comes down on its face, then ash and
## embers off it as it sinks.
func _watch_death() -> void:
	if heavy_death_clip.is_empty() or _anim == null:
		return
	var length := _anim.clip_length(heavy_death_clip) / maxf(death_rate, 0.01)
	if not _death_landed and _corpse_age >= length * death_lands:
		_death_landed = true
		var into := Blood.world_of(self)
		var at := global_position + _forward() * 1.4 * visual_scale / 1.6
		GroundFx.eruption(into, at + Vector3.UP * 0.05, 1.3 * visual_scale / 1.6, false)
		ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
		_sound_at(CLUB_GROUND, at, 0.7, 3.0)
		WindBlast.shake(self, 0.18, 0.6, 22.0)
	if not _ashed and _corpse_age >= corpse_linger - 0.6:
		_ashed = true
		var s := visual_scale / 1.6
		SkillFx.particles(Blood.world_of(self), global_position + Vector3.UP * 0.4 * s, {
			"amount": 160, "life": 2.6, "one_shot": false, "explosiveness": 0.0, "add": true,
			"speed": Vector2(0.3, 1.3), "dir": Vector3.UP, "spread": 25.0, "gravity": Vector3(0, 0.6, 0),
			"damping": 0.3, "size": Vector2(0.04, 0.1), "grow": -0.4,
			"box": Vector3(0.9, 0.3, 1.5) * s, "free_after": corpse_sink_time + 2.8,
			"colors": [Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.7, 0.3, 0.9), Color(0.9, 0.3, 0.05, 0.0)],
		})


## The snatch's clock: act seconds where its arm is drawn back and where it
## lets the swipe go (the slide in between).
func _grab_marks() -> Vector2:
	var t0 := grab_cock.x / grab_rate
	return Vector2(t0, t0 + grab_cock.y)


## Every peer: its hand into the ground — stone thrown up, earth and grit, the
## crack of it, its roar, the view jolted hard; his blood if it struck him.
@rpc("authority", "call_local", "reliable")
func net_grab_throw(at: Vector3, hit: bool) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	# the ground breaking under him: stone thrown up round him, earth and grit,
	# blood, the crack of it, its roar, the view jolted hard
	RockWave.spawn(into, at, 3.6 * s, 0.75 * s, 16.0, act_serial * 7 + 3)
	GroundFx.eruption(into, at + Vector3.UP * 0.05, 1.3 * s, false)
	ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
	if hit:
		Blood.splatter(into, at + Vector3.UP * 0.4, Vector3.UP, null, 1.6)
	_sound_at(CLUB_GROUND, at, 0.68, 5.0)
	_sound_at(CLUB_GROUND, at, 0.9, 1.0)
	Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 0.95, -1.0)
	_shake_view(0.42, 0.9, 0.16)


## Host, a string ended: how it keeps its distance now, and how long.
func _start_spacing() -> void:
	var span := spacing_time_raging if raging else spacing_time
	if span.y <= 0.0:
		return
	_spacing_left = _rng.randf_range(span.x, span.y)
	_spacing_held = 0.0
	_rush_left = 0.0
	_spacing = _spacing_kind()
	spacings_made[_spacing] = int(spacings_made.get(_spacing, 0)) + 1


func _spacing_kind() -> StringName:
	var w := spacing_weights
	if _taunt_wait > 0.0 or _quarry == null:
		w.w = 0.0
	var total := w.x + w.y + w.z + w.w
	if total <= 0.0:
		return &"prowl"
	var r := _rng.randf() * total
	if r < w.x:
		return &"prowl"
	if r < w.x + w.y:
		return &"back"
	if r < w.x + w.y + w.z:
		return &"watch"
	return &"taunt"


## Host, between its strings: keeping its distance — round him, backing off,
## watching him, or roaring at him — till its time is out or it breaks off
## all at once and comes at him (false: on to its choosing as ever).
func _keep_distance(gap: float, delta: float) -> bool:
	_spacing_left -= delta
	var can := _cooldown <= 0.0 and stamina >= attack_cost
	# (its breath back first: the dash in is timed from then)
	if can or _spacing_held < 0.0:
		_spacing_held += delta
	# Him off and away, or its time out: on as ever.
	if _spacing_left <= 0.0 or gap > back_off_to + 5.0:
		_spacing = &""
		return false
	# Him walking in on it, into its reach: at him.
	if can and gap < strike_off + 0.3 and _spacing_held > 0.25 and _coming_in() > 1.0:
		if _rng.randf() < punish_close:
			_spacing = &""
			return false
		# ...or it gives ground before him a little first
		_spacing = &"back"
		_spacing_held = -0.8
	# All at once, at him.
	if can and _spacing != &"taunt" and _spacing_held >= burst_after and _rng.randf() < burst_rate * delta:
		_burst(gap)
		return false
	mode = Mode.FIGHT
	# Standing or roaring in his face is no way to keep its distance: a few
	# steps back first.
	var kind := _spacing
	var stand_off := strike_off + 0.8
	if kind == &"taunt":
		stand_off = maxf(stand_off, taunt_from + 0.3)
	if (kind == &"watch" or kind == &"taunt") and gap < stand_off - 0.2:
		kind = &"back"
	match kind:
		&"taunt":
			if _taunt_wait > 0.0:
				_spacing = &"watch"
			elif gap >= taunt_from:
				_spacing = &"watch"
				_taunt_wait = _rng.randf_range(taunt_cooldown.x, taunt_cooldown.y) * (0.6 if raging else 1.0)
				taunts_made += 1
				velocity.x = 0.0
				velocity.z = 0.0
				_face(_quarry.global_position - global_position, 1.0, 50.0)
				_begin(TAUNT)
				# the roar done, it may come at him at once
				_spacing_left = maxf(_spacing_left, 0.8)
				_spacing_held = burst_after
				return true
		&"back":
			if gap < (back_off_to if _spacing == &"back" else stand_off):
				var away := global_position - _quarry.global_position
				away.y = 0.0
				_face(-away, delta, turn_speed)
				var want := away.normalized() * back_off_speed * clampf(visual_scale / 1.6, 0.6, 1.6)
				velocity.x = move_toward(velocity.x, want.x, acceleration * delta)
				velocity.z = move_toward(velocity.z, want.z, acceleration * delta)
				# backing off to roar at him: its time holds till it is off
				if _spacing == &"taunt" and _taunt_wait <= 0.0:
					_spacing_left = maxf(_spacing_left, 0.3)
				return true
			if _spacing == &"back":
				_spacing = &"prowl"
		&"watch":
			_face(_quarry.global_position - global_position, delta, turn_speed)
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
			return true
	var was := prowl_speed
	prowl_speed = spacing_prowl_speed
	var went := _prowl(gap, delta, strike_off + spacing_keep)
	prowl_speed = was
	if not went:
		_spacing = &""
	return went


## Host: how fast he comes at it (m/s; away, below 0).
func _coming_in() -> float:
	var body := _quarry as CharacterBody3D
	if body == null:
		return 0.0
	var to := global_position - body.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return Vector3(body.velocity.x, 0.0, body.velocity.z).dot(to.normalized())


## Host: its spacing broken off — a lunge or a leap if he is at their gap,
## else in at him at its run (its choosing takes over once he is in reach).
func _burst(gap: float) -> void:
	_spacing = &""
	_spacing_left = 0.0
	bursts_made += 1
	if gap >= lunge_from and gap <= lunge_to:
		_lunge_wait = 0.0
	elif gap >= leap_slam_from and gap <= leap_slam_to and _rng.randf() < 0.5:
		_leap_slam_wait = 0.0
	_rush_left = 1.6


## Host, between its strings: round him at `prowl_speed`, facing him, kept
## at `keep` m; off to the side it was going, now and then the other way.
## False when he is not near enough to prowl round (it closes in as ever).
func _prowl(gap: float, delta: float, keep: float) -> bool:
	if _quarry == null or prowl_speed <= 0.0 or gap > keep + 3.0:
		return false
	mode = Mode.FIGHT
	_prowl_turn -= delta
	if _prowl_turn <= 0.0:
		_prowl_turn = _rng.randf_range(prowl_turn_every.x, prowl_turn_every.y)
		if _rng.randf() < 0.5:
			_prowl_side = -_prowl_side
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	var ahead := to.normalized()
	if _prowl_home == Vector3.ZERO:
		_prowl_home = -ahead
	# kept within `prowl_arc` of where it came at him: going further out, back
	var around := rad_to_deg(_prowl_home.signed_angle_to(-ahead, Vector3.UP))
	if absf(around) > prowl_arc and absf(around) > absf(_prowl_was):
		_prowl_side = -_prowl_side
		_prowl_turn = _rng.randf_range(prowl_turn_every.x, prowl_turn_every.y)
	_prowl_was = around
	_face(ahead, delta, turn_speed)
	var side := ahead.cross(Vector3.UP) * _prowl_side
	# round him, and in or out to its reach
	var radial := clampf((gap - keep) * 1.5, -1.0, 1.0)
	var want := (side + ahead * radial).normalized() * prowl_speed * clampf(visual_scale / 1.6, 0.6, 1.6)
	velocity.x = move_toward(velocity.x, want.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, want.z, acceleration * delta)
	return true


## Host: the leaps from afar, if he is at their gap and they are due.
func _from_afar(gap: float, delta: float) -> bool:
	if stamina < attack_cost or _quarry_down():
		return false
	var run_ok := _run_slam_wait <= 0.0 and gap >= run_slam_from and gap <= run_slam_to
	var leap_ok := _leap_slam_wait <= 0.0 and gap >= leap_slam_from and gap <= leap_slam_to
	if run_ok and (not leap_ok or _rng.randf() < 0.5):
		# Off at a run at him first; it springs at `run_slam_takeoff`.
		_charging = true
		_charge_time = 0.0
		_run_slam_wait = _rng.randf_range(run_slam_cooldown.x, run_slam_cooldown.y)
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, _pace(run_speed), delta)
		return true
	if leap_ok:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LEAP_SLAM)
		return true
	return false


## A pace, quicker enraged.
func _pace(base: float) -> float:
	return base * (rage_pace if raging else 1.0)


## Host: whether he is running from it — the gap opening fast for a while
## with him well off — and its pace after him by that: a trot, or a run.
func _watch_flight(gap: float, delta: float) -> void:
	if _last_gap >= 0.0 and delta > 0.0:
		var opening := (gap - _last_gap) / delta
		if opening > flee_rate and gap > flee_from:
			_opening += delta
		else:
			_opening = maxf(_opening - delta * 0.5, 0.0)
	_last_gap = gap
	if _opening >= flee_time and gap > flee_from:
		running_after = true
	elif running_after and (gap < flee_from - 1.0 or _opening <= 0.0):
		running_after = false
	chase_speed = _pace(run_speed if running_after or runs_after else _trot_speed)


## The Brawler's own choosing goes through the strings too.
func _begin_attack() -> void:
	if _quarry_down() or _quarry == null:
		return
	if attacks.is_empty():
		super()
		return
	if _try_combo(_distance_to(_quarry)):
		return
	var pick := _pick_opener(_distance_to(_quarry))
	if pick >= 0:
		_open(pick)
	else:
		super()


## Host, practising one combo ([member PackBrute.drill_combo], here of
## `COMBOS`; no strings, no leaps, no pound): its breath got back prowling
## (him down too), then in to it and at him.
func _ogre_drill(gap: float, delta: float) -> bool:
	mode = Mode.FIGHT
	_charging = false
	if _quarry_down() or _cooldown > 0.0 or stamina < attack_cost:
		if _prowl(gap, delta, strike_off):
			return true
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return true
	var first := int((COMBOS[drill_combo]["moves"] as Array)[0])
	var want := float(_strike_from.get(first, strike_off))
	if gap <= want + 0.6:
		start_combo(drill_combo)
		return true
	_move_towards(_quarry.global_position, chase_speed, delta)
	return true


## Host: now and then one of its combos instead of a string, if he is in
## front and its first move lands from here.
func _try_combo(gap: float) -> bool:
	var where := _where_he_is()
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	var hugging := gap < nearest + 0.35 and where != &"behind"
	var chance := close_combo_chance if hugging else (combo_chance.y if raging else combo_chance.x)
	if _rng.randf() >= chance:
		return false
	if not hugging and where != &"front":
		return false
	var guarded := _quarry is Player and bool((_quarry as Player).is_blocking)
	var options: Array = []
	for i in COMBOS.size():
		var c: Dictionary = COMBOS[i]
		# never weighed (the triple pound: opened when its pound is due)
		if float(c["weight"]) <= 0.0:
			continue
		if bool(c.get("close", false)) != hugging:
			continue
		if bool(c.get("rage_only", false)) and not raging:
			continue
		if not hugging and not _fits(int((c["moves"] as Array)[0]), gap):
			continue
		var w := float(c["weight"]) * (0.2 if i == _last_combo else 1.0)
		if bool(c.get("guard", false)):
			# a shield up in front of it: beaten aside first, far more often
			w *= 4.0 if guarded else 0.5
		options.append([i, w])
	var pick := _weighed(options)
	if pick < 0:
		return false
	mode = Mode.FIGHT
	start_combo(pick)
	return true


func _combo_named(name: StringName) -> int:
	for i in COMBOS.size():
		if COMBOS[i]["name"] == name:
			return i
	return 0


## Host: combo `which` of `COMBOS` begun now, turned to him.
func start_combo(which: int) -> void:
	if _quarry != null:
		_face(_quarry.global_position - global_position, 1.0, 50.0)
	_combo_pending = which
	_open(int((COMBOS[which]["moves"] as Array)[0]))


## A string begun with `what`.
func _open(what: int) -> void:
	_string_count = 0
	_switches = 0
	if _quarry != null:
		_prowl_home = Vector3(global_position.x - _quarry.global_position.x, 0.0,
				global_position.z - _quarry.global_position.z).normalized()
	_prowl_was = 0.0
	_pounded = false
	# One combo on him for the whole string: its blows count together, so a
	# heavy one after a light one fells him ([Player.receive_blow]).
	_chain_serial = 1000000 + act_serial + 1
	_chain_blow = 0
	_kind_blows.clear()
	_closing = false
	_combo = _combo_pending
	_combo_pending = -1
	_combo_step = 0
	_combo_moves = []
	_combo_fells_at = []
	if _combo >= 0:
		_last_combo = _combo
		combos_made.append(_combo)
		var c: Dictionary = COMBOS[_combo]
		_combo_moves = (c["moves"] as Array).duplicate()
		_combo_fells_at = (c["fells"] as Array).duplicate()
		if raging and c.has("rage"):
			# enraged it runs on: its old close only staggers now, the new one fells
			_combo_moves.append_array(c["rage"])
			_combo_fells_at = [_combo_moves.size() - 1]
		last_combo_moves = _combo_moves
	if SWINGS.has(what) and what != KICK and what != LUNGE:
		_last_opener = what
	if what == KICK:
		_kick_wait = kick_cooldown
	_begin_move(what)


## The next move of a string (after `prev`, -1 for its first).
func _begin_move(what: int, prev: int = -1) -> void:
	if prev >= 0 and _strikes_table.has(prev):
		var n := _blow_moments(prev).size()
		_chain_blow += n
		var kind := _combo_kind(prev)
		_kind_blows[kind] = int(_kind_blows.get(kind, 0)) + n
	act_opens = prev < 0 and (SWINGS.has(what) or COMBO_MOVES.has(what))
	_string_count += 1
	_pounded = false
	_jump_speed = 0.0
	moves_made.append(what)
	if moves_made.size() > 200:
		moves_made = moves_made.slice(-100)
	_saw_roll = false
	_closing = _closes(what)
	if what == CATCH:
		catches_made += 1
	if _combo >= 0 and _combo_fells():
		# A combo's felling blow: a fresh combo to him, its blows his last,
		# so it throws him down by itself (Elden Ring's finisher).
		finishers_made += 1
		_chain_serial = 2000000 + act_serial + 1
		_chain_blow = 0
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	elif _combo < 0 and _closing and _finishes() and _strikes_table.has(what) and int((_strikes_table[what] as Array)[3]) > 1:
		# The close of a long string: its last blow fells him, if every blow
		# of its kind in the string found him (they count as one combo).
		finishers_made += 1
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = int(_kind_blows.get(_combo_kind(what), 0)) + _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	else:
		_begin(what)
	if FLIGHTS.has(what) and _quarry != null:
		var span := _flight_span(what)
		_flight_speed = _close_speed_for(what, span.y, span.x)
	_spin_on = false
	_spin_from = -1.0
	if what == OG_SPIN_SLIDE and _quarry != null:
		_spin_dash(false)
	if what == LUNGE and _quarry != null:
		var until := _blow_moments(LUNGE)[0]
		var m: Array = _moves_table[LUNGE]
		var own := _hips(m[0], _clip_time(LUNGE, until)).x - _hips(m[0], _clip_time(LUNGE, 0.0)).x
		var short := float(_strike_from.get(LUNGE, strike_off))
		_lunge_speed = maxf(_distance_to(_quarry) - short - own, 0.0) / maxf(until, 0.2)


## Its blows brought down on him from above: felled by one, he is crushed
## down where he stands ([method Player.receive_blow] asks).
const OVERHEAD := [SMASH, JUMP_SLAM, LEAP_SLAM, CATCH, OG_DOWN, OG_DOWN_HELD, OG_JUMP, OG_JUMP_HELD, OG_GROUND, OG_MJUMP]


func blow_from_above() -> bool:
	return OVERHEAD.has(act) and _blow_kind(act).is_empty()


## Its blows by name, for the hero's falls: he falls the way the user picked
## for each ([member Player.BLOW_FALLS], 2026-10-09).
const BLOW_NAMES := {
	SWEEP: &"sweep", CHOP: &"chop", BACKHAND: &"backhand", WIDE: &"wide", LOW: &"low",
	SMASH: &"smash", CLEAVE: &"cleave", JUMP_SLAM: &"jump_slam", WHIRL: &"whirl",
	KICK: &"kick", LUNGE: &"lunge", LEAP_SLAM: &"leap_slam", RUN_SLAM: &"run_slam",
	CATCH: &"catch", POUND: &"pound", POUND_2: &"pound", POUND_3: &"pound", HEAVY: &"heavy", STOMP: &"stomp",
	GRAB: &"grab",
}


## Whether the blow it is dealing now was held at the top of its wind-up
## (the "it stops, then strikes" swing): a heavy one, it fells (the user's
## word, 2026-10-10; [member Player.STAGGERS_ONLY]).
func blow_held() -> bool:
	return _hold_of(act) > 0.0


## The blow it is dealing now, by name (&"" none): [member BLOW_NAMES].
func blow_name() -> StringName:
	if COMBO_MOVES.has(act):
		return COMBO_MOVES[act][5]
	return BLOW_NAMES.get(act, &"")


## The kind a move's blows reach him as — his combo key goes by it, so the
## blows of a string count together only within one kind.
func _combo_kind(what: int) -> StringName:
	var kind := _blow_kind(what)
	if kind.is_empty() and OVERHEAD.has(what):
		return &"above"
	return kind


## Where he stands against the way it faces: "front", "side" or "behind".
func _where_he_is() -> StringName:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return &"front"
	var angle := rad_to_deg(_forward().angle_to(to.normalized()))
	if angle > 120.0:
		return &"behind"
	if angle > 55.0:
		return &"side"
	return &"front"


## How far off a swing can be begun: from a little inside where it lands to
## as far as it can step in before its blow.
func _fits(what: int, gap: float, slack: float = 0.0) -> bool:
	var want := float(_strike_from.get(what, strike_off))
	var ms := _blow_moments(what)
	var step := clampf(close_speed * ((ms[0] if not ms.is_empty() else 0.5) - 0.15), 0.3, 2.2)
	return gap >= want - 0.8 - slack and gap <= want + step + slack


func _side_weight(where: StringName, suits: StringName) -> float:
	if where == suits:
		return 3.0 if where != &"front" else 1.0
	if where == &"behind":
		return 0.08
	if where == &"side":
		return 0.35 if suits == &"front" else 0.8
	return 0.5 if suits == &"side" else 0.25


## Its first swing, by how far off he is and where: none if none will do.
func _pick_opener(gap: float) -> int:
	var where := _where_he_is()
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	if gap < nearest + 0.35 and _kick_wait <= 0.0 and where != &"behind":
		return KICK
	var options: Array = []
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		var base := float(sw[4])
		if base <= 0.0 or not _fits(what, gap):
			continue
		var w := base * _side_weight(where, sw[5])
		if what == _last_opener:
			w *= 0.25
		options.append([what, w])
	return _weighed(options)


func _weighed(options: Array) -> int:
	var total := 0.0
	for o: Array in options:
		total += maxf(float(o[1]), 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	for o: Array in options:
		roll -= maxf(float(o[1]), 0.0)
		if roll <= 0.0:
			return int(o[0])
	return int((options[-1] as Array)[0])


## Whether `what`, begun now as the `_string_count`th of its string, is its
## last: at the most a string runs, or by the same odds the string would end
## after it ([method _follow]) — weighed now, as it begins, so its blow knows
## it closes (a long string's close fells him; a lone heavy blow's is
## followed by its aftershock).
func _weighed_ahead(what: int) -> bool:
	return SWINGS.has(what) and what != KICK and what != LUNGE


## A combo's close picked by what he did: the first reading that holds of
## `options` ([reading, move]) — "rolled": he rolled under the move before;
## "far": he is past the reach of `plain` (its close as made) by
## `branch_far` — or `plain`.
func _read_him(options: Array, plain: int) -> int:
	var gap := _distance_to(_quarry)
	var reach := float(_strike_from.get(plain, strike_off))
	for o: Array in options:
		var holds := false
		match StringName(o[0]):
			&"rolled":
				holds = _saw_roll
			&"far":
				holds = gap > reach + branch_far * visual_scale / 1.6
		if holds:
			branches_taken[o[0]] = int(branches_taken.get(o[0], 0)) + 1
			return int(o[1])
	branches_taken[&"plain"] = int(branches_taken.get(&"plain", 0)) + 1
	return plain


## Whether the combo's move now is one of its felling blows.
func _combo_fells() -> bool:
	return _combo >= 0 and _combo_fells_at.has(_combo_step)


## Whether the string closing on `what` now is long enough to fell him.
func _finishes() -> bool:
	return _string_count >= (finisher_from.y if raging else finisher_from.x)



func _closes(what: int) -> bool:
	if _combo >= 0:
		return _combo_step >= _combo_moves.size() - 1
	if not _weighed_ahead(what):
		return false
	var most := string_most_raging if raging else string_most
	if _string_count >= most:
		return true
	var weights := _follow(what)
	var total := 0.0
	for k: int in weights:
		total += maxf(float(weights[k]), 0.0)
	return total > 0.0 and _rng.randf() < maxf(float(weights.get(-1, 0.0)), 0.0) / total


## What may come after `what` in a string, weighed: next -> weight (-1 the end).
func _follow(what: int) -> Dictionary:
	var weights := {}
	for f: Array in FOLLOW.get(what, []):
		weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
	if raging:
		for f: Array in FOLLOW_RAGING.get(what, []):
			weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
		# Enraged, it seldom stops.
		weights[-1] = float(weights.get(-1, 0.0)) * 0.35
	return weights


## What the string runs on into after `what`, or -1: weighed, never the same
## swing twice running, only one that lands from where he is now.
func _next_in_string(what: int) -> int:
	_switch_in_string()
	if _combo >= 0:
		# a combo: its next move, whatever (only him down, or out of breath,
		# break it off)
		# (a relentless one, the pound's three, goes on with him down)
		var on_him := bool(COMBOS[_combo].get("relentless", false)) or not _quarry_down()
		if _quarry == null or not on_him or _combo_step + 1 >= _combo_moves.size() \
				or stamina < attack_cost * 0.25:
			return -1
		_combo_step += 1
		var branch: Dictionary = COMBOS[_combo].get("branch", {})
		if branch.has(_combo_step):
			_combo_moves[_combo_step] = _read_him(branch[_combo_step], int(_combo_moves[_combo_step]))
		return int(_combo_moves[_combo_step])
	if _quarry == null or _quarry_down() or not FOLLOW.has(what):
		return -1
	if _string_count >= (string_most_raging if raging else string_most):
		return -1
	if stamina < attack_cost * 0.5:
		return -1
	var gap := _distance_to(_quarry)
	# He rolled out from under it: the roll-catch, held for the end of the
	# next roll he makes too early.
	if _saw_roll and what != CATCH and _fits(CATCH, gap, 1.5) and _rng.randf() < catch_chance:
		return CATCH
	if _closing:
		return -1
	var weights := _follow(what)
	# A swing's end was weighed as it began ([method _closes]).
	var past := _weighed_ahead(what)
	var options: Array = []
	for next: int in weights:
		var w := float(weights[next])
		if next == -1:
			if not past:
				options.append([-1, w])
			continue
		if next == what:
			continue
		match next:
			POUND:
				if gap > pound_to:
					continue
			HEAVY:
				var want := float(_strike_from.get(HEAVY, strike_off))
				if gap > want + 1.0 or gap < want - 1.6:
					continue
			_:
				if not _fits(next, gap, 1.0):
					continue
		options.append([next, w])
	return _weighed(options)
#endregion


#region Acting
func _extra_velocity(delta: float) -> Vector3:
	var held := _slide_span(act)
	if held.x >= 0.0:
		# Planted through the wind-up and the hold; then the slide, if he
		# backed off, or the plain step in under the blow.
		if _act_time < held.x:
			return Vector3.ZERO
		if _slide_serial == act_serial:
			return _forward() * _slide_speed if _act_time <= held.y else Vector3.ZERO
	if act == RAGE_ARM:
		return Vector3.ZERO
	if act == GRAB:
		# turned after him through the wind-up; its arm drawn back, slid in
		# on him (a skill's dash) so its hand comes to him as it sweeps
		var m := _grab_marks()
		var reach_at := m.y + (grab_catch.x - grab_cock.z) / grab_rate
		if _quarry != null and _act_time <= reach_at:
			if _act_time < reach_at - 0.08:
				_face(_quarry.global_position - global_position, get_physics_process_delta_time(), turn_speed * 3.0)
				_reframe()
			if _act_time >= reach_at - grab_dash_time:
				var s := visual_scale / 1.6
				var short := _distance_to(_quarry) - grab_hand_out * s
				var speed := clampf(short / maxf(reach_at - _act_time, 0.03), 0.0, grab_dash * s)
				if speed > 4.0 and not _grab_dashed:
					_grab_dashed = true
					grab_dashes += 1
					if is_inside_tree() and multiplayer.has_multiplayer_peer():
						net_slide.rpc()
					else:
						net_slide()
				return _forward() * speed
		return Vector3.ZERO
	if act == LUNGE:
		if _act_time <= _blow_moments(LUNGE)[0]:
			return _forward() * _lunge_speed
		return Vector3.ZERO
	if act == OG_SPIN_SLIDE:
		var ms := _blow_moments(act)
		if _spin_from >= 0.0 and not ms.is_empty() and _act_time >= _spin_from and _act_time <= ms[0]:
			if not _spin_on:
				_spin_on = true
				spin_dashes += 1
				if is_inside_tree() and multiplayer.has_multiplayer_peer():
					net_slide.rpc()
				else:
					net_slide()
			return _forward() * _spin_speed
		return Vector3.ZERO
	if act == JUMP_SLAM and _jump_speed > 0.0:
		var span := _jump_span()
		if _act_time >= span.x and _act_time <= span.y:
			return _forward() * _jump_speed
	if act == HEAVY and _heavy_speed > 0.0:
		var hs := _heavy_span()
		if _act_time >= hs.x and _act_time <= hs.y:
			return _forward() * _heavy_speed
		if _act_time < hs.x:
			return Vector3.ZERO
	if FLIGHTS.has(act):
		var span := _flight_span(act)
		if _act_time >= span.x and _act_time <= span.y:
			return _forward() * _flight_speed
		return Vector3.ZERO
	return super(delta)


## Act seconds of the move's last moment of turning after him: a little
## before its first blow (`commit_lead`), a leap a third into its flight.
func _commit_at(what: int) -> float:
	if FLIGHTS.has(what):
		var span := _flight_span(what)
		return lerpf(span.x, span.y, chase_flight_commit)
	var ms := _blow_moments(what)
	if ms.is_empty():
		return 0.0
	if what == JUMP_SLAM:
		return ms[0] - chase_commit
	if what == HEAVY:
		return ms[0] - heavy_commit
	if what == OG_SPIN_SLIDE and _spin_from >= 0.0:
		# after him till the last 15 % of its dash
		return ms[0] - maxf(0.15 * (ms[0] - _spin_from), 0.06)
	var heavy := _is_heavy(what)
	if act_serial == _wheel_serial:
		return ms[0] - wheel_commit
	return ms[0] - (commit_lead.y if heavy else commit_lead.x)


func _track_rate(what: int) -> float:
	if act_serial == _wheel_serial:
		return turn_speed * wheel_rate
	if FLIGHTS.has(what) or what == LUNGE:
		return turn_speed * 1.3
	if what == CATCH:
		return turn_speed * 1.2
	return turn_speed * (0.85 if _is_heavy(what) else 0.7)


## Turning after him till the move commits ([method _commit_at]), and then
## locked: the dash and the leaps sized to where he is now, as they turn.
func _track_before_blow(delta: float) -> void:
	if _quarry == null:
		return
	if _slide_after_him(delta):
		return
	if _act_time >= _commit_at(act):
		return
	var chases := _chases(act)
	var at := _quarry_ahead(act) if chases else _quarry.global_position
	# a leap in the air, a jump slam closing: turned after him hard
	var rate := _track_rate(act) * (3.0 if chases and _act_time >= _chase_from(act) else 1.0)
	_face(at - global_position, delta, rate)
	_reframe()
	if act == LUNGE:
		_lunge_speed = _close_speed_for(LUNGE, _blow_moments(LUNGE)[0], 0.0)
	elif FLIGHTS.has(act):
		var span := _flight_span(act)
		_flight_speed = _close_speed_for(act, span.y, span.x, true)
	elif act == JUMP_SLAM:
		_jump_closing()
	elif act == OG_SPIN_SLIDE:
		_spin_dash(true)
	elif act == HEAVY:
		_heavy_closing()


## Host: the sliding whirl's dash at him ([member spin_dash_speed]): from when
## (act s, -1 none: he is in its reach) and how fast, to be on him as the club
## comes round; once on its way, only its speed, to where he will be.
var _spin_from: float = -1.0
var _spin_speed: float = 0.0
var _spin_on: bool = false
var spin_dashes: int = 0


func _spin_dash(ahead: bool) -> void:
	var ms := _blow_moments(OG_SPIN_SLIDE)
	if ms.is_empty() or _quarry == null:
		return
	var blow := ms[0]
	var m: Array = _moves_table[OG_SPIN_SLIDE]
	var own := _hips(m[0], _clip_time(OG_SPIN_SLIDE, blow)).x - _hips(m[0], _clip_time(OG_SPIN_SLIDE, _act_time)).x
	var reach := float(_strike_from.get(OG_SPIN_SLIDE, strike_off))
	var gap := _gap_to(_quarry_ahead(OG_SPIN_SLIDE)) if ahead else _distance_to(_quarry)
	var d := clampf(gap - reach - own, 0.0, spin_slide_most * visual_scale / 1.6)
	var left := maxf(blow - _act_time, 0.05)
	if _spin_on:
		_spin_speed = d / left
		return
	if d < 0.3:
		_spin_from = -1.0
		_spin_speed = 0.0
		return
	var window := minf(d / (spin_dash_speed * visual_scale / 1.6), left)
	_spin_from = blow - window
	_spin_speed = d / maxf(window, 0.05)


## The moves running does not beat ([member chase_lead_most]): the leaps, the
## jump slam, a held swing.
func _chases(what: int) -> bool:
	return FLIGHTS.has(what) or what == JUMP_SLAM or what == OG_SPIN_SLIDE or what == HEAVY \
			or _slide_span(what).x >= 0.0


## Act seconds from which a chasing move is on its way at him (the leap off
## the ground, the jump slam closing, the held swing let go).
func _chase_from(what: int) -> float:
	if what == HEAVY:
		return 0.0
	if what == OG_SPIN_SLIDE:
		return _spin_from if _spin_from >= 0.0 else INF
	if FLIGHTS.has(what):
		return _flight_span(what).x
	if what == JUMP_SLAM:
		return _jump_span().x
	return _slide_span(what).x


## Where he will be when this move's first blow lands, if he runs on as he
## runs now (flat, on the ground he stands on).
func _quarry_ahead(what: int) -> Vector3:
	var at := _quarry.global_position
	var ms := _blow_moments(what)
	if ms.is_empty():
		return at
	return at + _his_run * clampf(ms[0] - _act_time, 0.0, chase_lead_most)


## Host: how he is running over the ground, as it sees him move (smoothed;
## a peer's body far off has no velocity of its own to read).
var _his_run: Vector3 = Vector3.ZERO
var _his_last: Vector3 = Vector3.INF
var _his_who: Node3D = null


func _watch_his_run(delta: float) -> void:
	if _quarry == null or not is_instance_valid(_quarry) or delta <= 0.0:
		_his_run = Vector3.ZERO
		_his_last = Vector3.INF
		return
	var at := _quarry.global_position
	if _his_who != _quarry or _his_last == Vector3.INF:
		_his_who = _quarry
		_his_last = at
		_his_run = Vector3.ZERO
		return
	var moved := (at - _his_last) / delta
	moved.y = 0.0
	_his_last = at
	# a jump of the body (set over, respawned): not a run
	if moved.length() > 14.0:
		return
	_his_run = _his_run.lerp(moved, 1.0 - exp(-12.0 * delta))


## The jump slam's closing on him: act seconds [from, its blow].
func _jump_span() -> Vector2:
	var ms := _blow_moments(JUMP_SLAM)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	return Vector2(maxf(ms[0] - jump_slam_close, 0.0), ms[0])


## Host: the jump slam's speed onto where he will be, if he is out of its
## reach; none if he is in it (it lands where it stands, as it always did).
## The great blow's closing on him: act seconds [from, its blow].
func _heavy_span() -> Vector2:
	var ms := _blow_moments(HEAVY)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	return Vector2(maxf(ms[0] - heavy_close, 0.0), ms[0])


var _heavy_speed: float = 0.0


## Host: the great blow's speed onto where he will be, him out of its reach
## (none in it: it comes down where it stands).
func _heavy_closing() -> void:
	var span := _heavy_span()
	if span.x < 0.0:
		return
	var reach := float(_strike_from.get(HEAVY, strike_off))
	var gap := _gap_to(_quarry_ahead(HEAVY))
	if gap <= reach + slide_slack * visual_scale / 1.6:
		_heavy_speed = 0.0
		return
	_heavy_speed = clampf(_close_speed_for(HEAVY, span.y, span.x, true), 0.0,
			heavy_close_most * visual_scale / 1.6 / maxf(span.y - span.x, 0.15))


func _jump_closing() -> void:
	var span := _jump_span()
	if span.x < 0.0:
		return
	var reach := float(_strike_from.get(JUMP_SLAM, strike_off))
	var gap := _gap_to(_quarry_ahead(JUMP_SLAM))
	if gap <= reach + slide_slack * visual_scale / 1.6:
		_jump_speed = 0.0
		return
	_jump_speed = clampf(_close_speed_for(JUMP_SLAM, span.y, span.x, true), 0.0,
			jump_slam_most * visual_scale / 1.6 / maxf(span.y - span.x, 0.15))


func _gap_to(at: Vector3) -> float:
	var gap := at - global_position
	gap.y = 0.0
	return gap.length()


## The speed on top of the clip's own travel that brings the move's blow on
## him from where he is now, laid over the act seconds from `from` (or now,
## if later) to `until`.
func _close_speed_for(what: int, until: float, from: float, ahead: bool = false) -> float:
	var ms := _blow_moments(what)
	var blow := ms[0] if not ms.is_empty() else until
	var m: Array = _moves_table[what]
	var own := _hips(m[0], _clip_time(what, blow)).x - _hips(m[0], _clip_time(what, _act_time)).x
	var short := float(_strike_from.get(what, strike_off))
	if FLIGHTS.has(what):
		# a leap comes down a little inside its reach: quicker through the air,
		# it overshot less and landed short of him from far (2026-10-11)
		short -= 0.5 * visual_scale / 1.6
	var left := maxf(until - maxf(from, _act_time), 0.15)
	var gap := _gap_to(_quarry_ahead(what)) if ahead else _distance_to(_quarry)
	return maxf(gap - short - own, 0.0) / left


## Act seconds a held swing slides over: [the end of its hold, its blow], or
## (-1, -1) if it is not held this time.
func _slide_span(what: int) -> Vector2:
	var sh := _shape(what)
	if sh.is_empty() or float(sh[2]) <= 0.0:
		return Vector2(-1.0, -1.0)
	var ms := _blow_moments(what)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	var release := float(sh[0]) * float(sh[1]) + float(sh[2])
	return Vector2(release, ms[0])


## Host: a held swing let go with him out of its reach slides at him and
## follows him round to its blow. True while it is sliding.
func _slide_after_him(delta: float) -> bool:
	var sp := _slide_span(act)
	if sp.x < 0.0 or _act_time > sp.y:
		return false
	if _slide_serial != act_serial:
		if not _decides() or _act_time < sp.x or _quarry_down():
			return false
		var reach := float(_strike_from.get(act, strike_off))
		if _gap_to(_quarry_ahead(act)) <= reach + slide_slack * visual_scale / 1.6:
			return false
		_slide_serial = act_serial
		slides_made += 1
		_face(_quarry_ahead(act) - global_position, 1.0, 50.0)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_slide.rpc()
		else:
			net_slide()
	# turned after where he will be till just before the blow, then locked
	if _act_time < sp.y - chase_commit:
		_face(_quarry_ahead(act) - global_position, delta, turn_speed * 4.0)
		_reframe()
	var window := maxf(sp.y - sp.x, 0.15)
	_slide_speed = clampf(_close_speed_for(act, sp.y, sp.x, true), 0.0,
			slide_most * visual_scale / 1.6 / window)
	return true


## Every peer: the held swing let go at him — a grunt, grit kicked up off
## its feet as it slides.
@rpc("authority", "call_local", "reliable")
func net_slide() -> void:
	_sound_at(GRUNTS, global_position + Vector3.UP * 1.6 * visual_scale, 0.8, 0.0)
	var into := Blood.world_of(self)
	var back := -_forward()
	for side: float in [-0.35, 0.35]:
		var at := global_position + back * 0.3 + _forward().cross(Vector3.UP) * side * visual_scale
		SkillFx.particles(into, at + Vector3.UP * 0.08, {
			"amount": 9, "life": 0.7, "one_shot": true, "explosiveness": 0.85, "add": false,
			"speed": Vector2(0.8, 2.0), "dir": back + Vector3.UP * 0.6, "spread": 35.0, "gravity": Vector3(0, -3.0, 0),
			"damping": 1.5, "size": Vector2(0.15, 0.32), "grow": 0.4, "sphere": 0.2,
			"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.4), Color(0.55, 0.5, 0.45, 0.0)],
		})
	WindBlast.shake(self, 0.05, 0.2, 9.0)


## A leap's flight in act seconds: [leaves the ground, lands], drawn out.
func _flight_span(what: int) -> Vector2:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	var a1 := (float(f[1]) - c0) / float(m[1])
	return Vector2(a0, a0 + (a1 - a0) * float(f[2]))


## [act s the flight begins, its length at the clip's pace, how much slower].
func _flight_warp(what: int) -> Vector3:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	return Vector3(a0, (float(f[1]) - float(f[0])) / float(m[1]), float(f[2]))


func _clip_time(what: int, t: float) -> float:
	if what == GRAB:
		var m := _grab_marks()
		if t <= m.x:
			return t * grab_rate
		if t <= m.y:
			return lerpf(grab_cock.x, grab_cock.z, (t - m.x) / maxf(grab_cock.y, 0.01))
		return grab_cock.z + (t - m.y) * grab_rate
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		if t > w.x:
			if t < w.x + w.y * w.z:
				t = w.x + (t - w.x) / w.z
			else:
				t -= w.y * (w.z - 1.0)
	return super(what, t)


func _move_length(what: int) -> float:
	var length := super(what)
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		length += w.y * (w.z - 1.0)
	# a swing the string goes on from: on into the next soon after its last
	# blow, its own recovery cut (the user's word, 2026-10-10: the pauses
	# in its strings were so long he could not tell it was a string)
	if what == act and (SWINGS.has(what) or COMBO_MOVES.has(what)) and not _closing and _string_count > 0:
		var ms := _blow_moments(what)
		if not ms.is_empty():
			length = minf(length, ms[ms.size() - 1] + string_follow_after)
	return length


func _blow_moments(what: int) -> PackedFloat32Array:
	var ms := super(what)
	if not FLIGHTS.has(what) or _anim == null:
		return ms
	var w := _flight_warp(what)
	var out := PackedFloat32Array()
	for m in ms:
		if m <= w.x:
			out.append(m)
		elif m <= w.x + w.y:
			out.append(w.x + (m - w.x) * w.z)
		else:
			out.append(m + w.y * (w.z - 1.0))
	return out


func _run_act(delta: float) -> void:
	var was := act
	var serial := act_serial
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides():
		return
	if was == act and serial == act_serial and _strikes_table.has(act):
		_watch_blows(t0)
	if act == RAGE and _rage_pushed != act_serial and _act_time >= rage_roar_at:
		_rage_pushed = act_serial
		_rage_throw()
	if act == GRAB:
		_grab_run()
	if act == RAGE_ARM and _armed_serial != act_serial and _act_time > 0.35:
		# the club down by the ground: in
		var tip := _weapon_tip_at()
		if tip.y - global_position.y < 0.45 * visual_scale / 1.6 \
				or _act_time >= _move_length(RAGE_ARM) * 0.8:
			_armed_serial = act_serial
			_arm_club()
	if (act == POUND or act == POUND_2 or act == POUND_3) and not _pounded and _act_time >= _pound_time(act):
		_pounded = true
		var k := 0 if act == POUND else (1 if act == POUND_2 else 2)
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z)
		var reach := pound_reaches[k] * visual_scale / 1.6
		_quake(at, reach, hit_damage * pound_share * (1.0 + 0.25 * k), false, rock_pace)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, reach, 1.0 + 0.35 * k)
		else:
			net_rocks(at, act_serial, reach, 1.0 + 0.35 * k)
	elif act == STOMP and not _pounded and _act_time >= _stomp_at:
		_pounded = true
		_stomp_down()
	elif act == HEAVY and not _pounded and _act_time >= _blow_moments(HEAVY)[0]:
		# the great blow into the ground: rock bursting up all round, and
		# everyone on the ground near it thrown down
		_pounded = true
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z)
		_quake(at, heavy_quake_radius * visual_scale / 1.6, hit_damage * heavy_quake_share, false, rock_pace)
		var length := heavy_rock_length * visual_scale / 1.6
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, length, 1.4)
		else:
			net_rocks(at, act_serial, length, 1.4)
	elif raging and OVERHEAD.has(act) and not FLIGHTS.has(act) and act != CATCH and not _pounded \
			and _strikes_table.has(act) and _act_time >= _blow_moments(act)[0]:
		# enraged, the ground breaks under its overhead blows
		_pounded = true
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z)
		var s := visual_scale / 1.6
		rage_grounds += 1
		_quake(at, rage_ground_radius * s, hit_damage * rage_ground_share, false, rock_pace)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, rage_ground_radius * s, 0.6)
		else:
			net_rocks(at, act_serial, rage_ground_radius * s, 0.6)
	elif act == GETOFF and not _pounded and _act_time >= _getoff_at():
		_pounded = true
		_getoff_shock()
	elif FLIGHTS.has(act) and not _pounded and _act_time >= _blow_moments(act)[0]:
		# down out of its leap: the ground breaks under it, rock bursting up
		# all round, whoever stands near thrown down
		_pounded = true
		var s := visual_scale / 1.6
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z).lerp(global_position, 0.5)
		_quake(at, leap_land_radius * s, hit_damage * leap_land_share, false, rock_pace)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, leap_rock_length * s, 0.8)
		else:
			net_rocks(at, act_serial, leap_rock_length * s, 0.8)
	elif act == OG_STOMP_FOOT and not _pounded and _act_time >= _blow_moments(OG_STOMP_FOOT)[0]:
		# its foot down: the ground bursts up round it (it staggers him)
		_pounded = true
		var foot := global_position
		if _skeleton != null:
			var b := _skeleton.find_bone("R_toe_joint")
			if b >= 0:
				foot = _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
		_aftershock(Vector3(foot.x, global_position.y, foot.z) + _forward() * 0.6 * visual_scale / 1.6,
				act_serial * 1000 + 55)


## Host, through a swing: did he roll from under its blow (for the
## roll-catch), and did a lone heavy blow or a slam meet the ground (an
## aftershock to follow).
func _watch_blows(t0: float) -> void:
	var ms := _blow_moments(act)
	if ms.is_empty():
		return
	if _quarry is Player:
		var st := (_quarry as Player).state
		if st == Player.State.DODGING or st == Player.State.DASHING:
			for m in ms:
				if absf(_act_time - m) < 0.3:
					_saw_roll = true
	var last := ms[ms.size() - 1]
	if aftershocks_follow and t0 < last and _act_time >= last and _shakes_after(act):
		_shock_look = Vector2(act_serial, _act_time + 0.35)
	# From its blow on, the first moment the club is down by the ground.
	if int(_shock_look.x) == act_serial and _act_time <= _shock_look.y:
		var tip := _weapon_tip_at()
		if tip.y - global_position.y < 0.9 * visual_scale:
			_shock_look = Vector2(-1, 0)
			var ahead := _forward() * aftershock_ahead * visual_scale / 1.6
			_shocks.append([Vector3(tip.x, global_position.y, tip.z) + ahead, aftershock_after, act_serial * 1000 + 77])


## Whether the ground answers this move's blow a beat later: the slams and
## the great blow always, a heavy swing when it closes its string alone or
## last (combos stay as they were).
func _shakes_after(what: int) -> bool:
	if FLIGHTS.has(what) or what == HEAVY or what == JUMP_SLAM:
		return true
	if COMBO_MOVES.has(what):
		return bool(COMBO_MOVES[what][2]) and _closing
	return SWINGS.has(what) and bool(SWINGS[what][2]) and _closing


func _physics_process(delta: float) -> void:
	_watch_his_run(delta)
	super(delta)
	# its swipe's wait runs all the time, through its strings too (the user's
	# word, 2026-10-12: in a real fight it never came — its wait only ran
	# between strings, so 12–20 s became a minute)
	if _decides() and act != GRAB and not is_dead:
		_grab_wait = maxf(_grab_wait - delta, 0.0)
	if _decides() and not is_dead:
		_watch_under(delta)
		_watch_party()
		_coop_watch(delta)
	if _shocks.is_empty() or is_dead or not _decides():
		return
	for i in range(_shocks.size() - 1, -1, -1):
		var sh: Array = _shocks[i]
		sh[1] = float(sh[1]) - delta
		if float(sh[1]) > 0.0:
			continue
		_shocks.remove_at(i)
		_aftershock(sh[0], int(sh[2]))


## Host: the second burst of earth: whoever is on the ground near it is
## caught (a stagger; off the ground, or rolling, it misses him).
func _aftershock(at: Vector3, id: int) -> void:
	aftershocks_made += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_aftershock.rpc(at)
	else:
		net_aftershock(at)
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
			continue
		var rel := who.global_position - at
		if absf(rel.y) > 2.0 or Vector2(rel.x, rel.z).length() > aftershock_radius * visual_scale / 1.6:
			continue
		who.call(&"receive_blow", hit_damage * aftershock_share * _blow_worth(0), self, 0, 2, id, false, &"ground")


## Every peer: the great blow's rock — rows of stone bursting up out from where
## the club went in, all the way round, grit thrown up, the view shaken hard.
@rpc("authority", "call_local", "reliable")
func net_rocks(at: Vector3, seed_of: int, length: float, size: float) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	RockWave.spawn(into, at, length, size * s, rock_pace, seed_of)
	GroundFx.eruption(into, at, (0.9 + 0.3 * size) * s, false)
	ImpactFx.thud(self, at, true)
	_sound_at(CLUB_GROUND, at, 0.75 - 0.05 * size, 2.0 + size)
	WindBlast.shake(self, 0.12 + 0.08 * size, 0.5 + 0.15 * size, 16.0)


## Every peer: the ground bursting up again ahead of where the club fell —
## earth and stones thrown up unevenly, a deep crack of it, the view shaken
## (no ring).
@rpc("authority", "call_local", "reliable")
func net_aftershock(at: Vector3) -> void:
	var into := Blood.world_of(self)
	var fwd := _forward()
	GroundFx.eruption(into, at + Vector3.UP * 0.05, 0.9, false)
	GroundFx.eruption(into, at + fwd * 0.9 + fwd.cross(Vector3.UP) * 0.4 + Vector3.UP * 0.05, 0.55, false)
	ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
	_sound_at(CLUB_GROUND, at, 0.72, 1.0)
	WindBlast.shake(self, 0.1, 0.35, 14.0)


## Host: the club down where he lies: a blow at him if it comes down by him.
func _stomp_down() -> void:
	var at := _weapon_tip_at()
	var world := Blood.world_of(self)
	DustRing.burst(world, Vector3(at.x, global_position.y + 0.05, at.z), 0.6 * visual_scale)
	ImpactFx.thud(self, at, true)
	if _quarry == null or not _quarry.has_method(&"receive_blow"):
		return
	var flat := Vector2(at.x - _quarry.global_position.x, at.z - _quarry.global_position.z).length()
	if flat <= 1.5:
		_quarry.call(&"receive_blow", hit_damage * stomp_share * _blow_worth(STOMP), self, 0, 1,
				act_serial, false, &"stomp")


func _after(what: int) -> void:
	match what:
		POUND:
			_pound_wait = _rng.randf_range(pound_cooldown.x, pound_cooldown.y) * (0.6 if raging else 1.0)
		HEAVY:
			_heavy_wait = _rng.randf_range(heavy_cooldown.x, heavy_cooldown.y) * (0.6 if raging else 1.0)
		STOMP:
			_stomp_wait = stomp_cooldown
		LUNGE:
			_lunge_wait = _rng.randf_range(lunge_cooldown.x, lunge_cooldown.y)
		LEAP_SLAM:
			_leap_slam_wait = _rng.randf_range(leap_slam_cooldown.x, leap_slam_cooldown.y) * (0.7 if raging else 1.0)
	var stringed := SWINGS.has(what) or COMBO_MOVES.has(what) or what == POUND or what == POUND_2 \
			or what == POUND_3 or what == HEAVY or FLIGHTS.has(what)
	var next := -1
	if stringed and not is_dead and _decides():
		next = _next_in_string(what)
	super(what)
	if what == RAGE and not is_dead and _decides() and _moves_table.has(RAGE_ARM):
		# its club driven into the ground, the stone coming up onto it
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(RAGE_ARM)
		return
	if stringed and not is_dead and _decides() and _getoff_due and _quarry != null \
			and _getoff(_distance_to(_quarry)):
		# its string broken off for the stamp: he was greedy, or under it
		_string_count = 0
		_chain_serial = -1
		_chain_blow = 0
		_closing = false
		_combo = -1
		return
	if next >= 0:
		# On into the next, turned a little after him.
		if _quarry != null:
			var to := _quarry.global_position - global_position
			rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), deg_to_rad(string_turn))
		_begin_move(next, what)
		if _wheel_next:
			_wheel_next = false
			_wheel_serial = act_serial
		return
	_wheel_next = false
	if stringed:
		var r := recover_raging if raging else recover
		_cooldown = _rng.randf_range(r.x, r.y)
		if not is_dead and _decides() and drill_combo < 0:
			_start_spacing()
	_string_count = 0
	_chain_serial = -1
	_chain_blow = 0
	_closing = false
	_combo = -1
#endregion


#region Co-op
## Host, every tick: how they stand round it — who cuts it from behind or
## stands there, who casts from afar — and its waits run.
func _coop_watch(delta: float) -> void:
	_coop_clock += delta
	var near := _heroes_near(sight_range * 1.5)
	var quicker := 1.0 + ring_quicker * maxf(float(near.size()) - 2.0, 0.0)
	_ring_wait = maxf(_ring_wait - delta * quicker, 0.0)
	_rear_wait = maxf(_rear_wait - delta, 0.0)
	_far_wait = maxf(_far_wait - delta, 0.0)
	var s := visual_scale / 1.6
	for who: Node3D in near:
		var id := who.get_instance_id()
		var behind := who != _quarry and _distance_to(who) <= rear_reach * s and _angle_of(who) > 110.0
		_behind_for[id] = float(_behind_for.get(id, 0.0)) + delta if behind else 0.0
		var hero := who as Player
		if hero == null:
			continue
		var casts := hero.net_casts
		if who != _quarry and casts != int(_far_casts.get(id, casts)) and _distance_to(who) >= far_from * s:
			_far_due = who
		_far_casts[id] = casts


## Host: a cut on it from `from`, kept if it came from behind its shoulders
## or from afar (and not from its quarry).
func _coop_cut(from: Node3D) -> void:
	if from == _quarry:
		return
	var id := from.get_instance_id()
	var s := visual_scale / 1.6
	var gap := _distance_to(from)
	if gap <= rear_reach * s and _angle_of(from) > 110.0:
		var rc := _recent(_rear_cuts.get(id, []), rear_window)
		rc.append(_coop_clock)
		_rear_cuts[id] = rc
	if gap >= far_from * s:
		var fc := _recent(_far_cuts.get(id, []), far_window)
		fc.append(_coop_clock)
		_far_cuts[id] = fc
		if fc.size() >= far_hits:
			_far_due = from


func _recent(times: Array, window: float) -> Array:
	var out: Array = []
	for at: float in times:
		if _coop_clock - at <= window:
			out.append(at)
	return out


## The heroes up for a fight with it within `most` m: alive, not fallen nor
## hidden, on its ground.
func _heroes_near(most: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or Brute.unseen(who) or bool(who.get("is_dead")) or not _on_ground(who):
			continue
		if _distance_to(who) <= most:
			out.append(who)
	return out


## Whether `who` is on the ground it holds (its leash round its camp).
func _on_ground(who: Node3D) -> bool:
	return who.global_position.distance_squared_to(camp_centre) < leash_radius * leash_radius


func _is_down(who: Node3D) -> bool:
	return who is Player and (who as Player).state == Player.State.DOWNED


## Degrees between where it faces and its way to `who`.
func _angle_of(who: Node3D) -> float:
	var to := who.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(_forward().angle_to(to.normalized()))


## The nearest of them on his feet (m), INF if none.
func _nearest_up_gap() -> float:
	var best := INF
	for who in _heroes_near(INF):
		if not _is_down(who):
			best = minf(best, _distance_to(who))
	return best


## Host: on `who` now, by a move of its own (its eyes flare on every peer).
func _turn_on(who: Node3D) -> void:
	_quarry = who
	Threat.turn_to(self, who, coop_anger)


## Host, free between moves with more than one at it: its answer to a ring
## round it, to the one at its back, to the one hurting it from afar (true if
## it went). Its rest between strings does not hold these back, their own
## waits do.
func _coop_answer(delta: float) -> bool:
	# (its run at one far off is not broken off by the others at its back)
	if drill_combo >= 0 or _charging or stamina < attack_cost * 0.5:
		return false
	var near := _heroes_near(sight_range * 1.5)
	if near.size() < 2:
		_far_due = null
		return false
	return _ring_answer(near) or _rear_answer() or _far_answer(delta)


func _ring_answer(near: Array[Node3D]) -> bool:
	if _ring_wait > 0.0:
		return false
	var r := ring_reach * visual_scale / 1.6
	var close := 0
	var round_it := false
	for who in near:
		if _is_down(who) or _distance_to(who) > r:
			continue
		close += 1
		if _angle_of(who) > 75.0:
			round_it = true
	if close < 2 or not round_it:
		return false
	_ring_wait = _rng.randf_range(ring_cooldown.x, ring_cooldown.y)
	rings_made += 1
	_charging = false
	_spacing = &""
	mode = Mode.FIGHT
	velocity.x = 0.0
	velocity.z = 0.0
	if _rng.randf() < 0.5:
		# its foot down (the ground bursts round it), and the whirl
		_combo_pending = _combo_named(&"stamp")
		_open(OG_STOMP_FOOT)
	else:
		_open(WHIRL)
	return true


func _rear_answer() -> bool:
	if _rear_wait > 0.0:
		return false
	var best: Node3D = null
	var most := 0.0
	for who in _heroes_near(rear_reach * visual_scale / 1.6):
		if who == _quarry or _is_down(who) or _angle_of(who) <= 110.0:
			continue
		var id := who.get_instance_id()
		var cuts := _recent(_rear_cuts.get(id, []), rear_window).size()
		var stood := float(_behind_for.get(id, 0.0))
		if cuts < rear_hits and stood < rear_stand:
			continue
		if float(cuts) + stood > most:
			most = float(cuts) + stood
			best = who
	if best == null:
		return false
	_rear_wait = _rng.randf_range(rear_cooldown.x, rear_cooldown.y)
	_rear_cuts.erase(best.get_instance_id())
	_behind_for.erase(best.get_instance_id())
	rears_made += 1
	_turn_on(best)
	_charging = false
	_spacing = &""
	mode = Mode.FIGHT
	velocity.x = 0.0
	velocity.z = 0.0
	# wheeled round at him through its wind-up, no snap
	_combo_pending = _combo_named(&"turn_back")
	_open(OG_BACK)
	_wheel_serial = act_serial
	return true


func _far_answer(delta: float) -> bool:
	var who := _far_due
	if who == null or _far_wait > 0.0:
		return false
	_far_due = null
	if not is_instance_valid(who) or who == _quarry or Brute.unseen(who) or _is_down(who) \
			or not _on_ground(who):
		return false
	var gap := _distance_to(who)
	if gap < far_from * visual_scale / 1.6:
		return false
	_far_wait = _rng.randf_range(far_cooldown.x, far_cooldown.y)
	_far_cuts.erase(who.get_instance_id())
	fars_made += 1
	# the ones it leaves behind: their cuts at its back as it goes count for
	# nothing, and it does not whip round on them the moment it is down
	_rear_cuts.clear()
	_behind_for.clear()
	_rear_wait = maxf(_rear_wait, 2.5)
	_turn_on(who)
	_spacing = &""
	mode = Mode.FIGHT
	if gap <= leap_slam_to * 1.35:
		_charging = false
		_open(LEAP_SLAM)
		_wheel_serial = act_serial
		return true
	# further: off at a run at him, springing at `run_slam_takeoff`
	_charging = true
	_charge_time = 0.0
	_run_slam_wait = _rng.randf_range(run_slam_cooldown.x, run_slam_cooldown.y)
	mode = Mode.CHASE
	_move_towards(who.global_position, _pace(run_speed), delta)
	return true


## Host, as a string runs on: its next blow onto another of them — its
## quarry down, out of its reach or round its back — or now and then onto one
## clearly nearer before it ([member switch_chance]).
func _switch_in_string() -> void:
	if drill_combo >= 0 or _switches >= switch_most:
		return
	var near := _heroes_near(sight_range)
	if near.size() < 2:
		return
	var reach_now := strike_off + 2.5 * visual_scale / 1.6
	var ok: bool = _quarry != null and is_instance_valid(_quarry) and not Brute.unseen(_quarry) and not _quarry_down()
	var q_gap := _distance_to(_quarry) if ok else INF
	var lost: bool = not ok or q_gap > reach_now or _angle_of(_quarry) > switch_turn
	var best: Node3D = null
	var best_score := INF
	for who in near:
		if who == _quarry or _is_down(who):
			continue
		var gap := _distance_to(who)
		var angle := _angle_of(who)
		if gap > reach_now or angle > switch_turn:
			continue
		var score := gap + angle / 45.0
		if score < best_score:
			best_score = score
			best = who
	if best == null:
		return
	if not lost:
		var q_score := q_gap + _angle_of(_quarry) / 45.0
		if best_score > q_score - 1.0 or _rng.randf() >= switch_chance:
			return
	_switches += 1
	switches_made += 1
	_turn_on(best)
	_wheel_next = true
#endregion


#region Looks and sounds
## Every peer: the swing heard coming, the club meeting the ground, its roar,
## and the weight of its feet.
func _process(delta: float) -> void:
	super(delta)
	# a great enemy: its bar is at the bottom of his view, not over its head
	if not boss_name.is_empty():
		if _health_bar != null:
			_health_bar.visible = false
		if _stamina_bar != null:
			_stamina_bar.visible = false
	if is_dead:
		_watch_death()
		# its fire out with it
		if _cracks != null:
			_cracks.set_shader_parameter(&"beat", 0.0)
		if _club_fire != null:
			_club_fire.emitting = false
		if _glow_hand != null:
			_glow_hand.visible = false
			_glow_sparks.emitting = false
			_glow_core.visible = false
		return
	if act_serial != _heard_serial:
		_heard_serial = act_serial
		_heard_clock = 0.0
		_heard = 0
		_on_new_act()
	else:
		_heard_clock += delta
	_watch_hold()
	_strain_in_hold()
	_bend_over_him(delta)
	_fade_if_between(delta)
	_grab_tell()
	_lift_in_flight()
	_take_off()
	if _strikes_table.has(act):
		var ms := _blow_moments(act)
		while _heard < ms.size() * 2:
			var i := _heard / 2
			var whoosh := _heard % 2 == 0
			var when := ms[i] - (0.16 if whoosh else 0.0)
			if _heard_clock < when:
				break
			_heard += 1
			if whoosh:
				Sfx.play(self, WHOOSH_HEAVY if _is_heavy(act) else WHOOSH_LIGHT, null, _weapon_tip_at(),
						0.95 if _is_heavy(act) else 1.05, -4.0 if _is_heavy(act) else -9.0)
			elif _is_heavy(act):
				_club_lands()
	elif act == TAUNT:
		# the roar itself, as its chest comes up
		if _heard == 0 and _heard_clock >= taunt_roar_at:
			_heard = 1
			Sfx.play(self, ROAR_SOUND, self, Vector3.ZERO, 1.05, -1.0)
			WindBlast.shake(self, 0.05, 0.6, 18.0)
	elif act == Act.NONE:
		_footfalls()


## Every peer: a swing held at the top of its wind-up shows it the moment it
## stops there (the user's word, 2026-10-10: the delay should be learnt).
func _watch_hold() -> void:
	if is_dead or act_serial == _glint_serial or not _holds.has(act):
		return
	var sh := _shape(act)
	if sh.is_empty() or float(sh[2]) <= 0.0:
		return
	if _heard_clock < float(sh[0]) * float(sh[1]):
		return
	_glint_serial = act_serial
	_glint()


## Every peer: the swipe's tell — from the moment its arm starts back its
## hand kindles cold blue, a light and a stream of sparks, brightest at the
## top (the user's word, 2026-10-12: "like a skill being cast"), out as the
## arm comes down; at the top a flare and a growl, then the rush of its slide.
var _told_serial: int = -1
var grab_glow_peak: float = 0.0


func _make_grab_glow() -> void:
	if _skeleton == null:
		return
	var bone := "L_midFinger_joint1" if _skeleton.find_bone("L_midFinger_joint1") >= 0 else "L_wrist_joint"
	if _skeleton.find_bone(bone) < 0:
		return
	var hold := BoneAttachment3D.new()
	hold.name = "GrabGlow"
	hold.bone_name = bone
	_skeleton.add_child(hold)
	var s := visual_scale / 1.6
	_glow_hand = OmniLight3D.new()
	_glow_hand.light_color = grab_glow
	_glow_hand.omni_range = 4.5 * s
	_glow_hand.light_energy = 0.0
	_glow_hand.shadow_enabled = false
	_glow_hand.visible = false
	hold.add_child(_glow_hand)
	var c := grab_glow
	# the hand's own blaze: a soft round glow on it, facing the view
	_glow_core = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.1 * s
	_glow_core.mesh = quad
	var fall := Gradient.new()
	fall.set_color(0, Color(1, 1, 1, 1))
	fall.set_color(1, Color(1, 1, 1, 0))
	fall.add_point(0.25, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = fall
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = Color(c.r, c.g, c.b, 0.0)
	_glow_core.material_override = m
	_glow_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_core.visible = false
	hold.add_child(_glow_core)
	_glow_sparks = SkillFx.particles(hold, Vector3.ZERO, {
		"amount": 120, "life": 0.5, "one_shot": false, "add": true,
		"speed": Vector2(0.4, 1.6), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3(0, 2.0, 0),
		"damping": 2.0, "size": Vector2(0.22 * s, 0.5 * s), "grow": -0.6, "sphere": 0.3 * s,
		"colors": [Color(0.85, 0.95, 1.0, 0.0), Color(c.r, c.g, c.b, 0.95), Color(c.r * 0.4, c.g * 0.5, c.b, 0.0)],
	})
	_glow_sparks.emitting = false


## Every peer: how lit its hand is now (0..1) — rising through the draw,
## full while held back and sliding in, gone as the arm comes down.
func _grab_glow_now() -> float:
	if act != GRAB or is_dead:
		return 0.0
	var ct := _clip_time(GRAB, _heard_clock)
	if ct >= grab_catch.x:
		return 0.0
	return clampf(ct / maxf(grab_cock.x, 0.01), 0.0, 1.0) * clampf((grab_catch.x - ct) / 0.08, 0.0, 1.0)


func _grab_tell() -> void:
	var lit := _grab_glow_now()
	if _glow_hand != null:
		var flick := 1.0 + 0.12 * sin(_heard_clock * 37.0)
		_glow_hand.light_energy = lit * 6.0 * flick
		_glow_hand.visible = lit > 0.01
		_glow_sparks.emitting = lit > 0.15
		_glow_sparks.amount_ratio = clampf(lit, 0.0, 1.0)
		_glow_core.visible = lit > 0.01
		var cm := _glow_core.material_override as StandardMaterial3D
		cm.albedo_color.a = lit * (0.85 + 0.15 * sin(_heard_clock * 23.0))
		_glow_core.scale = Vector3.ONE * (0.6 + 0.4 * lit)
		grab_glow_peak = maxf(grab_glow_peak, _glow_hand.light_energy)
	if act != GRAB or is_dead or _told_serial == act_serial:
		return
	if _heard_clock < _grab_marks().x - 0.2:
		return
	_told_serial = act_serial
	var at := grab_point()
	SkillFx.particles(Blood.world_of(self), at, {
		"amount": 30, "life": 0.5, "one_shot": true, "explosiveness": 1.0, "add": true,
		"speed": Vector2(1.5, 4.0), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3.ZERO,
		"damping": 5.0, "size": Vector2(0.14, 0.3), "grow": -0.6, "sphere": 0.1,
		"colors": [Color(0.8, 0.92, 1.0, 0.0), Color(grab_glow.r, grab_glow.g, grab_glow.b, 1.0), Color(0.1, 0.25, 0.9, 0.0)],
	})
	Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 0.8, -3.0)


## Its grab is no swing; a kick, a butt or a stamp (a limb, not the club)
## only bent if it would miss outright, as before.
func _stoop_skip(what: int) -> bool:
	if what == GRAB:
		return true
	return (_limbs_of.has(what) or what in [KICK, OG_HEADBUTT, OG_STOMP_FOOT]) and _strike_from.has(what)


## A string's first swing drawn out to `opener_least` s before its blow (its
## wind-up slowed; held swings and the slow great blow are slow enough).
func _shape(what: int) -> Array:
	var sh := super(what)
	if _in_lin or not sh.is_empty() or what != act or not act_opens or opener_least <= 0.0 \
			or not (SWINGS.has(what) or COMBO_MOVES.has(what)) or not _strikes_table.has(what):
		return sh
	var lead := 0.1
	var k := _windup_end(what, lead)
	if k <= 0.05 or k + lead >= opener_least:
		return sh
	return [k, minf((opener_least - lead) / k, 4.0), 0.0]


## Host: his cuts on it, counted for its stamp; where on its body it is struck.
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var tall := maxf(body_height * visual_scale, 0.5)
	var up := (at.y - global_position.y) / tall
	_part_stance = legs_stance if up < legs_below else 1.0
	if up > head_above:
		damage *= head_damage
	var bled := super(damage, at, blow, from, magic)
	_part_stance = 1.0
	if bled and not is_dead and from != null and from.is_in_group(&"player") and _decides():
		var now := Time.get_ticks_msec() / 1000.0
		_cut_times.append(now)
		while not _cut_times.is_empty() and now - float(_cut_times[0]) > getoff_window:
			_cut_times.pop_front()
		if _cut_times.size() >= getoff_hits:
			_getoff_due = true
		_coop_cut(from)
	return bled


func _stance_weight(from: Node3D, magic: bool) -> float:
	return super(from, magic) * _part_stance


## Host, every tick: its health grown for each more hero fighting it.
func _watch_party() -> void:
	if _own_health < 0.0:
		_own_health = max_health
	if party_health <= 0.0 or mode == Mode.GUARD or mode == Mode.RETURN:
		return
	var n := 0
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or bool(who.get("is_dead")):
			continue
		if who.global_position.distance_to(global_position) <= sight_range * 1.5:
			n += 1
	var want := _own_health * (1.0 + party_health * maxf(n - 1, 0))
	if want > max_health + 0.5:
		health += want - max_health
		max_health = want


func _made_whole() -> void:
	super()
	if _own_health > 0.0 and max_health > _own_health:
		max_health = _own_health
		health = max_health
	if _club_stones != null:
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_club_clean.rpc()
		else:
			net_club_clean()


## Every peer: the stone off its club again (home and calm).
@rpc("authority", "call_local", "reliable")
func net_club_clean() -> void:
	if _club_stones != null:
		_club_stones.queue_free()
		_club_stones = null


## Every peer, his own camera: faded while it stands between the camera and
## the hero the camera follows, so he is never lost behind it.
func _fade_if_between(delta: float) -> void:
	if fade_between <= 0.0 or body == null or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if cam != null and not is_dead:
		var me: Node3D = null
		for node in get_tree().get_nodes_in_group(&"player"):
			var p := node as Node3D
			if p != null and p.is_multiplayer_authority():
				me = p
				break
		if me != null:
			var from := cam.global_position
			var to := me.global_position + Vector3.UP * 1.0
			var r := body_radius * visual_scale
			var bottom := global_position + Vector3.UP * r
			var top := global_position + Vector3.UP * maxf(body_height * visual_scale - r, r)
			var pts := Geometry3D.get_closest_points_between_segments(from, to, bottom, top)
			var nearer := from.distance_to(global_position) < from.distance_to(me.global_position)
			if nearer and (pts[0] as Vector3).distance_to(pts[1]) < r * 1.1:
				want = fade_between
	_faded = move_toward(_faded, want, delta * 3.0)
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.transparency = _faded


## Host, every tick: how long he has stood in under it.
func _watch_under(delta: float) -> void:
	_getoff_wait = maxf(_getoff_wait - delta, 0.0)
	if _quarry == null or not is_instance_valid(_quarry):
		_under_for = 0.0
		return
	# (co-op: whoever stands in under it, not only its quarry)
	if _nearest_up_gap() <= getoff_under_gap * visual_scale / 1.6:
		_under_for += delta
		if _under_for >= getoff_under:
			_getoff_due = true
	else:
		_under_for = 0.0


## Host, free between moves: its stamp, if it is due and he is near.
func _getoff(gap: float) -> bool:
	if not _getoff_due:
		return false
	# (co-op: whoever is up and near, not only its quarry)
	if _getoff_wait > 0.0 or minf(gap if not _quarry_down() else INF, _nearest_up_gap()) \
			> getoff_radius * visual_scale / 1.6:
		_getoff_due = false
		_cut_times.clear()
		return false
	_getoff_due = false
	_cut_times.clear()
	_under_for = 0.0
	_getoff_wait = _rng.randf_range(getoff_cooldown.x, getoff_cooldown.y)
	getoffs_made += 1
	velocity.x = 0.0
	velocity.z = 0.0
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	act_opens = false
	_pounded = false
	_begin(GETOFF)
	return true


## Act seconds its stamping foot comes down (as its foot stamp's, at its pace).
func _getoff_at() -> float:
	var ms := _blow_moments(OG_STOMP_FOOT)
	if ms.is_empty():
		return 0.4
	return ms[0] * float((_moves_table[OG_STOMP_FOOT] as Array)[1]) / maxf(getoff_rate, 0.01)


## Host: the stamp's burst — everyone on the ground near staggered back.
func _getoff_shock() -> void:
	var r := getoff_radius * visual_scale / 1.6
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
			continue
		var rel := who.global_position - global_position
		if absf(rel.y) > 2.0 or Vector2(rel.x, rel.z).length() > r:
			continue
		who.call(&"receive_blow", hit_damage * getoff_share * _blow_worth(0), self, 0, 99,
				act_serial * 1000 + 95, false, &"ground")
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_getoff.rpc()
	else:
		net_getoff()


## Every peer: the stamp's burst — earth thrown up round its foot and out
## along the ground (no ring), the crack of it, the view jolted.
@rpc("authority", "call_local", "reliable")
func net_getoff() -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	var foot := global_position
	if _skeleton != null:
		var b := _skeleton.find_bone("R_toe_joint")
		if b >= 0:
			foot = _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
	foot.y = global_position.y
	GroundFx.eruption(into, foot + Vector3.UP * 0.05, 1.1 * s, false)
	SkillFx.particles(into, global_position + Vector3.UP * 0.2, {
		"amount": 70, "life": 0.7, "one_shot": true, "explosiveness": 0.95, "add": false,
		"speed": Vector2(5.0, 9.0) * s, "dir": Vector3(1, 0.1, 0), "spread": 180.0,
		"gravity": Vector3(0, -2.0, 0), "damping": 7.0, "size": Vector2(0.3, 0.7) * s, "grow": 0.6,
		"sphere": 0.5 * s,
		"colors": [Color(0.55, 0.5, 0.45, 0.0), Color(0.5, 0.45, 0.4, 0.5), Color(0.45, 0.42, 0.4, 0.0)],
	})
	ImpactFx.thud(self, foot + Vector3.UP * 0.2, true)
	_sound_at(CLUB_GROUND, foot, 0.8, 2.0)
	WindBlast.shake(self, 0.16, 0.4, 16.0)


## Host: a swing begun nearer him than its blow lands from has the clip's
## own step in shortened, so it does not walk into him and bring its club
## down beyond him (a step the size of a giant's, 2026-10-12).
func _begin(what: int) -> void:
	super(what)
	if _quarry == null or not _strikes().has(what) or FLIGHTS.has(what) or what == GRAB:
		return
	var ms := _blow_moments(what)
	if ms.is_empty():
		return
	var clip := _clip_of(what)
	var own := _hips(clip, _clip_time(what, ms[0])).x - _hips(clip, _clip_time(what, 0.0)).x
	if own < 0.2:
		return
	var room := _distance_to(_quarry) - float(_strike_from.get(what, strike_off))
	if room < own:
		_stretch = clampf(room / own, 0.0, 1.0)


## Every peer: bent forward over him through its reach and its hold, and up
## out of it into the slam (whose own clip bends it low).
func _bend_over_him(delta: float) -> void:
	if _lean == null:
		return
	var want := 0.0
	if not is_dead:
		if act == GRAB and _heard_clock >= _grab_marks().x - 0.1 \
				and _clip_time(GRAB, _heard_clock) < grab_smash_at + 0.4:
			# leaning into its slide and down into its swipe
			want = 0.4 if _clip_time(GRAB, _heard_clock) < grab_cock.z else 1.0
	_lean.amount = move_toward(_lean.amount, want, delta * (2.5 if want > _lean.amount else 4.0))
	_lean.facing = _forward()


## Every peer: through a swing held at the top it is not frozen but straining
## (the user's word, 2026-10-11: the hold read as lag) — its body trembles,
## harder as the hold runs out, and a creak and rush of air rise to the
## moment it lets go.
func _strain_in_hold() -> void:
	if body == null:
		return
	var on := false
	if not is_dead and _holds.has(act):
		var sh := _shape(act)
		if not sh.is_empty() and float(sh[2]) > 0.0:
			var top := float(sh[0]) * float(sh[1])
			var hold := float(sh[2])
			var u := (_heard_clock - top) / hold
			if u >= 0.0 and u <= 1.0:
				on = true
				var amp := (0.004 + 0.012 * u * u) * visual_scale
				var c := _heard_clock
				body.position.x = _body_rest_xz.x + amp * sin(c * 73.0) * cos(c * 21.0)
				body.position.z = _body_rest_xz.y + amp * sin(c * 61.0 + 1.3)
			if _strain_serial != act_serial and _heard_clock >= top + maxf(hold - 0.5, 0.0) \
					and _heard_clock < top + hold:
				_strain_serial = act_serial
				Sfx.play(self, STRAIN_SOUND, null, _weapon_tip_at(), 0.95, -6.0)
	if on:
		_trembling = true
	elif _trembling:
		_trembling = false
		body.position.x = _body_rest_xz.x
		body.position.z = _body_rest_xz.y


## A glint off the club's end — a hard white-gold flash and sparks — and a
## low growl.
func _glint() -> void:
	var tip := _weapon_tip_at()
	var into := Blood.world_of(self)
	SkillFx.particles(into, tip, {
		"amount": 26, "life": 0.45, "one_shot": true, "explosiveness": 1.0, "add": true,
		"speed": Vector2(1.5, 4.0), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3.ZERO,
		"damping": 5.0, "size": Vector2(0.12, 0.26), "grow": -0.6, "sphere": 0.08,
		"colors": [Color(1.0, 0.95, 0.75, 0.0), Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.55, 0.2, 0.0)],
	})
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.55)
	flash.omni_range = 3.0 * visual_scale
	flash.light_energy = 11.0
	flash.shadow_enabled = false
	into.add_child(flash)
	flash.global_position = tip
	var t := flash.create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_callback(flash.queue_free)
	Sfx.play_any(self, GRUNTS, self, 0.72, -2.0)


## Every peer: a leap's push off the ground — earth kicked back off its feet,
## a grunt, the ground felt.
var _took_off: int = -1


func _take_off() -> void:
	if not FLIGHTS.has(act) or is_dead or _took_off == act_serial or _anim == null:
		return
	if _heard_clock < _flight_span(act).x - 0.05:
		return
	_took_off = act_serial
	_sound_at(GRUNTS, global_position + Vector3.UP * 1.6 * visual_scale, 0.8, 0.0)
	_sound_at(CLUB_GROUND, global_position, 0.6, -8.0)
	var into := Blood.world_of(self)
	var back := -_forward()
	var s := visual_scale / 1.6
	for side: float in [-0.4, 0.4]:
		var at := global_position + back * 0.2 * s + _forward().cross(Vector3.UP) * side * s
		SkillFx.particles(into, at + Vector3.UP * 0.08, {
			"amount": 16, "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
			"speed": Vector2(1.0, 3.0), "dir": back + Vector3.UP * 0.8, "spread": 45.0, "gravity": Vector3(0, -4.0, 0),
			"damping": 1.2, "size": Vector2(0.2, 0.45), "grow": 0.5, "sphere": 0.25 * s,
			"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.5), Color(0.55, 0.5, 0.45, 0.0)],
		})
	WindBlast.shake(self, 0.06, 0.25, 10.0)


## Every peer: through a leap's flight the body is carried higher than the
## clip's own jump, an arc over the act clock; back on the ground after.
func _lift_in_flight() -> void:
	if body == null:
		return
	if FLIGHTS.has(act) and not is_dead and _anim != null:
		var span := _flight_span(act)
		var u := clampf((_heard_clock - span.x) / maxf(span.y - span.x, 0.05), 0.0, 1.0)
		# Up over the first 60 %, then brought down hard.
		var arc := sin(PI * 0.5 * u / 0.6) if u < 0.6 else cos(PI * 0.5 * (u - 0.6) / 0.4)
		body.position.y = _body_rest_y + float((FLIGHTS[act] as Array)[3]) * visual_scale / 1.6 * arc
		_lifted = true
	elif _lifted:
		_lifted = false
		if not is_dead:
			body.position.y = _body_rest_y


## Its walk, its trot, its run, by its pace (every peer sees the pace), each
## played at the rate its feet keep to the ground; anything else (sideways,
## back, standing) as any of the pack.
func _play_locomotion(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	if pace < 0.15 or trot_clip.is_empty() or planar.dot(_forward()) < pace * 0.6:
		super(delta)
		return
	var now := _anim.current_clip()
	var clip := walk_clip
	var to_trot := trot_above - (0.25 if now == trot_clip or now == run_clip else 0.0)
	var to_run := run_gait_above - (0.3 if now == run_clip else 0.0)
	if pace > to_run and not run_clip.is_empty():
		clip = run_clip
	elif pace > to_trot:
		clip = run_clip if runs_after and not run_clip.is_empty() else trot_clip
	_anim.play(clip, 0.25, gait_rate(clip, pace))


func _is_heavy(what: int) -> bool:
	if COMBO_MOVES.has(what):
		return bool(COMBO_MOVES[what][2])
	return what == HEAVY or what == STOMP or (SWINGS.has(what) and bool(SWINGS[what][2]))


func _on_new_act() -> void:
	if act == GETOFF:
		# its foot up: the grunt that says it is coming
		Sfx.play_any(self, GRUNTS, self, 0.8, 2.0)
	if act == RAGE:
		Sfx.play(self, ROAR_SOUND, self, Vector3.ZERO, 0.95, 2.0)
	elif act == TAUNT:
		Sfx.play_any(self, GRUNTS, self, 0.75, -4.0)
	elif act == STANCE:
		Sfx.play_any(self, GRUNTS, self, 0.8, -2.0)
	elif act == POUND or act == POUND_3 or act == HEAVY:
		Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 1.1, -6.0)
	elif act == LEAP_SLAM:
		# down into its crouch: the roar that says it is coming
		Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 0.95, -1.0)
	elif _is_heavy(act) and randf() < 0.45:
		Sfx.play_any(self, GRUNTS, self, 1.0, -7.0)


## A heavy blow come down: if the club is down by the ground, the ground
## takes it — the crack of it, earth and grit thrown up, the view shaken.
func _club_lands() -> void:
	var tip := _weapon_tip_at()
	if tip.y - global_position.y > 0.9 * visual_scale:
		return
	var at := Vector3(tip.x, global_position.y + 0.05, tip.z)
	_sound_at(CLUB_GROUND, at, 1.0, -2.0)
	var into := Blood.world_of(self)
	GroundFx.eruption(into, at, 0.55, false)
	WindBlast.shake(self, 0.07, 0.28, 12.0)


## Walking or running, each foot as it comes down: a deep step and a little
## dust off it, the view nudged when he is near.
func _footfalls() -> void:
	if _skeleton == null or _ankles.size() < 2:
		return
	var pace := Vector2(velocity.x, velocity.z).length()
	for k in 2:
		if _ankles[k] < 0:
			continue
		var foot := _skeleton.global_transform * _skeleton.get_bone_global_pose(_ankles[k]).origin
		var low := foot.y - global_position.y < 0.16 * visual_scale
		if low and not _foot_down[k] and pace > 0.6:
			var into := Blood.world_of(self)
			_sound_at(STEPS, foot, 0.92 if pace > run_gait_above else 1.0,
					-9.0 if pace < 3.0 else (-5.0 if pace < run_gait_above else -2.0))
			SkillFx.particles(into, Vector3(foot.x, global_position.y + 0.08, foot.z), {
				"amount": 5, "life": 0.8, "one_shot": true, "explosiveness": 0.9, "add": false,
				"speed": Vector2(0.3, 0.9), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
				"damping": 2.0, "size": Vector2(0.18, 0.35), "grow": 0.3, "sphere": 0.15,
				"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.3), Color(0.55, 0.5, 0.45, 0.0)],
			})
			if pace > 2.5:
				WindBlast.shake(self, 0.035 if pace > run_gait_above else 0.02, 0.15, 7.0)
		_foot_down[k] = low


func _sound_at(paths: Array, at: Vector3, pitch: float, volume_db: float) -> void:
	Sfx.play(self, String(paths[randi() % paths.size()]), null, at, pitch, volume_db)
#endregion
