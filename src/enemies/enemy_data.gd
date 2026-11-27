class_name EnemyData
extends Resource
## Data-driven enemy stats. Behaviour lives in the matching Enemy subclass.

@export var id: StringName = &"mite"
@export var display_name := "Mite"
@export_group("Body")
@export var max_hp := 30.0
@export var speed_m := 5.0
@export var accel_m := 30.0
@export var radius_m := 0.4
@export var hit_height_m := 0.4
@export var mass := 1.0
@export var stagger_threshold := 30.0
@export var stagger_time := 0.8
@export var front_armor := 0.0          # damage reduction from the front arc
@export var back_mult := 1.0            # bonus damage from behind (weak spot)
@export var turn_rate := 12.0           # rad/s
@export var flying := false
@export var boss := false
## Can Fury's Lash drag it around? (volatile kamikazes are not; heavies drag the player instead)
@export var yankable := true
@export_group("Attack")
@export var damage := 10.0
@export var attack_range_m := 2.0
@export var attack_cooldown := 1.5
@export var telegraph_time := 0.4
@export_group("Rewards")
@export var xp := 6
@export var loot_chance := 0.04
@export_group("Presentation")
@export var sheet_move := "mite_run"
@export var sheet_attack := "mite_attack"
@export var stride_m := 1.4
@export var visual_scale := 1.0
## Multiplies the sprite colour (brighten dark silhouettes without re-rendering)
@export var body_tint := Color(1, 1, 1, 1)
@export var blood_color := Color(0.9, 0.15, 0.2)
@export var impact_style := "flesh"
@export var death_size := 1.0
