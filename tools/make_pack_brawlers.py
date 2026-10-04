"""tools/make_pack_brawlers.py — writes scenes/enemies/pack/<kind>.tscn, one
[Brawler] for each fighting creature of Polysplit's Biped Creatures pack
(CREATURES_PACK.md), on the clips baked onto the pack's shared skeleton by
tools/creature_clips.gd.

    python3 tools/make_pack_brawlers.py

Everything a creature is told lives in the table below: the pack's FBX and
colours, its size against the heroes (CREATURES_PACK.md §6), its clips, what
lands each attack (Brawler.attack_limbs: "" is the weapon in its right fist),
and how hard and quick it is.
"""
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

R_FIST = "R_elbow_joint>R_midFinger_joint3:0.12"
L_FIST = "L_elbow_joint>L_midFinger_joint3:0.12"
FISTS = L_FIST + "|" + R_FIST
KICK = "R_knee_joint>R_toe_joint:0.12"
BITE = "head_joint>head_joint@0.11,0.13,0:0.2"
SHIELD = "L_wrist_joint>L_equip_joint@0,0.1,0:0.32"
WEAPON = ""

# Shared by every one: they keep at it under a string of cuts
# (README, "Fighting back while being cut").
COMMON = dict(hit_cost=0.0, attack_cost=10.0, regen_delay=0.5, stamina_regen=30.0,
              strike_at_reach=True, steady_in_attack=True, blows_to_fell=3, cooldown=(0.15, 0.5),
              block=0.0, dash=0.0, counter=0.0, min_speed=2.0, roam=3.0)

