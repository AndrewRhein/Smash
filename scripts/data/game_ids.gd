class_name GameIds
extends RefCounted
## Single source of truth for every string ID shared between gameplay and
## presentation. Gameplay validates move data against these lists, and
## presentation adapters should register art under exactly these names.
## Add a new ID here first, then reference it from data/characters/*.tres.

# --- Characters --------------------------------------------------------------
const CHARACTER_GANDALF := &"gandalf"
const CHARACTER_VADER := &"vader"
const CHARACTER_ELON := &"elon"
# Vader is retained as a legacy regression fixture, not in the playable roster.
const CHARACTER_LEO := &"leo"
const CHARACTER_IDS := [&"gandalf", &"vader", &"elon", &"leo"]

# --- Move slots (also the stable move IDs) -----------------------------------
const MOVE_LIGHT := &"light"
const MOVE_HEAVY := &"heavy"
const MOVE_SPECIAL_1 := &"special_1"
const MOVE_SPECIAL_2 := &"special_2"
const MOVE_SPECIAL_3 := &"special_3"
## Recovery special (up + special). Usable once per airtime; leaves you helpless.
const MOVE_SPECIAL_UP := &"special_up"
const MOVE_SLOTS := [&"light", &"heavy", &"special_1", &"special_2", &"special_3", &"special_up"]
## Optional directional attacks (Smash tilts / smashes / aerials). A character
## may define any of these; missing ones fall back (see
## CharacterData.resolve_attack), so a character with only light/heavy works.
const OPTIONAL_MOVE_SLOTS := [
	&"light_up", &"light_down",                      # up / down tilt (ground)
	&"heavy_up", &"heavy_down",                      # up / down smash
	&"air_neutral", &"air_forward", &"air_back", &"air_up", &"air_down",  # aerials
]

# --- Shared (state-driven) animation IDs -------------------------------------
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_JUMP := &"jump"
const ANIM_FALL := &"fall"
const ANIM_HURT := &"hurt"
const ANIM_KNOCKBACK := &"knockback"
const ANIM_DEFEAT := &"defeat"
const ANIM_VICTORY := &"victory"
const ANIM_SHIELD := &"shield"
const ANIM_SHIELD_BREAK := &"shield_break"
const ANIM_SPOT_DODGE := &"spot_dodge"
const ANIM_ROLL := &"roll"
const ANIM_AIR_DODGE := &"air_dodge"
## Core states every character's art must cover.
const SHARED_ANIMATION_IDS := [
	&"idle", &"walk", &"run", &"jump", &"fall",
	&"hurt", &"knockback", &"defeat", &"victory",
]
## Shield / dodge states (docs/SMASH_CORE.md). Art is still pending for every
## character; adapters fall back to idle and the StatusVisual overlay shows them.
const MECHANIC_ANIMATION_IDS := [&"shield", &"shield_break", &"spot_dodge", &"roll", &"air_dodge"]

# --- Move-specific animation IDs ---------------------------------------------
const MOVE_ANIMATION_IDS := {
	&"gandalf": [&"staff_strike", &"heavy_staff", &"lightning", &"fireball", &"magic_push", &"wind_rise"],
	&"vader": [&"saber_slash", &"heavy_saber", &"force_push", &"force_choke", &"force_guard", &"force_leap"],
	&"elon": [&"ion_jab", &"rocket_hammer", &"thruster_burst", &"orbital_tractor", &"energy_shield"],
	&"leo": [&"palm_strike", &"crosier_smash", &"censer_swing", &"holy_tome", &"benediction", &"ascension",
		&"tome_lift", &"key_sweep", &"monstrance", &"flying_kick", &"heavenward_fist"],
}

# --- Effect IDs (effect_requested) -------------------------------------------
const EFFECT_HIT_SPARK := &"hit_spark"
const EFFECT_GUARD_BLOCK := &"guard_block"
const EFFECT_BLAST_KO := &"blast_ko"
const EFFECT_RESPAWN := &"respawn"
const EFFECT_DOUBLE_JUMP := &"double_jump"
const EFFECT_PROJECTILE_FIZZLE := &"projectile_fizzle"
const EFFECT_CHOKE_RELEASE := &"choke_release"
const EFFECT_IDS := [
	&"hit_spark", &"guard_block", &"blast_ko", &"respawn", &"double_jump",
	&"projectile_fizzle", &"choke_release",
	&"staff_swing", &"heavy_staff_swing", &"lightning_telegraph", &"lightning_bolt",
	&"fireball_cast", &"magic_push",
	&"saber_swing", &"heavy_saber_swing", &"force_push", &"force_choke", &"force_guard",
	&"ion_jab", &"rocket_hammer", &"thruster_burst", &"orbital_tractor", &"energy_shield",
]

# --- Damage types (used by Force guard) --------------------------------------
const DAMAGE_MELEE := &"melee"
const DAMAGE_MAGIC := &"magic"
const DAMAGE_PROJECTILE := &"projectile"
const DAMAGE_TYPES := [&"melee", &"magic", &"projectile"]

# --- Move special behaviours -------------------------------------------------
const SPECIAL_NONE := &""
const SPECIAL_CHOKE := &"choke"
const SPECIAL_GUARD := &"guard"
const SPECIAL_BEHAVIOURS := [&"", &"choke", &"guard"]


static func all_animation_ids() -> Array:
	var ids: Array = SHARED_ANIMATION_IDS + MECHANIC_ANIMATION_IDS
	for character_id: StringName in MOVE_ANIMATION_IDS:
		ids.append_array(MOVE_ANIMATION_IDS[character_id])
	return ids


static func is_animation_id(id: StringName) -> bool:
	return all_animation_ids().has(id)
