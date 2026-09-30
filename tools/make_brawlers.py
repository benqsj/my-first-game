"""tools/make_brawlers.py — writes scenes/enemies/<key>.tscn for the creatures
and bosses built by vepxis-art tools/mon_build.py, one [Brawler] each.

    python3 tools/make_brawlers.py

Everything a creature is told lives in the table below: its clips, which of
its own bones do what, how big and how hard it is.
"""
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

C = {
    "minotaur": dict(node="Minotaur", h=3.2, r=0.75, boss=True, health=900, dmg=55, reach=2.8, sight=18,
                     speed=1.5, chase=3.6, run_above=2.6, hips="pelvis", feet=("foot_l", "foot_r"),
                     idle="MN_idle", walk="MN_walk_forward", run="MN_run", back="MN_walk_back",
                     strafe=("MN_walk_strafe_left45", "MN_walk_strafe_right45"),
                     attacks=["MN_attack1", "MN_attack2", "MN_attack3"],
                     big=["MN_attack4_kick", "MN_attack5_kick"], big_reach=4.0,
                     hit="MN_hit_1", death="MN_death", weapon="hand_r", tip=(0, 0.6, 0), wr=0.45,
                     strike=["hand_r"], pdef=40, mdef=20),
    # The demon on the minotaur's own clips (the same mannequin names):
    # its digitigrade legs sit better in a beast's stance than in Mixamo's.
    "demon": dict(node="Demon", h=2.5, r=0.55, boss=False, health=420, dmg=38, reach=2.3, sight=15,
                  speed=1.4, chase=3.4, run_above=2.6, hips="pelvis", feet=("foot_l", "foot_r"),
                  idle="DM_idle", walk="DM_walk_forward", run="DM_run", back="DM_walk_back",
                  strafe=("DM_walk_strafe_left45", "DM_walk_strafe_right45"),
                  attacks=["DM_attack1", "DM_attack2", "DM_attack3"], big=["DM_attack4_kick"], big_reach=3.6,
                  hit="DM_hit_1", death="DM_death", weapon="hand_r", tip=(0, 0.5, 0), wr=0.35,
                  strike=["hand_r"], pdef=30, mdef=15),
    "frog": dict(node="Frog", h=1.5, r=0.4, boss=False, health=140, dmg=16, reach=1.6, sight=12,
                 speed=1.3, chase=2.9, run_above=2.4, hips="Hips", feet=("LeftFoot", "RightFoot"),
                 idle="FR_Idle", walk="FR_Walk", run="FR_Run", strafe=("FR_StrafeL", "FR_StrafeR"),
                 attacks=["FR_Cut1", "FR_Cut2", "FR_Cut3", "FR_Combo"],
                 hit="FR_Hit", death="FR_Death", weapon="RightHand", tip=(0, 0.25, 0), wr=0.25,
                 strike=["RightHand"], pdef=15, mdef=10),
    "ogre": dict(node="Ogre", h=2.8, r=0.8, boss=False, health=520, dmg=42, reach=2.4, sight=14,
                 speed=1.2, chase=3.0, run_above=2.6, hips="DEF-spine", feet=("DEF-foot.L", "DEF-foot.R"),
                 idle="OG_Idle", walk="OG_Walk", run="OG_Run", strafe=("OG_StrafeL", "OG_StrafeR"),
                 attacks=["OG_Punch", "OG_SwipeL", "OG_SwipeR", "OG_Slam"], roar="OG_Thump",
                 hit="OG_Hit", death="OG_Death", weapon="DEF-hand.R", tip=(0, 0.1, 0), wr=0.4,
                 strike=["DEF-hand.R", "DEF-hand.L"], pdef=25, mdef=10),
    "dark_knight": dict(node="DarkKnight", h=2.3, r=0.55, boss=True, health=950, dmg=55, reach=2.6, sight=18,
                        speed=1.4, chase=3.8, run_above=2.8, hips="pelvis", feet=("foot_l", "foot_r"),
                        idle="DK_Idle", walk="DK_Walk", run="DK_Run", back="DK_Back",
                        strafe=("DK_StrafeL", "DK_StrafeR"),
                        attacks=["DK_Combo", "DK_Power", "DK_High", "DK_Cross"], big=["DK_Jump"], big_reach=6.0,
                        hit="DK_Hit", death="DK_Death", weapon="hand_r", tip=(0, 0.6, 0), wr=0.45,
                        strike=["hand_r"], pdef=45, mdef=25),
    "centaur": dict(node="Centaur", h=2.7, r=0.9, boss=True, health=800, dmg=50, reach=3.2, sight=18,
                    speed=1.8, chase=4.2, run_above=3.0, hips="Hip", feet=("r_hoof.L", "r_hoof.R"),
                    idle="CT_Idle1", guard="CT_Battle_Idle", walk="CT_Walk1", run="CT_Run",
                    attacks=["CT_Attack1", "CT_Attack2", "CT_Attack3"], roar="CT_Bat_Idle_Trick",
                    hit="CT_Hit1", death="CT_Death1", weapon="weapon_bone", tip=(0, 1.2, 0), wr=0.5,
                    strike=["weapon_bone"], pdef=35, mdef=25),
    "dragon_terror": dict(node="DragonTerror", h=4.2, r=1.6, boss=True, health=1600, dmg=70, reach=4.5,
                          sight=24, speed=1.6, chase=4.5, run_above=3.2, hips="Root",
                          feet=("Toe1_L", "Toe1_L.001"), idle="DT_Idle01", walk="DT_Walk", run="DT_Run",
                          attacks=["DT_BasicAttack", "DT_Attackwingclaw"], big=["DT_FlameAttack"],
                          big_reach=10.0, roar="DT_Scream", hit="DT_Gethit", death="DT_Die",
                          weapon="Head", tip=(0, 0.8, 0), wr=0.9, strike=["Head"], pdef=50, mdef=35),
    "dragon_nightmare": dict(node="DragonNightmare", h=3.4, r=1.4, boss=True, health=1300, dmg=60, reach=4.0,
                             sight=22, speed=1.6, chase=4.4, run_above=3.2, hips="Root",
                             feet=("L_Toe_Middle01", "R_Toe_Middle01"), idle="DN_Idle01", walk="DN_Walk",
                             run="DN_Run", back="DN_Walkback", strafe=("DN_Walkleft", "DN_Walkright"),
                             attacks=["DN_BasicAttack", "DN_ClawAttack", "DN_HornAttack"], roar="DN_Scream",
                             hit="DN_Gethit", death="DN_Die", weapon="Head", tip=(0, 0.8, 0), wr=0.8,
                             strike=["Head"], pdef=45, mdef=30),
    "dragon_usurper": dict(node="DragonUsurper", h=3.6, r=1.5, boss=True, health=1400, dmg=65, reach=4.2,
                           sight=22, speed=1.6, chase=4.4, run_above=3.2, hips="Root",
                           feet=("MiddleToe01_L", "MiddleToe01_R"), idle="DU_Idle01", walk="DU_Walk",
                           run="DU_Run", attacks=["DU_Attackmouth", "DU_Attackhand"], big=["DU_Attackflame"],
                           big_reach=10.0, roar="DU_Scream", hit="DU_Gethit", death="DU_Die",
                           weapon="Head", tip=(0, 0.8, 0), wr=0.8, strike=["Head"], pdef=45, mdef=30),
    "dragon_souleater": dict(node="DragonSoulEater", h=3.4, r=1.4, boss=True, health=1300, dmg=60, reach=4.0,
                             sight=22, speed=1.6, chase=4.4, run_above=3.2, hips="Root_Pelvis",
                             feet=("Toe_Left", "Toe_Right"), idle="DS_Idle", walk="DS_Walk", run="DS_Run",
                             attacks=["DS_BasicAttack", "DS_TailAttack"], big=["DS_FireballShoot"],
                             big_reach=10.0, roar="DS_Scream", hit="DS_GetHit", death="DS_Die",
                             weapon="Head", tip=(0, 0.8, 0), wr=0.8, strike=["Head", "Tail03"], pdef=45, mdef=30),
}

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


