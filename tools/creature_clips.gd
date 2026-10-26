extends SceneTree

## tools/creature_clips.gd — the mannequin's clips (UAL 2's and Kevin's) baked
## onto Polysplit's 99-bone skeleton, the one all thirteen Biped Creatures
## share (CREATURES_PACK.md §5), so any of them plays them as its own.
##
##   godot --headless --path . --script res://tools/creature_clips.gd
##
## Out: assets/creatures/anim/biped_clips.scn (the bare skeleton and an
## AnimationPlayer holding every clip, for [SkeletonAnim] as `clip_source`)
## and biped_clip_meta.json (how far the hips travel in each, for
## [ClipFighter]).
##
## Each figure bone is turned in the world as its partner on the mannequin
## has turned from rest, after its rest has been turned to point the way the
## partner's does (both rests are T-poses facing +Z, a few degrees apart):
##   global = pose · rest_src⁻¹ · align · rest_fig
## Bones with no partner (hair, cape, coat tails, the equip and bow bones)
## ride their parents at rest. The hips are carried as well, by the
## mannequin's hip travel scaled to the figure's height; what the root carries
## across the ground is taken out (the clips are in place) and goes to the
## meta instead, [forward, left] in metres at the figure's size.

const MQ := "res://assets/anim/lab/ual2_mannequin.glb"
const KV := "res://assets/anim/lab/kevin_lib.res"
## DoubleL's RPG Animations Pack (the free one, 2026-10-25): its heavy
## blows (the user: a lean after each, a slow way back, as Elden Ring's), on
## the mannequin by vepxis-art tools/dl_godot.gd.
const DL := "res://assets/anim/lab/doublel_lib.res"
## The mage hero's own clips on the mannequin (casts, the staff held).
const MAGE := "res://assets/anim/heroes/mage_mannequin.res"
## Tariel's own sword-and-shield clips on the mannequin (the orc's hilt blow,
## its flourish, its cross cut, 2026-10-13).
const TARIEL := "res://assets/anim/heroes/tariel_mannequin.res"
const FIG := "res://assets/creatures/Skeleton_Base.fbx"
const OUT := "res://assets/creatures/anim/biped_clips.scn"
const META := "res://assets/creatures/anim/biped_clip_meta.json"
const FPS := 30.0