# attacks: [clip, rate, to (share of the clip played), limb, blows]
C = {
    "skeleton": dict(node="Skeleton", fbx="Skeleton_Base", s=0.95, body="Body_Skeleton", objects="Objects",
                     idle="CR_ZombieIdle", guard="CR_ZombieIdle", walk="CR_ZombieWalk", run="CR_ZombieRun",
                     run_above=2.2, fidget="CR_ZombieScratch", speed=1.4, chase=4.0, health=110, dmg=16,
                     pdef=12, mdef=5, sight=12, hit="CR_Hit", death="CR_Death2", too_close=0.12, min_speed=0.8,
                     weapon=("R_wrist_joint", (0.12, 0, 0), 0.18), strike=["R_wrist_joint", "L_wrist_joint"],
                     attacks=[["CR_Punch1", 1.25, 0.88, R_FIST, 1], ["CR_PunchL", 1.25, 0.88, L_FIST, 1],
                              ["CR_PunchCombo", 1.2, 0.92, FISTS, 2], ["CR_Hook", 1.1, 0.95, FISTS, 1],
                              ["CR_Uppercut", 1.2, 0.9, FISTS, 1], ["CR_Kick", 1.2, 0.9, KICK, 1],
                              ["CR_ZombieBite", 1.2, 0.9, BITE, 1]]),
    "skeleton_warrior": dict(node="SkeletonWarrior", fbx="Skeleton_Warrior", s=0.95, body="Body_Skeleton",
                             objects="Objects_SkelWarrior", idle="CR_Idle", guard="CR_ShieldIdle", walk="CR_Walk",
                             run="CR_Run", run_above=2.6, strafe=("CR_StrafeL", "CR_StrafeR"), back="CR_WalkBack",
                             speed=1.7, chase=4.4, health=200, dmg=24, pdef=30, mdef=10, sight=14,
                             hit="CR_Hit", death="CR_Death", block=0.25, block_clip="CR_BlockHit", dash=0.1,
                             counter=0.3, too_close=0.35, block_cost=20.0,
                             weapon=("R_equip_joint", (1.15, 0, 0), 0.12), strike=["R_wrist_joint"],
                             attacks=[["CR_Slash1", 1.25, 0.88, WEAPON, 1], ["CR_Slash2", 1.25, 0.85, WEAPON, 1],
                                      ["CR_Slash3", 1.25, 0.85, WEAPON, 1], ["CR_Slash4", 1.25, 0.88, WEAPON, 1],
                                      ["CR_ShieldBash", 1.25, 0.9, SHIELD, 1]]),
    # A falchion, armour on the shoulders and legs; cuts, a three-cut combo, a kick.
    "orc": dict(node="Orc", fbx="Orc", s=1.1, body="Body_Orc", objects="Objects_Orc",
                idle="CR_Idle", guard="CR_CombatIdle", walk="CR_Walk", run="CR_Run", run_above=2.8,
                strafe=("CR_StrafeL", "CR_StrafeR"), back="CR_WalkBack",
                speed=1.6, chase=4.4, health=260, dmg=26, pdef=25, mdef=10, sight=15,
                hit="CR_Hit", death="CR_Death3", dash=0.1, too_close=0.35,
                weapon=("R_equip_joint", (1.1, 0, 0), 0.12), strike=["R_wrist_joint"],
                attacks=[["CR_Slash1", 1.25, 0.88, WEAPON, 1], ["CR_Slash2", 1.25, 0.85, WEAPON, 1],
                         ["CR_Slash3", 1.25, 0.85, WEAPON, 1], ["CR_Slash4", 1.25, 0.88, WEAPON, 1],
                         ["CR_SwordCombo", 1.2, 0.9, WEAPON, 3], ["CR_Kick", 1.2, 0.9, KICK, 1]]),
    # Small and quick, a club; darts aside.
    "goblin": dict(node="Goblin", fbx="Goblin", s=0.65, body="Body_Goblin", objects="Objects_Goblin",
                   idle="CR_CombatIdle", guard="CR_CombatIdle", walk="CR_Walk", run="CR_Sprint", run_above=3.0,
                   strafe=("CR_StrafeL", "CR_StrafeR"), back="CR_WalkBack",
                   speed=2.2, chase=5.4, health=70, dmg=11, pdef=8, mdef=5, sight=14,
                   hit="CR_Hit", death="CR_Death2", dash=0.25, too_close=0.2, cooldown=(0.1, 0.35),
                   weapon=("R_equip_joint", (0.66, 0, 0), 0.1), strike=["R_wrist_joint"],
                   attacks=[["CR_Slash1", 1.45, 0.85, WEAPON, 1], ["CR_Slash2", 1.45, 0.85, WEAPON, 1],
                            ["CR_Slash5", 1.45, 0.85, WEAPON, 1], ["CR_Kick", 1.4, 0.85, KICK, 1]]),
    # Big and heavy: a great club in both hands, a ground slam; each blow fells.
    "ogre": dict(node="Ogre", fbx="Ogre", s=1.6, body="Body_Ogre", objects="Objects_Ogre",
                 idle="CR_HeavyIdle", guard="CR_HeavyIdle", walk="CR_Walk", run="CR_Run", run_above=3.0,
                 speed=1.5, chase=3.8, health=520, dmg=42, pdef=35, mdef=10, sight=16,
                 hit="CR_Hit2", death="CR_Death4", too_close=0.4, cooldown=(0.4, 1.0), min_speed=1.2,
                 weapon=("R_equip_joint", (0.92, 0, 0), 0.18), strike=["R_wrist_joint"],
                 attacks=[["CR_Heavy1", 1.05, 0.9, WEAPON, 1], ["CR_Heavy2", 1.05, 0.9, WEAPON, 1],
                          ["CR_Heavy3", 1.05, 0.9, WEAPON, 1], ["CR_Heavy4", 1.05, 0.9, WEAPON, 1],
                          ["CR_GroundPound", 1.0, 0.92, WEAPON, 1]]),
    # Big, empty-handed: fists, a slam with both, a kick.
    "troll": dict(node="Troll", fbx="Troll", s=1.6, body="Body_Troll", objects="Objects",
                  idle="CR_IdleWounded", guard="CR_CombatIdle", walk="CR_Walk", run="CR_Run", run_above=3.0,
                  speed=1.5, chase=3.8, health=450, dmg=38, pdef=25, mdef=15, sight=15,
                  hit="CR_Hit2", death="CR_Death", too_close=0.3, cooldown=(0.3, 0.8),
                  weapon=("R_wrist_joint", (0.12, 0, 0), 0.2), strike=["R_wrist_joint", "L_wrist_joint"],
                  attacks=[["CR_Punch1", 1.15, 0.88, R_FIST, 1], ["CR_PunchL", 1.15, 0.88, L_FIST, 1],
                           ["CR_Hook", 1.05, 0.95, FISTS, 1], ["CR_Uppercut", 1.1, 0.9, FISTS, 1],
                           ["CR_GroundPound", 1.0, 0.92, FISTS, 1], ["CR_Kick", 1.1, 0.9, KICK, 1]]),
    # Lean and fast: claws, a bite; darts aside.
    "ghoul": dict(node="Ghoul", fbx="Ghoul", s=0.95, body="Body_Ghoul", objects="Objects",
                  idle="CR_ZombieIdle", guard="CR_ZombieIdle", walk="CR_Walk", run="CR_ZombieRun", run_above=2.6,
                  speed=1.8, chase=5.4, health=120, dmg=16, pdef=10, mdef=10, sight=15,
                  hit="CR_Hit", death="CR_Death2", dash=0.2, too_close=0.12, min_speed=0.8, cooldown=(0.1, 0.35),
                  weapon=("R_wrist_joint", (0.12, 0, 0), 0.16), strike=["R_wrist_joint", "L_wrist_joint"],
                  attacks=[["CR_ZombieScratch", 1.4, 0.9, FISTS, 1], ["CR_Hook", 1.2, 0.95, FISTS, 1],
                           ["CR_PunchL", 1.35, 0.88, L_FIST, 1], ["CR_PunchCombo", 1.3, 0.92, FISTS, 2],
                           ["CR_ZombieBite", 1.3, 0.9, BITE, 1]]),
    # Stone: slow, enormous fists, a slam; hard to hurt.
    "golem": dict(node="Golem", fbx="Golem", s=1.8, body="Body_Golem", objects="Objects",
                  idle="CR_CombatIdle", guard="CR_CombatIdle", walk="CR_Walk", run="CR_Run", run_above=3.2,
                  speed=1.2, chase=3.2, health=800, dmg=55, pdef=60, mdef=20, sight=14,
                  hit="CR_Hit2", death="CR_Death4", too_close=0.4, cooldown=(0.5, 1.2), min_speed=1.2,
                  weapon=("R_wrist_joint", (0.12, 0, 0), 0.24),
                  strike=["R_wrist_joint", "L_wrist_joint"],
                  attacks=[["CR_Punch1", 0.95, 0.88, R_FIST.replace(":0.12", ":0.16"), 1],
                           ["CR_Hook", 0.95, 0.95, FISTS.replace(":0.12", ":0.16"), 1],
                           ["CR_Uppercut", 0.95, 0.9, FISTS.replace(":0.12", ":0.16"), 1],
                           ["CR_GroundPound", 0.9, 0.92, FISTS.replace(":0.12", ":0.16"), 1]]),
    "zombie_m": dict(node="ZombieMan", fbx="Zombie_M", s=0.95, body="Body_Zombie", objects="Objects_Zombie",
                     idle="CR_ZombieIdle", guard="CR_ZombieIdle", walk="CR_ZombieWalk", run="CR_ZombieRun",
                     run_above=2.2, fidget="CR_ZombieIdle", speed=0.9, chase=2.8, health=140, dmg=16,
                     pdef=8, mdef=5, sight=11, hit="CR_Hit", death="CR_Death2", too_close=0.12, min_speed=0.8,
                     cooldown=(0.4, 1.0), weapon=("R_wrist_joint", (0.12, 0, 0), 0.16),
                     strike=["R_wrist_joint", "L_wrist_joint"],
                     attacks=[["CR_ZombieScratch", 1.2, 0.9, FISTS, 1], ["CR_ZombieBite", 1.15, 0.9, BITE, 1],
                              ["CR_PunchCombo", 1.1, 0.92, FISTS, 2], ["CR_Hook", 1.0, 0.95, FISTS, 1]]),
}
C["zombie_f"] = dict(C["zombie_m"], node="ZombieWoman", fbx="Zombie_F")
# Keeps a spell's length off: bolts, a burst under his feet, a blast to drive
# him off up close, the staff, and the dead raised ([MageFighter]).
C["skeleton_mage"] = dict(node="SkeletonMage", fbx="Skeleton_Mage", s=0.95, body="Body_Skeleton",
                          objects="Objects_SkelMage", script="res://scripts/mage_fighter.gd",
                          idle="CR_MG_Idle", guard="CR_MG_Idle", walk="CR_MG_Walk", run="CR_MG_Run", run_above=2.8,
                          strafe=("CR_MG_WalkL", "CR_MG_WalkR"), back="CR_MG_WalkBack",
                          speed=1.5, chase=3.2, health=120, dmg=22, pdef=8, mdef=30, sight=24,
                          hit="CR_MG_Hit", death="CR_MG_Death", too_close=0.3, cooldown=(0.5, 1.1),
                          weapon=("R_equip_joint", (-0.9, 0, 0), 0.1), strike=["R_wrist_joint"],
                          attacks=[["CR_Staff1", 1.25, 0.9, WEAPON, 1], ["CR_Staff2", 1.25, 0.9, WEAPON, 1]])