def scene(key, c):
    loops = [c["idle"], c["walk"], c["run"]] + list(c.get("strafe", ())) + ([c["back"]] if c.get("back") else []) \
        + ([c["guard"]] if c.get("guard") else [])
    lines = [
        '[gd_scene load_steps=6 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/brawler.gd" id="1_fighter"]',
        '[ext_resource type="PackedScene" path="res://assets/monsters/%s/%s.glb" id="2_model"]' % (key, key),
        '[ext_resource type="Script" path="res://scripts/net_smooth.gd" id="net_smooth"]', '',
        '[sub_resource type="CapsuleShape3D" id="Capsule_body"]',
        'radius = %s' % c["r"], 'height = %s' % max(c["h"] * 0.8, c["r"] * 2 + 0.1), '',
        '[sub_resource type="SceneReplicationConfig" id="Repl_body"]', REPL, '',
        '[node name="%s" type="CharacterBody3D" groups=["enemy"]]' % c["node"],
        'collision_layer = 4', 'collision_mask = 7', 'script = ExtResource("1_fighter")',
        'speed = %s' % c["speed"], 'roam_radius = 3.0', 'rest_time = 2.4',
        'step_height = %s' % round(0.4 * max(c["h"] / 1.8, 1.0), 2),
        'walk_clip = &"%s"' % c["walk"], 'idle_clip = &"%s"' % c["idle"], 'fidget_clip = &"%s"' % c["idle"],
        'fidget_interval = 0.0',
        'clip_source = "res://assets/monsters/%s/%s.glb"' % (key, key),
        'loop_clips = %s' % psa(loops),
        'settle_on_ground = false',
        'hips_bone = "%s"' % c["hips"], 'foot_bones = %s' % psa(c["feet"]),
        'sight_range = %s' % c["sight"], 'leash_radius = %s' % (c["sight"] * 2.5),
        'chase_speed = %s' % c["chase"], 'chase_retime_max = 2.2',
        'max_health = %s' % c["health"], 'bar_height = %s' % round(c["h"] * 1.08, 2),
        'body_radius = %s' % round(c["r"] * 0.9, 2), 'body_height = %s' % round(c["h"] * 0.85, 2),
        'max_stamina = %s' % (200 if c["boss"] else 120), 'block_chance = 0.0', 'dash_chance = 0.0',
        'p_def = %s' % c["pdef"], 'm_def = %s' % c["mdef"],
        'reach = %s' % c["reach"], 'hit_damage = %s' % c["dmg"],
        'attack_cooldown = Vector2(%s, %s)' % ((1.2, 2.6) if c["boss"] else (1.5, 3.0)),
        'attack_clip = &"%s"' % c["attacks"][0], 'block_clip = &"%s"' % c["hit"], 'dash_clip = &"%s"' % c["hit"],
        'break_clip = &"%s"' % c["hit"], 'death_clip = &"%s"' % c["death"],
        'guard_idle_clip = &"%s"' % c.get("guard", c["idle"]), 'dies_by_clip = true',
        'clip_meta = "res://assets/monsters/%s/%s_clip_meta.json"' % (key, key),
        'run_clip = &"%s"' % c["run"], 'run_above = %s' % c["run_above"],
        'weapon_tip = Vector3(%s, %s, %s)' % c["tip"], 'weapon_radius = %s' % c["wr"],
        'strike_off = %s' % round(c["reach"] * 0.6, 2), 'close_speed = %s' % c["chase"],
        'attacks = %s' % arr(c["attacks"]),
        'strike_bones = %s' % psa(c["strike"]), 'weapon_bone = &"%s"' % c["weapon"],
        'hit_clip = &"%s"' % c["hit"],
    ]
    if c.get("strafe"):
        lines += ['strafe_l_clip = &"%s"' % c["strafe"][0], 'strafe_r_clip = &"%s"' % c["strafe"][1]]
    if c.get("back"):
        lines += ['back_clip = &"%s"' % c["back"]]
    if c.get("big"):
        lines += ['big_attacks = %s' % arr(c["big"]), 'big_reach = %s' % c["big_reach"]]
    if c.get("roar"):
        lines += ['roar_clip = &"%s"' % c["roar"]]
    lines += [
        '', '[node name="CollisionShape3D" type="CollisionShape3D" parent="."]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)' % round(max(c["h"] * 0.4, c["r"] + 0.05), 3),
        'shape = SubResource("Capsule_body")', '',
        '[node name="Visuals" type="Node3D" parent="."]',
        'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)', '',
        '[node name="Model" parent="Visuals" instance=ExtResource("2_model")]', '',
        '[node name="Body" type="MultiplayerSynchronizer" parent="."]',
        'replication_interval = 0.033', 'replication_config = SubResource("Repl_body")', '',
        '[node name="NetSmooth" type="Node" parent="."]', 'script = ExtResource("net_smooth")', '']
    return "\n".join(lines)


for key, c in C.items():
    path = os.path.join(HERE, "scenes/enemies/%s.tscn" % key)
    open(path, "w").write(scene(key, c))
    print("wrote", path)