## [name here, clip on the mannequin, a cycle]
const CLIPS := [
	["CR_Idle", "KV_Idle01", true],
	["CR_CombatIdle", "KV_CombatIdle1H01", true],
	["CR_ShieldIdle", "Idle_Shield", true],
	["CR_Walk", "KV_Walk01_Forward", true],
	["CR_WalkBack", "KV_Walk01_Backward", true],
	["CR_StrafeL", "KV_StrafeWalk01_Left", true],
	["CR_StrafeR", "KV_StrafeWalk01_Right", true],
	["CR_Run", "KV_Run01_Forward", true],
	["CR_Slash1", "KV_Attack1H01_R", false],
	["CR_Slash2", "KV_Attack1H02_R", false],
	["CR_Slash3", "KV_Attack1H03_R", false],
	["CR_Slash4", "KV_Attack1H04_R", false],
	["CR_Slash5", "KV_Attack1H05_R", false],
	["CR_ShieldBash", "KV_AttackShield01", false],
	["CR_ShieldBash2", "KV_AttackShield02", false],
	["CR_ShieldDash", "Shield_Dash", false],
	["CR_Block", "KV_BlockShield01_Loop", true],
	["CR_BlockHit", "KV_BlockShield01_Hit", false],
	["CR_Hit", "KV_CombatDamage01", false],
	["CR_Hit2", "KV_CombatDamage02", false],
	["CR_Stun", "KV_Stun01", false],
	["CR_Death", "KV_CombatDeath01", false],
	["CR_Death2", "KV_CombatDeath02", false],
	["CR_Dodge", "KV_Dodge01", false],
	["CR_Punch1", "KV_AttackPunch01_R", false],
	["CR_Punch2", "KV_AttackPunch03_R", false],
	["CR_Kick", "KV_AttackKick01_R", false],
	["CR_PunchL", "KV_AttackPunch01_L", false],
	["CR_Heavy1", "KV_Attack2H01", false],
	["CR_Heavy2", "KV_Attack2H02", false],
	["CR_Heavy3", "KV_Attack2H03", false],
	["CR_Heavy4", "KV_Attack2H04", false],
	["CR_HeavyIdle", "KV_CombatIdle2H01", true],
	["CR_GroundPound", "Sword_GroundPound", false],
	["CR_SwordCombo", "Sword_Regular_Combo", false],
	["CR_HeavyCombo", "Sword_Heavy_Combo", false],
	["CR_Knee", "Melee_Knee", false],
	["CR_IdleWounded", "KV_IdleWounded01", true],
	["CR_Sprint", "KV_Sprint01_Forward", true],
	["CR_Death3", "KV_CombatDeath03", false],
	["CR_Death4", "KV_CombatDeath04", false],
	["CR_BowNotch", "Bow_Notch", false],
	["CR_BowAim", "Bow_Aim_Neutral", true],
	["CR_BowShoot", "Bow_Shoot", false],
	["CR_BowRapid", "Bow_RapidShoot", false],
	["CR_MG_Idle", "MG_Idle", true],
	["CR_MG_Walk", "MG_Walk", true],
	["CR_MG_WalkBack", "MG_Walk_Back", true],
	["CR_MG_WalkL", "MG_Walk_Left", true],
	["CR_MG_WalkR", "MG_Walk_Right", true],
	["CR_MG_Run", "MG_Run", true],
	["CR_MG_Throw", "MG_Cast_Throw", false],
	["CR_MG_Ground", "MG_Cast_Ground", false],
	["CR_MG_Blast", "MG_Cast_Blast", false],
	["CR_MG_Raise", "MG_Cast_2H", false],
	["CR_MG_Hit", "MG_Hit", false],
	["CR_MG_Death", "MG_Death", false],
	["CR_Staff1", "KV_AttackPolearm01", false],
	["CR_Staff2", "KV_AttackPolearm03", false],
	# Nock and draw (the hand on the string at 0.63 s, full at 1.05), held on
	# the aim a breath, and loosed at 1.45 s (BowFighter.LOOSE_AT).
	["CR_BowShot", [["Bow_Notch", 0.0, 1.25], ["Bow_Aim_Neutral", 0.0, 0.2], ["Bow_Shoot", 0.0, -1.0]], false],
	["CR_PunchCombo", "Melee_Combo", false],
	["CR_Hook", "Melee_Hook", false],
	["CR_Uppercut", "Melee_Uppercut", false],
	["CR_ZombieIdle", "Zombie_Idle", true],
	["CR_ZombieWalk", "Zombie_Walk_Fwd", true],
	["CR_ZombieRun", "Zombie_Run_Fwd", true],
	["CR_ZombieScratch", "Zombie_Scratch", false],
	["CR_ZombieBite", "Zombie_Bite", false],
	["CR_Rise", "Zombie_Spawn", false],
	# The zombies' and the ghoul's own (2026-10-06): up off the ground, the
	# shamble and the scuttle every way, and the ghoul's leap.
	["CR_GetUp", "LayToIdle", false],
	["CR_ZombieWalkBack", "Zombie_Walk_Bwd", true],
	["CR_ZombieWalkL", "Zombie_Walk_L", true],
	["CR_ZombieWalkR", "Zombie_Walk_R", true],
	["CR_ZombieRunBack", "Zombie_Run_Bwd", true],
	["CR_ZombieRunL", "Zombie_Run_L", true],
	["CR_ZombieRunR", "Zombie_Run_R", true],
	["CR_Leap", [["NinjaJump_Start", 0.0, -1.0], ["NinjaJump_Land", 0.0, -1.0]], false],
	# The goblin's and the ghoul's (2026-10-07): a stone thrown overhand, a
	# call to the others, the ghoul's scream into its frenzy, and bent over a
	# corpse, feeding.
	["CR_Throw", "OverhandThrow", false],
	["CR_Call", "Idle_Rail_Call", false],
	["CR_Transform", "MonsterTransformation", false],
	["CR_Harvest", "Farm_Harvest", false],
	["CR_Consume", "Consume", false],
	["CR_Surprise", "Surprise", false],
	# The ogre's strings (2026-10-08, the user's word: the same combo again and
	# again): UAL 2's sword strikes one by one, light and heavy, the dash, the
	# rising cut, turns about, a second kick, the polearm's sweeps; and going
	# down and back up for its stance broken.
	["CR_HeavyA", "Sword_Heavy_A", false],
	["CR_HeavyB", "Sword_Heavy_B", false],
	["CR_HeavyC", "Sword_Heavy_C", false],
	["CR_HeavyD", "Sword_Heavy_D", false],
	["CR_LightA", "Sword_Light_A", false],
	["CR_LightB", "Sword_Light_B", false],
	["CR_LightC", "Sword_Light_C", false],
	["CR_LightD", "Sword_Light_D", false],
	["CR_RegA", "Sword_Regular_A", false],
	["CR_RegB", "Sword_Regular_B", false],
	["CR_RegC", "Sword_Regular_C", false],
	["CR_SwordDash", "Sword_Dash", false],
	["CR_SwordUpper", "Sword_UpperCut", false],
	["CR_Turn180L", "Turn180_L", false],
	["CR_Turn180R", "Turn180_R", false],
	["CR_TurnL", "KV_Turn01_Left", false],
	["CR_TurnR", "KV_Turn01_Right", false],
	["CR_Kick2", "KV_AttackKick02_R", false],
	["CR_Polearm2", "KV_AttackPolearm02", false],
	["CR_Polearm4", "KV_AttackPolearm04", false],
	["CR_LayDown", "IdleToLay", false],
	["CR_KipUp", "KipUp", false],
	["CR_Knockback", "Hit_Knockback", false],
	# The orc's own (2026-10-13, the user's word: not the ogre's combos): a
	# blade in each hand — the left hand's cuts, both at once, its guard of
	# crossed blades and the blow it turns aside, drawing both; the leaping
	# cuts; a cross cut, the hilt in his face, a flourish, a stamp of a kick.
	["CR_SlashL1", "KV_Attack1H01_L", false],
	["CR_SlashL2", "KV_Attack1H02_L", false],
	["CR_SlashL3", "KV_Attack1H03_L", false],
	["CR_SlashL4", "KV_Attack1H04_L", false],
	["CR_SlashL5", "KV_Attack1H05_L", false],
	["CR_DW1", "KV_AttackDW01", false],
	["CR_DW2", "KV_AttackDW02", false],
	["CR_ParryDW", "KV_ParryDW01_Loop", true],
	["CR_ParryDWHit", "KV_ParryDW01_Hit", false],
	["CR_DrawBoth", "KV_UnsheatheHips01_Both", false],
	["CR_KickL", "KV_AttackKick02_L", false],
	["CR_CombatEnter", "KV_CombatEnter1H01", false],
	["CR_AerialA", "Sword_Aerial_A", false],
	["CR_AerialB", "Sword_Aerial_B", false],
	["CR_AerialCombo", "Sword_Aerial_Combo", false],
	["CR_LightCombo", "Sword_Light_Combo", false],
	["CR_Hilt", "SS_Hilt_Melee", false],
	["CR_CrossSlash", "SS_Cross_Slash", false],
	["CR_SwordPlay", "SS_Sword_Play_Idle", false],
	["CR_PowerUp", "SS_Power_Up", false],
	["CR_SpartaKick", "SS_Sparta_Kick", false],
	["CR_LowAttack", "SS_Low_Attack", false],
	["CR_HighAttack", "SS_High_Attack", false],
	["CR_RollQuick", "Roll_Quick_To_Run", false],
	# The orc's arms (2026-10-14, the user's word: a great sword on its
	# shoulder): a weapon at rest on the shoulder, Kevin's two-handed and
	# polearm stances, guards and the blows they take, and drawing them.
	["CR_Shoulder", "KV_ObjectGripShoulder01_R", true],
	["CR_Shoulder2", "KV_ObjectGripShoulder02_R", true],
	["CR_Hold2H", "KV_WeaponHold2H01", true],
	["CR_HoldPole", "KV_WeaponHoldPolearm01", true],
	["CR_Parry2H", "KV_Parry2H01_Loop", true],
	["CR_Parry2HHit", "KV_Parry2H01_Hit", false],
	["CR_PoleIdle", "KV_CombatIdlePolearm01", true],
	["CR_ParryPole", "KV_ParryPolearm01_Loop", true],
	["CR_ParryPoleHit", "KV_ParryPolearm01_Hit", false],
	["CR_Enter2H", "KV_CombatEnter2H01", false],
	["CR_EnterPole", "KV_CombatEnterPolearm01", false],
	["CR_Polearm1", "KV_AttackPolearm01", false],
	["CR_Polearm3", "KV_AttackPolearm03", false],
	# DoubleL's (2026-10-25, the troll's tree, the user's word: heavy blows
	# with a lean after and a slow way back): one-handed, a heavy weapon up
	["CR_DL_HeavyA1", "DL_1Hand_Up_Attack_A_1", false],
	["CR_DL_HeavyA2", "DL_1Hand_Up_Attack_A_2", false],
	["CR_DL_HeavyA3", "DL_1Hand_Up_Attack_A_3", false],
	["CR_DL_HeavyB1", "DL_1Hand_Up_Attack_B_1", false],
	["CR_DL_HeavyB2", "DL_1Hand_Up_Attack_B_2", false],
	["CR_DL_HeavyB3", "DL_1Hand_Up_Attack_B_3", false],
	["CR_DL_Lunge", "DL_Enemy_Attack_1", false],
	["CR_DL_RunLunge", "DL_Enemy_Attack_1_Run", false],
	["CR_DL_HitHeavy", "DL_Hit_B_4", false],
	["CR_DL_HitHeavy2", "DL_Hit_B_5", false],
	["CR_DL_HeavyIdle", "DL_1Hand_Up_Stand_Idle_A_2", true],
]