# Keeps its distance: shoots from afar, runs from him when he comes close,
# turns and shoots, runs again ([BowFighter], scripts/bow_fighter.gd).
C["skeleton_archer"] = dict(node="SkeletonArcher", fbx="Skeleton_Archer", s=0.95, body="Body_Skeleton",
                            objects="Objects_SkelArcher", script="res://scripts/bow_fighter.gd",
                            idle="CR_Idle", guard="CR_CombatIdle", walk="CR_Walk", run="CR_Run", run_above=2.6,
                            strafe=("CR_StrafeL", "CR_StrafeR"), back="CR_WalkBack",
                            speed=1.6, chase=4.8, health=110, dmg=18, pdef=10, mdef=10, sight=26,
                            hit="CR_Hit", death="CR_Death", too_close=0.0, cooldown=(0.35, 0.8),
                            weapon=("R_wrist_joint", (0.12, 0, 0), 0.12), strike=["R_wrist_joint"], attacks=[],
                            extra=['shot_rate = 1.3', 'shoot_range = 24.0', 'flee_under = 6.0', 'keep_away = 11.0',
                                   'flee_time = 1.7', 'arrow_speed = 34.0'])

REPL = "\n".join(
    "properties/%d/path = NodePath(\"%s\")\nproperties/%d/spawn = true\nproperties/%d/replication_mode = %d"
    % (i, p, i, i, m) for i, (p, m) in enumerate([
        ("NetSmooth:net_position", 1), ("NetSmooth:net_rotation", 1), (".:velocity", 1), (".:health", 1),
        (".:stamina", 1), (".:is_dead", 1), (".:mode", 2), (".:act", 2), (".:act_serial", 2),
        ("NetSmooth:net_stamp", 1)]))


