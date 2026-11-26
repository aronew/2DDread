class_name WeaponData
extends Resource
## Data-driven weapon definition. Duplicate a .tres in data/weapons to make a
## new weapon; the combat code never needs to change for a new gun.

@export var id: StringName = &"rifle"
@export var display_name := "Rifle"
@export_multiline var flavor := ""
## Player torso sprite sheet (assets/sprites/player/player_torso_<torso>.json)
@export var torso := "rifle"
@export_enum("auto", "semi", "charge") var fire_mode := "auto"

@export_group("Damage")
@export var damage := 10.0
@export var damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
@export var pellets := 1
@export var crit_chance := 0.05
@export var crit_mult := 2.0
@export var knockback_m := 1.0
@export var stagger := 5.0
@export var status := {}
@export var falloff_start_m := 999.0
@export var falloff_min := 1.0

@export_group("Firing")
@export var fire_interval := 0.1
@export var spread_deg := 2.0
@export var bloom_per_shot_deg := 0.0
@export var bloom_max_deg := 0.0
@export var bloom_recovery := 10.0
@export var charge_time := 0.0
@export var move_speed_mult := 1.0

@export_group("Projectile")
@export_enum("bolt", "pellet", "rail", "arc", "grenade", "acid", "missile") var proj_kind := "bolt"
@export var hitscan := false
@export var projectile_speed_m := 40.0
@export var range_m := 18.0
@export var pierce := 0
@export var ricochet := 0
@export var explode_radius_m := 0.0
@export var chain_count := 0
@export var chain_range_m := 3.5
@export var proj_color := Color(0.6, 0.85, 1.0)
@export var proj_width := 4.0
@export var proj_length_m := 0.8

@export_group("Ammo")
@export_enum("light", "shells", "cells", "heat", "charges") var ammo_type := "light"
@export var mag_size := 30
@export var reload_time := 1.4
@export var reload_per_round := false
@export var heat_per_shot := 0.0
@export var heat_cool_rate := 0.5
@export var overheat_time := 1.5

@export_group("Feel")
@export var recoil_kick := 4.0
@export var shake := 0.05
@export var hitstop := 0.0
@export var muzzle_color := Color(1.0, 0.85, 0.6)
@export var muzzle_scale := 1.0
@export var muzzle_wide := false
@export var muzzle_light := 1.6
@export var sound_fire := "rifle_fire"
@export var impact_style := "metal"
@export var icon_color := Color(0.7, 0.9, 1.0)