## Clips straight out of Mixamo (without skin, on X Bot), carried onto the
## figure the same way through Mixamo's bone names. Mixamo's skeleton has no
## root bone: a clip exported with its travel carries it in the hips, and
## that is taken out here as the root's would be (a cycle's straight drift
## only, an attack's whole path over the ground, to the meta).
## [name here, the fbx, a cycle, from s, to s (-1: its end)]
const MIXAMO := [
	# The ghoul running on all fours (2026-10-07, the user's pick).
	["CR_CrawlRun", "res://assets/creatures/anim/mixamo/Running_Crawl.fbx", true, 0.0, -1.0],
	# The ogre's gait (2026-10-09, the user's word: long heavy strides, a
	# lumbering trot, a real run when he runs from it).
	# (Its run is CR_Run, the long-strided one, played slower.)
	["CR_OgreWalk", "res://assets/creatures/anim/mixamo/Orc_Walk.fbx", true, 0.0, -1.0],
	["CR_OgreTrot", "res://assets/creatures/anim/mixamo/Weighted_Run.fbx", true, 0.0, -1.0],
	# Off its run at him from afar: the run-up, a great leap, down club first.
	["CR_RunJumpSlam", "res://assets/creatures/anim/mixamo/Run_Jump_Attack.fbx", false, 0.0, -1.0],
	# The ogre's authored combos (2026-10-10, candidates): Mixamo's great axe and
	# great sword packs and two-handed swings, the club two-handed.
	["CR_OG_Attack_Horizontal", "res://assets/creatures/anim/mixamo/OG_Attack_Horizontal.fbx", false, 0.0, -1.0],
	["CR_OG_Attack_Backhand", "res://assets/creatures/anim/mixamo/OG_Attack_Backhand.fbx", false, 0.0, -1.0],
	["CR_OG_Attack_Downward", "res://assets/creatures/anim/mixamo/OG_Attack_Downward.fbx", false, 0.0, -1.0],
	["CR_OG_Attack_360", "res://assets/creatures/anim/mixamo/OG_Attack_360.fbx", false, 0.0, -1.0],
	["CR_OG_Combo_1", "res://assets/creatures/anim/mixamo/OG_Combo_1.fbx", false, 0.0, -1.0],
	["CR_OG_Combo_2", "res://assets/creatures/anim/mixamo/OG_Combo_2.fbx", false, 0.0, -1.0],
	["CR_OG_Combo_3", "res://assets/creatures/anim/mixamo/OG_Combo_3.fbx", false, 0.0, -1.0],
	["CR_OG_Kick", "res://assets/creatures/anim/mixamo/OG_Kick.fbx", false, 0.0, -1.0],
	["CR_OG_Battlecry", "res://assets/creatures/anim/mixamo/OG_Battlecry.fbx", false, 0.0, -1.0],
	["CR_OG_Combo_Slash", "res://assets/creatures/anim/mixamo/OG_Combo_Slash.fbx", false, 0.0, -1.0],
	["CR_OG_Downward_Slash", "res://assets/creatures/anim/mixamo/OG_Downward_Slash.fbx", false, 0.0, -1.0],
	["CR_OG_Low_Slash", "res://assets/creatures/anim/mixamo/OG_Low_Slash.fbx", false, 0.0, -1.0],
	["CR_OG_Power_Slash", "res://assets/creatures/anim/mixamo/OG_Power_Slash.fbx", false, 0.0, -1.0],
	["CR_OG_Power_Up", "res://assets/creatures/anim/mixamo/OG_Power_Up.fbx", false, 0.0, -1.0],
	["CR_OG_Spin_Kick", "res://assets/creatures/anim/mixamo/OG_Spin_Kick.fbx", false, 0.0, -1.0],
	["CR_OG_Jump_Attack", "res://assets/creatures/anim/mixamo/OG_Jump_Attack.fbx", false, 0.0, -1.0],
	["CR_OG_Heavy_Swing", "res://assets/creatures/anim/mixamo/OG_Heavy_Swing.fbx", false, 0.0, -1.0],
	["CR_OG_TwoHand_Combo", "res://assets/creatures/anim/mixamo/OG_TwoHand_Combo.fbx", false, 0.0, -1.0],
	["CR_OG_Side_Kick", "res://assets/creatures/anim/mixamo/OG_Side_Kick.fbx", false, 0.0, -1.0],
	# ...and fresh from Mixamo for it (2026-10-10, vepxis-art/mixamo_ogre): the
	# club combos, an overhead bash, a swipe of its free hand, a headbutt, a
	# stamp, a leap at him, a two-handed blow down.
	["CR_OG_Club_Combo2H", "res://assets/creatures/anim/mixamo/OG_Club_Combo2H.fbx", false, 0.0, -1.0],
	["CR_OG_Club_Combo1H", "res://assets/creatures/anim/mixamo/OG_Club_Combo1H.fbx", false, 0.0, -1.0],
	["CR_OG_Bash", "res://assets/creatures/anim/mixamo/OG_Bash.fbx", false, 0.0, -1.0],
	["CR_OG_Mutant_Swipe", "res://assets/creatures/anim/mixamo/OG_Mutant_Swipe.fbx", false, 0.0, -1.0],
	["CR_OG_Headbutt", "res://assets/creatures/anim/mixamo/OG_Headbutt.fbx", false, 0.0, -1.0],
	["CR_OG_Stomp", "res://assets/creatures/anim/mixamo/OG_Stomp.fbx", false, 0.0, -1.0],
	["CR_OG_Mutant_Jump", "res://assets/creatures/anim/mixamo/OG_Mutant_Jump.fbx", false, 0.0, -1.0],
	["CR_OG_Zombie_Overhead", "res://assets/creatures/anim/mixamo/OG_Zombie_Overhead.fbx", false, 0.0, -1.0],
	# Its grab (2026-10-11, the user's word): Mixamo's one-handed choke lift,
	# mirrored — its free left hand; the right keeps the club.
	["CR_OG_Choke_Lift", "res://assets/creatures/anim/mixamo/OG_Choke_Lift_L.fbx", false, 0.0, -1.0],
	# The orc with a great weapon (2026-10-14, the user's word: two-handed, it
	# ran bent and looking aside): Mixamo's great sword pack — its stance,
	# walk and run with the sword held, its guard and the blow it takes, and
	# the high spinning cut (vepxis-art/mixamo_orc/GA_*).
	["CR_GS_Idle", "res://assets/creatures/anim/mixamo/GS_Idle.fbx", true, 0.0, -1.0],
	["CR_GS_Walk", "res://assets/creatures/anim/mixamo/GS_Walk.fbx", true, 0.0, -1.0],
	["CR_GS_Run", "res://assets/creatures/anim/mixamo/GS_Run.fbx", true, 0.0, -1.0],
	["CR_GS_Block", "res://assets/creatures/anim/mixamo/GS_Block_Idle.fbx", true, 0.0, -1.0],
	["CR_GS_Impact", "res://assets/creatures/anim/mixamo/GS_Impact.fbx", false, 0.0, -1.0],
	["CR_GS_HighSpin", "res://assets/creatures/anim/mixamo/GS_High_Spin_Attack.fbx", false, 0.0, -1.0],
	# ...and the rest of the pack, fresh (2026-10-14, the user's OK): its
	# strafes and its walk and run backwards, the blow on its guard and on its
	# head, the hilt in his face, the slide in from a run, the crouching cut,
	# its powering up, drawing it, and its pose struck at him.
	["CR_GS_WalkBack", "res://assets/creatures/anim/mixamo/GS_Walk_Back.fbx", true, 0.0, -1.0],
	["CR_GS_RunBack", "res://assets/creatures/anim/mixamo/GS_Run_Back.fbx", true, 0.0, -1.0],
	["CR_GS_StrafeL", "res://assets/creatures/anim/mixamo/GS_Strafe_L.fbx", true, 0.0, -1.0],
	["CR_GS_StrafeR", "res://assets/creatures/anim/mixamo/GS_Strafe_R.fbx", true, 0.0, -1.0],
	["CR_GS_BlockedImpact", "res://assets/creatures/anim/mixamo/GS_Blocked_Impact.fbx", false, 0.0, -1.0],
	["CR_GS_HeadImpact", "res://assets/creatures/anim/mixamo/GS_Head_Impact.fbx", false, 0.0, -1.0],
	["CR_GS_Hilt", "res://assets/creatures/anim/mixamo/GS_Hilt.fbx", false, 0.0, -1.0],
	["CR_GS_Slide", "res://assets/creatures/anim/mixamo/GS_Slide_Attack.fbx", false, 0.0, -1.0],
	["CR_GS_CrouchSlash", "res://assets/creatures/anim/mixamo/GS_Crouch_Slash.fbx", false, 0.0, -1.0],
	["CR_GS_PowerUp", "res://assets/creatures/anim/mixamo/GS_Power_Up.fbx", false, 0.0, -1.0],
	["CR_GS_Draw", "res://assets/creatures/anim/mixamo/GS_Draw.fbx", false, 0.0, -1.0],
	["CR_GS_Pose", "res://assets/creatures/anim/mixamo/GS_Strike_Pose.fbx", false, 0.0, -1.0],
	# The butcher's own (2026-10-23, the user's word: give him strings of his
	# own that run on, not the orc's): Mixamo's sword strings, its cuts in
	# and out, a thrust and cut, a swipe, a leap at him, a low spin, a kick,
	# the torch-in-hand two-blow strings (vepxis-art/mixamo_butcher/).
	["CR_BU_OneHand_Sword_Combo", "res://assets/creatures/anim/mixamo/BU_OneHand_Sword_Combo.fbx", false, 0.0, -1.0],
	["CR_BU_TwoHand_Sword_Combo", "res://assets/creatures/anim/mixamo/BU_TwoHand_Sword_Combo.fbx", false, 0.0, -1.0],
	["CR_BU_Thrust_Slash", "res://assets/creatures/anim/mixamo/BU_Thrust_Slash.fbx", false, 0.0, -1.0],
	["CR_BU_Outward_Slash", "res://assets/creatures/anim/mixamo/BU_Outward_Slash.fbx", false, 0.0, -1.0],
	["CR_BU_Inward_Slash", "res://assets/creatures/anim/mixamo/BU_Inward_Slash.fbx", false, 0.0, -1.0],
	["CR_BU_Zombie_Swipe", "res://assets/creatures/anim/mixamo/BU_Zombie_Swipe.fbx", false, 0.0, -1.0],
	["CR_BU_Run_Jump_Attack", "res://assets/creatures/anim/mixamo/BU_Run_Jump_Attack.fbx", false, 0.0, -1.0],
	["CR_BU_Attack_360_Low", "res://assets/creatures/anim/mixamo/BU_Attack_360_Low.fbx", false, 0.0, -1.0],
	["CR_BU_Kick_Axe", "res://assets/creatures/anim/mixamo/BU_Kick_Axe.fbx", false, 0.0, -1.0],
	["CR_BU_Torch_Combo_03", "res://assets/creatures/anim/mixamo/BU_Torch_Combo_03.fbx", false, 0.0, -1.0],
	["CR_BU_Torch_Combo_04", "res://assets/creatures/anim/mixamo/BU_Torch_Combo_04.fbx", false, 0.0, -1.0],
	["CR_BU_Torch_Combo_05", "res://assets/creatures/anim/mixamo/BU_Torch_Combo_05.fbx", false, 0.0, -1.0],
	# The troll's own (2026-10-25, the user's word: not the ogre's; a club of
	# its own and swings of its own that run on into each other): the great
	# swings of a man with a heavy bat, a drive up from low, a swing and its
	# knee, a butt-end jab, a swing up between its legs; its brutal walk, its
	# breathing, its roar (vepxis-art/mixamo_troll/).
	["CR_TR_Homerun", "res://assets/creatures/anim/mixamo/TR_Homerun.fbx", false, 0.0, -1.0],
	["CR_TR_BatSingle", "res://assets/creatures/anim/mixamo/TR_Bat_Single.fbx", false, 0.0, -1.0],
	["CR_TR_BatDouble", "res://assets/creatures/anim/mixamo/TR_Bat_Double.fbx", false, 0.0, -1.0],
	["CR_TR_BatStrike", "res://assets/creatures/anim/mixamo/TR_Bat_Strike.fbx", false, 0.0, -1.0],
	["CR_TR_GolfDrive", "res://assets/creatures/anim/mixamo/TR_Golf_Drive.fbx", false, 0.0, -1.0],
	["CR_TR_KneeJab", "res://assets/creatures/anim/mixamo/TR_Knee_Jab.fbx", false, 0.0, -1.0],
	["CR_TR_ButtSmash", "res://assets/creatures/anim/mixamo/TR_Butt_Smash.fbx", false, 0.0, -1.0],
	["CR_TR_KettleSwing", "res://assets/creatures/anim/mixamo/TR_Kettle_Swing.fbx", false, 0.0, -1.0],
	["CR_TR_MutantWalk", "res://assets/creatures/anim/mixamo/TR_Mutant_Walk.fbx", true, 0.0, -1.0],
	["CR_TR_MutantIdle", "res://assets/creatures/anim/mixamo/TR_Mutant_Idle.fbx", true, 0.0, -1.0],
	["CR_TR_Roar", "res://assets/creatures/anim/mixamo/TR_Mutant_Roar.fbx", false, 0.0, -1.0],
	# its second look (later the same day: no weapon but its body and the ground,
	# a tree torn up at half its health): fists, knees, a grab and slam, a
	# stomp, a tackle, lifting and throwing rock, flexing.
	["CR_TR_Flex", "res://assets/creatures/anim/mixamo/TR_Flex.fbx", false, 0.0, -1.0],
	["CR_TR_Stomp", "res://assets/creatures/anim/mixamo/TR_Floor_Stomp.fbx", false, 0.0, -1.0],
	["CR_TR_GoalieThrow", "res://assets/creatures/anim/mixamo/TR_Goalie_Throw.fbx", false, 0.0, -1.0],
	["CR_TR_Headbutt", "res://assets/creatures/anim/mixamo/TR_Headbutt_Grab.fbx", false, 0.0, -1.0],
	["CR_TR_Slammer", "res://assets/creatures/anim/mixamo/TR_Hell_Slammer.fbx", false, 0.0, -1.0],
	["CR_TR_KneesUppercut", "res://assets/creatures/anim/mixamo/TR_Knees_Uppercut.fbx", false, 0.0, -1.0],
	["CR_TR_Lift", "res://assets/creatures/anim/mixamo/TR_Lift_Heavy.fbx", false, 0.0, -1.0],
	["CR_TR_PullPlant", "res://assets/creatures/anim/mixamo/TR_Pull_Plant.fbx", false, 0.0, -1.0],
	["CR_TR_PullPlantKneel", "res://assets/creatures/anim/mixamo/TR_Pull_Plant_Kneel.fbx", false, 0.0, -1.0],
	["CR_TR_PickFloor", "res://assets/creatures/anim/mixamo/TR_Pick_Floor.fbx", false, 0.0, -1.0],
	["CR_TR_PullHeavy", "res://assets/creatures/anim/mixamo/TR_Pull_Heavy.fbx", false, 0.0, -1.0],
	["CR_TR_Hook", "res://assets/creatures/anim/mixamo/TR_Long_Hook.fbx", false, 0.0, -1.0],
	["CR_TR_Jab", "res://assets/creatures/anim/mixamo/TR_Mutant_Punch.fbx", false, 0.0, -1.0],
	["CR_TR_ChaseUppercut", "res://assets/creatures/anim/mixamo/TR_Surprise_Uppercut.fbx", false, 0.0, -1.0],
	["CR_TR_Tackle", "res://assets/creatures/anim/mixamo/TR_Tackle.fbx", false, 0.0, -1.0],
	["CR_TR_ThrowIn", "res://assets/creatures/anim/mixamo/TR_Throw_In.fbx", false, 0.0, -1.0],
	["CR_TR_ThrowObject", "res://assets/creatures/anim/mixamo/TR_Throw_Object.fbx", false, 0.0, -1.0],
	["CR_TR_GKFarThrow", "res://assets/creatures/anim/mixamo/TR_GK_Far_Throw.fbx", false, 0.0, -1.0],
	["CR_TR_MutantRun", "res://assets/creatures/anim/mixamo/TR_Mutant_Run.fbx", true, 0.0, -1.0],
	# The golem's own (2026-10-26, the user's word: not the troll's way; its
	# design shown in films first): fists and feet up close (a jab and cross,
	# a roundhouse, a hook, an uppercut, a drive kick, low, front and side
	# kicks, a cross), thorns all round, stamped-up stones drawn in and hurled,
	# four punches hurling air at him; its heavy walk and stand.
	["CR_GM_JabCross", "res://assets/creatures/anim/mixamo/GM_Jab_Cross.fbx", false, 0.0, -1.0],
	["CR_GM_Roundhouse", "res://assets/creatures/anim/mixamo/GM_Roundhouse.fbx", false, 0.0, -1.0],
	["CR_GM_Hook", "res://assets/creatures/anim/mixamo/GM_Hook.fbx", false, 0.0, -1.0],
	["CR_GM_Uppercut", "res://assets/creatures/anim/mixamo/GM_Uppercut.fbx", false, 0.0, -1.0],
	["CR_GM_DriveKick", "res://assets/creatures/anim/mixamo/GM_Drive_Kick.fbx", false, 0.0, -1.0],
	["CR_GM_LowKick", "res://assets/creatures/anim/mixamo/GM_Low_Kick.fbx", false, 0.0, -1.0],
	["CR_GM_FrontKick", "res://assets/creatures/anim/mixamo/GM_Front_Kick.fbx", false, 0.0, -1.0],
	["CR_GM_Cross", "res://assets/creatures/anim/mixamo/GM_Cross.fbx", false, 0.0, -1.0],
	["CR_GM_SideKick", "res://assets/creatures/anim/mixamo/GM_Side_Kick.fbx", false, 0.0, -1.0],
	["CR_GM_Thorns", "res://assets/creatures/anim/mixamo/GM_Thorns.fbx", false, 0.0, -1.0],
	["CR_GM_Stomp", "res://assets/creatures/anim/mixamo/GM_Stomp.fbx", false, 0.0, -1.0],
	["CR_GM_Hurl", "res://assets/creatures/anim/mixamo/GM_Hurl.fbx", false, 0.0, -1.0],
	["CR_GM_QuadPunch", "res://assets/creatures/anim/mixamo/GM_Quad_Punch.fbx", false, 0.0, -1.0],
	["CR_GM_Walk", "res://assets/creatures/anim/mixamo/GM_Walk.fbx", true, 0.0, -1.0],
	["CR_GM_Idle", "res://assets/creatures/anim/mixamo/GM_Idle.fbx", true, 0.0, -1.0],
]