def arr(names):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % n for n in names)


def psa(names):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % n for n in names)


def r2(x):
    return round(x, 3)


def scene(c):
    c = dict(COMMON, **c)
    s = c["s"]
    loops = [c["idle"], c["guard"], c["walk"], c["run"]] + list(c.get("strafe", ())) + ([c["back"]] if c.get("back") else [])
    loops = list(dict.fromkeys(loops))
    atk = c["attacks"]
    strike_off = 1.5 * s
    L = [
        '[gd_scene load_steps=7 format=3]', '',
        '[ext_resource type="Script" path="%s" id="1_fighter"]' % c.get("script", "res://scripts/brawler.gd"),
        '[ext_resource type="PackedScene" path="res://assets/creatures/%s.fbx" id="2_model"]' % c["fbx"],
        '[ext_resource type="Script" path="res://scripts/net_smooth.gd" id="net_smooth"]',
        '[ext_resource type="Script" path="res://scripts/pack_dress.gd" id="4_dress"]', '',
        '[sub_resource type="CapsuleShape3D" id="Capsule_body"]', 'radius = %s' % r2(0.4 * s), 'height = %s' % r2(1.8 * s), '',
        '[sub_resource type="SceneReplicationConfig" id="Repl_body"]', REPL, '',
        '[node name="%s" type="CharacterBody3D" groups=["enemy"]]' % c["node"],
        'collision_layer = 4', 'collision_mask = 7', 'script = ExtResource("1_fighter")',
        'speed = %s' % c["speed"], 'roam_radius = %s' % c["roam"], 'rest_time = 2.4', 'step_height = %s' % r2(0.4 * max(s, 1.0)),
        'walk_clip = &"%s"' % c["walk"], 'idle_clip = &"%s"' % c["idle"],
        'fidget_clip = &"%s"' % c.get("fidget", c["idle"]), 'fidget_interval = %s' % (9.0 if c.get("fidget") else 0.0),
        'loop_clips = %s' % psa(loops),
        'sight_range = %s' % c["sight"], 'leash_radius = %s' % (c["sight"] * 2.5),
        'chase_speed = %s' % c["chase"], 'chase_retime_max = 2.4',
        'max_health = %s' % c["health"], 'bar_height = %s' % r2(2.25 * s), 'body_radius = %s' % r2(0.36 * s),
        'body_height = %s' % r2(1.85 * s), 'max_stamina = 100',
        'block_chance = %s' % c["block"], 'dash_chance = %s' % c["dash"],
        'p_def = %s' % c["pdef"], 'm_def = %s' % c["mdef"],
        'reach = %s' % r2(strike_off + 0.6), 'hit_damage = %s' % c["dmg"],
        'attack_cooldown = Vector2(%s, %s)' % c["cooldown"],
        'attack_clip = &"%s"' % (atk[0][0] if atk else c["idle"]),
        'block_clip = &"%s"' % c.get("block_clip", c["hit"]), 'dash_clip = &"CR_Dodge"', 'break_clip = &"%s"' % c["hit"],
        'death_clip = &"%s"' % c["death"], 'guard_idle_clip = &"%s"' % c["guard"], 'dies_by_clip = true',
        'clip_source = "res://assets/creatures/anim/biped_clips.scn"',
        'clip_meta = "res://assets/creatures/anim/biped_clip_meta.json"',
        'settle_on_ground = false', 'hips_bone = "pelvis_joint"', 'foot_bones = %s' % psa(["L_ankle_joint", "R_ankle_joint"]),
        'visual_scale = %s' % s,
        'run_clip = &"%s"' % c["run"], 'run_above = %s' % c["run_above"],
        'strike_off = %s' % r2(strike_off), 'close_speed = %s' % c["chase"],
        'weapon_bone = &"%s"' % c["weapon"][0], 'weapon_tip = Vector3(%s, %s, %s)' % c["weapon"][1],
        'weapon_radius = %s' % c["weapon"][2], 'strike_bones = %s' % psa(c["strike"]),
        'hit_clip = &"%s"' % c["hit"],
        'attacks = %s' % arr([a[0] for a in atk]),
        'attack_parts = Array[Vector3]([%s])' % ", ".join("Vector3(%s, 0, %s)" % (a[1], a[2]) for a in atk),
        'attack_limbs = %s' % psa([a[3] for a in atk]),
        'attack_blows = PackedInt32Array(%s)' % ", ".join(str(a[4]) for a in atk),
        'strike_at_reach = %s' % str(c["strike_at_reach"] and bool(atk)).lower(), 'blows_to_fell = %s' % c["blows_to_fell"],
        'too_close = %s' % c["too_close"], 'steady_in_attack = %s' % str(c["steady_in_attack"]).lower(),
        'hit_cost = %s' % c["hit_cost"], 'attack_cost = %s' % c["attack_cost"],
        'regen_delay = %s' % c["regen_delay"], 'stamina_regen = %s' % c["stamina_regen"],
        'blow_min_speed = %s' % c["min_speed"],
    ]
    if c.get("strafe"):
        L += ['strafe_l_clip = &"%s"' % c["strafe"][0], 'strafe_r_clip = &"%s"' % c["strafe"][1]]
    if c.get("back"):
        L += ['back_clip = &"%s"' % c["back"]]
    L += c.get("extra", [])
    if c["counter"] > 0:
        L += ['counter_after = %s' % c["counter"]]
    if c.get("block_cost"):
        L += ['block_cost = %s' % c["block_cost"]]
    L += [
        '', '[node name="CollisionShape3D" type="CollisionShape3D" parent="."]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)' % r2(0.9 * s), 'shape = SubResource("Capsule_body")', '',
        '[node name="Visuals" type="Node3D" parent="."]', 'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)', '',
        '[node name="Model" parent="Visuals" instance=ExtResource("2_model")]', '',
        '[node name="Dress" type="Node" parent="Visuals"]', 'script = ExtResource("4_dress")',
        'body = "%s"' % c["body"], 'objects = "%s"' % c["objects"], '',
        '[node name="Body" type="MultiplayerSynchronizer" parent="."]', 'replication_interval = 0.033',
        'replication_config = SubResource("Repl_body")', '',
        '[node name="NetSmooth" type="Node" parent="."]', 'script = ExtResource("net_smooth")', '']
    return "\n".join(L)


os.makedirs(os.path.join(HERE, "scenes/enemies/pack"), exist_ok=True)
for key, c in C.items():
    path = os.path.join(HERE, "scenes/enemies/pack/%s.tscn" % key)
    open(path, "w").write(scene(c))
    print("wrote", path)