## Mannequin bone -> Mixamo's (after "mixamorig").
const MIXAMO_NAMES := {
	"pelvis": "Hips", "spine_01": "Spine", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
	"ball_leaf_l": "LeftToe_End",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
	"ball_leaf_r": "RightToe_End",
}

## Clips made of two baked here: the legs (and hips) of the first, the body
## from the waist up of the second, the second looped under the first's
## length. The skeleton warrior walking in behind its raised shield.
## [name here, legs from, waist up from (, the bones whose limbs are taken
## instead of the waist's)]
const ARMS := ["L_clavicle_joint", "R_clavicle_joint"]
const LAYERED := [
	["CR_ShieldWalk", "CR_Walk", "CR_Block"],
	["CR_ShieldBack", "CR_WalkBack", "CR_Block"],
	["CR_ShieldL", "CR_StrafeL", "CR_Block"],
	["CR_ShieldR", "CR_StrafeR", "CR_Block"],
	# the orc's great weapon at rest on its shoulder as it walks and runs, held
	# before it roused; a polearm the same (2026-10-14)
	# (the arms alone, from the collarbones: the stance's twisted body and
	# its head turned aside on a run's legs bent it at the waist and looked
	# away from where it ran — the user's word, 2026-10-14)
	["CR_ShoulderWalk", "CR_Walk", "CR_Shoulder", ARMS],
	["CR_ShoulderRun", "CR_Run", "CR_Shoulder", ARMS],
	["CR_HeavyWalk", "CR_Walk", "CR_HeavyIdle", ARMS],
	["CR_HeavyRun", "CR_Run", "CR_HeavyIdle", ARMS],
	["CR_HeavyBack", "CR_WalkBack", "CR_HeavyIdle", ARMS],
	["CR_HeavyL", "CR_StrafeL", "CR_HeavyIdle", ARMS],
	["CR_HeavyR", "CR_StrafeR", "CR_HeavyIdle", ARMS],
	["CR_PoleWalk", "CR_Walk", "CR_HoldPole", ARMS],
	["CR_PoleRun", "CR_Run", "CR_PoleIdle", ARMS],
	["CR_PoleGuardWalk", "CR_Walk", "CR_PoleIdle", ARMS],
	["CR_PoleBack", "CR_WalkBack", "CR_PoleIdle", ARMS],
	["CR_PoleL", "CR_StrafeL", "CR_PoleIdle", ARMS],
	["CR_PoleR", "CR_StrafeR", "CR_PoleIdle", ARMS],
]

var _map := {}  # figure bone -> mannequin bone
var _aim := {}  # figure bone -> [figure child, mannequin child] its direction is taken toward


func _initialize() -> void:
	_run.call_deferred()


func _pairs() -> void:
	_map = {&"pelvis_joint": &"pelvis", &"waist_joint": &"spine_01", &"chest_joint": &"spine_03",
			&"neck_joint": &"neck_01", &"head_joint": &"Head"}
	_aim = {&"pelvis_joint": [&"waist_joint", &"spine_01"], &"waist_joint": [&"chest_joint", &"spine_03"],
			&"chest_joint": [&"neck_joint", &"neck_01"], &"neck_joint": [&"head_joint", &"Head"]}
	for s: String in ["l", "r"]:
		var S := s.to_upper()
		var chain := [["clavicle", "clavicle"], ["shoulder", "upperarm"], ["elbow", "lowerarm"], ["wrist", "hand"],
				["thigh", "thigh"], ["knee", "calf"], ["ankle", "foot"], ["ball", "ball"]]
		for i in chain.size():
			var f := StringName("%s_%s_joint" % [S, chain[i][0]])
			_map[f] = StringName("%s_%s" % [chain[i][1], s])
			if i != 3 and i != 7:
				_aim[f] = [StringName("%s_%s_joint" % [S, chain[i + 1][0]]), StringName("%s_%s" % [chain[i + 1][1], s])]
		_aim[StringName("%s_wrist_joint" % S)] = [StringName("%s_midFinger_joint1" % S), StringName("middle_01_%s" % s)]
		_aim[StringName("%s_ball_joint" % S)] = [StringName("%s_toe_joint" % S), StringName("ball_leaf_%s" % s)]
		for fg: Array in [["index", "index"], ["mid", "middle"], ["ring", "ring"], ["pinky", "pinky"], ["thumb", "thumb"]]:
			for k in 3:
				var f := StringName("%s_%sFinger_joint%d" % [S, fg[0], k + 1])
				_map[f] = StringName("%s_%02d_%s" % [fg[1], k + 1, s])
				if k < 2:
					_aim[f] = [StringName("%s_%sFinger_joint%d" % [S, fg[0], k + 2]), StringName("%s_%02d_%s" % [fg[1], k + 2, s])]


func _run() -> void:
	_pairs()
	var mq := (load(MQ) as PackedScene).instantiate() as Node3D
	root.add_child(mq)
	var src := mq.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := mq.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for src_lib: AnimationLibrary in [player.get_animation_library(&""), load(KV) as AnimationLibrary,
			load(MAGE) as AnimationLibrary, load(DL) as AnimationLibrary]:
		for clip: StringName in src_lib.get_animation_list():
			lib.add_animation(clip, src_lib.get_animation(clip))
	# Tariel's only where the rest have none of that name
	var tariel := load(TARIEL) as AnimationLibrary
	var his := {}
	for clip: StringName in tariel.get_animation_list():
		if not lib.has_animation(clip):
			lib.add_animation(clip, tariel.get_animation(clip))
			his[clip] = true
	# his own sword-and-shield clips came with the feet bent up at the ankle
	# (SkinnedRig.OWN_FOOT_FIX: the boots folded on him; the orc's feet too,
	# the user's word 2026-10-14): put right here as on him
	if not his.has(&"SS_Idle") and tariel.has_animation(&"SS_Idle"):
		lib.add_animation(&"SS_Idle", tariel.get_animation(&"SS_Idle"))
	var fixer := SkinnedRig.new()
	fixer._fix_own_feet(lib, src, his, float(SkinnedRig.OWN_FOOT_FIX[&"tariel"][0]),
			SkinnedRig.OWN_FOOT_FIX[&"tariel"][1])
	fixer.free()
	for clip: StringName in lib.get_animation_list():
		Moveset.complete(lib.get_animation(clip), src)
	for lib_name: StringName in player.get_animation_library_list():
		player.remove_animation_library(lib_name)
	player.add_animation_library(&"", lib)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	var fig_root := (load(FIG) as PackedScene).instantiate() as Node3D
	root.add_child(fig_root)
	var fig := fig_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var n := fig.get_bone_count()

	# Rests, parents first.
	var order := PackedInt32Array()
	var done := {}
	while order.size() < n:
		for i in n:
			if not done.has(i) and (fig.get_bone_parent(i) < 0 or done.has(fig.get_bone_parent(i))):
				order.append(i)
				done[i] = true
	var out_lib := AnimationLibrary.new()
	var meta := {}
	_bake(src, player, lib, CLIPS, func(m: String) -> String: return m, fig, order, out_lib, meta)
	for c: Array in MIXAMO:
		var mx := (load(String(c[1])) as PackedScene).instantiate() as Node3D
		root.add_child(mx)
		var mx_skel := mx.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mx_player := mx.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var take := StringName("")
		for clip_name: StringName in mx_player.get_animation_list():
			if String(clip_name) != "RESET":
				take = clip_name
				break
		var prefix := ""
		for i in mx_skel.get_bone_count():
			var bn := mx_skel.get_bone_name(i)
			if bn.ends_with("Hips"):
				prefix = bn.substr(0, bn.length() - 4)
				break
		var mx_lib := AnimationLibrary.new()
		mx_lib.add_animation(take, mx_player.get_animation(take))
		for lib_name: StringName in mx_player.get_animation_library_list():
			mx_player.remove_animation_library(lib_name)
		mx_player.add_animation_library(&"", mx_lib)
		mx_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_bake(mx_skel, mx_player, mx_lib, [[c[0], [[String(take), c[3], c[4]]], c[2]]],
				func(m: String) -> String: return prefix + _mixamo_name(m),
				fig, order, out_lib, meta, true)
		mx.queue_free()

	_layer(out_lib, meta, fig)

	# The bare skeleton and the player, as a scene SkeletonAnim can load.
	var holder := Node3D.new()
	holder.name = "BipedClips"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	holder.add_child(skel)
	skel.owner = holder
	for i in n:
		skel.add_bone(fig.get_bone_name(i))
	for i in n:
		skel.set_bone_parent(i, fig.get_bone_parent(i))
		skel.set_bone_rest(i, fig.get_bone_rest(i))
	skel.reset_bone_poses()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	holder.add_child(ap)
	ap.owner = holder
	ap.add_animation_library(&"", out_lib)
	var packed := PackedScene.new()
	packed.pack(holder)
	var err := ResourceSaver.save(packed, OUT)
	var file := FileAccess.open(META, FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()

	# Where the pack's weapons reach, in their bones' own frames (for the
	# Brawler's weapon_tip).
	for pair: Array in [["Skeleton_Warrior", "Skeleton_Warrior_Sword", "R_equip_joint"],
			["Orc", "Orc_Sword", "R_equip_joint"], ["Goblin", "Goblin_Club", "R_equip_joint"],
			["Ogre", "Ogre_Club", "R_equip_joint"], ["Skeleton_Mage", "Skeleton_Mage_Staff", "R_equip_joint"]]:
		var sc := (load("res://assets/creatures/%s.fbx" % pair[0]) as PackedScene).instantiate()
		var mi := sc.find_child(pair[1], true, false) as MeshInstance3D
		var sk := sc.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bone := sk.find_bone(pair[2])
		var bt := sk.get_bone_global_rest(bone)
		var far := Vector3.ZERO
		var far_d := 0.0
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var d := v.distance_to(bt.origin)
			if d > far_d:
				far_d = d
				far = v
		print("TIP ", pair[1], " on ", pair[2], " local ", bt.affine_inverse() * far, " length %.2f" % far_d)
		sc.free()
	print("SAVED ", OUT, " err ", err, " clips ", out_lib.get_animation_list().size())
	quit()


## A mannequin bone's name on Mixamo's skeleton (without the prefix).
func _mixamo_name(m: String) -> String:
	if MIXAMO_NAMES.has(m):
		return String(MIXAMO_NAMES[m])
	# The fingers: index_02_l -> LeftHandIndex2.
	var parts := m.split("_")
	if parts.size() == 3 and parts[1].is_valid_int():
		var side := "Left" if parts[2] == "l" else "Right"
		return "%sHand%s%d" % [side, parts[0].capitalize(), int(parts[1])]
	return "?" + m


## Every clip of `clips` ([name, mannequin clip or segments, a cycle]) off
## `src` playing `lib` in `player`, onto the figure, into `out_lib` and
## `meta`. `rename` turns a mannequin bone name into `src`'s own.
func _bake(src: Skeleton3D, player: AnimationPlayer, lib: AnimationLibrary, clips: Array, rename: Callable,
		fig: Skeleton3D, order: PackedInt32Array, out_lib: AnimationLibrary, meta: Dictionary,
		hips_root: bool = false) -> void:
	var n := fig.get_bone_count()
	var d_rest: Array[Transform3D] = []
	for i in n:
		d_rest.append(fig.get_bone_global_rest(i).orthonormalized())
	var s_rest: Array[Transform3D] = []
	for i in src.get_bone_count():
		s_rest.append(src.get_bone_global_rest(i).orthonormalized())
	var from := PackedInt32Array()
	from.resize(n)
	from.fill(-1)
	var offset: Array[Basis] = []  # rest_src⁻¹ · align · rest_fig, per figure bone
	offset.resize(n)
	for key: StringName in _map:
		var t := fig.find_bone(String(key))
		var s := src.find_bone(rename.call(String(_map[key])))
		if t < 0 or s < 0:
			push_error("no bone %s / %s" % [key, _map[key]])
			continue
		from[t] = s
		var align := Basis.IDENTITY
		if _aim.has(key):
			var tc := fig.find_bone(String(_aim[key][0]))
			var sc := src.find_bone(rename.call(String(_aim[key][1])))
			if tc >= 0 and sc >= 0:
				var a := (d_rest[tc].origin - d_rest[t].origin).normalized()
				var b := (s_rest[sc].origin - s_rest[s].origin).normalized()
				if a.length() > 0.5 and b.length() > 0.5 and a.dot(b) < 0.99999:
					var axis := a.cross(b)
					if axis.length() > 1e-6:
						align = Basis(axis.normalized(), a.angle_to(b))
		offset[t] = s_rest[s].basis.inverse() * align * d_rest[t].basis
	var hips := fig.find_bone("pelvis_joint")
	var s_hips := src.find_bone(rename.call("pelvis"))
	var s_root := src.find_bone(rename.call("root"))
	var k := d_rest[hips].origin.y / s_rest[s_hips].origin.y
	print("height ratio ", k)

	var g: Array[Transform3D] = []
	g.resize(n)
	for c: Array in clips:
		# A clip of several: [[mannequin clip, from s, to s], ...] played one
		# after the other (the archer's draw, aim and loose as one move).
		var segments: Array = (c[1] as Array).duplicate(true) if c[1] is Array else [[c[1], 0.0, -1.0]]
		var total := 0.0
		var missing := false
		for seg: Array in segments:
			if not lib.has_animation(StringName(seg[0])):
				push_error("no clip " + String(seg[0]))
				missing = true
				break
			var seg_len := lib.get_animation(StringName(seg[0])).length
			if float(seg[2]) < 0.0 or float(seg[2]) > seg_len:
				seg[2] = seg_len
			total += float(seg[2]) - float(seg[1])
		if missing:
			continue
		var loop: bool = c[2]
		var frames := maxi(int(round(total * FPS)), 1)
		var count := frames if loop else frames + 1
		var anim := Animation.new()
		anim.length = float(frames) / FPS
		anim.step = 1.0 / FPS
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		var rot_track := {}
		for t in n:
			if from[t] >= 0 or t == hips:
				var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(tr, NodePath("Skeleton3D:" + fig.get_bone_name(t)))
				rot_track[t] = tr
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, NodePath("Skeleton3D:pelvis_joint"))
		player.play(StringName(segments[0][0]))
		player.seek(float(segments[0][1]), true)
		var root0 := src.get_bone_global_pose(s_root).origin if s_root >= 0 else Vector3.ZERO
		# No root bone (Mixamo's): the travel is the hips' over the ground; a
		# cycle's only as a straight drift from its first frame to its last.
		var hips0 := src.get_bone_global_pose(s_hips).origin
		var drift := Vector3.ZERO
		if s_root < 0 and hips_root and loop and segments.size() == 1:
			player.seek(float(segments[0][2]), true)
			drift = src.get_bone_global_pose(s_hips).origin - hips0
			drift.y = 0.0
			player.seek(float(segments[0][1]), true)
		var path := []
		var playing := String(segments[0][0])
		for f in count:
			var time := minf(float(f) / FPS, total)
			var seg_i := 0
			while seg_i < segments.size() - 1 and time > float(segments[seg_i][2]) - float(segments[seg_i][1]):
				time -= float(segments[seg_i][2]) - float(segments[seg_i][1])
				seg_i += 1
			var seg: Array = segments[seg_i]
			if String(seg[0]) != playing:
				playing = String(seg[0])
				player.play(StringName(playing))
			player.seek(minf(float(seg[1]) + time, float(seg[2])), true)
			var travel := (src.get_bone_global_pose(s_root).origin - root0) if s_root >= 0 else Vector3.ZERO
			var in_place := false
			if s_root < 0 and hips_root:
				if loop:
					# a cycle is walked by the body's own pace, not its path
					travel = drift * (float(f) / float(maxi(frames, 1)))
					in_place = true
				else:
					travel = src.get_bone_global_pose(s_hips).origin - hips0
			travel.y = 0.0
			if in_place:
				path.append([0.0, 0.0, 0.0])
			else:
				path.append([snappedf(travel.z * k, 0.0001), snappedf(travel.x * k, 0.0001), 0.0])
			for t in order:
				var p := fig.get_bone_parent(t)
				var pg: Transform3D = g[p] if p >= 0 else Transform3D.IDENTITY
				var rest_local := fig.get_bone_rest(t).orthonormalized()
				var s := from[t]
				var gt: Transform3D
				if s >= 0:
					var pose := src.get_bone_global_pose(s).orthonormalized()
					gt.basis = (pose.basis * offset[t]).orthonormalized()
					if t == hips:
						gt.origin = d_rest[t].origin + (pose.origin - s_rest[s].origin - travel) * k
					else:
						gt.origin = pg * rest_local.origin
				else:
					gt = pg * rest_local
				g[t] = gt
				if rot_track.has(t):
					var local := pg.affine_inverse() * gt
					anim.rotation_track_insert_key(rot_track[t], float(f) / FPS, local.basis.get_rotation_quaternion())
					if t == hips:
						anim.position_track_insert_key(pos_track, float(f) / FPS, local.origin)
		player.stop()
		out_lib.add_animation(StringName(c[0]), anim)
		meta[String(c[0])] = {"frames": count, "fps": int(FPS), "loop": loop, "hips": path, "from": str(c[1])}
		print("CLIP ", c[0], " <- ", c[1], " frames ", count, " travel %.2f" % float(path[-1][0]))


## The LAYERED clips, out of clips already baked: every key of the legs'
## clip kept, the waist and all above it turned as the other clip has them
## at that moment (looped).
func _layer(out_lib: AnimationLibrary, meta: Dictionary, fig: Skeleton3D) -> void:
	var waist := fig.find_bone("waist_joint")
	for c: Array in LAYERED:
		var legs := out_lib.get_animation(StringName(c[1]))
		var upper := out_lib.get_animation(StringName(c[2]))
		if legs == null or upper == null:
			push_error("layered %s: missing %s / %s" % [c[0], c[1], c[2]])
			continue
		var anim := legs.duplicate(true) as Animation
		var swapped := 0
		var roots: Array = [waist]
		if c.size() > 3:
			roots = (c[3] as Array).map(func(n: String) -> int: return fig.find_bone(n))
		for tr in anim.get_track_count():
			if anim.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := fig.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
			var b := bone
			while b >= 0 and not roots.has(b):
				b = fig.get_bone_parent(b)
			if b < 0:
				continue
			var src := upper.find_track(anim.track_get_path(tr), Animation.TYPE_ROTATION_3D)
			if src < 0:
				continue
			for k in anim.track_get_key_count(tr):
				var t := fmod(anim.track_get_key_time(tr, k), upper.length)
				anim.track_set_key_value(tr, k, upper.rotation_track_interpolate(src, t))
			swapped += 1
		out_lib.add_animation(StringName(c[0]), anim)
		var m: Dictionary = (meta[String(c[1])] as Dictionary).duplicate(true)
		m["from"] = "%s legs, %s waist up" % [c[1], c[2]]
		meta[String(c[0])] = m
		print("LAYERED ", c[0], " bones from ", c[2], ": ", swapped)
